defmodule AgentProofWeb.DashboardLiveTest do
  use AgentProofWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AgentProof.Fixtures

  alias AgentProof.{Authorizations, Transactions}

  @grant %{
    "agent_name" => "ShopBot",
    "max_amount" => "200",
    "currency" => "USD",
    "description" => "Headphones up to $200"
  }

  test "shows the grant form and which providers are active", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#grant-form")
    assert has_element?(view, "#paypal-mode", "demo")
    assert has_element?(view, "#ai-provider", "demo")
  end

  describe "authorizing an agent" do
    test "a valid grant adds a card with an empty spending meter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#grant-form", grant: @grant) |> render_submit()

      [authorization] = Authorizations.list_authorizations()
      assert has_element?(view, "#authorizations-#{authorization.id}", "ShopBot")
      assert has_element?(view, "#meter-#{authorization.id}", "0.00")
      assert has_element?(view, "#flash-info")
    end

    test "invalid input shows errors and creates nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view |> form("#grant-form", grant: %{@grant | "max_amount" => "0"}) |> render_submit()

      assert html =~ "must be greater than 0"
      assert Authorizations.list_authorizations() == []
    end
  end

  describe "deleting a bot" do
    test "an unused bot can be deleted and its card disappears", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#delete-agent-#{authorization.id}") |> render_click()

      refute has_element?(view, "#authorizations-#{authorization.id}")
      assert has_element?(view, "#flash-info", "Deleted ShopBot.")
      assert Authorizations.list_authorizations() == []
    end

    test "a bot with purchases shows a lock instead of a delete button", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      transaction_fixture(authorization)
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#delete-locked-#{authorization.id}")
      refute has_element?(view, "#delete-agent-#{authorization.id}")
    end

    test "a crafted delete event cannot remove purchase evidence", %{conn: conn} do
      authorization = authorization_fixture(agent_fixture())
      transaction_fixture(authorization)
      {:ok, view, _html} = live(conn, ~p"/")

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
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#shop-form-#{authorization.id}", shop: %{query: "headphones"})
      |> render_submit(%{authorization_id: authorization.id})

      [transaction] = Transactions.list_transactions()
      assert has_element?(view, "#transaction-#{transaction.id}", "completed")
      assert has_element?(view, "#meter-#{authorization.id}", "189.99")
      assert has_element?(view, "#flash-info", "bought Sony WH-1000XM5 Headphones")
    end

    test "an over-budget pick is blocked and nothing is bought",
         %{conn: conn, authorization: authorization} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#shop-form-#{authorization.id}", shop: %{query: "laptop"})
      |> render_submit(%{authorization_id: authorization.id})

      assert has_element?(view, "#flash-error", "Blocked")
      assert Transactions.list_transactions() == []
    end
  end
end
