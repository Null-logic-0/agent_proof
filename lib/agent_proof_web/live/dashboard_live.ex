defmodule AgentProofWeb.DashboardLive do
  use AgentProofWeb, :live_view

  import AgentProofWeb.AuthorizationCard
  import AgentProofWeb.GrantForm

  alias AgentProof.{Authorizations, Transactions}
  alias AgentProof.Agents.ShoppingAgent

  # Prefilled so a demo can start with one click.
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
     |> assign(:shop_form, to_form(%{"query" => "headphones"}, as: :shop))
     |> stream(:authorizations, Enum.map(Authorizations.list_authorizations(), &card/1))}
  end

  @impl true
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

  # The button is only shown for unused agents, but the context enforces the
  # rule too: a crafted event cannot delete purchase evidence.
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

  def handle_event("shop", %{"authorization_id" => id, "shop" => %{"query" => query}}, socket) do
    authorization = Authorizations.get_authorization!(id)
    result = ShoppingAgent.run(authorization, query)
    authorization = Authorizations.preload_activity(authorization)

    {:noreply,
     socket
     |> stream_insert(:authorizations, card(authorization))
     |> put_shop_flash(result, query, authorization)}
  end

  defp build_grant_form(params),
    do: params |> Authorizations.change_grant() |> to_form(as: :grant)

  # A stream item: the authorization plus what it has spent so far.
  defp card(authorization) do
    %{
      id: authorization.id,
      authorization: authorization,
      spent: Transactions.spent_amount(authorization)
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
