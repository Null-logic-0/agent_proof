defmodule AgentProofWeb.HistoryLiveTest do
  use AgentProofWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AgentProof.Fixtures

  # History loads in a background task; render_async/1 waits for it.
  defp live_history(conn, path \\ ~p"/history") do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    view
  end

  test "the first render shows a loading skeleton", %{conn: conn} do
    html = conn |> get(~p"/history") |> html_response(200)

    assert html =~ ~s(id="history-loading")
  end

  test "shows an empty state when there are no transactions", %{conn: conn} do
    view = live_history(conn)

    assert has_element?(view, "#history-empty")
    refute has_element?(view, "#history-loading")
    refute has_element?(view, "#transactions")
    refute has_element?(view, "#pagination")
  end

  test "lists transactions with their agent and status", %{conn: conn} do
    transaction = transaction_fixture(authorization_fixture(agent_fixture()))
    view = live_history(conn)

    assert has_element?(view, "#transactions-#{transaction.id}", "ShopBot")
    assert has_element?(view, "#transactions-#{transaction.id}", "Sony WH-1000XM5 Headphones")
    assert has_element?(view, "#transactions-#{transaction.id}", "completed")
    assert has_element?(view, "#history-total", "1 transactions")
    refute has_element?(view, "#pagination")
  end

  test "a page past the end says so and links back to page 1", %{conn: conn} do
    transaction_fixture(authorization_fixture(agent_fixture()))
    view = live_history(conn, ~p"/history?page=5")

    assert has_element?(view, "#history-page-empty", "There is no page 5")
    assert has_element?(view, "#history-page-empty a[href='/history']")
  end

  describe "pagination" do
    setup do
      authorization = authorization_fixture(agent_fixture())
      # 21 transactions: a full first page of 20, plus one on page 2.
      transactions = for _ <- 1..21, do: transaction_fixture(authorization)
      %{oldest: hd(transactions), newest: List.last(transactions)}
    end

    test "page 1 shows the newest 20", %{conn: conn, oldest: oldest, newest: newest} do
      view = live_history(conn)

      assert has_element?(view, "#transactions-#{newest.id}")
      refute has_element?(view, "#transactions-#{oldest.id}")
      assert has_element?(view, "#page-2")
      assert has_element?(view, "#page-next")
      refute has_element?(view, "#page-prev")
    end

    test "moving to page 2 replaces the rows instead of appending them",
         %{conn: conn, oldest: oldest, newest: newest} do
      view = live_history(conn)

      view |> element("#page-next") |> render_click()
      assert_patch(view, ~p"/history?page=2")
      render_async(view)

      assert has_element?(view, "#transactions-#{oldest.id}")
      refute has_element?(view, "#transactions-#{newest.id}")
      assert has_element?(view, "#page-prev")
    end

    test "an invalid page param falls back to page 1", %{conn: conn, newest: newest} do
      view = live_history(conn, ~p"/history?page=abc")

      assert has_element?(view, "#transactions-#{newest.id}")
    end
  end

  test "the navbar links here from every page, marked current here", %{conn: conn} do
    {:ok, dashboard, _html} = live(conn, ~p"/")
    refute has_element?(dashboard, "#nav-history[aria-current]")

    assert {:ok, history, _html} =
             dashboard
             |> element("#nav-history")
             |> render_click()
             |> follow_redirect(conn, ~p"/history")

    assert has_element?(history, "#nav-history[aria-current=page]")
  end

  test "the dashboard links here once a bot has 5 purchases", %{conn: conn} do
    authorization = authorization_fixture(agent_fixture())
    for _ <- 1..5, do: transaction_fixture(authorization)

    {:ok, view, _html} = live(conn, ~p"/")
    render_async(view)

    assert {:ok, _history, _html} =
             view
             |> element("#authorizations-#{authorization.id} a", "View transaction history")
             |> render_click()
             |> follow_redirect(conn, ~p"/history")
  end
end
