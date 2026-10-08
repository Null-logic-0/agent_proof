defmodule AgentProof.Transactions.Fulfillment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :carrier, :string
    field :tracking_number, :string
    field :delivered_at, :utc_datetime
  end

  @doc false
  def changeset(fulfillment, attrs) do
    fulfillment
    |> cast(attrs, [:carrier, :tracking_number, :delivered_at])
    |> validate_required([:carrier, :tracking_number, :delivered_at])
  end
end
