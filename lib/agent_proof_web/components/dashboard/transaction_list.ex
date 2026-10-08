defmodule AgentProofWeb.TransactionList do
  use AgentProofWeb, :html

  import AgentProofWeb.StatusBadge

  @doc """
  An authorization's purchases, newest first. Renders nothing when empty.
  """
  attr :transactions, :list, required: true

  def transaction_list(assigns) do
    ~H"""
    <ul :if={@transactions != []} class="divide-y divide-base-200 border-t border-base-200">
      <li
        :for={transaction <- @transactions}
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
    """
  end
end
