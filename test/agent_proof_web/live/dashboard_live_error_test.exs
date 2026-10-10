defmodule AgentProofWeb.DashboardLiveErrorTest do
  # async: false, so it runs after all async tests: it swaps the authorizations source.
  use AgentProofWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import AgentProof.Fixtures

  setup do
    Application.put_env(:agent_proof, :authorizations_source, AgentProof.FailingSource)
    on_exit(fn -> Application.delete_env(:agent_proof, :authorizations_source) end)
  end

  test "a failed load shows a friendly error, keeps the form usable, and can be retried",
       %{conn: conn} do
    authorization = authorization_fixture(agent_fixture())

    log =
      capture_log(fn ->
        {:ok, view, _html} = live(conn, ~p"/")
        render_async(view)

        assert has_element?(view, "#authorizations-error", "Couldn't load your agents")
        refute has_element?(view, "#authorizations-error", "database unavailable")
        assert has_element?(view, "#grant-form")

        Application.delete_env(:agent_proof, :authorizations_source)
        view |> element("#authorizations-error-retry") |> render_click()
        render_async(view)

        refute has_element?(view, "#authorizations-error")
        assert has_element?(view, "#authorizations-#{authorization.id}")
      end)

    assert log =~ "Could not load authorizations"
    assert log =~ "database unavailable"
  end

  test "a failed 'load more' keeps the shown cards and lets you try again", %{conn: conn} do
    Application.delete_env(:agent_proof, :authorizations_source)
    for n <- 1..4, do: authorization_fixture(agent_fixture(%{name: "Bot #{n}"}))

    {:ok, view, _html} = live(conn, ~p"/")
    render_async(view)

    Application.put_env(:agent_proof, :authorizations_source, AgentProof.FailingSource)

    log =
      capture_log(fn ->
        view |> element("#load-more") |> render_click()
        render_async(view)
      end)

    assert log =~ "Could not load more authorizations"
    assert has_element?(view, "#flash-error", "Couldn't load more agents")
    assert has_element?(view, "#load-more")
    refute has_element?(view, "#authorizations-error")
  end
end
