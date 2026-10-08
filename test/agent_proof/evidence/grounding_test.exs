defmodule AgentProof.Evidence.GroundingTest do
  use ExUnit.Case, async: true

  alias AgentProof.Evidence.Grounding

  @facts %{
    "authorization" => %{"max_amount" => "1099.00", "authorized_at" => "2026-10-08T13:46:01Z"},
    "transaction" => %{
      "product_name" => "Sony WH-1000XM5 Headphones",
      "amount" => "189.99",
      "paypal_order_id" => "6CF36743HA4658629"
    },
    "fulfillment" => %{
      "tracking_number" => "1Z999AA10123456784",
      "delivered_at" => "2026-10-07T13:46:01Z"
    },
    "agent_actions" => [%{"details" => %{"sku" => "SONY-WH1000XM5"}}]
  }

  test "text built only from the facts is grounded" do
    text =
      "ShopBot paid $189.99 of a $1,099.00 budget under PayPal order 6CF36743HA4658629 " <>
        "for the Sony WH-1000XM5 (SONY-WH1000XM5), delivered on 2026-10-07 " <>
        "(UPS 1Z999AA10123456784), authorized at 2026-10-08T13:46:01Z."

    assert Grounding.ungrounded(text, @facts) == []
  end

  test "invented amounts are caught, with or without thousands separators" do
    assert Grounding.ungrounded("A refund of $249.99 and $2,000.00.", @facts) ==
             ["249.99", "2000.00"]
  end

  test "invented identifiers and dates are caught" do
    assert Grounding.ungrounded("Tracking 1Z000BB99999999999, order 9XY12345AB.", @facts) ==
             ["1Z000BB99999999999", "9XY12345AB"]

    assert Grounding.ungrounded("Delivered on 2026-10-09.", @facts) == ["2026-10-09"]
  end

  test "ordinary words are not treated as identifiers" do
    assert Grounding.ungrounded("The noise-cancelling headphones were authorized.", @facts) ==
             []
  end
end
