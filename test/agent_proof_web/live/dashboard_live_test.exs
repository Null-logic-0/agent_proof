defmodule AgentProofWeb.DashboardLiveTest do
  use AgentProofWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AgentProof.Fixtures

  alias AgentProof.{Authorizations, Transactions}

  # The authorization cards load in a background task; render_async/1 waits for it.
  defp live_dashboard(conn) do
    {:ok, view, _html} = live(conn, ~p"/")
    render_async(view)
    view
  end

  @grant %{
    "agent_name" => "ShopBot",
    "max_amount" => "200",
    "currency" => "USD",
    "description" => "Headphones up to $200"
  }

  test "shows the grant form and which providers are active", %{conn: conn} do
    view = live_dashboard(conn)

    assert has_element?(view, "#grant-form")
    assert has_element?(view, "#paypal-mode", "demo")
    assert has_element?(view, "#ai-provider", "demo")
  end

  describe "infinite scroll" do
    setup do
      %{
        authorizations:
          for(n <- 1..5, do: authorization_fixture(agent_fixture(%{name: "Bot #{n}"})))
      }
    end

    defp card_ids(view) do
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#authorizations > article")
      |> LazyHTML.attribute("id")
    end

    test "renders the newest 3 cards first", %{conn: conn, authorizations: auths} do
      [_a1, _a2, a3, a4, a5] = auths
      view = live_dashboard(conn)

      assert card_ids(view) == [
               "authorizations-#{a5.id}",
               "authorizations-#{a4.id}",
               "authorizations-#{a3.id}"
             ]

      assert has_element?(view, "#load-more")
      assert has_element?(view, "#authorizations[phx-viewport-bottom=load_more]")
    end

    test "reaching the bottom loads the next cards, until there are no more",
         %{conn: conn, authorizations: [a1, a2 | _]} do
      view = live_dashboard(conn)

      # What phx-viewport-bottom sends when the last card scrolls into view.
      render_hook(view, "load_more", %{})
      render_async(view)

      assert Enum.take(card_ids(view), -2) == [
               "authorizations-#{a2.id}",
               "authorizations-#{a1.id}"
             ]

      assert length(card_ids(view)) == 5
      refute has_element?(view, "#load-more")
      refute has_element?(view, "#authorizations[phx-viewport-bottom]")
    end

    test "the Load more button does the same", %{conn: conn} do
      view = live_dashboard(conn)

      view |> element("#load-more") |> render_click()
      render_async(view)

      assert length(card_ids(view)) == 5
    end

    test "a new agent appears on top and later loads don't repeat or skip any",
         %{conn: conn} do
      view = live_dashboard(conn)

      view
      |> form("#grant-form", grant: %{@grant | "agent_name" => "Newcomer"})
      |> render_submit()

      view |> element("#load-more") |> render_click()
      render_async(view)

      ids = card_ids(view)
      assert length(ids) == 6
      assert ids == Enum.uniq(ids)
      assert has_element?(view, "#authorizations > article:first-child", "Newcomer")
    end
  end

  describe "loading the agents" do
    test "the first render shows the form right away and placeholders for the list",
         %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(id="grant-form")
      assert html =~ ~s(id="authorizations-loading")
    end

    test "with no agents, the empty state shows once loaded", %{conn: conn} do
      view = live_dashboard(conn)

      assert has_element?(view, "#authorizations-empty", "No authorized agents yet")
      refute has_element?(view, "#authorizations-loading")
    end

    test "existing agents appear once loaded", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      view = live_dashboard(conn)

      assert has_element?(view, "#authorizations-#{authorization.id}", "ShopBot")
    end
  end

  describe "authorizing an agent" do
    test "a valid grant adds a card with an empty spending meter", %{conn: conn} do
      view = live_dashboard(conn)

      view |> form("#grant-form", grant: @grant) |> render_submit()

      [authorization] = Authorizations.list_authorizations()
      assert has_element?(view, "#authorizations-#{authorization.id}", "ShopBot")
      assert has_element?(view, "#meter-#{authorization.id}", "0.00")
      assert has_element?(view, "#flash-info")
    end

    test "invalid input shows errors and creates nothing", %{conn: conn} do
      view = live_dashboard(conn)

      html =
        view |> form("#grant-form", grant: %{@grant | "max_amount" => "0"}) |> render_submit()

      assert html =~ "must be greater than 0"
      assert Authorizations.list_authorizations() == []
    end
  end

  describe "editing a bot" do
    setup do
      %{authorization: authorization_fixture(agent_fixture())}
    end

    test "the edit button opens a prefilled modal", %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)
      refute has_element?(view, "#edit-agent-modal")

      view |> element("#edit-agent-#{authorization.id}") |> render_click()

      assert has_element?(view, "#edit-agent-form #settings_agent_name[value='ShopBot']")
      assert has_element?(view, "#edit-agent-spent", "0.00")
    end

    test "saving updates the card and closes the modal",
         %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)
      view |> element("#edit-agent-#{authorization.id}") |> render_click()

      view
      |> form("#edit-agent-form",
        settings: %{agent_name: "ShopBot Pro", max_amount: "500", description: "Audio gear"}
      )
      |> render_submit()

      refute has_element?(view, "#edit-agent-modal")
      assert has_element?(view, "#authorizations-#{authorization.id}", "ShopBot Pro")
      assert has_element?(view, "#meter-#{authorization.id}", "500.00")
      assert has_element?(view, "#flash-info", "Updated ShopBot Pro.")
    end

    test "invalid input keeps the modal open with errors",
         %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)
      view |> element("#edit-agent-#{authorization.id}") |> render_click()

      html = view |> form("#edit-agent-form", settings: %{max_amount: "0"}) |> render_change()

      assert html =~ "must be greater than 0"
      assert has_element?(view, "#edit-agent-modal")
    end

    test "cancel closes the modal without changes", %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)
      view |> element("#edit-agent-#{authorization.id}") |> render_click()

      view |> element("#edit-agent-cancel") |> render_click()

      refute has_element?(view, "#edit-agent-modal")
      assert has_element?(view, "#authorizations-#{authorization.id}", "ShopBot")
    end
  end

  describe "deleting a bot" do
    test "an unused bot can be deleted and its card disappears", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      view = live_dashboard(conn)

      view |> element("#delete-agent-#{authorization.id}") |> render_click()

      refute has_element?(view, "#authorizations-#{authorization.id}")
      assert has_element?(view, "#flash-info", "Deleted ShopBot.")
      assert Authorizations.list_authorizations() == []
    end

    test "a bot with purchases shows a lock instead of a delete button", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      transaction_fixture(authorization)
      view = live_dashboard(conn)

      assert has_element?(view, "#delete-locked-#{authorization.id}")
      refute has_element?(view, "#delete-agent-#{authorization.id}")
    end

    test "a crafted delete event cannot remove purchase evidence", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      transaction_fixture(authorization)
      view = live_dashboard(conn)

      render_click(view, "delete_agent", %{"id" => authorization.id})

      assert has_element?(view, "#flash-error", "kept as dispute evidence")
      assert has_element?(view, "#authorizations-#{authorization.id}")
    end
  end

  describe "letting the agent shop" do
    setup do
      %{authorization: authorization_fixture(agent_fixture())}
    end

    test "a purchase appears on the card and fills the meter",
         %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)

      view
      |> form("#shop-form-#{authorization.id}", shop: %{query: "headphones"})
      |> render_submit(%{authorization_id: authorization.id})

      [transaction] = Transactions.list_transactions()
      assert has_element?(view, "#transaction-#{transaction.id}", "completed")
      assert has_element?(view, "#meter-#{authorization.id}", "189.99")
      assert has_element?(view, "#flash-info", "bought Sony WH-1000XM5 Headphones")
    end

    test "a new card's search box starts empty, not with a guess",
         %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)

      assert has_element?(view, "#shop-query-#{authorization.id}[placeholder]")
      refute has_element?(view, "#shop-query-#{authorization.id}[value]:not([value=''])")
    end

    test "a blank search asks for a query and buys nothing",
         %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)

      view
      |> form("#shop-form-#{authorization.id}", shop: %{query: "   "})
      |> render_submit(%{authorization_id: authorization.id})

      assert has_element?(view, "#flash-error", "Tell the agent what to look for first.")
      assert Transactions.list_transactions() == []
    end

    test "the search box keeps what was searched for after shopping",
         %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)

      view
      |> form("#shop-form-#{authorization.id}", shop: %{query: "usb cable"})
      |> render_submit(%{authorization_id: authorization.id})

      [transaction] = Transactions.list_transactions()
      assert transaction.product_name == "Anker USB-C Cable (6 ft)"
      assert has_element?(view, "#shop-query-#{authorization.id}[value='usb cable']")
    end

    test "the search box suggests the catalog's products",
         %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)

      assert has_element?(view, "#shop-query-#{authorization.id}[list=catalog-products]")

      for name <- Enum.map(AgentProof.Catalog.list_products(), & &1.name) do
        assert has_element?(view, ~s(#catalog-products option[value="#{name}"]))
      end
    end

    test "an over-budget pick is blocked and nothing is bought",
         %{conn: conn, authorization: authorization} do
      view = live_dashboard(conn)

      view
      |> form("#shop-form-#{authorization.id}", shop: %{query: "laptop"})
      |> render_submit(%{authorization_id: authorization.id})

      assert has_element?(view, "#flash-error", "Blocked")
      assert Transactions.list_transactions() == []
    end
  end
end
