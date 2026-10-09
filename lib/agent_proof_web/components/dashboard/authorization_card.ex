defmodule AgentProofWeb.AuthorizationCard do
  use AgentProofWeb, :html

  import AgentProofWeb.ShopForm
  import AgentProofWeb.SpendingMeter
  import AgentProofWeb.TransactionList

  attr :id, :string, required: true
  attr :card, :map, required: true

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
              type="button"
              id={"edit-agent-#{@card.id}"}
              class="btn btn-ghost btn-sm btn-square"
              phx-click="edit_agent"
              phx-value-id={@card.id}
              aria-label={"Edit #{@card.authorization.agent.name}"}
            >
              <.icon name="hero-pencil-square" class="size-4" />
            </button>
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

        <.shop_form form={@card.shop_form} authorization_id={@card.id} />

        <.transaction_list transactions={@card.authorization.transactions} />
      </div>
    </article>
    """
  end
end
