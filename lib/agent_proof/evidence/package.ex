defmodule AgentProof.Evidence.Package do
  use Ecto.Schema
  import Ecto.Changeset

  @fields [
    :summary,
    :authorization_evidence,
    :transaction_evidence,
    :fulfillment_evidence,
    :ai_explanation,
    :ai_provider
  ]

  schema "evidence" do
    field :summary, :string
    field :authorization_evidence, :map
    field :transaction_evidence, :map
    field :fulfillment_evidence, :map
    field :ai_explanation, :string
    field :ai_provider, :string

    belongs_to :dispute, AgentProof.Disputes.Dispute

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(package, attrs) do
    package
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> assoc_constraint(:dispute)
    |> unique_constraint(:dispute_id)
  end
end
