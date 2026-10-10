defmodule AgentProofWeb.SubmissionPanel do
  use AgentProofWeb, :html

  @doc """
  Preview of the exact PayPal request, with the Submit button.
  """
  attr :submission, :map, required: true, doc: "from Evidence.prepare_submission/1"
  attr :submitting, :boolean, required: true

  def submission_panel(assigns) do
    ~H"""
    <section id="submission-panel" class="card mt-6 border-2 border-primary/40 bg-base-100 shadow-sm">
      <div class="card-body gap-4">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="card-title text-base">
              <.icon name="hero-paper-airplane" class="size-5 text-primary" /> PayPal submission
            </h2>
            <p class="mt-1 break-all text-xs text-base-content/60">
              provide-evidence for dispute <span class="font-mono">{@submission.dispute_id}</span>
            </p>
          </div>
          <span
            id="submission-mode"
            class={[
              "badge badge-soft",
              if(@submission.simulated?, do: "badge-warning", else: "badge-success")
            ]}
          >
            {if @submission.simulated?, do: "simulated submission", else: "PayPal Sandbox"}
          </span>
        </div>

        <p :if={@submission.simulated?} class="text-sm text-base-content/70">
          This dispute was created in AgentProof, so PayPal doesn't know it. The exact request
          below is prepared and recorded, but not sent.
        </p>

        <div class="space-y-3">
          <div
            :for={{evidence, index} <- Enum.with_index(@submission.payload["evidences"])}
            id={"submission-item-#{index}"}
            class="rounded-box border border-base-300 p-3"
          >
            <div class="flex flex-wrap items-center gap-2">
              <span class="badge badge-sm badge-outline font-mono">{evidence["evidence_type"]}</span>
              <span
                :for={tracking <- get_in(evidence, ["evidence_info", "tracking_info"]) || []}
                class="text-xs text-base-content/60"
              >
                {tracking["carrier_name"]} · {tracking["tracking_number"]}
              </span>
            </div>
            <p class="mt-2 whitespace-pre-line break-words text-sm">{evidence["notes"]}</p>
          </div>
        </div>

        <details id="submission-json" class="rounded-box bg-base-200/60 p-3">
          <summary class="cursor-pointer text-sm font-medium">Show the exact request (JSON)</summary>
          <pre class="mt-2 overflow-x-auto whitespace-pre-wrap break-all text-xs">{Jason.encode!(@submission.payload, pretty: true)}</pre>
        </details>

        <div class="flex flex-wrap justify-end gap-2">
          <button
            type="button"
            id="cancel-submission"
            class="btn btn-sm btn-ghost"
            phx-click="cancel_submission"
            disabled={@submitting}
          >
            Cancel
          </button>
          <button
            type="button"
            id="submit-evidence"
            class="btn btn-sm btn-primary"
            phx-click="submit_evidence"
            disabled={@submitting}
            data-confirm="Once submitted, the evidence can't be changed. Submit it to PayPal?"
          >
            <span :if={@submitting} class="loading loading-spinner loading-xs" />
            <.icon :if={!@submitting} name="hero-paper-airplane" class="size-4" />
            {if @submitting, do: "Submitting…", else: "Submit to PayPal"}
          </button>
        </div>
      </div>
    </section>
    """
  end
end
