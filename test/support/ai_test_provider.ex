defmodule AgentProof.AI.TestProvider do
  @moduledoc """
  AI provider for tests: returns whatever the test passes as `reply:`, or
  calls it with the request when it is a function.

      AI.generate(request, provider: TestProvider, reply: {:ok, %{"summary" => 1}})
      AI.generate(request, provider: TestProvider, reply: fn request -> ... end)
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
