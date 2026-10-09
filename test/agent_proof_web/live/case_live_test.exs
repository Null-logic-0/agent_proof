defmodule AgentProofWeb.CaseLiveTest do
  use AgentProofWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AgentProof.Fixtures

  alias AgentProof.{Disputes, Transactions}
  alias AgentProof.Agents.ShoppingAgent

  setup do
    authorization = authorization_fixture(agent_fixture())
    {:ok, transaction} = ShoppingAgent.run(authorization, "headphones")
    %{authorization: authorization, transaction: transaction}
  end

  test "shows the case header and the timeline", %{conn: conn, transaction: transaction} do
    {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

    assert has_element?(view, "#case-header", "Sony WH-1000XM5 Headphones")
    assert has_element?(view, "#case-header", "DEMO-ORDER-transaction-#{transaction.id}")
    assert has_element?(view, "#timeline #event-authorization", "Customer authorized ShopBot")
    assert has_element?(view, "#timeline", "Budget check approved by AgentProof")
    assert has_element?(view, "#deliver")
    assert has_element?(view, "#dispute-form")
    refute has_element?(view, "#investigate")
  end

  test "an unknown transaction is a 404", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/transactions/0") end
  end

  test "Mark as delivered adds a simulated delivery", %{conn: conn, transaction: transaction} do
    {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

    view |> element("#deliver") |> render_click()

    assert has_element?(view, "#event-fulfillment", "Delivered by UPS")
    assert has_element?(view, "#event-fulfillment", "simulated")
    refute has_element?(view, "#deliver")
  end

  test "opening a dispute adds it and enables the investigation",
       %{conn: conn, transaction: transaction} do
    {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

    view |> form("#dispute-form", dispute: %{reason: "not_received"}) |> render_submit()

    assert has_element?(view, "#event-dispute", "Reason: not received")
    assert has_element?(view, "#case-dispute-status", "open")
    assert has_element?(view, "#investigate", "Run AI investigation")
    refute has_element?(view, "#dispute-form")
  end

  test "the AI investigation saves evidence and shows it", %{conn: conn, transaction: transaction} do
    {:ok, _dispute} = Disputes.open_dispute(transaction, %{reason: :unauthorized})
    {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

    view |> element("#investigate") |> render_click()
    render_async(view)

    assert has_element?(view, "#evidence-summary")
    assert has_element?(view, "#evidence-provider", "demo")
    assert has_element?(view, "#event-evidence")
    assert has_element?(view, "#case-dispute-status", "evidence ready")
    assert has_element?(view, "#investigate", "Run the investigation again")
    assert has_element?(view, "#flash-info", "Evidence ready")
  end

  test "an unpaid transaction cannot be delivered or disputed",
       %{conn: conn, authorization: authorization} do
    failed = transaction_fixture(authorization, %{status: :failed})
    {:ok, view, _html} = live(conn, ~p"/transactions/#{failed.id}")

    assert has_element?(view, "#case-actions", "Only paid transactions")
    refute has_element?(view, "#deliver")
    refute has_element?(view, "#dispute-form")
  end

  describe "links to the case page" do
    test "from the dashboard's purchase list", %{conn: conn, transaction: transaction} do
      {:ok, view, _html} = live(conn, ~p"/")
      render_async(view)

      assert {:ok, case_view, _html} =
               view
               |> element("#case-link-#{transaction.id}")
               |> render_click()
               |> follow_redirect(conn, ~p"/transactions/#{transaction.id}")

      assert has_element?(case_view, "#timeline")
    end

    test "from the history table", %{conn: conn, transaction: transaction} do
      {:ok, view, _html} = live(conn, ~p"/history")
      render_async(view)

      assert {:ok, _case_view, _html} =
               view
               |> element("#transactions-#{transaction.id} a", "Sony WH-1000XM5 Headphones")
               |> render_click()
               |> follow_redirect(conn, ~p"/transactions/#{transaction.id}")
    end
  end

  test "Transactions.get_case!/1 reflects what the page shows", %{transaction: transaction} do
    assert Transactions.get_case!(transaction.id).dispute == nil
  end
end
