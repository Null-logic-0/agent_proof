defmodule AgentProof.Authorizations.Authorization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "authorizations" do
    field :max_amount, :decimal
    field :currency, :string
    field :description, :string
    # Set only by AgentProof.Authorizations.suggest_query/2, never cast from input.
    field :suggested_query, :string
    field :suggested_by, :string

    belongs_to :agent, AgentProof.Agents.Agent
    has_many :transactions, AgentProof.Transactions.Transaction

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(authorization, attrs) do
    authorization
    |> cast(attrs, [:max_amount, :currency, :description])
    |> validate_required([:max_amount, :currency, :description])
    # numeric(12,2) holds up to 9,999,999,999.99; larger values would crash the insert.
    |> validate_number(:max_amount, greater_than: 0, less_than: 10_000_000_000)
    |> validate_format(:currency, ~r/\A[A-Z]{3}\z/, message: "must be a 3-letter uppercase code")
    |> assoc_constraint(:agent)
    |> check_constraint(:max_amount, name: :max_amount_must_be_positive)
  end
end
