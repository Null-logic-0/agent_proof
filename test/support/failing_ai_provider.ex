defmodule AgentProof.AI.FailingProvider do
  @moduledoc """
  AI provider that always fails as if the AI server were down, used to test
  the investigation's error state.
  """

  @behaviour AgentProof.AI.Provider

  @impl true
  def name, do: "failing"

  @impl true
  def generate(_request, _opts), do: {:error, {:transport, :econnrefused}}
end
