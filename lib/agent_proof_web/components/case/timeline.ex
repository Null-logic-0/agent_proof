defmodule AgentProofWeb.Timeline do
  use AgentProofWeb, :html

  @doc """
  The transaction timeline: who did what, when. `events` come from
  `AgentProof.Transactions.timeline/1`, oldest first.
  """
  attr :events, :list, required: true

  def timeline(assigns) do
    assigns = assign(assigns, :last, length(assigns.events) - 1)

    ~H"""
    <ul id="timeline" class="timeline timeline-vertical timeline-compact timeline-snap-icon">
      <li :for={{event, index} <- Enum.with_index(@events)} id={"event-#{event.id}"}>
        <hr :if={index > 0} class="bg-base-300" />
        <div class="timeline-middle">
          <span class={[
            "grid size-8 place-items-center rounded-full",
            actor_style(event)
          ]}>
            <.icon name={actor_icon(event.actor)} class="size-4" />
          </span>
        </div>
        <div class="timeline-end mb-6 ml-2 min-w-0">
          <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
            <time class="text-xs text-base-content/50 tabular-nums">
              {Calendar.strftime(event.at, "%b %-d, %H:%M:%S")}
            </time>
            <span class="text-xs font-medium text-base-content/60">{actor_label(event.actor)}</span>
            <span :if={event.simulated?} class="badge badge-ghost badge-xs">simulated</span>
          </div>
          <p class={["font-medium", event.status == :error && "text-error"]}>{event.title}</p>
          <p :if={event.details} class="break-words text-sm text-base-content/70">
            {event.details}
          </p>
        </div>
        <hr :if={index < @last} class="bg-base-300" />
      </li>
    </ul>
    """
  end

  defp actor_icon(:customer), do: "hero-user"
  defp actor_icon(:agent), do: "hero-cpu-chip"
  defp actor_icon(:system), do: "hero-shield-check"
  defp actor_icon(:paypal), do: "hero-credit-card"
  defp actor_icon(:carrier), do: "hero-truck"
  defp actor_icon(:ai), do: "hero-sparkles"
  defp actor_icon(:merchant), do: "hero-building-storefront"

  defp actor_label(:customer), do: "Customer"
  defp actor_label(:agent), do: "Agent"
  defp actor_label(:system), do: "AgentProof"
  defp actor_label(:paypal), do: "PayPal"
  defp actor_label(:carrier), do: "Carrier"
  defp actor_label(:ai), do: "AI"
  defp actor_label(:merchant), do: "Merchant"

  defp actor_style(%{status: :error}), do: "bg-error/15 text-error"
  defp actor_style(%{status: :warning}), do: "bg-warning/15 text-warning"
  defp actor_style(%{actor: :agent}), do: "bg-primary/15 text-primary"
  defp actor_style(%{actor: :system}), do: "bg-success/15 text-success"
  defp actor_style(%{actor: :ai}), do: "bg-secondary/15 text-secondary"
  defp actor_style(%{actor: :merchant}), do: "bg-success/15 text-success"
  defp actor_style(_event), do: "bg-base-200 text-base-content/70"
end
