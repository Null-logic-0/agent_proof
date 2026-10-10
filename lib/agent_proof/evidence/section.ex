defmodule AgentProof.Evidence.Section do
  use Ecto.Schema
  import Ecto.Changeset

  alias AgentProof.Evidence.Grounding

  @primary_key false
  embedded_schema do
    field :statement, :string
    field :facts, {:array, :string}, default: []
  end

  @doc """
  Validates one evidence section. `required_mentions` are values it must quote.
  """
  def changeset(section, attrs, case_facts \\ nil, required_mentions \\ []) do
    section
    |> cast(attrs, [:statement, :facts])
    |> validate_required([:statement])
    |> validate_length(:statement, max: 600)
    |> validate_length(:facts, max: 12)
    |> validate_change(:facts, fn :facts, facts ->
      if Enum.any?(facts, &(String.trim(&1) == "")),
        do: [facts: "must not contain blank entries"],
        else: []
    end)
    |> Grounding.validate(:statement, case_facts)
    |> Grounding.validate(:facts, case_facts)
    |> validate_mentions(required_mentions)
  end

  defp validate_mentions(changeset, []), do: changeset

  defp validate_mentions(changeset, required_mentions) do
    text =
      Enum.join([get_field(changeset, :statement) || "" | get_field(changeset, :facts)], "\n")

    Enum.reduce(required_mentions, changeset, fn {label, value}, changeset ->
      if String.contains?(text, value),
        do: changeset,
        else: add_error(changeset, :statement, "must include #{label} #{value}")
    end)
  end
end
