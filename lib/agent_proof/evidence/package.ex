defmodule AgentProof.Evidence.Package do
  use Ecto.Schema
  import Ecto.Changeset

  alias AgentProof.Evidence.{Grounding, Section}

  @sections [:authorization_evidence, :transaction_evidence, :fulfillment_evidence]

  schema "evidence" do
    field :summary, :string
    embeds_one :authorization_evidence, Section
    embeds_one :transaction_evidence, Section
    embeds_one :fulfillment_evidence, Section
    field :ai_explanation, :string
    field :ai_provider, :string

    belongs_to :dispute, AgentProof.Disputes.Dispute

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(package, attrs) do
    package
    |> cast(attrs, [:summary, :ai_explanation, :ai_provider])
    |> validate_required([:summary, :ai_explanation, :ai_provider])
    |> cast_sections(nil)
    |> assoc_constraint(:dispute)
    |> unique_constraint(:dispute_id)
  end

  @doc """
  Validates a model's raw evidence map: shape, lengths, and grounding in the
  case `facts`. `dispute_id` and `ai_provider` are set on the struct by code,
  never taken from the model.
  """
  def ai_changeset(package, attrs, facts) do
    package
    |> cast(attrs, [:summary, :ai_explanation])
    |> validate_required([:summary, :ai_explanation, :ai_provider])
    |> validate_length(:summary, max: 1000)
    |> validate_length(:ai_explanation, max: 1000)
    |> Grounding.validate(:summary, facts)
    |> Grounding.validate(:ai_explanation, facts)
    |> cast_sections(facts)
    |> assoc_constraint(:dispute)
  end

  defp cast_sections(changeset, facts) do
    Enum.reduce(@sections, changeset, fn section, changeset ->
      cast_embed(changeset, section, required: true, with: &Section.changeset(&1, &2, facts))
    end)
  end
end
