defmodule AgentProof.Repo.Migrations.AddApprovedAtToEvidence do
  use Ecto.Migration

  # When the merchant approved this evidence package. Nil until approved; a
  # regenerated package starts unapproved again.
  def change do
    alter table(:evidence) do
      add :approved_at, :utc_datetime
    end
  end
end
