defmodule AgentProof.DemoScenarioTest do
  use AgentProof.DataCase, async: true

  alias AgentProof.{AI, DemoScenario, PayPal, Transactions}

  test "builds a complete disputed case through the real contexts, ready for review" do
    assert {:ok, transaction} = DemoScenario.run(adapter: PayPal.Demo, provider: AI.Demo)

    disputed = Transactions.get_case!(transaction.id)
    assert disputed.authorization.agent.name == "DemoBot"
    assert disputed.status == :completed
    assert disputed.paypal_order_id == "DEMO-ORDER-transaction-#{disputed.id}"
    assert %{carrier: "UPS"} = disputed.fulfillment
    assert disputed.dispute.reason == :unauthorized
    assert disputed.dispute.status == :evidence_ready
    assert disputed.dispute.evidence.ai_provider == "demo"
    assert disputed.dispute.evidence.approved_at == nil

    facts = Transactions.reconstruct(disputed, disputed.dispute)
    assert Enum.all?(facts["checks"], fn {_check, result} -> result == true end)

    ids = disputed |> Transactions.timeline() |> Enum.map(& &1.id)
    assert Enum.take(ids, -3) == ["fulfillment", "dispute", "evidence"]
  end
end
