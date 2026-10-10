defmodule AgentProofWeb.GrantForm do
  use AgentProofWeb, :html

  @doc """
  Form for authorizing a new agent.
  """
  attr :form, Phoenix.HTML.Form, required: true

  def grant_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="grant-form"
      phx-change="validate"
      phx-submit="grant"
      class="mt-2"
    >
      <.input field={@form[:agent_name]} label="Agent name" />
      <div class="grid grid-cols-[minmax(0,1fr)_6.5rem] gap-3">
        <.input
          field={@form[:max_amount]}
          type="number"
          step="0.01"
          min="0"
          label="Spending limit"
        />
        <.input field={@form[:currency]} type="select" label="Currency" options={["USD"]} />
      </div>
      <.input
        field={@form[:description]}
        type="textarea"
        rows="3"
        label="What may it buy?"
      />
      <.button
        id="grant-submit"
        class="btn btn-primary btn-block mt-2"
        phx-disable-with="Authorizing…"
      >
        <.icon name="hero-shield-check" class="size-4" /> Authorize agent
      </.button>
    </.form>
    """
  end
end
