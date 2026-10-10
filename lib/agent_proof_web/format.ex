defmodule AgentProofWeb.Format do
  @moduledoc """
  Display formatting shared by all templates.
  """

  @doc """
  Formats money with two decimals, e.g. `Decimal.new("200")` -> `"200.00"`.
  """
  def money(%Decimal{} = amount), do: amount |> Decimal.round(2) |> Decimal.to_string()
end
