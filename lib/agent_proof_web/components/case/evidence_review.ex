defmodule AgentProofWeb.EvidenceReview do
  use AgentProofWeb, :html

  import AgentProofWeb.VerifiedFacts

  @doc """
  The evidence package beside the verified checks, with the approval buttons.
  """
  attr :evidence, :map, required: true
  attr :facts, :map, required: true, doc: "from Transactions.reconstruct/2"
  attr :submitted, :boolean, default: false
  attr :preparing, :boolean, default: false, doc: "whether the submission preview is open"

  def evidence_review(assigns) do
    assigns =
      assign(assigns, :sections, [
        {"authorization", "Authorization", assigns.evidence.authorization_evidence},
        {"transaction", "Transaction", assigns.evidence.transaction_evidence},
        {"fulfillment", "Fulfillment", assigns.evidence.fulfillment_evidence}
      ])

    ~H"""
    <section id="evidence-review" class="card mt-6 border border-base-300 bg-base-100 shadow-sm">
      <div class="card-body gap-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="card-title text-base">
              <.icon name="hero-document-check" class="size-5 text-secondary" /> Evidence package
            </h2>
            <div class="mt-1 flex flex-wrap items-center gap-2 text-xs text-base-content/60">
              <span>Written by</span>
              <span
                id="evidence-provider"
                class={[
                  "badge badge-soft badge-sm",
                  if(String.starts_with?(@evidence.ai_provider, "demo"),
                    do: "badge-warning",
                    else: "badge-success"
                  )
                ]}
              >
                {@evidence.ai_provider}
              </span>
              <span>· {Calendar.strftime(@evidence.inserted_at, "%b %-d, %H:%M")}</span>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <span id="evidence-status" class={["badge", status_style(@evidence, @submitted)]}>
              {status_label(@evidence, @submitted)}
            </span>
            <button
              :if={!@submitted && !@evidence.approved_at}
              id="approve-evidence"
              type="button"
              class="btn btn-sm btn-success"
              phx-click="approve_evidence"
              phx-disable-with="Approving…"
            >
              <.icon name="hero-check" class="size-4" /> Approve evidence
            </button>
            <button
              :if={!@submitted && @evidence.approved_at}
              id="withdraw-approval"
              type="button"
              class="btn btn-sm btn-ghost"
              phx-click="withdraw_approval"
            >
              Withdraw approval
            </button>
            <button
              :if={!@submitted && @evidence.approved_at && !@preparing}
              id="prepare-submission"
              type="button"
              class="btn btn-sm btn-primary"
              phx-click="prepare_submission"
            >
              <.icon name="hero-paper-airplane" class="size-4" /> Prepare PayPal submission
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 items-start gap-5 lg:grid-cols-[minmax(0,1fr)_18rem]">
          <div class="space-y-5">
            <div>
              <p class="text-xs font-medium uppercase tracking-wide text-base-content/50">
                Summary
              </p>
              <p id="evidence-summary" class="mt-1">{@evidence.summary}</p>
            </div>

            <div :for={{key, label, section} <- @sections} id={"evidence-section-#{key}"}>
              <p class="text-xs font-medium uppercase tracking-wide text-base-content/50">
                {label}
              </p>
              <p class="mt-1">{section.statement}</p>
              <ul
                :if={section.facts != []}
                class="mt-2 list-disc space-y-1 pl-5 text-sm text-base-content/80"
              >
                <li :for={fact <- section.facts} class="break-words">{fact}</li>
              </ul>
            </div>

            <div id="evidence-explanation" class="rounded-box bg-base-200/60 p-3 text-sm">
              <p class="text-xs font-medium uppercase tracking-wide text-base-content/50">
                The AI's reasoning
              </p>
              <p class="mt-1 italic">{@evidence.ai_explanation}</p>
            </div>
          </div>

          <.verified_facts facts={@facts} />
        </div>
      </div>
    </section>
    """
  end

  defp status_label(_evidence, true), do: "Submitted"

  defp status_label(%{approved_at: nil}, false), do: "Ready for review"

  defp status_label(%{approved_at: approved_at}, false),
    do: "Approved #{Calendar.strftime(approved_at, "%b %-d, %H:%M")}"

  defp status_style(_evidence, true), do: "badge-info"
  defp status_style(%{approved_at: nil}, false), do: "badge-warning badge-soft"
  defp status_style(_evidence, false), do: "badge-success"
end
