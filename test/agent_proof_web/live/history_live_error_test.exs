defmodule AgentProofWeb.HistoryLiveErrorTest do
  # async: false, so it runs after all async tests: it swaps the history source.
  use AgentProofWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import AgentProof.Fixtures

  setup do
    Application.put_env(:agent_proof, :history_source, AgentProof.FailingSource)
    on_exit(fn -> Application.delete_env(:agent_proof, :history_source) end)
  end

  test "a failed load shows a friendly error, logs the real one, and can be retried",
       %{conn: conn} do
    transaction = transaction_fixture(authorization_fixture(agent_fixture()))

    log =
      capture_log(fn ->
        {:ok, view, _html} = live(conn, ~p"/history")
        render_async(view)

        assert has_element?(view, "#history-error", "Couldn't load the transaction history")
        refute has_element?(view, "#history-error", "database unavailable")

        Application.delete_env(:agent_proof, :history_source)
        view |> element("#history-error-retry") |> render_click()
        render_async(view)

        refute has_element?(view, "#history-error")
        assert has_element?(view, "#transactions-#{transaction.id}")
      end)

    assert log =~ "Could not load the transaction history"
    assert log =~ "database unavailable"
  end

  test "an error after a successful load replaces the stale table", %{conn: conn} do
    Application.delete_env(:agent_proof, :history_source)
    transaction = transaction_fixture(authorization_fixture(agent_fixture()))

    {:ok, view, _html} = live(conn, ~p"/history")
    render_async(view)
    assert has_element?(view, "#transactions-#{transaction.id}")

    Application.put_env(:agent_proof, :history_source, AgentProof.FailingSource)

    capture_log(fn ->
      render_patch(view, ~p"/history?page=2")
      render_async(view)
    end)

    assert has_element?(view, "#history-error")
    refute has_element?(view, "#transactions")
  end
end
