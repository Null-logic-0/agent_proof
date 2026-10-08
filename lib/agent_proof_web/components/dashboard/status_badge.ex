defmodule AgentProofWeb.StatusBadge do
  use AgentProofWeb, :html

  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-soft badge-sm",
      case @status do
        :completed -> "badge-success"
        :created -> "badge-warning"
        :failed -> "badge-error"
      end
    ]}>
      {@status}
    </span>
    """
  end
end
