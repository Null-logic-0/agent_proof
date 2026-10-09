defmodule AgentProofWeb.CaseLiveErrorTest do
  # async: false because it swaps the AI provider in application config.
  # ExUnit runs this only after every async test has finished.
  use AgentProofWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import AgentProof.Fixtures

  alias AgentProof.Disputes
  alias AgentProof.Agents.ShoppingAgent

  setup do
    original = Application.fetch_env!(:agent_proof, :ai_provider)
    Application.put_env(:agent_proof, :ai_provider, AgentProof.AI.FailingProvider)
    on_exit(fn -> Application.put_env(:agent_proof, :ai_provider, original) end)
    %{original_provider: original}
  end

  test "an unreachable AI shows a plain error, saves nothing, and Try again works",
       %{conn: conn, original_provider: original} do
    authorization = authorization_fixture(agent_fixture())
    {:ok, transaction} = ShoppingAgent.run(authorization, "headphones")
    {:ok, _dispute} = Disputes.open_dispute(transaction, %{reason: :unauthorized})

    {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

    log =
      capture_log(fn ->
        view |> element("#investigate") |> render_click()
        render_async(view)
      end)

    assert log =~ "AI investigation failed"
    assert has_element?(view, "#investigation-error", "failing isn't reachable")
    refute has_element?(view, "#evidence-summary")
    assert has_element?(view, "#case-dispute-status", "open")

    # The AI comes back; Try again runs the investigation.
    Application.put_env(:agent_proof, :ai_provider, original)
    view |> element("#investigation-error-retry") |> render_click()
    render_async(view)

    refute has_element?(view, "#investigation-error")
    assert has_element?(view, "#evidence-summary")
  end
end
