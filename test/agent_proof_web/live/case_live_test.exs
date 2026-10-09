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

  describe "evidence review" do
    setup %{transaction: transaction} do
      {:ok, dispute} = Disputes.open_dispute(transaction, %{reason: :unauthorized})
      {:ok, package} = AgentProof.Evidence.generate_for_dispute(dispute.id)
      %{package: package}
    end

    test "shows every AI-written section beside the code-verified checks",
         %{conn: conn, transaction: transaction} do
      {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

      assert has_element?(view, "#evidence-provider", "demo")
      assert has_element?(view, "#evidence-summary")

      for section <- ~w(authorization transaction fulfillment) do
        assert has_element?(view, "#evidence-section-#{section}")
      end

      assert has_element?(view, "#evidence-section-transaction li", "search_products")
      assert has_element?(view, "#evidence-explanation", "No language model was used")
      assert has_element?(view, "#check-within_budget .hero-check-circle")
      assert has_element?(view, "#check-currency_matches .hero-check-circle")
      assert has_element?(view, "#evidence-status", "Ready for review")
    end

    test "approving shows it everywhere, and withdrawing undoes it",
         %{conn: conn, transaction: transaction} do
      {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

      view |> element("#approve-evidence") |> render_click()

      assert has_element?(view, "#evidence-status", "Approved")
      assert has_element?(view, "#event-approval", "Merchant approved the evidence")
      assert has_element?(view, "#case-actions", "Approved")
      assert has_element?(view, "#withdraw-approval")

      view |> element("#withdraw-approval") |> render_click()

      assert has_element?(view, "#evidence-status", "Ready for review")
      refute has_element?(view, "#event-approval")
      assert has_element?(view, "#approve-evidence")
    end

    test "running the investigation again discards the approval",
         %{conn: conn, transaction: transaction} do
      {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")
      view |> element("#approve-evidence") |> render_click()

      assert has_element?(view, "#investigate[data-confirm]")
      view |> element("#investigate") |> render_click()
      render_async(view)

      assert has_element?(view, "#evidence-status", "Ready for review")
      refute has_element?(view, "#event-approval")
    end
  end

  describe "PayPal submission" do
    setup %{transaction: transaction} do
      {:ok, transaction} =
        Transactions.record_fulfillment(transaction, %{
          carrier: "UPS",
          tracking_number: "1Z999AA10123456784",
          delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:ok, dispute} = Disputes.open_dispute(transaction, %{reason: :unauthorized})
      {:ok, package} = AgentProof.Evidence.generate_for_dispute(dispute.id)
      %{package: package}
    end

    test "is offered only once the evidence is approved",
         %{conn: conn, transaction: transaction, package: package} do
      {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")
      refute has_element?(view, "#prepare-submission")

      {:ok, _} = AgentProof.Evidence.approve(package)
      {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")
      assert has_element?(view, "#prepare-submission")
    end

    test "the preview shows what will be sent, and submitting freezes the case",
         %{conn: conn, transaction: transaction, package: package} do
      {:ok, _} = AgentProof.Evidence.approve(package)
      {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

      view |> element("#prepare-submission") |> render_click()

      assert has_element?(view, "#submission-mode", "simulated submission")
      assert has_element?(view, "#submission-item-0", "PROOF_OF_FULFILLMENT")
      assert has_element?(view, "#submission-item-1", "OTHER")
      assert has_element?(view, "#submission-json", "evidence_type")
      assert has_element?(view, "#submit-evidence[data-confirm]")

      view |> element("#submit-evidence") |> render_click()
      render_async(view)

      refute has_element?(view, "#submission-panel")
      assert has_element?(view, "#evidence-status", "Submitted")
      assert has_element?(view, "#event-submission", "Evidence submitted to PayPal")
      assert has_element?(view, "#case-submitted", "simulated")
      assert has_element?(view, "#case-dispute-status", "submitted")
      refute has_element?(view, "#withdraw-approval")
      refute has_element?(view, "#prepare-submission")
      refute has_element?(view, "#investigate")
    end

    test "Cancel closes the preview without submitting",
         %{conn: conn, transaction: transaction, package: package} do
      {:ok, _} = AgentProof.Evidence.approve(package)
      {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

      view |> element("#prepare-submission") |> render_click()
      view |> element("#cancel-submission") |> render_click()

      refute has_element?(view, "#submission-panel")
      assert has_element?(view, "#evidence-status", "Approved")
    end
  end

  test "the checks show failures and missing facts honestly",
       %{conn: conn, authorization: authorization} do
    # A purchase in the wrong currency, never delivered, with no budget check logged.
    flawed = transaction_fixture(authorization, %{currency: "EUR"})
    {:ok, dispute} = Disputes.open_dispute(flawed, %{reason: :not_received})
    {:ok, _package} = AgentProof.Evidence.generate_for_dispute(dispute.id)

    {:ok, view, _html} = live(conn, ~p"/transactions/#{flawed.id}")

    assert has_element?(view, "#check-currency_matches .hero-x-circle")
    assert has_element?(view, "#check-system_budget_check_logged .hero-x-circle")
    assert has_element?(view, "#check-delivered_before_dispute .hero-minus-circle")
    assert has_element?(view, "#check-delivered_before_dispute", "no delivery recorded")
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
