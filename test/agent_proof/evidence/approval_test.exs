defmodule AgentProof.Evidence.ApprovalTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Evidence

  setup do
    dispute = disputed_case_fixture()
    {:ok, package} = Evidence.generate_for_dispute(dispute.id)
    %{dispute: dispute, package: package}
  end

  test "new evidence starts unapproved", %{package: package} do
    assert package.approved_at == nil
  end

  test "approve/1 records when the merchant approved", %{package: package} do
    assert {:ok, approved} = Evidence.approve(package)
    assert %DateTime{} = approved.approved_at
  end

  test "withdraw_approval/1 clears it", %{package: package} do
    {:ok, approved} = Evidence.approve(package)

    assert {:ok, withdrawn} = Evidence.withdraw_approval(approved)
    assert withdrawn.approved_at == nil
  end

  test "regenerating replaces the package and discards the approval",
       %{dispute: dispute, package: package} do
    {:ok, _approved} = Evidence.approve(package)

    {:ok, regenerated} = Evidence.generate_for_dispute(dispute.id)

    assert regenerated.id == package.id
    assert regenerated.approved_at == nil
  end

  test "a submitted dispute's evidence can no longer be approved or withdrawn",
       %{dispute: dispute, package: package} do
    {:ok, approved} = Evidence.approve(package)
    dispute |> Ecto.Changeset.change(status: :submitted) |> Repo.update!()

    assert Evidence.approve(Repo.reload!(approved)) == {:error, :already_submitted}
    assert Evidence.withdraw_approval(Repo.reload!(approved)) == {:error, :already_submitted}
  end
end
