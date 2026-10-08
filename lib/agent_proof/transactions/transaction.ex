defmodule AgentProof.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :paypal_order_id, :string
    field :amount, :decimal
    field :currency, :string
    field :product_name, :string
    field :status, Ecto.Enum, values: [:created, :completed, :failed]
    field :agent_actions, {:array, :map}, default: []

    embeds_one :fulfillment, AgentProof.Transactions.Fulfillment, on_replace: :update

    belongs_to :authorization, AgentProof.Authorizations.Authorization
    has_one :dispute, AgentProof.Disputes.Dispute

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:paypal_order_id, :amount, :currency, :product_name, :status])
    |> validate_required([:amount, :currency, :product_name, :status])
    |> validate_number(:amount, greater_than: 0)
    |> validate_format(:currency, ~r/\A[A-Z]{3}\z/, message: "must be a 3-letter uppercase code")
    |> assoc_constraint(:authorization)
    |> unique_constraint(:paypal_order_id)
    |> check_constraint(:amount, name: :amount_must_be_positive)
  end

  @doc false
  def fulfillment_changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [])
    |> cast_embed(:fulfillment, required: true)
  end
end
