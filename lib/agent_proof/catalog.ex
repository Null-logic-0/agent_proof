defmodule AgentProof.Catalog do
  @moduledoc """
  A small hardcoded product catalog standing in for a merchant's store.

  Simulated for the MVP: no database, and the same query always returns the
  same products in the same order.
  """

  @products [
    %{
      sku: "SONY-WH1000XM5",
      name: "Sony WH-1000XM5 Headphones",
      category: "headphones",
      price: Decimal.new("189.99"),
      currency: "USD"
    },
    %{
      sku: "ANKER-USBC-6FT",
      name: "Anker USB-C Cable (6 ft)",
      category: "cables",
      price: Decimal.new("19.99"),
      currency: "USD"
    },
    %{
      sku: "LOGI-MX-MASTER-3S",
      name: "Logitech MX Master 3S Mouse",
      category: "mice",
      price: Decimal.new("99.99"),
      currency: "USD"
    },
    %{
      sku: "APPLE-MBA-13",
      name: "MacBook Air 13-inch Laptop",
      category: "laptops",
      price: Decimal.new("1099.00"),
      currency: "USD"
    }
  ]

  def list_products, do: @products

  @doc """
  Returns products whose name or category contains `query`, ignoring case.
  """
  def search(query) do
    case query |> String.trim() |> String.downcase() do
      "" ->
        []

      query ->
        Enum.filter(@products, fn product ->
          String.contains?(String.downcase("#{product.name} #{product.category}"), query)
        end)
    end
  end
end
