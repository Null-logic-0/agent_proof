defmodule AgentProof.Repo.Migrations.CreateAuthorizations do
  use Ecto.Migration

  def change do
    create table(:authorizations) do
      add :agent_id, references(:agents), null: false
      add :max_amount, :decimal, precision: 12, scale: 2, null: false
      add :currency, :string, size: 3, null: false
      add :description, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:authorizations, [:agent_id])

    create constraint(:authorizations, :max_amount_must_be_positive, check: "max_amount > 0")
  end
end
