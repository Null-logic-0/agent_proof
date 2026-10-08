defmodule AgentProof.Repo.Migrations.CreateEvidence do
  use Ecto.Migration

  def change do
    create table(:evidence) do
      add :dispute_id, references(:disputes), null: false
      add :summary, :text, null: false
      add :authorization_evidence, :jsonb, null: false
      add :transaction_evidence, :jsonb, null: false
      add :fulfillment_evidence, :jsonb, null: false
      add :ai_explanation, :text, null: false
      add :ai_provider, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:evidence, [:dispute_id])
  end
end
