defmodule AgentProof.AITest do
  use ExUnit.Case, async: true

  alias AgentProof.AI
  alias AgentProof.AI.{Demo, TestProvider}

  @facts %{
    "agent_name" => "ShopBot",
    "authorization" => %{
      "max_amount" => "200.00",
      "currency" => "USD",
      "description" => "Headphones up to $200",
      "authorized_at" => "2026-10-08T12:00:00Z"
    },
    "transaction" => %{
      "product_name" => "Sony WH-1000XM5 Headphones",
      "amount" => "189.99",
      "currency" => "USD",
      "paypal_order_id" => "6CF36743HA4658629",
      "capture_simulated" => true,
      "purchased_at" => "2026-10-08T12:00:05Z"
    },
    "fulfillment" => %{
      "carrier" => "UPS",
      "tracking_number" => "1Z999AA10123456784",
      "delivered_at" => "2026-10-10T14:00:00Z"
    },
    "dispute" => %{
      "reason" => "unauthorized",
      "opened_at" => "2026-10-12T09:00:00Z",
      "due_date" => "2026-10-22"
    },
    "checks" => %{
      "within_budget" => true,
      "currency_matches" => true,
      "system_budget_check_logged" => true,
      "delivered_before_dispute" => true
    },
    "agent_actions" => [
      %{"action" => "search_products", "actor" => "agent", "at" => "2026-10-08T12:00:01Z"},
      %{"action" => "budget_check", "actor" => "system", "at" => "2026-10-08T12:00:02Z"}
    ]
  }

  defp request(facts \\ @facts), do: %{system: "", prompt: "", schema: %{}, facts: facts}

  defp demo(facts \\ @facts) do
    {:ok, evidence} = Demo.generate(request(facts), [])
    evidence
  end

  describe "AI.Demo" do
    test "returns exactly the evidence shape" do
      evidence = demo()

      assert Map.keys(evidence) |> Enum.sort() ==
               ~w(ai_explanation authorization_evidence fulfillment_evidence summary transaction_evidence)

      for section <- ~w(authorization_evidence transaction_evidence fulfillment_evidence) do
        assert %{"statement" => statement, "facts" => facts} = evidence[section]
        assert is_binary(statement)
        assert Enum.all?(facts, &is_binary/1)
      end
    end

    test "the same facts always produce the same evidence" do
      assert demo() == demo()
    end

    test "follows the budget check instead of assuming it passed" do
      over_budget = put_in(@facts, ["checks", "within_budget"], false)

      assert demo()["summary"] =~ "within the 200.00 USD budget"
      assert demo(over_budget)["summary"] =~ "outside the 200.00 USD budget"

      assert "The amount exceeds the authorized budget." in demo(over_budget)[
               "authorization_evidence"
             ]["facts"]
    end

    test "says so when nothing was delivered" do
      assert demo(%{@facts | "fulfillment" => nil})["fulfillment_evidence"] == %{
               "statement" => "No fulfillment record exists for this transaction.",
               "facts" => []
             }
    end

    test "is honest about what it is and about simulated captures" do
      evidence = demo()
      real_capture = put_in(@facts, ["transaction", "capture_simulated"], false)

      assert evidence["ai_explanation"] =~ "No language model was used"
      assert Enum.any?(evidence["transaction_evidence"]["facts"], &(&1 =~ "simulated"))
      refute Enum.any?(demo(real_capture)["transaction_evidence"]["facts"], &(&1 =~ "simulated"))
    end
  end

  describe "provider selection" do
    test "uses the configured provider by default" do
      assert {:ok, %{"summary" => _}} = AI.generate(request())
      assert AI.provider_name() == "demo"
    end

    test "an explicit :provider option wins over config" do
      assert AI.generate(request(), provider: TestProvider, reply: {:ok, %{"x" => 1}}) ==
               {:ok, %{"x" => 1}}

      assert AI.provider_name(provider: TestProvider) == "test"
    end
  end
end
