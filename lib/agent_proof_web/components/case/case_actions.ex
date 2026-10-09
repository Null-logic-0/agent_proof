defmodule AgentProofWeb.CaseActions do
  use AgentProofWeb, :html

  @reasons [
    {"Unauthorized", "unauthorized"},
    {"Not received", "not_received"},
    {"Not as described", "not_as_described"},
    {"Other", "other"}
  ]

  @doc """
  The demo's next steps for a case: deliver (simulated carrier), dispute
  (simulated customer), then the AI investigation. Its events are handled by
  the LiveView.
  """
  attr :transaction, :map, required: true, doc: "a transaction from Transactions.get_case!/1"
  attr :dispute_form, Phoenix.HTML.Form, required: true
  attr :investigating, :boolean, required: true
  attr :ai_provider, :string, required: true

  def case_actions(assigns) do
    assigns = assign(assigns, :reasons, @reasons)

    ~H"""
    <section id="case-actions" class="card border border-base-300 bg-base-100 shadow-sm">
      <div class="card-body gap-4">
        <h2 class="card-title text-base">Case actions</h2>

        <p :if={@transaction.status != :completed} class="text-sm text-base-content/70">
          Only paid transactions can be delivered or disputed.
        </p>

        <div :if={@transaction.status == :completed}>
          <p class="text-xs font-medium uppercase tracking-wide text-base-content/50">
            1 · Delivery
          </p>
          <p :if={@transaction.fulfillment} class="mt-1 flex items-center gap-1 text-sm">
            <.icon name="hero-check-circle" class="size-4 text-success" /> Delivered
          </p>
          <button
            :if={!@transaction.fulfillment}
            id="deliver"
            type="button"
            class="btn btn-sm btn-outline mt-2 w-full"
            phx-click="deliver"
            phx-disable-with="Delivering…"
          >
            <.icon name="hero-truck" class="size-4" /> Mark as delivered
            <span class="badge badge-ghost badge-xs">simulated</span>
          </button>
        </div>

        <div :if={@transaction.status == :completed}>
          <p class="text-xs font-medium uppercase tracking-wide text-base-content/50">
            2 · Dispute
          </p>
          <p :if={@transaction.dispute} class="mt-1 flex items-center gap-1 text-sm">
            <.icon name="hero-exclamation-circle" class="size-4 text-warning" />
            Disputed: {String.replace(to_string(@transaction.dispute.reason), "_", " ")}
          </p>
          <.form
            :if={!@transaction.dispute}
            for={@dispute_form}
            id="dispute-form"
            phx-submit="open_dispute"
            class="mt-2"
          >
            <.input field={@dispute_form[:reason]} type="select" options={@reasons} />
            <.button
              id="open-dispute"
              class="btn btn-sm btn-warning w-full"
              phx-disable-with="Opening…"
            >
              <.icon name="hero-flag" class="size-4" /> Customer opens a dispute
              <span class="badge badge-ghost badge-xs">simulated</span>
            </.button>
          </.form>
        </div>

        <div :if={@transaction.dispute}>
          <p class="text-xs font-medium uppercase tracking-wide text-base-content/50">
            3 · AI investigation
          </p>
          <button
            :if={@transaction.dispute.status != :submitted}
            id="investigate"
            type="button"
            class="btn btn-sm btn-primary mt-2 w-full"
            phx-click="investigate"
            disabled={@investigating}
          >
            <span :if={@investigating} class="loading loading-spinner loading-xs" />
            <.icon :if={!@investigating} name="hero-sparkles" class="size-4" />
            {cond do
              @investigating -> "AI is investigating…"
              @transaction.dispute.evidence -> "Run the investigation again"
              true -> "Run AI investigation"
            end}
          </button>
          <p class="mt-1 text-xs text-base-content/50">
            <span :if={@investigating}>Usually 5–15 seconds · </span>with {@ai_provider}
          </p>
        </div>
      </div>
    </section>
    """
  end
end
