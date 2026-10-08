defmodule AgentProof.AI.GenerateEvidenceTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.{AI, Transactions}
  alias AgentProof.AI.{EvidenceSchema, Prompt, TestProvider}

  test "sends the reconstructed facts, prompts, and schema to the provider" do
    dispute = disputed_case_fixture()
    facts = Transactions.reconstruct(dispute.transaction, dispute)

    capture_request = fn request ->
      send(self(), {:request, request})
      {:ok, %{"summary" => "stub"}}
    end

    assert AI.generate_evidence(dispute.transaction, dispute,
             provider: TestProvider,
             reply: capture_request
           ) == {:ok, %{"summary" => "stub"}}

    assert_received {:request, request}
    assert request.facts == facts
    assert request.system == Prompt.system()
    assert request.prompt == Prompt.user(facts)
    assert request.schema == EvidenceSchema.json_schema()
  end

  test "works end to end with AI.Demo on a real case" do
    dispute = disputed_case_fixture()

    assert {:ok, evidence} = AI.generate_evidence(dispute.transaction, dispute)

    assert evidence["summary"] =~
             "ShopBot bought Sony WH-1000XM5 Headphones for 189.99 USD, " <>
               "within the 200.00 USD budget"

    assert evidence["transaction_evidence"]["statement"] =~
             "DEMO-ORDER-transaction-#{dispute.transaction.id}"
  end

  test "returns provider errors untouched" do
    dispute = disputed_case_fixture()

    assert AI.generate_evidence(dispute.transaction, dispute,
             provider: TestProvider,
             reply: {:error, {:transport, :econnrefused}}
           ) == {:error, {:transport, :econnrefused}}
  end
end
