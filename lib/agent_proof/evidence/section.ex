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
  Validates one evidence section. With `case_facts`, every amount and
  identifier must also be grounded in them.
  """
  def changeset(section, attrs, case_facts \\ nil) do
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
  end
end
