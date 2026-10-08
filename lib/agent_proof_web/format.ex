defmodule AgentProofWeb.Format do
  @moduledoc """
  Display formatting shared by LiveViews and components. Imported into every
  template through `html_helpers` in `AgentProofWeb`.
  """

  @doc """
  Formats money with two decimals, e.g. `Decimal.new("200")` -> `"200.00"`.
  """
  def money(%Decimal{} = amount), do: amount |> Decimal.round(2) |> Decimal.to_string()
end
