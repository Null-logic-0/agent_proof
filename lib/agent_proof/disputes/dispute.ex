defmodule AgentProof.Disputes.Dispute do
  use Ecto.Schema
  import Ecto.Changeset

  schema "disputes" do
    field :paypal_dispute_id, :string
    field :reason, Ecto.Enum, values: [:unauthorized, :not_received, :not_as_described, :other]
    field :status, Ecto.Enum, values: [:open, :evidence_ready, :submitted]
    field :due_date, :date
    # Set only by AgentProof.Disputes.mark_submitted/1, never cast from input.
    field :submitted_at, :utc_datetime

    belongs_to :transaction, AgentProof.Transactions.Transaction
    has_one :evidence, AgentProof.Evidence.Package

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(dispute, attrs) do
    dispute
    |> cast(attrs, [:paypal_dispute_id, :reason, :status, :due_date])
    |> validate_required([:paypal_dispute_id, :reason, :status])
    |> assoc_constraint(:transaction)
    |> unique_constraint(:transaction_id)
  end

  @doc """
  Whether the dispute was created in AgentProof, so PayPal doesn't know it.
  """
  def simulated?(%__MODULE__{paypal_dispute_id: "DEMO-" <> _rest}), do: true
  def simulated?(%__MODULE__{}), do: false

  @doc """
  Changeset for opening a dispute. Only `reason` comes from input.
  """
  def open_changeset(dispute, attrs) do
    dispute
    |> cast(attrs, [:reason])
    |> validate_required([:reason])
    |> assoc_constraint(:transaction)
    |> unique_constraint(:transaction_id)
  end
end
