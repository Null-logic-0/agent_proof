defmodule AgentProofWeb.HomeLive do
  use AgentProofWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app {assigns}>
      <h1>
        hey
      </h1>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
