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

  describe "search and sort" do
    setup do
      shop_bot = authorization_fixture(agent_fixture())
      office_bot = authorization_fixture(agent_fixture(%{name: "OfficeBot"}))

      %{
        headphones: transaction_fixture(shop_bot),
        laptop:
          transaction_fixture(shop_bot, %{
            product_name: "MacBook Air 13-inch Laptop",
            amount: "1099.00"
          }),
        cable:
          transaction_fixture(office_bot, %{
            product_name: "Anker USB-C Cable (6 ft)",
            amount: "19.99"
          })
      }
    end

    defp filter(view, q, sort),
      do: view |> form("#history-filters", %{q: q, sort: sort}) |> render_change()

    defp row_ids(view) do
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#transactions tr")
      |> LazyHTML.attribute("id")
    end

    test "typing a search filters the rows and keeps it in the URL",
         %{conn: conn, laptop: laptop, headphones: headphones} do
      view = live_history(conn)

      filter(view, "macbook", "newest")
      assert_patch(view, ~p"/history?q=macbook")
      render_async(view)

      assert has_element?(view, "#transactions-#{laptop.id}")
      refute has_element?(view, "#transactions-#{headphones.id}")
      assert has_element?(view, "#history-total", "1 matching transactions")
    end

    test "agents can be searched too", %{conn: conn, cable: cable, laptop: laptop} do
      view = live_history(conn, ~p"/history?q=officebot")

      assert has_element?(view, "#transactions-#{cable.id}")
      refute has_element?(view, "#transactions-#{laptop.id}")
      assert has_element?(view, "#history-search[value=officebot]")
    end

    test "no matches says so, and Clear filters brings everything back", %{conn: conn} do
      view = live_history(conn)

      filter(view, "zzz", "newest")
      assert_patch(view, ~p"/history?q=zzz")
      render_async(view)

      assert has_element?(view, "#history-no-matches", "No transactions match “zzz”")
      refute has_element?(view, "#history-empty")

      view |> element("#clear-filters") |> render_click()
      assert_patch(view, ~p"/history")
      render_async(view)

      assert length(row_ids(view)) == 3
    end

    test "the sort reorders the rows and keeps it in the URL",
         %{conn: conn, laptop: laptop, headphones: headphones, cable: cable} do
      view = live_history(conn)

      filter(view, "", "amount_desc")
      assert_patch(view, ~p"/history?sort=amount_desc")
      render_async(view)

      assert row_ids(view) ==
               Enum.map([laptop, headphones, cable], &"transactions-#{&1.id}")

      assert has_element?(view, "#history-sort option[selected][value=amount_desc]")
    end

    test "the status filter shows only that status and keeps it in the URL",
         %{conn: conn, laptop: laptop, headphones: headphones} do
      failed = transaction_fixture(%{id: laptop.authorization_id}, %{status: :failed})
      view = live_history(conn)

      view |> form("#history-filters", %{status: "failed"}) |> render_change()
      assert_patch(view, ~p"/history?status=failed")
      render_async(view)

      assert row_ids(view) == ["transactions-#{failed.id}"]
      refute has_element?(view, "#transactions-#{headphones.id}")
      assert has_element?(view, "#history-status option[selected][value=failed]")
      assert has_element?(view, "#history-total", "1 matching transactions")
    end

    test "a status with no transactions says so", %{conn: conn} do
      view = live_history(conn, ~p"/history?status=created")

      assert has_element?(view, "#history-no-matches", "No created transactions")
      assert has_element?(view, "#clear-filters[href='/history']")
    end

    test "an unknown status shows every status", %{conn: conn} do
      view = live_history(conn, ~p"/history?status=bogus")

      assert has_element?(view, "#history-status option[selected][value='']")
      assert length(row_ids(view)) == 3
    end

    test "an unknown sort falls back to newest first", %{conn: conn} do
      view = live_history(conn, ~p"/history?sort=bogus")

      assert has_element?(view, "#history-sort option[selected][value=newest]")
      assert length(row_ids(view)) == 3
    end

    test "page links keep the search, the status, and the sort", %{conn: conn, laptop: laptop} do
      for _ <- 1..20,
          do:
            transaction_fixture(%{id: laptop.authorization_id}, %{
              product_name: "MacBook Air 13-inch Laptop"
            })

      view = live_history(conn, ~p"/history?q=macbook&status=completed&sort=amount_asc")

      assert has_element?(
               view,
               "#page-2[href='/history?page=2&q=macbook&sort=amount_asc&status=completed']"
             )
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
