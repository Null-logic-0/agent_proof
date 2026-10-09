defmodule AgentProofWeb.VerifiedFacts do
  use AgentProofWeb, :html

  @checks [
    {"within_budget", "Within the budget at purchase time"},
    {"system_budget_check_logged", "Budget check logged by AgentProof"},
    {"currency_matches", "Currency matches the authorization"},
    {"authorized_before_purchase", "Authorized before the purchase"},
    {"delivered_before_dispute", "Delivered before the dispute"}
  ]

  @doc """
  The checks AgentProof computed in code (`Transactions.reconstruct/2`), the
  same facts the AI was given. Shown beside the AI's text so it is clear what
  is proven and what is written.
  """
  attr :facts, :map, required: true

  def verified_facts(assigns) do
    assigns = assign(assigns, :checks, @checks)

    ~H"""
    <div id="verified-facts" class="rounded-box border border-base-300 bg-base-200/40 p-4">
      <h3 class="flex items-center gap-1.5 text-sm font-semibold">
        <.icon name="hero-shield-check" class="size-4 text-success" /> Verified by AgentProof
      </h3>
      <p class="mt-0.5 text-xs text-base-content/60">Computed from stored records, not by AI.</p>

      <ul class="mt-3 space-y-2 text-sm">
        <li :for={{key, label} <- @checks} id={"check-#{key}"} class="flex items-start gap-2">
          <.check_icon value={@facts["checks"][key]} />
          <span>
            {label}
            <span :if={is_nil(@facts["checks"][key])} class="text-base-content/50">
              (no delivery recorded)
            </span>
          </span>
        </li>
      </ul>

      <ul class="mt-3 space-y-1 border-t border-base-300 pt-3 text-xs text-base-content/60">
        <li :if={@facts["transaction"]["capture_simulated"]}>
          The payment capture was simulated; no real funds moved.
        </li>
        <li :if={@facts["authorization"]["edited_after_purchase"]}>
          The authorization was edited after the purchase; these checks use the terms in force at purchase time.
        </li>
        <li>
          The AI's text passed validation: every amount and ID matches these records, and the PayPal order ID is quoted.
        </li>
      </ul>
    </div>
    """
  end

  attr :value, :any, required: true

  defp check_icon(%{value: true} = assigns) do
    ~H"""
    <.icon name="hero-check-circle" class="mt-0.5 size-4 shrink-0 text-success" />
    """
  end

  defp check_icon(%{value: false} = assigns) do
    ~H"""
    <.icon name="hero-x-circle" class="mt-0.5 size-4 shrink-0 text-error" />
    """
  end

  defp check_icon(assigns) do
    ~H"""
    <.icon name="hero-minus-circle" class="mt-0.5 size-4 shrink-0 text-base-content/40" />
    """
  end
end
