defmodule AgentProof.AI.Provider do
  @moduledoc """
  Behaviour every AI provider implements (Demo, Ollama, OpenAI).
  """

  @type request :: %{
          task: :evidence | :search_query,
          system: String.t(),
          prompt: String.t(),
          schema: map(),
          facts: map()
        }

  @doc "Generates evidence for `request`. Returns the decoded JSON, unvalidated."
  @callback generate(request(), opts :: keyword()) :: {:ok, map()} | {:error, term()}

  @doc ~s(Label stored in `evidence.ai_provider`, e.g. "demo" or "ollama:llama3.2".)
  @callback name() :: String.t()
end
