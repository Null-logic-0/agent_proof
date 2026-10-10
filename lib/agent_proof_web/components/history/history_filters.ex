defmodule AgentProofWeb.HistoryFilters do
  use AgentProofWeb, :html

  @status_options [
    {"All statuses", ""},
    {"Completed", "completed"},
    {"Created", "created"},
    {"Failed", "failed"}
  ]

  @sort_options [
    {"Newest first", "newest"},
    {"Oldest first", "oldest"},
    {"Amount: high to low", "amount_desc"},
    {"Amount: low to high", "amount_asc"},
    {"Status: completed first", "status_asc"},
    {"Status: failed first", "status_desc"}
  ]

  @doc """
  Search, status filter, and sort for the transaction history.
  """
  attr :form, Phoenix.HTML.Form, required: true

  def history_filters(assigns) do
    assigns = assign(assigns, status_options: @status_options, sort_options: @sort_options)

    ~H"""
    <.form
      for={@form}
      id="history-filters"
      phx-change="filter"
      phx-submit="filter"
      class="mb-4 flex flex-col gap-2 sm:flex-row sm:items-start"
    >
      <div class="min-w-0 flex-1">
        <.input
          field={@form[:q]}
          id="history-search"
          type="search"
          placeholder="Search by product, agent, or PayPal order"
          autocomplete="off"
          phx-debounce="300"
        />
      </div>
      <div class="sm:w-44">
        <.input
          field={@form[:status]}
          id="history-status"
          type="select"
          options={@status_options}
          aria-label="Filter by status"
        />
      </div>
      <div class="sm:w-60">
        <.input
          field={@form[:sort]}
          id="history-sort"
          type="select"
          options={@sort_options}
          aria-label="Sort transactions"
        />
      </div>
    </.form>
    """
  end
end
