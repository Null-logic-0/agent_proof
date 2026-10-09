defmodule AgentProofWeb.EvidenceSummary do
  use AgentProofWeb, :html

  @doc """
  The saved evidence package at a glance: its summary and which AI wrote it.
  """
  attr :evidence, :map, required: true

  def evidence_summary(assigns) do
    ~H"""
    <section id="evidence-summary" class="card border border-base-300 bg-base-100 shadow-sm">
      <div class="card-body gap-3">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2 class="card-title text-base">
            <.icon name="hero-document-check" class="size-5 text-secondary" /> Evidence package
          </h2>
          <span
            id="evidence-provider"
            class={[
              "badge badge-soft badge-sm",
              if(@evidence.ai_provider == "demo", do: "badge-warning", else: "badge-success")
            ]}
          >
            {@evidence.ai_provider}
          </span>
        </div>
        <p class="text-sm">{@evidence.summary}</p>
        <p class="text-xs text-base-content/50">
          Validated and saved {Calendar.strftime(@evidence.updated_at, "%b %-d, %H:%M")}
        </p>
      </div>
    </section>
    """
  end
end
