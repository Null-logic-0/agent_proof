defmodule AgentProofWeb.ShopForm do
  use AgentProofWeb, :html

  @doc """
  The form that sends the agent shopping for one authorization. Its `shop`
  event is handled by the LiveView that renders it.
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :authorization_id, :integer, required: true

  def shop_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id={"shop-form-#{@authorization_id}"}
      phx-submit="shop"
      class="flex flex-col gap-2 sm:flex-row sm:items-start"
    >
      <input type="hidden" name="authorization_id" value={@authorization_id} />
      <div class="min-w-0 flex-1">
        <.input
          field={@form[:query]}
          id={"shop-query-#{@authorization_id}"}
          placeholder="What should the agent look for?"
        />
      </div>
      <.button class="btn btn-primary shrink-0 sm:mt-1" phx-disable-with="Shopping…">
        <.icon name="hero-sparkles" class="size-4" /> Let the agent shop
      </.button>
    </.form>
    """
  end
end
