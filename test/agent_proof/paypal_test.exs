defmodule AgentProof.PayPalTest do
  use ExUnit.Case, async: true

  alias AgentProof.PayPal
  alias AgentProof.PayPal.{Demo, TestClient}

  @order %{
    amount: Decimal.new("189.99"),
    currency: "USD",
    description: "Sony WH-1000XM5 Headphones",
    reference_id: "transaction-42"
  }

  describe "Demo adapter" do
    test "derives the same IDs from the same order" do
      assert Demo.create_order(@order, []) == {:ok, %{order_id: "DEMO-ORDER-transaction-42"}}
      assert Demo.create_order(@order, []) == {:ok, %{order_id: "DEMO-ORDER-transaction-42"}}

      assert Demo.capture_order("DEMO-ORDER-transaction-42", []) ==
               {:ok,
                %{
                  order_id: "DEMO-ORDER-transaction-42",
                  capture_id: "DEMO-CAPTURE-transaction-42",
                  simulated: true
                }}
    end

    test "refuses to capture an order it did not create" do
      assert Demo.capture_order("5O190127TN364715T", []) == {:error, :unknown_order}
    end
  end

  describe "adapter selection" do
    test "uses the configured adapter by default" do
      assert PayPal.create_order(@order) == {:ok, %{order_id: "DEMO-ORDER-transaction-42"}}
    end

    test "an explicit :adapter option wins over config" do
      assert PayPal.create_order(@order, adapter: TestClient, fail: :create) ==
               {:error, :sandbox_unavailable}
    end
  end
end
