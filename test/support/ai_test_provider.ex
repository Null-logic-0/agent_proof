defmodule AgentProof.AI.TestProvider do
  @moduledoc """
  AI provider for tests: returns whatever the test passes as `reply:`.

      AI.generate(request, provider: TestProvider, reply: {:ok, %{"summary" => 1}})
  """

  @behaviour AgentProof.AI.Provider

  @impl true
  def name, do: "test"

  @impl true
  def generate(_request, opts), do: Keyword.get(opts, :reply, {:error, :no_reply})
end
