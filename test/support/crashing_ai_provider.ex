defmodule AgentProof.AI.CrashingProvider do
  @moduledoc """
  AI provider that raises, to test the investigation's error state.
  """

  @behaviour AgentProof.AI.Provider

  @impl true
  def name, do: "crashing"

  @impl true
  def generate(_request, _opts), do: raise("the AI provider crashed")
end
