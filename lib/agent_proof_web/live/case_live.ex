defmodule AgentProofWeb.CaseLive do
  use AgentProofWeb, :live_view

  require Logger

  import AgentProofWeb.CaseActions
  import AgentProofWeb.CaseHeader
  import AgentProofWeb.ErrorState
  import AgentProofWeb.EvidenceSummary
  import AgentProofWeb.LoadingState
  import AgentProofWeb.Timeline

  alias AgentProof.{AI, Disputes, Evidence, Transactions}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:dispute_form, to_form(%{"reason" => "unauthorized"}, as: :dispute))
     |> assign(:ai_provider, AI.provider_name())
     |> assign(investigating: false, investigation_error: nil)
     |> load_case(id)}
  end

  # Simulated carrier: records a UPS delivery that happens now.
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

  # Simulated customer: opens a dispute with the chosen reason.
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

  # Runs the AI in a task: it can take 5–15 seconds, and the page stays
  # responsive meanwhile. A second click while it runs is ignored.
  def handle_event("investigate", _params, socket) do
    %{transaction: transaction, investigating: investigating} = socket.assigns

    if transaction.dispute && !investigating do
      dispute_id = transaction.dispute.id

      {:noreply,
       socket
       |> assign(investigating: true, investigation_error: nil)
       |> start_async(:investigate, fn -> Evidence.generate_for_dispute(dispute_id) end)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_async(:investigate, {:ok, {:ok, evidence}}, socket) do
    {:noreply,
     socket
     |> assign(:investigating, false)
     |> reload()
     |> put_flash(:info, "Evidence ready, written by #{evidence.ai_provider}.")}
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
  end

  defp reload(socket), do: load_case(socket, socket.assigns.transaction.id)

  # Plain-language reasons; the details are in the server log.
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
