defmodule AgentProof.Repo.Migrations.AddSubmittedAtToDisputes do
  use Ecto.Migration

  # When the merchant submitted the evidence to PayPal. Nil until submitted;
  # once set, the dispute and its evidence are frozen.
  def change do
    alter table(:disputes) do
      add :submitted_at, :utc_datetime
    end
  end
end
