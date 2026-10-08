defmodule AgentProof.AI.Ollama do
  @moduledoc """
  AI provider for a local Ollama server.

  Uses structured output: the request's JSON Schema is sent as `format`, so
  the model can only produce JSON of that shape. The shape is guaranteed;
  the content still has to be validated.

  Configuration (`config :agent_proof, AgentProof.AI.Ollama`):

    * `:base_url` - the Ollama server, e.g. "http://localhost:11434"
    * `:model` - a pulled model, e.g. "llama3.2"
    * `:req_options` - extra `Req` options, applied last (tests use `Req.Test`)

  Errors are normalized to `{:ollama, status, message}`, `{:transport, reason}`,
  or `:invalid_json`.
  """

  @behaviour AgentProof.AI.Provider

  @impl true
  def name, do: "ollama:" <> config!(:model)

  @impl true
  def generate(request, _opts) do
    body = %{
      model: config!(:model),
      messages: [
        %{role: "system", content: request.system},
        %{role: "user", content: request.prompt}
      ],
      format: request.schema,
      stream: false,
      options: %{temperature: 0},
      # Keep the model in memory between calls, so a demo never waits on a cold start.
      keep_alive: "10m"
    }

    options =
      [
        method: :post,
        base_url: config!(:base_url),
        url: "/api/chat",
        json: body,
        receive_timeout: 120_000
      ]
      |> Keyword.merge(config(:req_options, []))

    case Req.request(options) do
      {:ok, %Req.Response{status: 200, body: %{"message" => %{"content" => content}}}} ->
        decode(content)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:ollama, status, error_message(body)}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport, reason}}

      {:error, exception} ->
        {:error, {:transport, exception.__struct__}}
    end
  end

  # The model's answer arrives as a JSON string inside the JSON response body.
  defp decode(content) do
    case Jason.decode(content) do
      {:ok, %{} = evidence} -> {:ok, evidence}
      _not_an_object -> {:error, :invalid_json}
    end
  end

  defp error_message(%{"error" => message}) when is_binary(message), do: message
  defp error_message(_body), do: "unknown error"

  defp config!(key), do: Keyword.fetch!(settings(), key)
  defp config(key, default), do: Keyword.get(settings(), key, default)
  defp settings, do: Application.get_env(:agent_proof, __MODULE__, [])
end
