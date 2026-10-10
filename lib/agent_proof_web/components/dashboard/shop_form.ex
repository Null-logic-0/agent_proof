defmodule AgentProofWeb.ShopForm do
  use AgentProofWeb, :html

  @doc """
  Form that sends an agent shopping.
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :authorization_id, :integer, required: true
  attr :suggested_by, :string, default: nil, doc: "who suggested the query in the box"
  attr :suggesting, :boolean, default: false

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
          list="catalog-products"
          autocomplete="off"
          placeholder="What should the agent look for?"
        />
        <p
          :if={@suggesting}
          id={"shop-suggesting-#{@authorization_id}"}
          class="mt-1 flex items-center gap-1.5 text-xs text-base-content/50"
        >
          <span class="loading loading-spinner loading-xs" />
          Suggesting a search from the description…
        </p>
        <p
          :if={@suggested_by}
          id={"shop-suggested-by-#{@authorization_id}"}
          class="mt-1 flex items-center gap-1 text-xs text-base-content/50"
        >
          <.icon name="hero-sparkles" class="size-3" /> Suggested by {@suggested_by}
        </p>
      </div>
      <.button class="btn btn-primary shrink-0 sm:mt-1" phx-disable-with="Shopping…">
        <.icon name="hero-sparkles" class="size-4" /> Let the agent shop
      </.button>
    </.form>
    """
  end
end
