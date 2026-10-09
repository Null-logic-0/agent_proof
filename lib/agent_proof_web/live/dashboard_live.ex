defmodule AgentProofWeb.DashboardLive do
  use AgentProofWeb, :live_view

  require Logger

  import AgentProofWeb.AuthorizationCard
  import AgentProofWeb.EditAgentModal
  import AgentProofWeb.EmptyState
  import AgentProofWeb.ErrorState
  import AgentProofWeb.GrantForm
  import AgentProofWeb.LoadingState

  alias AgentProof.{Authorizations, Transactions}
  alias AgentProof.Agents.ShoppingAgent
  alias Phoenix.LiveView.AsyncResult

  # Cards per load: the first 3 render, scrolling to the bottom loads 3 more.
  @per_page 3

  # Prefilled demo.
  @grant_defaults %{
    "agent_name" => "ShopBot",
    "max_amount" => "200",
    "currency" => "USD",
    "description" => "Buy noise-cancelling headphones, up to $200"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "AgentProof")
     |> assign(:form, build_grant_form(@grant_defaults))
     |> assign(:product_names, Enum.map(AgentProof.Catalog.list_products(), & &1.name))
     |> assign(editing: nil, edit_form: nil)
     |> assign(:listing, AsyncResult.loading())
     |> assign(oldest_id: nil, more?: false, loading_more: false)
     |> stream(:authorizations, [])
     |> load_authorizations()}
  end

  @impl true
  def handle_async(:load_authorizations, {:ok, {cards, more?}}, socket) do
    {:noreply,
     socket
     |> assign(:listing, AsyncResult.ok(socket.assigns.listing, true))
     |> assign(more?: more?, oldest_id: oldest_id(cards, nil))
     |> stream(:authorizations, cards, reset: true)}
  end

  def handle_async(:load_authorizations, {:exit, reason}, socket) do
    Logger.error("Could not load authorizations: #{inspect(reason)}")
    {:noreply, assign(socket, :listing, AsyncResult.failed(%AsyncResult{}, reason))}
  end

  def handle_async(:load_more, {:ok, {cards, more?}}, socket) do
    {:noreply,
     socket
     |> assign(
       more?: more?,
       loading_more: false,
       oldest_id: oldest_id(cards, socket.assigns.oldest_id)
     )
     # Appends to the end of the list.
     |> stream(:authorizations, cards)}
  end

  # The cards already shown stay; scrolling again (or Load more) retries.
  def handle_async(:load_more, {:exit, reason}, socket) do
    Logger.error("Could not load more authorizations: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(:loading_more, false)
     |> put_flash(:error, "Couldn't load more agents. Please try again.")}
  end

  @impl true
  def handle_event("retry_load", _params, socket), do: {:noreply, load_authorizations(socket)}

  # Sent by phx-viewport-bottom when the last card scrolls into view, and by
  # the Load more button.
  def handle_event("load_more", _params, socket) do
    if socket.assigns.more? and not socket.assigns.loading_more do
      source = authorizations_source()
      before_id = socket.assigns.oldest_id

      {:noreply,
       socket
       |> assign(:loading_more, true)
       |> start_async(:load_more, fn -> load_cards(source, before_id) end)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate", %{"grant" => params}, socket) do
    form = params |> Authorizations.change_grant() |> to_form(action: :validate, as: :grant)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("grant", %{"grant" => params}, socket) do
    case Authorizations.grant(params) do
      {:ok, authorization} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Authorized #{authorization.agent.name} to spend up to " <>
             "#{money(authorization.max_amount)} #{authorization.currency}."
         )
         |> stream_insert(:authorizations, card(authorization), at: 0)
         |> assign(:form, build_grant_form(@grant_defaults))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :grant))}
    end
  end

  # The button is only shown for unused agents
  def handle_event("delete_agent", %{"id" => id}, socket) do
    authorization = id |> Authorizations.get_authorization!() |> Authorizations.preload_activity()

    case Authorizations.delete_agent(authorization.agent) do
      {:ok, %{agent: agent, authorization_ids: ids}} ->
        socket =
          Enum.reduce(ids, socket, fn id, socket ->
            stream_delete_by_dom_id(socket, :authorizations, "authorizations-#{id}")
          end)

        {:noreply, put_flash(socket, :info, "Deleted #{agent.name}.")}

      {:error, :has_purchases} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "#{authorization.agent.name} has purchase records. They are kept as dispute evidence."
         )}
    end
  end

  def handle_event("edit_agent", %{"id" => id}, socket) do
    card =
      id |> Authorizations.get_authorization!() |> Authorizations.preload_activity() |> card()

    {:noreply,
     assign(socket,
       editing: card,
       edit_form: card.authorization |> Authorizations.change_settings() |> to_form(as: :settings)
     )}
  end

  def handle_event("validate_edit", %{"settings" => params}, socket) do
    form =
      socket.assigns.editing.authorization
      |> Authorizations.change_settings(params)
      |> to_form(action: :validate, as: :settings)

    {:noreply, assign(socket, :edit_form, form)}
  end

  def handle_event("save_edit", %{"settings" => params}, socket) do
    case Authorizations.update_settings(socket.assigns.editing.authorization, params) do
      {:ok, authorization} ->
        {:noreply,
         socket
         |> assign(editing: nil, edit_form: nil)
         |> stream_insert(:authorizations, card(authorization))
         |> put_flash(:info, "Updated #{authorization.agent.name}.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset, as: :settings))}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: nil, edit_form: nil)}
  end

  def handle_event("shop", %{"authorization_id" => id, "shop" => %{"query" => query}}, socket) do
    authorization = Authorizations.get_authorization!(id)
    result = ShoppingAgent.run(authorization, query)
    authorization = Authorizations.preload_activity(authorization)

    {:noreply,
     socket
     # Keep what was searched for, instead of resetting the box to the default.
     |> stream_insert(:authorizations, card(authorization, query))
     |> put_shop_flash(result, query, authorization)}
  end

  # The cards load in a task (only once the browser is connected), so the page
  # and the grant form render right away while the list shows a skeleton.
  defp load_authorizations(socket) do
    source = authorizations_source()

    socket
    |> assign(:listing, AsyncResult.loading(socket.assigns.listing))
    |> assign(more?: false, loading_more: false)
    |> start_async(:load_authorizations, fn -> load_cards(source, nil) end)
  end

  # One page of cards older than `before_id`, plus whether more exist.
  defp load_cards(source, before_id) do
    {authorizations, more?} = source.list_authorizations_page(before_id, @per_page)
    {Enum.map(authorizations, &card/1), more?}
  end

  # The id the next page continues from: the last (oldest) card loaded.
  defp oldest_id([], current), do: current
  defp oldest_id(cards, _current), do: List.last(cards).id

  defp authorizations_source do
    Application.get_env(:agent_proof, :authorizations_source, Authorizations)
  end

  defp build_grant_form(params),
    do: params |> Authorizations.change_grant() |> to_form(as: :grant)

  # A stream item: the authorization, what it has spent, and its own shop form.
  # Stream items cannot read per-card assigns, so each card carries its form
  # (and with it, the last search) inside the item.
  defp card(authorization, query \\ "headphones") do
    %{
      id: authorization.id,
      authorization: authorization,
      spent: Transactions.spent_amount(authorization),
      shop_form: to_form(%{"query" => query}, as: :shop)
    }
  end

  defp put_shop_flash(socket, {:ok, transaction}, _query, authorization) do
    put_flash(
      socket,
      :info,
      "#{authorization.agent.name} bought #{transaction.product_name} for " <>
        "#{money(transaction.amount)} #{transaction.currency}."
    )
  end

  defp put_shop_flash(socket, {:error, :exceeds_budget}, query, authorization) do
    put_flash(
      socket,
      :error,
      "Blocked: the agent's pick for “#{query}” would exceed the " <>
        "#{money(authorization.max_amount)} #{authorization.currency} budget."
    )
  end

  defp put_shop_flash(socket, {:error, :no_matching_product}, query, _authorization) do
    put_flash(socket, :error, "No product matches “#{query}”.")
  end

  defp put_shop_flash(socket, {:error, :payment_failed}, _query, _authorization) do
    put_flash(socket, :error, "PayPal could not complete the payment. The budget was released.")
  end

  defp put_shop_flash(socket, {:error, :currency_mismatch}, _query, _authorization) do
    put_flash(socket, :error, "Blocked: the product's currency differs from the authorization.")
  end

  defp put_shop_flash(socket, {:error, _reason}, _query, _authorization) do
    put_flash(socket, :error, "The purchase could not be completed.")
  end
end
