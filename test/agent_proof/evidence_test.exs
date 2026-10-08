defmodule AgentProof.EvidenceTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Evidence
  alias AgentProof.Evidence.Package

  setup do
    transaction = transaction_fixture(authorization_fixture(agent_fixture()))

    %{dispute: dispute_fixture(transaction)}
  end

  test "requires every evidence field" do
    changeset = Package.changeset(%Package{}, %{})

    for field <- Map.keys(valid_evidence_attrs()) do
      assert "can't be blank" in Map.fetch!(errors_on(changeset), field)
    end
  end

  test "a second package for the same dispute becomes a changeset error", %{dispute: dispute} do
    evidence_fixture(dispute)

    assert {:error, changeset} =
             %Package{dispute_id: dispute.id}
             |> Package.changeset(valid_evidence_attrs())
             |> Repo.insert()

    assert "has already been taken" in errors_on(changeset).dispute_id
  end

  describe "get_package_by_dispute/1" do
    test "returns the dispute's package", %{dispute: dispute} do
      package = evidence_fixture(dispute)

      assert Evidence.get_package_by_dispute(dispute) == package
    end

    test "returns nil before evidence is generated", %{dispute: dispute} do
      assert Evidence.get_package_by_dispute(dispute) == nil
    end
  end
end
