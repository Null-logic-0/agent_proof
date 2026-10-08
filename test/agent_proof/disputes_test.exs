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

  test "the full case chain preloads from a dispute",
       %{agent: agent, transaction: transaction} do
    dispute = dispute_fixture(transaction)
    package = evidence_fixture(dispute)

    loaded = Repo.preload(dispute, [:evidence, transaction: [authorization: :agent]])

    assert loaded.evidence.id == package.id
    assert loaded.transaction.id == transaction.id
    assert loaded.transaction.authorization.agent.id == agent.id
  end
end
