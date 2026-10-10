defmodule AgentProofWeb.ErrorState do
  use AgentProofWeb, :html

  @doc """
  A friendly error message with a Try again button.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :retry, :string, required: true, doc: "the event the Try again button sends"

  def error_state(assigns) do
    ~H"""
    <div id={@id} role="alert" class="card border border-error/30 bg-error/5">
      <div class="card-body items-center text-center">
        <.icon name="hero-exclamation-triangle" class="size-8 text-error" />
        <p class="font-medium">{@title}</p>
        <p class="text-sm text-base-content/70">{@message}</p>
        <button
          type="button"
          id={"#{@id}-retry"}
          class="btn btn-sm btn-outline btn-error mt-2"
          phx-click={@retry}
          phx-disable-with="Retrying…"
        >
          <.icon name="hero-arrow-path" class="size-4" /> Try again
        </button>
      </div>
    </div>
    """
  end
end
