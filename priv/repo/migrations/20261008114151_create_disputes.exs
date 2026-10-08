defmodule AgentProof.Repo.Migrations.CreateDisputes do
  use Ecto.Migration

  def change do
    create table(:disputes) do
      add :transaction_id, references(:transactions), null: false
      add :paypal_dispute_id, :string, null: false
      add :reason, :string, null: false
      add :status, :string, null: false
      add :due_date, :date

      timestamps(type: :utc_datetime)
    end

    create unique_index(:disputes, [:transaction_id])
  end
end
