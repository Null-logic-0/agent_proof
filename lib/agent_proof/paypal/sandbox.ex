defmodule AgentProof.PayPal.Sandbox do
  @moduledoc """
  PayPal adapter for the PayPal Sandbox REST API.

  Real: the OAuth client-credentials token and order creation.

  Simulated: capture. PayPal only captures orders that a buyer has approved;
  an agent paying with no buyer present needs PayPal Vault, which is out of
  scope for the MVP. Captures are returned with `simulated: true`.

  Configuration (`config :agent_proof, AgentProof.PayPal.Sandbox`):

    * `:base_url` - REST API host, e.g. "https://api-m.sandbox.paypal.com"
    * `:client_id`, `:client_secret` - the REST app's credentials
    * `:req_options` - extra `Req` options, applied last (tests use `Req.Test`)

  Errors are normalized to `{:paypal, status, name}` or `{:transport, reason}`
  so that tokens and secrets never reach logs or the database.
  """

  @behaviour AgentProof.PayPal.Client

  @impl true
  def create_order(order, _opts) do
    body = %{
      intent: "CAPTURE",
      purchase_units: [
        %{
          reference_id: order.reference_id,
          description: order.description,
          amount: %{
            currency_code: order.currency,
            value: order.amount |> Decimal.round(2) |> Decimal.to_string()
          }
        }
      ]
    }

    with {:ok, token} <- access_token(),
         {:ok, %{"id" => order_id}} <-
           request(:post, "/v2/checkout/orders",
             auth: {:bearer, token},
             json: body,
             # Same id on every retry of this call, so PayPal never creates a duplicate.
             headers: [{"paypal-request-id", Ecto.UUID.generate()}],
             retry: :transient,
             max_retries: 2
           ) do
      {:ok, %{order_id: order_id}}
    end
  end

  @impl true
  def capture_order(order_id, _opts) do
    {:ok, %{order_id: order_id, capture_id: "SIMULATED-CAPTURE-" <> order_id, simulated: true}}
  end

  @doc """
  Fetches an order from PayPal. Not part of the adapter contract; used to
  verify that an order really exists at PayPal.
  """
  def get_order(order_id) do
    with {:ok, token} <- access_token(),
         {:ok, %{"id" => id, "status" => status}} <-
           request(:get, "/v2/checkout/orders/:id",
             auth: {:bearer, token},
             path_params: [id: order_id]
           ) do
      {:ok, %{order_id: id, status: status}}
    end
  end

  defp access_token do
    with {:ok, %{"access_token" => token}} <-
           request(:post, "/v1/oauth2/token",
             auth: {:basic, "#{config!(:client_id)}:#{config!(:client_secret)}"},
             form: [grant_type: "client_credentials"]
           ) do
      {:ok, token}
    end
  end

  defp request(method, path, options) do
    options =
      [method: method, base_url: config!(:base_url), url: path, receive_timeout: 10_000]
      |> Keyword.merge(options)
      |> Keyword.merge(config(:req_options, []))

    case Req.request(options) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:paypal, status, error_name(body)}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport, reason}}

      {:error, exception} ->
        {:error, {:transport, exception.__struct__}}
    end
  end

  # The Orders API names errors in "name"; the OAuth endpoint uses "error".
  defp error_name(%{"name" => name}), do: name
  defp error_name(%{"error" => error}), do: error
  defp error_name(_body), do: "UNKNOWN_ERROR"

  defp config!(key), do: Keyword.fetch!(settings(), key)
  defp config(key, default), do: Keyword.get(settings(), key, default)
  defp settings, do: Application.get_env(:agent_proof, __MODULE__, [])
end
