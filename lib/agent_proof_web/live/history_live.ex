defmodule AgentProofWeb.HistoryLive do
  use AgentProofWeb, :live_view

  require Logger

  import AgentProofWeb.{
    EmptyState,
    ErrorState,
    HistoryFilters,
    LoadingState,
    Pagination,
    TransactionTable
  }

  alias AgentProof.Transactions
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
    query = String.trim(params["q"] || "")

    status =
      if params["status"] in Transactions.history_statuses(), do: params["status"], else: ""

    sort = if params["sort"] in Transactions.history_sorts(), do: params["sort"], else: "newest"

    {:noreply,
     socket
     |> assign(
       page_number: Map.get(params, "page", "1"),
       query: query,
       status: status,
       sort: sort
     )
     |> assign(:filtered, query != "" or status != "")
     |> assign(:filters, to_form(%{"q" => query, "status" => status, "sort" => sort}))
     |> load_page()}
  end

  @impl true
  def handle_event("retry", _params, socket), do: {:noreply, load_page(socket)}

  # A new search, status, or sort starts again at page 1.
  def handle_event("filter", %{"q" => query, "status" => status, "sort" => sort}, socket) do
    {:noreply,
     push_patch(socket, to: history_path(String.trim(query), status, sort), replace: true)}
  end

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
    params = %{
      "page" => socket.assigns.page_number,
      "page_size" => @page_size,
      "q" => socket.assigns.query,
      "status" => socket.assigns.status,
      "sort" => socket.assigns.sort
    }

    source = history_source()

    socket
    |> assign(:page, AsyncResult.loading(socket.assigns.page))
    |> start_async(:load_page, fn -> source.list_transaction_history(params) end)
  end

  defp history_source do
    Application.get_env(:agent_proof, :history_source, Transactions)
  end

  defp history_path(query, status, sort, page \\ 1) do
    params =
      Enum.reject([q: query, status: status, sort: sort, page: page], fn {key, value} ->
        value in ["", nil] or {key, value} in [sort: "newest", page: 1]
      end)

    if params == [], do: ~p"/history", else: ~p"/history?#{params}"
  end

  defp no_matches_title("", status), do: "No #{status} transactions"
  defp no_matches_title(query, ""), do: "No transactions match “#{query}”"
  defp no_matches_title(query, status), do: "No #{status} transactions match “#{query}”"
end
