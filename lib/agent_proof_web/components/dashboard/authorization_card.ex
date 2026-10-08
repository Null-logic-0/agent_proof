defmodule AgentProofWeb.AuthorizationCard do
  use AgentProofWeb, :html

  import AgentProofWeb.SpendingMeter
  import AgentProofWeb.StatusBadge

  attr :id, :string, required: true
  attr :card, :map, required: true
  attr :shop_form, Phoenix.HTML.Form, required: true

  def authorization_card(assigns) do
    ~H"""
    <article
      id={@id}
      class="card border border-base-300 bg-base-100 shadow-sm transition-shadow hover:shadow-md"
    >
      <div class="card-body gap-4">
        <div class="flex flex-col gap-1 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
          <div class="min-w-0">
            <h3 class="card-title text-base">
              <.icon name="hero-cpu-chip" class="size-5 text-primary" />
              {@card.authorization.agent.name}
            </h3>
            <p class="mt-1 text-sm text-base-content/70">“{@card.authorization.description}”</p>
          </div>
          <div class="flex shrink-0 items-center gap-1">
            <span class="text-xs text-base-content/50">
              Authorized {Calendar.strftime(@card.authorization.inserted_at, "%b %-d, %H:%M")}
            </span>
            <button
              :if={@card.authorization.transactions == []}
              type="button"
              id={"delete-agent-#{@card.id}"}
              class="btn btn-ghost btn-sm btn-square text-error"
              phx-click="delete_agent"
              phx-value-id={@card.id}
              data-confirm={"Delete #{@card.authorization.agent.name} and its authorization?"}
              aria-label={"Delete #{@card.authorization.agent.name}"}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
            <span
              :if={@card.authorization.transactions != []}
              id={"delete-locked-#{@card.id}"}
              class="tooltip tooltip-left"
              data-tip="Has purchase records, kept as dispute evidence"
            >
              <span class="btn btn-ghost btn-sm btn-square btn-disabled" aria-hidden="true">
                <.icon name="hero-lock-closed" class="size-4" />
              </span>
            </span>
          </div>
        </div>

        <.spending_meter
          id={"meter-#{@card.id}"}
          spent={@card.spent}
          max={@card.authorization.max_amount}
          currency={@card.authorization.currency}
        />

        <.form
          for={@shop_form}
          id={"shop-form-#{@card.id}"}
          phx-submit="shop"
          class="flex flex-col gap-2 sm:flex-row sm:items-start"
        >
          <input type="hidden" name="authorization_id" value={@card.id} />
          <div class="min-w-0 flex-1">
            <.input
              field={@shop_form[:query]}
              id={"shop-query-#{@card.id}"}
              placeholder="What should the agent look for?"
            />
          </div>
          <.button class="btn btn-primary shrink-0 sm:mt-1" phx-disable-with="Shopping…">
            <.icon name="hero-sparkles" class="size-4" /> Let the agent shop
          </.button>
        </.form>

        <ul
          :if={@card.authorization.transactions != []}
          class="divide-y divide-base-200 border-t border-base-200"
        >
          <li
            :for={transaction <- @card.authorization.transactions}
            id={"transaction-#{transaction.id}"}
            class="flex flex-col gap-1.5 py-3 text-sm sm:flex-row sm:items-center sm:justify-between sm:gap-3"
          >
            <div class="min-w-0">
              <p class="font-medium sm:truncate">{transaction.product_name}</p>
              <p class="truncate font-mono text-xs text-base-content/50">
                {transaction.paypal_order_id || "no PayPal order"}
              </p>
            </div>
            <div class="flex shrink-0 items-center gap-3">
              <span class="font-medium tabular-nums">
                {money(transaction.amount)} {transaction.currency}
              </span>
              <.status_badge status={transaction.status} />
            </div>
          </li>
        </ul>
      </div>
    </article>
    """
  end
end
