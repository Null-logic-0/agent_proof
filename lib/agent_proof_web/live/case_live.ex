defmodule AgentProofWeb.CaseLive do
  use AgentProofWeb, :live_view

  require Logger

  import AgentProofWeb.CaseActions
  import AgentProofWeb.CaseHeader
  import AgentProofWeb.ErrorState
  import AgentProofWeb.EvidenceReview
  import AgentProofWeb.LoadingState
  import AgentProofWeb.SubmissionPanel
  import AgentProofWeb.Timeline

  alias AgentProof.{AI, Disputes, Evidence, Transactions}
  alias AgentProofWeb.DemoMode

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:dispute_form, to_form(%{"reason" => "unauthorized"}, as: :dispute))
     |> assign(:ai_provider, AI.provider_name(DemoMode.opts(socket.assigns.demo_mode)))
     |> assign(investigating: false, investigation_error: nil)
     |> assign(submission: nil, submitting: false, submission_error: nil)
     |> load_case(id)}
  end

  @impl true
  def handle_event("deliver", _params, socket) do
    transaction = socket.assigns.transaction

    attrs = %{
      carrier: "UPS",
      tracking_number: "1ZDEMO" <> String.pad_leading(to_string(transaction.id), 10, "0"),
      delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case Transactions.record_fulfillment(transaction, attrs) do
      {:ok, _transaction} ->
        {:noreply, socket |> reload() |> put_flash(:info, "Marked as delivered (simulated).")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Only paid transactions can be delivered.")}
    end
  end

  def handle_event("open_dispute", %{"dispute" => params}, socket) do
    case Disputes.open_dispute(socket.assigns.transaction, params) do
      {:ok, _dispute} ->
        {:noreply,
         socket |> reload() |> put_flash(:info, "The customer opened a dispute (simulated).")}

      {:error, :not_disputable} ->
        {:noreply, put_flash(socket, :error, "Only paid transactions can be disputed.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         socket |> reload() |> put_flash(:error, "This transaction is already disputed.")}
    end
  end

  # The AI can take seconds, so it runs in a task. Repeat clicks are ignored.
  def handle_event("investigate", _params, socket) do
    %{transaction: transaction, investigating: investigating} = socket.assigns

    if transaction.dispute && !investigating do
      dispute_id = transaction.dispute.id
      opts = DemoMode.opts(socket.assigns.demo_mode)

      {:noreply,
       socket
       |> assign(investigating: true, investigation_error: nil)
       |> start_async(:investigate, fn -> Evidence.generate_for_dispute(dispute_id, opts) end)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("approve_evidence", _params, socket) do
    case Evidence.approve(socket.assigns.transaction.dispute.evidence) do
      {:ok, _evidence} ->
        {:noreply,
         socket |> reload() |> put_flash(:info, "Evidence approved. It can now be submitted.")}

      {:error, :already_submitted} ->
        {:noreply, put_flash(socket, :error, "This dispute was already submitted.")}
    end
  end

  def handle_event("withdraw_approval", _params, socket) do
    case Evidence.withdraw_approval(socket.assigns.transaction.dispute.evidence) do
      {:ok, _evidence} ->
        {:noreply, socket |> reload() |> put_flash(:info, "Approval withdrawn.")}

      {:error, :already_submitted} ->
        {:noreply, put_flash(socket, :error, "This dispute was already submitted.")}
    end
  end

  def handle_event("prepare_submission", _params, socket) do
    submission = Evidence.prepare_submission(socket.assigns.transaction.dispute.evidence)
    {:noreply, assign(socket, submission: submission, submission_error: nil)}
  end

  def handle_event("cancel_submission", _params, socket) do
    {:noreply, assign(socket, submission: nil, submission_error: nil)}
  end

  # Runs in a task. Demo Mode doesn't apply: the dispute decides where evidence goes.
  def handle_event("submit_evidence", _params, socket) do
    package = socket.assigns.transaction.dispute.evidence

    if socket.assigns.submitting do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(submitting: true, submission_error: nil)
       |> start_async(:submit, fn -> Evidence.submit(package) end)}
    end
  end

  @impl true
  def handle_async(:submit, {:ok, {:ok, %{simulated?: simulated?}}}, socket) do
    message =
      if simulated?,
        do: "Evidence submitted (simulated: PayPal doesn't know this dispute).",
        else: "Evidence submitted to PayPal."

    {:noreply,
     socket
     |> assign(submission: nil, submitting: false)
     |> reload()
     |> put_flash(:info, message)}
  end

  def handle_async(:submit, {:ok, {:error, reason}}, socket) do
    Logger.warning("Evidence submission failed: #{inspect(reason, limit: 10)}")

    {:noreply, assign(socket, submitting: false, submission_error: submission_error(reason))}
  end

  def handle_async(:submit, {:exit, reason}, socket) do
    Logger.error("Evidence submission crashed: #{inspect(reason, limit: 10)}")

    {:noreply,
     assign(socket,
       submitting: false,
       submission_error: "Something went wrong while submitting. Please try again."
     )}
  end

  def handle_async(:investigate, {:ok, {:ok, evidence}}, socket) do
    message =
      if Evidence.fallback?(evidence),
        do:
          "#{socket.assigns.ai_provider} wasn't available, so the demo adapter wrote " <>
            "this evidence from the same facts.",
        else: "Evidence ready, written by #{evidence.ai_provider}."

    {:noreply,
     socket
     |> assign(:investigating, false)
     |> reload()
     |> put_flash(:info, message)}
  end

  def handle_async(:investigate, {:ok, {:error, reason}}, socket) do
    Logger.warning("AI investigation failed: #{inspect(reason, limit: 10)}")

    {:noreply,
     assign(socket, investigating: false, investigation_error: investigation_error(reason))}
  end

  def handle_async(:investigate, {:exit, reason}, socket) do
    Logger.error("AI investigation crashed: #{inspect(reason, limit: 10)}")

    {:noreply,
     assign(socket,
       investigating: false,
       investigation_error: "Something went wrong during the investigation. Please try again."
     )}
  end

  defp load_case(socket, id) do
    transaction = Transactions.get_case!(id)

    socket
    |> assign(:page_title, transaction.product_name)
    |> assign(:transaction, transaction)
    |> assign(:timeline, Transactions.timeline(transaction))
    |> assign(
      :facts,
      transaction.dispute && Transactions.reconstruct(transaction, transaction.dispute)
    )
  end

  defp reload(socket), do: load_case(socket, socket.assigns.transaction.id)

  defp submission_error(:not_approved), do: "Approve the evidence before submitting it."
  defp submission_error(:already_submitted), do: "This evidence was already submitted."

  defp submission_error({:transport, _reason}),
    do: "PayPal isn't reachable right now. Your approved evidence is safe; please try again."

  defp submission_error(_reason),
    do: "PayPal rejected the submission. Your approved evidence is safe; please try again."

  defp investigation_error({:transport, _reason}),
    do: "#{AI.provider_name()} isn't reachable. Is the AI server running?"

  defp investigation_error({:invalid_evidence, _changeset}),
    do: "The AI's answer failed validation twice, so nothing was saved."

  defp investigation_error(:invalid_json),
    do: "The AI didn't return valid JSON twice, so nothing was saved."

  defp investigation_error({:refusal, _message}),
    do: "The AI declined to write this evidence."

  defp investigation_error(:already_submitted),
    do: "This dispute was already submitted, so its evidence is frozen."

  defp investigation_error(_reason),
    do: "The AI provider returned an error. Please try again."
end
