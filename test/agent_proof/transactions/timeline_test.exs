defmodule AgentProof.Transactions.TimelineTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures
  import ExUnit.CaptureLog

  alias AgentProof.{Authorizations, Evidence, Transactions}
  alias AgentProof.Agents.ShoppingAgent
  alias AgentProof.PayPal.TestClient

  defp buy_headphones(opts \\ []) do
    authorization = authorization_fixture(agent_fixture())
    ShoppingAgent.run(authorization, "headphones", opts)
  end

  defp timeline(transaction_id),
    do: transaction_id |> Transactions.get_case!() |> Transactions.timeline()

  test "get_case!/1 preloads the agent and the dispute, and raises for unknown ids" do
    {:ok, transaction} = buy_headphones()

    loaded = Transactions.get_case!(transaction.id)
    assert loaded.authorization.agent.name == "ShopBot"
    assert loaded.dispute == nil
    assert_raise Ecto.NoResultsError, fn -> Transactions.get_case!(-1) end
  end

  test "a purchase becomes the authorization, then the agent's and the system's steps" do
    {:ok, transaction} = buy_headphones()
    events = timeline(transaction.id)

    assert Enum.map(events, &{&1.actor, &1.title}) == [
             {:customer, "Customer authorized ShopBot"},
             {:agent, "Searched the catalog"},
             {:agent, "Selected Sony WH-1000XM5 Headphones"},
             {:system, "Budget check approved by AgentProof"},
             {:paypal, "PayPal order created"},
             {:paypal, "Payment captured"}
           ]

    assert %{details: ~s(Up to 200.00 USD: "Buy noise-cancelling headphones, up to $200")} =
             hd(events)

    assert List.last(events).simulated?
  end

  test "delivery, dispute, and evidence add events, ordered by time" do
    tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
    dispute = disputed_case_fixture(delivered_at: tomorrow)
    {:ok, _evidence} = Evidence.generate_for_dispute(dispute.id)

    events = timeline(dispute.transaction.id)
    by_id = Map.new(events, &{&1.id, &1})

    assert %{actor: :customer, status: :warning, simulated?: true} = by_id["dispute"]
    assert by_id["dispute"].details =~ "Reason: unauthorized"
    assert %{actor: :ai} = by_id["evidence"]
    assert by_id["evidence"].details =~ "demo"
    assert %{actor: :carrier, simulated?: true} = by_id["fulfillment"]

    # Delivered "tomorrow", so it sorts after everything else.
    assert List.last(events).id == "fulfillment"
  end

  test "a failed payment shows as an error" do
    capture_log(fn -> buy_headphones(adapter: TestClient, fail: :create) end)
    [failed] = Transactions.list_transactions()

    assert %{title: "Payment failed", status: :error} = List.last(timeline(failed.id))
  end

  test "editing the authorization later does not change the story" do
    {:ok, transaction} = buy_headphones()
    authorization = transaction.authorization_id |> Authorizations.get_authorization!()

    {:ok, _} =
      authorization
      |> Authorizations.preload_activity()
      |> Authorizations.update_settings(%{"max_amount" => "5000", "description" => "Anything"})

    assert hd(timeline(transaction.id)).details =~ "Up to 200.00 USD"
  end
end
