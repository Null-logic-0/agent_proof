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
        :for={transaction <- Enum.take(@transactions, 5)}
        id={"transaction-#{transaction.id}"}
        class="flex flex-col gap-1.5 py-3 text-sm sm:flex-row sm:items-center sm:justify-between sm:gap-3"
      >
        <div class="min-w-0">
          <.link
            navigate={~p"/transactions/#{transaction.id}"}
            id={"case-link-#{transaction.id}"}
            class="link link-hover block font-medium sm:truncate"
          >
            {transaction.product_name}
          </.link>
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
    <div :if={length(@transactions) >= 5} class="mt-4 flex justify-center">
      <.link
        class="btn btn-outline btn-sm btn-info"
        navigate={~p"/history"}
      >
        View transaction history
      </.link>
    </div>
    """
  end
end
