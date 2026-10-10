defmodule AgentProof.AI.OpenAI do
  @moduledoc """
  Optional AI provider for OpenAI.
  """

  @behaviour AgentProof.AI.Provider

  @impl true
  def name, do: "openai:" <> config!(:model)

  @impl true
  def generate(request, _opts) do
    body = %{
      model: config!(:model),
      input: [
        %{role: "system", content: request.system},
        %{role: "user", content: request.prompt}
      ],
      text: %{
        format: %{
          type: "json_schema",
          name: "dispute_evidence",
          schema: request.schema,
          strict: true
        }
      }
    }

    options =
      [
        method: :post,
        base_url: config!(:base_url),
        url: "/v1/responses",
        auth: {:bearer, config!(:api_key)},
        json: body,
        receive_timeout: 120_000
      ]
      |> Keyword.merge(config(:req_options, []))

    case Req.request(options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parse(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:openai, status, error_code(body)}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport, reason}}

      {:error, exception} ->
        {:error, {:transport, exception.__struct__}}
    end
  end

  defp parse(%{"status" => "incomplete"} = body) do
    {:error, {:incomplete, get_in(body, ["incomplete_details", "reason"])}}
  end

  defp parse(%{"output" => output}) when is_list(output) do
    # Reasoning models put a "reasoning" item before the assistant "message".
    content =
      Enum.find_value(output, [], fn
        %{"type" => "message", "content" => content} -> content
        _other -> nil
      end)

    cond do
      refusal = content_value(content, "refusal", "refusal") -> {:error, {:refusal, refusal}}
      text = content_value(content, "output_text", "text") -> decode(text)
      true -> {:error, :invalid_json}
    end
  end

  defp parse(_body), do: {:error, :invalid_json}

  defp content_value(content, type, key) do
    Enum.find_value(content, fn item -> item["type"] == type && item[key] end)
  end

  # The model's answer arrives as a JSON string inside the JSON response body.
  defp decode(text) do
    case Jason.decode(text) do
      {:ok, %{} = evidence} -> {:ok, evidence}
      _not_an_object -> {:error, :invalid_json}
    end
  end

  defp error_code(%{"error" => %{} = error}),
    do: error["code"] || error["type"] || "unknown_error"

  defp error_code(_body), do: "unknown_error"

  defp config!(key), do: Keyword.fetch!(settings(), key)
  defp config(key, default), do: Keyword.get(settings(), key, default)
  defp settings, do: Application.get_env(:agent_proof, __MODULE__, [])
end
