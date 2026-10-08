defmodule AgentProof.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    create table(:agents) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
