defmodule AgentProof.PayPal.EvidencePayloadTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Evidence
  alias AgentProof.PayPal.EvidencePayload

  defp payload(dispute) do
    {:ok, package} = Evidence.generate_for_dispute(dispute.id)
    EvidencePayload.build(package, dispute.transaction)
  end

  test "a delivered purchase sends proof of fulfillment plus the agent's authorization" do
    dispute = disputed_case_fixture()
    transaction = dispute.transaction

    assert %{"evidences" => [fulfillment, other]} = payload(dispute)

    assert fulfillment["evidence_type"] == "PROOF_OF_FULFILLMENT"

    assert fulfillment["evidence_info"]["tracking_info"] == [
             %{"carrier_name" => "UPS", "tracking_number" => "1Z999AA10123456784"}
           ]

    assert other["evidence_type"] == "OTHER"
    assert other["notes"] =~ "Authorization: The customer authorized ShopBot"
    assert other["notes"] =~ "DEMO-ORDER-transaction-#{transaction.id}"
  end

  test "without a delivery, only the authorization evidence is sent" do
    dispute = disputed_case_fixture(delivered_at: nil)

    assert %{"evidences" => [%{"evidence_type" => "OTHER"}]} = payload(dispute)
  end

  test "notes are capped at the conservative limit" do
    dispute = disputed_case_fixture()
    {:ok, package} = Evidence.generate_for_dispute(dispute.id)
    long = %{package | summary: String.duplicate("evidence ", 400)}

    %{"evidences" => evidences} = EvidencePayload.build(long, dispute.transaction)
    other = List.last(evidences)

    assert String.length(other["notes"]) == EvidencePayload.max_notes()
    assert String.ends_with?(other["notes"], "…")
  end
end
