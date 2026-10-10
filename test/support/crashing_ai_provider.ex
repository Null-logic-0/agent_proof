defmodule AgentProof.AI.CrashingProvider do
  @moduledoc """
  AI provider that raises, as a bug would, used to test the investigation's
  error state. A crash is not an answer, so nothing falls back to AI.Demo.
  """

  @behaviour AgentProof.AI.Provider

  @impl true
  def name, do: "crashing"

  @impl true
  def generate(_request, _opts), do: raise("the AI provider crashed")
end
