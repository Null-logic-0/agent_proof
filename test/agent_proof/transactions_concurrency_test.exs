defmodule AgentProof.TransactionsConcurrencyTest do
  # Runs outside the SQL sandbox on purpose. Inside the sandbox every process
  # shares one connection, so queries run one at a time and a race can never
  # happen. Here each task gets its own real connection and real commits.
  #
  # `async: false` guarantees ExUnit runs this after all async tests finish,
  # so no other test can see the rows committed here.
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias AgentProof.{Agents, Authorizations, Repo, Transactions}
  alias AgentProof.Agents.Agent
  alias AgentProof.Authorizations.Authorization
  alias AgentProof.Transactions.Transaction

  setup do
    :ok = Sandbox.checkout(Repo, sandbox: false)

    {:ok, agent} = Agents.create_agent(%{name: "Concurrency Bot"})

    {:ok, authorization} =
      Authorizations.create_authorization(agent, %{
        max_amount: "200.00",
        currency: "USD",
        description: "Concurrency test budget"
      })

    on_exit(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)
      Repo.delete_all(from t in Transaction, where: t.authorization_id == ^authorization.id)
      Repo.delete_all(from a in Authorization, where: a.id == ^authorization.id)
      Repo.delete_all(from a in Agent, where: a.id == ^agent.id)
    end)

    %{authorization: authorization}
  end

  test "concurrent purchases never exceed the budget", %{authorization: authorization} do
    product = %{name: "USB-C cable", price: Decimal.new("50.00"), currency: "USD"}

    results =
      1..5
      |> Task.async_stream(
        fn _ ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          Transactions.purchase(authorization, product)
        end,
        max_concurrency: 5,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 4
    assert Enum.count(results, &(&1 == {:error, :exceeds_budget})) == 1
    assert Decimal.equal?(Transactions.spent_amount(authorization), "200.00")
  end
end
