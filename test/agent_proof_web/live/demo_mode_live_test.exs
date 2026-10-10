defmodule AgentProofWeb.DemoModeLiveTest do
  # async: false, so it runs after all async tests: it swaps PayPal and the AI for ones
  # that are down.
  use AgentProofWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import AgentProof.Fixtures

  alias AgentProof.{Disputes, Transactions}

  setup do
    for {key, down} <- [
          paypal_adapter: AgentProof.UnreachablePayPal,
          ai_provider: AgentProof.AI.FailingProvider
        ] do
      original = Application.fetch_env!(:agent_proof, key)
      Application.put_env(:agent_proof, key, down)
      on_exit(fn -> Application.put_env(:agent_proof, key, original) end)
    end

    :ok
  end

  defp shop(view, authorization) do
    view
    |> form("#shop-form-#{authorization.id}", shop: %{query: "headphones"})
    |> render_submit(%{authorization_id: authorization.id})
  end

  describe "Demo Mode off" do
    test "the configured services are shown, with no banner or scenario", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#paypal-mode", "unreachable")
      assert has_element?(view, "#ai-provider", "failing")
      assert has_element?(view, "#demo-mode-toggle-button[aria-pressed=false]", "off")
      refute has_element?(view, "#demo-banner")
      refute has_element?(view, "#demo-scenario")
    end

    test "the navbar switch turns it on, and it stays on across pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/history")

      conn = view |> form("#demo-mode-toggle") |> submit_form(conn)

      assert redirected_to(conn) == "/history"
      assert get_session(conn, :demo_mode) == true

      {:ok, view, _html} = conn |> recycle() |> live(~p"/")
      assert has_element?(view, "#demo-banner")
    end

    test "a purchase PayPal can't take is paid through the demo adapter, with a note",
         %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      {:ok, view, _html} = live(conn, ~p"/")
      render_async(view)

      capture_log(fn -> shop(view, authorization) end)

      assert has_element?(view, "#flash-info", "PayPal was unavailable")
      assert Transactions.paypal_fallback?(hd(Transactions.list_transactions()))
    end

    test "search suggestions fall back to the demo mock, labelled", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())

      capture_log(fn ->
        {:ok, view, _html} = live(conn, ~p"/")
        # Once for the cards, once for their search suggestions.
        render_async(view)
        render_async(view)

        assert has_element?(
                 view,
                 "#shop-suggested-by-#{authorization.id}",
                 "Suggested by demo-fallback"
               )
      end)
    end

    test "a crafted scenario event does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_hook(view, "run_demo_scenario", %{})

      assert Transactions.list_transactions() == []
    end
  end

  describe "Demo Mode on" do
    setup %{conn: conn}, do: %{conn: init_test_session(conn, demo_mode: true)}

    test "every page shows the banner, and the badges switch to demo", %{conn: conn} do
      transaction = transaction_fixture(authorization_fixture(agent_fixture()))

      for path <- [~p"/", ~p"/history", ~p"/transactions/#{transaction.id}"] do
        {:ok, view, _html} = live(conn, path)

        assert has_element?(view, "#demo-banner", "Demo Mode is on")
        assert has_element?(view, "#paypal-mode", "demo")
        assert has_element?(view, "#ai-provider", "demo")
        assert has_element?(view, "#demo-mode-toggle-button[aria-pressed=true]", "on")
      end
    end

    test "the banner's Turn off returns to the same page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/history")

      conn = view |> form("#demo-mode-off") |> submit_form(conn)

      assert redirected_to(conn) == "/history"
      assert get_session(conn, :demo_mode) == false
    end

    test "purchases use PayPal.Demo directly, not as a fallback", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      {:ok, view, _html} = live(conn, ~p"/")
      render_async(view)

      shop(view, authorization)

      assert has_element?(view, "#flash-info", "bought Sony WH-1000XM5 Headphones")
      refute has_element?(view, "#flash-info", "PayPal was unavailable")
      refute Transactions.paypal_fallback?(hd(Transactions.list_transactions()))
    end

    test "search suggestions use AI.Demo directly, not as a fallback", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      {:ok, view, _html} = live(conn, ~p"/")
      render_async(view)
      render_async(view)

      assert has_element?(view, "#shop-suggested-by-#{authorization.id}", "Suggested by demo")
      refute has_element?(view, "#shop-suggested-by-#{authorization.id}", "fallback")
    end

    test "investigations use AI.Demo directly, not as a fallback", %{conn: conn} do
      transaction = transaction_fixture(authorization_fixture(agent_fixture()))
      {:ok, _dispute} = Disputes.open_dispute(transaction, %{reason: :unauthorized})
      {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

      assert has_element?(view, "#case-actions", "with demo")

      view |> element("#investigate") |> render_click()
      render_async(view)

      assert has_element?(view, "#evidence-provider", "demo")
      refute has_element?(view, "#evidence-provider", "fallback")
    end

    test "the scenario builds a complete case and opens it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      {:ok, case_view, _html} =
        view
        |> element("#run-demo-scenario")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(case_view, "#flash-info", "Demo case ready")
      assert has_element?(case_view, "#timeline", "Customer authorized DemoBot")
      assert has_element?(case_view, "#event-fulfillment", "Delivered by UPS")
      assert has_element?(case_view, "#evidence-status", "Ready for review")
      assert has_element?(case_view, "#check-delivered_before_dispute .hero-check-circle")
      assert has_element?(case_view, "#demo-banner")
    end
  end
end
