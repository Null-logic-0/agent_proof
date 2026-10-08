defmodule AgentProofWeb.SpendingMeter do
  use AgentProofWeb, :html

  attr :id, :string, required: true
  attr :spent, Decimal, required: true
  attr :max, Decimal, required: true
  attr :currency, :string, required: true

  def spending_meter(assigns) do
    percent =
      assigns.spent
      |> Decimal.div(assigns.max)
      |> Decimal.mult(100)
      |> Decimal.min(100)
      |> Decimal.round(1)

    assigns = assign(assigns, :percent, percent)

    ~H"""
    <div id={@id}>
      <div class="flex items-baseline justify-between text-sm">
        <span class="font-medium">Spent</span>
        <span class="text-base-content/60 tabular-nums">
          <span class="font-semibold text-base-content">{money(@spent)}</span>
          of {money(@max)} {@currency}
        </span>
      </div>
      <progress
        class={[
          "progress mt-2 w-full",
          if(Decimal.gt?(@percent, 90), do: "progress-warning", else: "progress-primary")
        ]}
        value={Decimal.to_string(@percent)}
        max="100"
      />
    </div>
    """
  end
end
