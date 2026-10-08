defmodule AgentProofWeb.EditAgentModal do
  use AgentProofWeb, :html

  @doc """
  Modal for editing an agent's name, spending limit, and description. Spent
  is shown read-only: it is calculated from real purchases. Its events
  (`validate_edit`, `save_edit`, `cancel_edit`) are handled by the LiveView.
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :card, :map, required: true, doc: "the authorization and its spent amount"

  def edit_agent_modal(assigns) do
    ~H"""
    <div
      id="edit-agent-modal"
      class="modal modal-open"
      phx-window-keydown="cancel_edit"
      phx-key="escape"
    >
      <div class="modal-box">
        <h3 class="text-lg font-semibold">Edit {@card.authorization.agent.name}</h3>
        <p id="edit-agent-spent" class="mt-1 text-sm text-base-content/70">
          Spent so far:
          <span class="font-semibold text-base-content">
            {money(@card.spent)} {@card.authorization.currency}
          </span>
          (calculated from its purchases)
        </p>

        <.form
          for={@form}
          id="edit-agent-form"
          phx-change="validate_edit"
          phx-submit="save_edit"
          class="mt-4"
        >
          <.input field={@form[:agent_name]} label="Agent name" />
          <.input
            field={@form[:max_amount]}
            type="number"
            step="0.01"
            min="0"
            label={"Spending limit (#{@card.authorization.currency})"}
          />
          <.input field={@form[:description]} type="textarea" rows="3" label="What may it buy?" />
          <p :if={@card.authorization.transactions != []} class="mt-1 text-xs text-base-content/60">
            Past purchases keep the limit and description that applied when they were made.
          </p>

          <div class="modal-action">
            <button type="button" id="edit-agent-cancel" class="btn btn-ghost" phx-click="cancel_edit">
              Cancel
            </button>
            <.button id="edit-agent-submit" class="btn btn-primary" phx-disable-with="Saving…">
              Save
            </.button>
          </div>
        </.form>
      </div>
      <div class="modal-backdrop" phx-click="cancel_edit"></div>
    </div>
    """
  end
end
