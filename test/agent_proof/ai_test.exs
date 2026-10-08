defmodule AgentProof.AITest do
  use ExUnit.Case, async: true

  alias AgentProof.AI
  alias AgentProof.AI.{Demo, EvidenceSchema, Prompt, TestProvider}

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
      "authorized_before_purchase" => true,
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

  describe "EvidenceSchema" do
    # OpenAI strict mode: every object lists all its properties as required
    # and forbids extra ones.
    defp assert_strict(%{"type" => "object", "properties" => properties} = schema) do
      assert schema["additionalProperties"] == false
      assert Enum.sort(schema["required"]) == Enum.sort(Map.keys(properties))
      Enum.each(properties, fn {_name, property} -> assert_strict(property) end)
    end

    defp assert_strict(%{"type" => "array", "items" => items}), do: assert_strict(items)
    defp assert_strict(%{"type" => "string"}), do: :ok

    # A tiny JSON Schema checker covering the keywords our schema uses.
    defp conforms?(%{} = value, %{"type" => "object"} = schema) do
      Enum.sort(Map.keys(value)) == Enum.sort(schema["required"]) and
        Enum.all?(value, fn {key, v} -> conforms?(v, schema["properties"][key]) end)
    end

    defp conforms?(value, %{"type" => "array", "items" => items}) when is_list(value),
      do: Enum.all?(value, &conforms?(&1, items))

    defp conforms?(value, %{"type" => "string"}), do: is_binary(value)
    defp conforms?(_value, _schema), do: false

    test "satisfies OpenAI's strict-mode rules on every object" do
      assert_strict(EvidenceSchema.json_schema())
    end

    test "AI.Demo's output conforms to the schema" do
      assert conforms?(demo(), EvidenceSchema.json_schema())
    end

    test "the checker rejects a non-conforming answer" do
      refute conforms?(Map.delete(demo(), "summary"), EvidenceSchema.json_schema())
      refute conforms?(Map.put(demo(), "extra", "x"), EvidenceSchema.json_schema())
    end
  end

  describe "Prompt" do
    test "the system prompt carries the grounding rules" do
      system = Prompt.system()

      assert system =~ "Use only the facts provided"
      assert system =~ ~s("checks" were computed by the merchant's system and are authoritative)
      assert system =~ "If the payment capture was simulated, say so"
    end

    test "the user prompt embeds exactly the facts as JSON" do
      [_before, json] = String.split(Prompt.user(@facts), "Case facts (JSON):\n")
      [json, _after] = String.split(json, "\n\nWrite the evidence package.")

      assert Jason.decode!(json) == @facts
    end

    test "guidance follows the dispute reason" do
      not_received = put_in(@facts, ["dispute", "reason"], "not_received")

      assert Prompt.user(@facts) =~ "Focus on what the customer authorized"
      assert Prompt.user(not_received) =~ "Focus on fulfillment"
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
