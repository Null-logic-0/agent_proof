defmodule AgentProof.Agents.ShoppingAgentTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Agents.ShoppingAgent
  alias AgentProof.PayPal.TestClient
  alias AgentProof.Transactions
  alias AgentProof.Transactions.AgentAction

  setup do
    %{authorization: authorization_fixture(agent_fixture())}
  end

  test "buys a matching product and stores its action log in order",
       %{authorization: authorization} do
    assert {:ok, transaction} = ShoppingAgent.run(authorization, "headphones")

    assert transaction.product_name == "Sony WH-1000XM5 Headphones"
    assert transaction.status == :completed
    assert Decimal.equal?(transaction.amount, "189.99")

    assert [
             %AgentAction{action: :search_products, actor: :agent} = searched,
             %AgentAction{action: :select_product, actor: :agent} = selected,
             %AgentAction{action: :budget_check, actor: :system},
             %AgentAction{action: :create_paypal_order, actor: :system},
             %AgentAction{action: :capture_payment, actor: :system}
           ] = transaction.agent_actions

    assert searched.details == %{"query" => "headphones", "results" => 1}
    assert selected.details["price"] == "189.99"

    times = Enum.map(transaction.agent_actions, & &1.at)
    assert times == Enum.sort(times, DateTime)
  end

  test "the action log reloads as typed structs", %{authorization: authorization} do
    {:ok, transaction} = ShoppingAgent.run(authorization, "headphones")

    reloaded = Transactions.get_transaction!(transaction.id)

    assert reloaded.agent_actions == transaction.agent_actions
    assert %DateTime{} = hd(reloaded.agent_actions).at
  end

  test "the budget, not the agent, blocks an over-limit product",
       %{authorization: authorization} do
    assert ShoppingAgent.run(authorization, "laptop") == {:error, :exceeds_budget}
    assert Transactions.list_transactions() == []
  end

  test "an over-limit product is blocked before PayPal is ever called",
       %{authorization: authorization} do
    # If PayPal were reached, this adapter would turn it into :payment_failed.
    assert ShoppingAgent.run(authorization, "laptop", adapter: TestClient, fail: :create) ==
             {:error, :exceeds_budget}
  end

  test "reports when nothing matches", %{authorization: authorization} do
    assert ShoppingAgent.run(authorization, "unicorn") == {:error, :no_matching_product}
  end
end
