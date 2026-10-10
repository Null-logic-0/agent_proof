defmodule AgentProof.AI.TestProvider do
  @moduledoc """
  AI provider for tests that returns whatever the test passes as `reply:`.
  """

  @behaviour AgentProof.AI.Provider

  @impl true
  def name, do: "test"

  @impl true
  def generate(request, opts) do
    case Keyword.get(opts, :reply, {:error, :no_reply}) do
      reply when is_function(reply, 1) -> reply.(request)
      reply -> reply
    end
  end
end
