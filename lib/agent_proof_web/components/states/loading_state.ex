defmodule AgentProofWeb.LoadingState do
  use AgentProofWeb, :html

  @doc """
  Placeholder rows shown while data loads.
  """
  attr :id, :string, required: true
  attr :rows, :integer, default: 5

  def loading_state(assigns) do
    ~H"""
    <div
      id={@id}
      role="status"
      aria-live="polite"
      class="rounded-box border border-base-300 bg-base-100 p-4"
    >
      <span class="sr-only">Loading…</span>
      <div class="skeleton mb-4 h-4 w-1/3"></div>
      <div :for={_row <- 1..@rows//1} class="flex items-center gap-4 border-t border-base-200 py-3">
        <div class="skeleton h-4 w-24 shrink-0"></div>
        <div class="skeleton h-4 flex-1"></div>
        <div class="skeleton h-4 w-16 shrink-0"></div>
      </div>
    </div>
    """
  end
end
