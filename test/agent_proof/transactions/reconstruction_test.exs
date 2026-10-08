defmodule AgentProof.Transactions.ReconstructionTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.{Disputes, Transactions}

  defp facts(dispute), do: Transactions.reconstruct(dispute.transaction, dispute)

  test "rebuilds a delivered, disputed agent purchase as plain facts" do
    dispute = disputed_case_fixture()
    transaction = dispute.transaction
    facts = facts(dispute)

    assert facts["agent_name"] == "ShopBot"

    assert %{
             "max_amount" => "200.00",
             "currency" => "USD",
             "description" => "Buy noise-cancelling headphones, up to $200"
           } = facts["authorization"]

    assert facts["transaction"] == %{
             "product_name" => "Sony WH-1000XM5 Headphones",
             "amount" => "189.99",
             "currency" => "USD",
             "status" => "completed",
             "paypal_order_id" => "DEMO-ORDER-transaction-#{transaction.id}",
             "capture_simulated" => true,
             "purchased_at" => DateTime.to_iso8601(transaction.inserted_at)
           }

    assert %{"carrier" => "UPS", "tracking_number" => "1Z999AA10123456784"} =
             facts["fulfillment"]

    assert facts["dispute"]["reason"] == "unauthorized"
    assert facts["dispute"]["due_date"] == Date.to_iso8601(dispute.due_date)

    assert facts["checks"] == %{
             "within_budget" => true,
             "system_budget_check_logged" => true,
             "currency_matches" => true,
             "authorized_before_purchase" => true,
             "delivered_before_dispute" => true
           }

    assert Enum.map(facts["agent_actions"], &{&1["action"], &1["actor"]}) == [
             {"search_products", "agent"},
             {"select_product", "agent"},
             {"budget_check", "system"},
             {"create_paypal_order", "system"},
             {"capture_payment", "system"}
           ]
  end

  test "facts are plain JSON data: they survive an encode/decode round trip" do
    facts = facts(disputed_case_fixture())

    assert facts |> Jason.encode!() |> Jason.decode!() == facts
  end

  test "no fulfillment is reported as missing, not guessed" do
    facts = facts(disputed_case_fixture(delivered_at: nil))

    assert facts["fulfillment"] == nil
    assert facts["checks"]["delivered_before_dispute"] == nil
  end

  test "a delivery after the dispute opened is flagged" do
    tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

    assert facts(disputed_case_fixture(delivered_at: tomorrow))["checks"][
             "delivered_before_dispute"
           ] == false
  end

  test "without a logged budget check, falls back to the amount and says so" do
    # Fixture transactions have no action log and no capture record.
    authorization = authorization_fixture(agent_fixture())
    transaction = transaction_fixture(authorization, %{currency: "EUR"})
    {:ok, dispute} = Disputes.open_dispute(transaction, %{reason: :other})

    facts = facts(Disputes.get_case!(dispute.id))

    assert facts["checks"]["system_budget_check_logged"] == false
    assert facts["checks"]["within_budget"] == true
    assert facts["checks"]["currency_matches"] == false
    assert facts["transaction"]["capture_simulated"] == nil
  end
end
