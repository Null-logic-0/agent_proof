defmodule AgentProof.Evidence.Grounding do
  @moduledoc """
  Finds amounts and IDs in AI-written text that are not in the case facts.
  """

  # 189.99 and 1,099.00
  @amount ~r/\d{1,3}(?:,\d{3})+\.\d{2}|\d+\.\d{2}/
  # IDs: tokens of 10+ characters that mix letters and digits, e.g. order ids and timestamps.
  @identifier ~r/\b[A-Za-z0-9][A-Za-z0-9-]{8,}[A-Za-z0-9]\b/
  @date ~r/\b\d{4}-\d{2}-\d{2}\b/

  def ungrounded(text, facts) when is_binary(text) do
    known = Jason.encode!(facts)

    (amounts(text) ++ identifiers(text) ++ dates(text))
    |> Enum.uniq()
    |> Enum.reject(&String.contains?(known, &1))
  end

  @doc """
  Adds a changeset error to `field` for each ungrounded token. Skipped when `facts` is `nil`.
  """
  def validate(changeset, _field, nil), do: changeset

  def validate(changeset, field, facts) do
    Ecto.Changeset.validate_change(changeset, field, fn ^field, value ->
      case ungrounded(text(value), facts) do
        [] -> []
        tokens -> [{field, "mentions #{Enum.join(tokens, ", ")}, not found in the case facts"}]
      end
    end)
  end

  defp text(value) when is_binary(value), do: value
  defp text(values) when is_list(values), do: Enum.join(values, "\n")

  defp amounts(text) do
    @amount |> Regex.scan(text) |> List.flatten() |> Enum.map(&String.replace(&1, ",", ""))
  end

  defp identifiers(text) do
    @identifier
    |> Regex.scan(text)
    |> List.flatten()
    |> Enum.filter(&(String.match?(&1, ~r/[A-Za-z]/) and String.match?(&1, ~r/\d/)))
  end

  defp dates(text), do: @date |> Regex.scan(text) |> List.flatten()
end
