defmodule AgentProof.Agents.ShoppingAgent do
  @moduledoc """
  A scripted stand-in for a real AI shopping agent: it buys the first catalog match.
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
