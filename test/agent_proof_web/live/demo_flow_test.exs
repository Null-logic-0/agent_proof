defmodule AgentProofWeb.DemoFlowTest do
  # The whole demo, driven only through the UI.
  use AgentProofWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentProof.{Authorizations, Transactions}

  @grant %{
    agent_name: "ShopBot",
    max_amount: "200",
    currency: "USD",
    description: "Buy noise-cancelling headphones, up to $200"
  }

  test "authorize, shop, dispute, investigate, approve, and submit", %{conn: conn} do
    {:ok, dashboard, _html} = live(conn, ~p"/")
    render_async(dashboard)

    dashboard |> form("#grant-form", grant: @grant) |> render_submit()
    [authorization] = Authorizations.list_authorizations()

    shop = fn query ->
      dashboard
      |> form("#shop-form-#{authorization.id}", shop: %{query: query})
      |> render_submit(%{authorization_id: authorization.id})
    end

    shop.("laptop")
    assert has_element?(dashboard, "#flash-error", "Blocked")

    shop.("headphones")
    assert [%{status: :completed} = transaction] = Transactions.list_transactions()

    {:ok, case_view, _html} =
      dashboard
      |> element("#case-link-#{transaction.id}")
      |> render_click()
      |> follow_redirect(conn, ~p"/transactions/#{transaction.id}")

    case_view |> element("#deliver") |> render_click()
    case_view |> form("#dispute-form", dispute: %{reason: "unauthorized"}) |> render_submit()

    case_view |> element("#investigate") |> render_click()
    render_async(case_view)

    assert has_element?(case_view, "#evidence-status", "Ready for review")

    for check <-
          ~w(within_budget system_budget_check_logged currency_matches authorized_before_purchase) do
      assert has_element?(case_view, "#check-#{check} .hero-check-circle")
    end

    case_view |> element("#approve-evidence") |> render_click()
    case_view |> element("#prepare-submission") |> render_click()
    assert has_element?(case_view, "#submission-item-0", "PROOF_OF_FULFILLMENT")

    case_view |> element("#submit-evidence") |> render_click()
    render_async(case_view)

    assert has_element?(case_view, "#evidence-status", "Submitted")
    assert has_element?(case_view, "#case-dispute-status", "submitted")

    # Presence, not order: timestamps are stored to the second.
    for title <- [
          "Customer authorized ShopBot",
          "Searched the catalog",
          "Selected Sony WH-1000XM5 Headphones",
          "Budget check approved by AgentProof",
          "PayPal order created",
          "Payment captured",
          "Delivered by UPS",
          "Customer opened a dispute",
          "AI reconstructed the transaction and wrote the evidence",
          "Merchant approved the evidence",
          "Evidence submitted to PayPal"
        ] do
      assert has_element?(case_view, "#timeline", title)
    end
  end
end
