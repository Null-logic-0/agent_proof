defmodule AgentProof.CatalogTest do
  use ExUnit.Case, async: true

  alias AgentProof.Catalog

  test "finds products by name or category, ignoring case and whitespace" do
    assert [%{sku: "SONY-WH1000XM5"}] = Catalog.search("headphones")
    assert [%{sku: "SONY-WH1000XM5"}] = Catalog.search("  HEADPHONES ")
    assert [%{sku: "APPLE-MBA-13"}] = Catalog.search("laptop")
  end

  test "returns nothing for unknown or blank queries" do
    assert Catalog.search("unicorn") == []
    assert Catalog.search("   ") == []
  end

  test "prices are Decimals" do
    assert Enum.all?(Catalog.list_products(), &match?(%Decimal{}, &1.price))
  end
end
