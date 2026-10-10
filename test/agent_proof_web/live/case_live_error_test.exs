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
    on_exit(fn -> Application.put_env(:agent_proof, :ai_provider, original) end)

    authorization = authorization_fixture(agent_fixture())
    {:ok, transaction} = ShoppingAgent.run(authorization, "headphones")
    {:ok, _dispute} = Disputes.open_dispute(transaction, %{reason: :unauthorized})

    %{original_provider: original, transaction: transaction}
  end

  defp use_ai(provider), do: Application.put_env(:agent_proof, :ai_provider, provider)

  test "an unreachable AI falls back to demo evidence, clearly labelled",
       %{conn: conn, transaction: transaction} do
    use_ai(AgentProof.AI.FailingProvider)
    {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

    log =
      capture_log(fn ->
        view |> element("#investigate") |> render_click()
        render_async(view)
      end)

    assert log =~ "AI investigation failed with failing"
    assert has_element?(view, "#evidence-provider.badge-warning", "demo-fallback")
    assert has_element?(view, "#flash-info", "failing wasn't available")
    assert has_element?(view, "#event-evidence", "demo-fallback")
    assert has_element?(view, "#case-dispute-status", "evidence ready")
    refute has_element?(view, "#investigation-error")
  end

  test "a crashing AI shows a plain error, saves nothing, and Try again works",
       %{conn: conn, transaction: transaction, original_provider: original} do
    use_ai(AgentProof.AI.CrashingProvider)
    {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")

    log =
      capture_log(fn ->
        view |> element("#investigate") |> render_click()
        render_async(view)
      end)

    assert log =~ "AI investigation crashed"
    assert has_element?(view, "#investigation-error", "Something went wrong")
    refute has_element?(view, "#evidence-summary")
    assert has_element?(view, "#case-dispute-status", "open")

    # The AI is fixed; Try again runs the investigation.
    use_ai(original)
    view |> element("#investigation-error-retry") |> render_click()
    render_async(view)

    refute has_element?(view, "#investigation-error")
    assert has_element?(view, "#evidence-summary")
  end
end
