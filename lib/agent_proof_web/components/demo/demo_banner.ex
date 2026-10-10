defmodule AgentProofWeb.DemoBanner do
  use AgentProofWeb, :html

  import AgentProofWeb.DemoModeSwitch

  @doc """
  Banner shown on every page while Demo Mode is on.
  """
  attr :return_to, :string, required: true

  def demo_banner(assigns) do
    ~H"""
    <div
      id="demo-banner"
      role="status"
      class="alert alert-warning alert-soft rounded-none border-x-0 border-t-0 px-4 py-2.5 sm:px-6 lg:px-8"
    >
      <div class="mx-auto flex w-full max-w-7xl flex-wrap items-center justify-between gap-x-4 gap-y-2">
        <p class="flex min-w-0 items-start gap-2 text-sm">
          <.icon name="hero-beaker" class="mt-0.5 size-4 shrink-0" />
          <span>
            <span class="font-semibold">Demo Mode is on.</span>
            Purchases and AI investigations use the deterministic demo adapters, so no PayPal
            or AI service is called for them.
          </span>
        </p>
        <.demo_mode_switch
          id="demo-mode-off"
          demo_mode={true}
          return_to={@return_to}
          class="btn btn-xs btn-ghost"
        >
          Turn off
        </.demo_mode_switch>
      </div>
    </div>
    """
  end
end
