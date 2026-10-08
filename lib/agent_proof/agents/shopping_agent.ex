defmodule AgentProof.Agents.ShoppingAgent do
  @moduledoc """
  A deterministic stand-in for an external AI shopping agent.

  It searches the catalog, picks the first match, and hands its action log to
  `AgentProof.Transactions.purchase/3`. Simulated for the MVP: a real agent
  would choose products itself and report the same kind of log. The agent
  never checks the budget; the purchase policy decides.
  """

  alias AgentProof.{Catalog, Transactions}
  alias AgentProof.Authorizations.Authorization

  def run(%Authorization{} = authorization, query, opts \\ []) do
    products = Catalog.search(query)
    searched = action(:search_products, %{"query" => query, "results" => length(products)})

    case products do
      [] ->
        {:error, :no_matching_product}

      [product | _] ->
        selected =
          action(:select_product, %{
            "sku" => product.sku,
            "product" => product.name,
            "price" => Decimal.to_string(product.price)
          })

        Transactions.purchase(authorization, product, [searched, selected], opts)
    end
  end

  defp action(name, details) do
    %{action: name, at: DateTime.utc_now(), details: details}
  end
end
