defmodule AgentProof.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agents" do
    field :name, :string

    has_many :authorizations, AgentProof.Authorizations.Authorization

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 255)
  end
end
