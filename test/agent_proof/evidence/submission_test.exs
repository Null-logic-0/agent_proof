defmodule AgentProof.Evidence.SubmissionTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.{Disputes, Evidence}
  alias AgentProof.Disputes.Dispute
  alias AgentProof.PayPal.TestClient

  setup do
    dispute = disputed_case_fixture()
    {:ok, package} = Evidence.generate_for_dispute(dispute.id)
    %{dispute: dispute, package: package}
  end

  test "unapproved evidence cannot be submitted", %{package: package} do
    assert Evidence.submit(package) == {:error, :not_approved}
  end

  test "prepare_submission/1 shows the target, the payload, and the mode",
       %{dispute: dispute, package: package} do
    submission = Evidence.prepare_submission(package)

    assert submission.dispute_id == "DEMO-PP-D-#{dispute.transaction.id}"
    assert submission.simulated?
    assert %{"evidences" => [_fulfillment, _other]} = submission.payload
  end

  test "approved evidence is submitted, the dispute is final, and the evidence frozen",
       %{dispute: dispute, package: package} do
    {:ok, approved} = Evidence.approve(package)

    assert {:ok, %{dispute: submitted, simulated?: true}} = Evidence.submit(approved)
    assert submitted.status == :submitted
    assert %DateTime{} = submitted.submitted_at

    approved = Repo.reload!(approved)
    assert Evidence.submit(approved) == {:error, :already_submitted}
    assert Evidence.withdraw_approval(approved) == {:error, :already_submitted}
    assert Evidence.generate_for_dispute(dispute.id) == {:error, :already_submitted}
  end

  test "a PayPal failure leaves the dispute approved and unsubmitted",
       %{dispute: dispute, package: package} do
    {:ok, approved} = Evidence.approve(package)

    assert Evidence.submit(approved, adapter: TestClient, fail: :submit) ==
             {:error, {:paypal, 422, "UNPROCESSABLE_ENTITY"}}

    reloaded = Disputes.get_dispute!(dispute.id)
    assert reloaded.status == :evidence_ready
    assert reloaded.submitted_at == nil
  end

  test "only DEMO- disputes are simulated" do
    assert Dispute.simulated?(%Dispute{paypal_dispute_id: "DEMO-PP-D-1"})
    refute Dispute.simulated?(%Dispute{paypal_dispute_id: "PP-D-12345"})
  end
end
