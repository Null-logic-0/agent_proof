defmodule AgentProofWeb.CaseLiveSubmissionErrorTest do
  # async: false, so it runs after all async tests: it swaps the PayPal adapter in config.
  use AgentProofWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import AgentProof.Fixtures

  alias AgentProof.Evidence

  setup do
    original = Application.fetch_env!(:agent_proof, :paypal_adapter)
    on_exit(fn -> Application.put_env(:agent_proof, :paypal_adapter, original) end)
    %{original_adapter: original}
  end

  test "an unreachable PayPal keeps the evidence approved and lets you try again",
       %{conn: conn, original_adapter: original} do
    # A dispute PayPal knows (no DEMO- prefix), so the configured adapter is used.
    transaction = transaction_fixture(authorization_fixture(agent_fixture()))
    dispute = dispute_fixture(transaction, %{paypal_dispute_id: "PP-D-12345"})
    {:ok, package} = Evidence.generate_for_dispute(dispute.id)
    {:ok, _} = Evidence.approve(package)

    Application.put_env(:agent_proof, :paypal_adapter, AgentProof.FailingPayPal)
    {:ok, view, _html} = live(conn, ~p"/transactions/#{transaction.id}")
    view |> element("#prepare-submission") |> render_click()
    assert has_element?(view, "#submission-mode", "PayPal Sandbox")

    log =
      capture_log(fn ->
        view |> element("#submit-evidence") |> render_click()
        render_async(view)
      end)

    assert log =~ "Evidence submission failed"
    assert has_element?(view, "#submission-error", "PayPal isn't reachable")
    assert has_element?(view, "#evidence-status", "Approved")

    Application.put_env(:agent_proof, :paypal_adapter, original)
    view |> element("#submission-error-retry") |> render_click()
    render_async(view)

    assert has_element?(view, "#evidence-status", "Submitted")
  end
end
