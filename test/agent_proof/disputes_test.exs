defmodule AgentProof.DisputesTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Disputes
  alias AgentProof.Disputes.Dispute

  setup do
    agent = agent_fixture()
    authorization = authorization_fixture(agent)

    %{agent: agent, transaction: transaction_fixture(authorization)}
  end

  test "rejects a reason outside the enum", %{transaction: transaction} do
    changeset =
      Dispute.changeset(%Dispute{transaction_id: transaction.id}, %{
        paypal_dispute_id: "PP-D-1",
        reason: "UNAUTHORISED",
        status: :open
      })

    assert "is invalid" in errors_on(changeset).reason
  end

  test "a second dispute on the same transaction becomes a changeset error",
       %{transaction: transaction} do
    dispute_fixture(transaction)

    assert {:error, changeset} =
             %Dispute{transaction_id: transaction.id}
             |> Dispute.changeset(%{paypal_dispute_id: "PP-D-2", reason: :other, status: :open})
             |> Repo.insert()

    assert "has already been taken" in errors_on(changeset).transaction_id
  end

  test "get_dispute!/1 returns the dispute", %{transaction: transaction} do
    dispute = dispute_fixture(transaction)

    assert Disputes.get_dispute!(dispute.id) == dispute
  end

  describe "open_dispute/3" do
    test "opens a dispute with system-set id, status, and due date",
         %{transaction: transaction} do
      assert {:ok, %Dispute{} = dispute} =
               Disputes.open_dispute(transaction, %{reason: :unauthorized}, today: ~D[2026-10-08])

      assert dispute.transaction_id == transaction.id
      assert dispute.reason == :unauthorized
      assert dispute.status == :open
      assert dispute.paypal_dispute_id == "DEMO-PP-D-#{transaction.id}"
      assert dispute.due_date == ~D[2026-10-18]
    end

    test "accepts string-key params from a form", %{transaction: transaction} do
      assert {:ok, %Dispute{reason: :not_received}} =
               Disputes.open_dispute(transaction, %{"reason" => "not_received"})
    end

    test "ignores status, PayPal id, and due date from input", %{transaction: transaction} do
      {:ok, dispute} =
        Disputes.open_dispute(
          transaction,
          %{
            reason: :other,
            status: :submitted,
            paypal_dispute_id: "PP-D-FAKE",
            due_date: ~D[2030-01-01]
          },
          today: ~D[2026-10-08]
        )

      assert dispute.status == :open
      assert dispute.paypal_dispute_id == "DEMO-PP-D-#{transaction.id}"
      assert dispute.due_date == ~D[2026-10-18]
    end

    test "requires a known reason", %{transaction: transaction} do
      assert {:error, changeset} = Disputes.open_dispute(transaction, %{})
      assert "can't be blank" in errors_on(changeset).reason

      assert {:error, changeset} = Disputes.open_dispute(transaction, %{reason: "chargeback"})
      assert "is invalid" in errors_on(changeset).reason
    end

    test "only paid transactions can be disputed", %{agent: agent} do
      authorization = authorization_fixture(agent)

      for status <- [:created, :failed] do
        transaction = transaction_fixture(authorization, %{status: status})

        assert Disputes.open_dispute(transaction, %{reason: :unauthorized}) ==
                 {:error, :not_disputable}
      end
    end

    test "a transaction can only be disputed once", %{transaction: transaction} do
      assert {:ok, _} = Disputes.open_dispute(transaction, %{reason: :unauthorized})
      assert {:error, changeset} = Disputes.open_dispute(transaction, %{reason: :other})
      assert "has already been taken" in errors_on(changeset).transaction_id
    end
  end

  describe "get_case!/1" do
    test "loads the dispute with its whole chain and evidence",
         %{agent: agent, transaction: transaction} do
      {:ok, dispute} = Disputes.open_dispute(transaction, %{reason: :unauthorized})
      package = evidence_fixture(dispute)

      loaded = Disputes.get_case!(dispute.id)

      assert loaded.evidence.id == package.id
      assert loaded.transaction.id == transaction.id
      assert loaded.transaction.authorization.agent.id == agent.id
    end

    test "evidence is nil before an investigation", %{transaction: transaction} do
      {:ok, dispute} = Disputes.open_dispute(transaction, %{reason: :unauthorized})

      assert Disputes.get_case!(dispute.id).evidence == nil
    end
  end
end
