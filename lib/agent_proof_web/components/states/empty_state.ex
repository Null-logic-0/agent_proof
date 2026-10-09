defmodule AgentProofWeb.EmptyState do
  use AgentProofWeb, :html

  @doc """
  Shown when there is nothing to list, with an optional next step.
  """
  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :class, :any, default: nil, doc: "extra classes, added to the defaults"
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div id={@id} class={["card border border-dashed border-base-300", @class]}>
      <div class="card-body items-center text-center">
        <.icon name={@icon} class="size-8 text-base-content/30" />
        <p class="text-sm font-medium">{@title}</p>
        <p class="text-sm text-base-content/60">{@message}</p>
        <div :if={@actions != []} class="mt-2">{render_slot(@actions)}</div>
      </div>
    </div>
    """
  end
end
