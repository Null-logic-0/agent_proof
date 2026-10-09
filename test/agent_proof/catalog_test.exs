defmodule AgentProof.CatalogTest do
  use ExUnit.Case, async: true

  alias AgentProof.Catalog

  test "finds products by name or category, ignoring case and whitespace" do
    assert [%{sku: "SONY-WH1000XM5"}] = Catalog.search("headphones")
    assert [%{sku: "SONY-WH1000XM5"}] = Catalog.search("  HEADPHONES ")
    assert [%{sku: "APPLE-MBA-13"}] = Catalog.search("laptop")
  end

  test "matches every word of a query, in any order" do
    assert [%{sku: "ANKER-USBC-6FT"}] = Catalog.search("usb cable")
    assert [%{sku: "LOGI-MX-MASTER-3S"}] = Catalog.search("logitech mouse")
    assert [%{sku: "LOGI-MX-MASTER-3S"}] = Catalog.search("Mouse, Logitech")
    assert Catalog.search("unicorn mouse") == []
  end

  test "a full product name finds that product" do
    for product <- Catalog.list_products() do
      assert [found] = Catalog.search(product.name)
      assert found.sku == product.sku
    end
  end

  test "returns nothing for unknown or blank queries" do
    assert Catalog.search("unicorn") == []
    assert Catalog.search("   ") == []
  end

  test "prices are Decimals" do
    assert Enum.all?(Catalog.list_products(), &match?(%Decimal{}, &1.price))
  end
end
