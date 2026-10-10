defmodule AgentProof.Repo.Migrations.AddSuggestedQueryToAuthorizations do
  use Ecto.Migration

  def change do
    alter table(:authorizations) do
      add :suggested_query, :string
      add :suggested_by, :string
    end
  end
end
