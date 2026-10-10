defmodule AgentProof.PayPal.Sandbox do
  @moduledoc """
  PayPal adapter for the Sandbox REST API. Capture is simulated: it needs a buyer's approval.
  """

  @behaviour AgentProof.PayPal.Client

  @impl true
  def name, do: "sandbox"

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
  Sends evidence as multipart form data, with the JSON in a part named `input`.
  """
  @impl true
  def submit_evidence(dispute_id, payload, _opts) do
    with {:ok, token} <- access_token(),
         {:ok, _body} <-
           request(:post, "/v1/customer/disputes/:id/provide-evidence",
             auth: {:bearer, token},
             path_params: [id: dispute_id],
             form_multipart: [input: {Jason.encode!(payload), content_type: "application/json"}]
           ) do
      {:ok, %{simulated: false}}
    end
  end

  @doc """
  Fetches an order from PayPal, to check that it really exists.
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
