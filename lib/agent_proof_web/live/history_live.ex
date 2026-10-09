defmodule AgentProofWeb.HistoryLive do
  use AgentProofWeb, :live_view

  require Logger

  import AgentProofWeb.EmptyState
  import AgentProofWeb.ErrorState
  import AgentProofWeb.LoadingState
  import AgentProofWeb.Pagination
  import AgentProofWeb.TransactionTable

  alias Phoenix.LiveView.AsyncResult

  @page_size "20"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Transaction History")
     |> assign(:page, AsyncResult.loading())
     |> stream(:transactions, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:page_number, Map.get(params, "page", "1"))
     |> load_page()}
  end

  @impl true
  def handle_event("retry", _params, socket), do: {:noreply, load_page(socket)}

  @impl true
  def handle_async(:load_page, {:ok, {transactions, meta}}, socket) do
    {:noreply,
     socket
     |> assign(:page, AsyncResult.ok(socket.assigns.page, meta))
     |> stream(:transactions, transactions, reset: true)}
  end

  def handle_async(:load_page, {:exit, reason}, socket) do
    Logger.error("Could not load the transaction history: #{inspect(reason)}")

    {:noreply, assign(socket, :page, AsyncResult.failed(%AsyncResult{}, reason))}
  end

  defp load_page(socket) do
    params = %{"page" => socket.assigns.page_number, "page_size" => @page_size}
    source = history_source()

    socket
    |> assign(:page, AsyncResult.loading(socket.assigns.page))
    |> start_async(:load_page, fn -> source.list_transaction_history(params) end)
  end

  defp history_source do
    Application.get_env(:agent_proof, :history_source, AgentProof.Transactions)
  end

  defp page_path(page), do: ~p"/history?page=#{page}"
end
