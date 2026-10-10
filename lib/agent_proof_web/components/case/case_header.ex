defmodule AgentProofWeb.CaseHeader do
  use AgentProofWeb, :html

  import AgentProofWeb.StatusBadge

  @doc """
  The case's headline: product, agent, amount, and status.
  """
  attr :transaction, :map, required: true, doc: "a transaction from Transactions.get_case!/1"

  def case_header(assigns) do
    ~H"""
    <div id="case-header" class="mb-6">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="min-w-0">
          <p class="text-sm text-base-content/60">
            <.icon name="hero-cpu-chip" class="size-4 text-primary" />
            {@transaction.authorization.agent.name}
          </p>
          <h1 class="mt-1 text-2xl font-semibold tracking-tight">{@transaction.product_name}</h1>
          <p class="mt-1 break-all font-mono text-xs text-base-content/50">
            {@transaction.paypal_order_id || "no PayPal order"}
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xl font-semibold tabular-nums">
            {money(@transaction.amount)} {@transaction.currency}
          </span>
          <.status_badge status={@transaction.status} />
          <span
            :if={@transaction.dispute}
            id="case-dispute-status"
            class={[
              "badge badge-soft badge-sm",
              if(@transaction.dispute.status == :open, do: "badge-warning", else: "badge-info")
            ]}
          >
            dispute: {String.replace(to_string(@transaction.dispute.status), "_", " ")}
          </span>
        </div>
      </div>
    </div>
    """
  end
end
