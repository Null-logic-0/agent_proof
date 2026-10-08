defmodule AgentProof.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :authorization_id, references(:authorizations), null: false
      add :paypal_order_id, :string
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :currency, :string, size: 3, null: false
      add :product_name, :string, null: false
      add :status, :string, null: false
      add :agent_actions, :jsonb, null: false, default: fragment("'[]'::jsonb")
      add :fulfillment, :jsonb

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:authorization_id])
    create unique_index(:transactions, [:paypal_order_id])

    create constraint(:transactions, :amount_must_be_positive, check: "amount > 0")
  end
end
