defmodule AgentProofWeb.TransactionTable do
  use AgentProofWeb, :html

  import AgentProofWeb.StatusBadge

  @doc """
  Table of transactions with their agent. Scrolls sideways on small screens.
  """
  attr :id, :string, required: true
  attr :rows, :any, required: true

  def transaction_table(assigns) do
    ~H"""
    <div class="overflow-x-auto rounded-box border border-base-300 bg-base-100">
      <.table id={@id} rows={@rows}>
        <:col :let={{_id, transaction}} label="Date">
          <span class="whitespace-nowrap">
            {Calendar.strftime(transaction.inserted_at, "%b %-d, %Y %H:%M")}
          </span>
        </:col>
        <:col :let={{_id, transaction}} label="Agent">
          {transaction.authorization.agent.name}
        </:col>
        <:col :let={{_id, transaction}} label="Product">
          <.link navigate={~p"/transactions/#{transaction.id}"} class="link link-hover">
            {transaction.product_name}
          </.link>
        </:col>
        <:col :let={{_id, transaction}} label="Amount">
          <span class="whitespace-nowrap font-medium tabular-nums">
            {money(transaction.amount)} {transaction.currency}
          </span>
        </:col>
        <:col :let={{_id, transaction}} label="PayPal order">
          <span class="font-mono text-xs text-base-content/60">
            {transaction.paypal_order_id || "—"}
          </span>
        </:col>
        <:col :let={{_id, transaction}} label="Status">
          <.status_badge status={transaction.status} />
        </:col>
      </.table>
    </div>
    """
  end
end
