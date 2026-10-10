defmodule AgentProofWeb.DemoScenarioCard do
  use AgentProofWeb, :html

  @doc """
  Dashboard card that runs the demo scenario.
  """
  def demo_scenario_card(assigns) do
    ~H"""
    <section id="demo-scenario" class="card mb-6 border border-warning/40 bg-base-100 shadow-sm">
      <div class="card-body gap-4 md:flex-row md:items-center md:justify-between">
        <div class="min-w-0">
          <h2 class="card-title text-base">
            <.icon name="hero-play-circle" class="size-5 text-warning" /> Demo scenario
          </h2>
          <p class="mt-1 text-sm text-base-content/70">
            One click builds a complete case: DemoBot gets a $200 budget, buys headphones,
            the delivery is recorded, the customer disputes the charge, and the AI writes the
            evidence. Then you review, approve, and submit it.
          </p>
        </div>
        <button
          id="run-demo-scenario"
          type="button"
          class="btn btn-warning shrink-0"
          phx-click="run_demo_scenario"
          phx-disable-with="Building the case…"
        >
          <.icon name="hero-play" class="size-4" /> Run the demo scenario
        </button>
      </div>
    </section>
    """
  end
end
