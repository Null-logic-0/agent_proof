defmodule AgentProof.Transactions do
  @moduledoc """
  What an agent actually purchased.
  """

  import Ecto.Query, warn: false

  require Logger

  alias AgentProof.{PayPal, Repo}
  alias AgentProof.Authorizations
  alias AgentProof.Authorizations.Authorization
  alias AgentProof.Transactions.{AgentAction, Transaction}

  def list_transactions do
    Transaction
    |> order_by(desc: :id)
    |> Repo.all()
  end

  def get_transaction!(id), do: Repo.get!(Transaction, id)

  @doc """
  Total amount committed against `authorization`.

  Created orders count because they still reserve budget; failed ones never
  charged anyone.
  """
  def spent_amount(%Authorization{id: authorization_id}) do
    Transaction
    |> where([t], t.authorization_id == ^authorization_id)
    |> where([t], t.status in ^[:created, :completed])
    |> select([t], coalesce(sum(t.amount), 0))
    |> Repo.one()
  end

  @doc """
  Buys `product` for an agent in three phases:

    1. Reserve: lock the authorization, check the budget, and insert a
       `:created` transaction in one database transaction, so concurrent
       purchases cannot overspend it.
    2. Pay: create and capture a PayPal order, outside the lock.
    3. Finalize: mark the transaction `:completed`, or `:failed`, which
       releases the reserved budget.

  `agent_actions` is the agent's own log (untrusted input). It is validated
  and stored with the transaction, followed by AgentProof's system actions.

  Options:

    * `:adapter` - the PayPal adapter (see `AgentProof.PayPal`)
  """
  def purchase(authorization, product, agent_actions \\ [], opts \\ []) do
    with {:ok, agent_actions} <- AgentAction.from_agent(agent_actions),
         {:ok, transaction} <- reserve(authorization, product, agent_actions) do
      pay(transaction, opts)
    end
  end

  defp reserve(
         %Authorization{} = authorization,
         %{name: name, price: %Decimal{} = price, currency: currency},
         agent_actions
       ) do
    Repo.transact(fn ->
      authorization = Authorizations.lock_authorization!(authorization)
      spent = spent_amount(authorization)

      with :ok <- Authorizations.check_purchase(authorization, spent, price, currency) do
        budget_check =
          AgentAction.system(:budget_check, %{
            "result" => "approved",
            "spent" => money(spent),
            "amount" => money(price),
            "max_amount" => money(authorization.max_amount),
            "currency" => currency
          })

        %Transaction{authorization_id: authorization.id}
        |> Transaction.changeset(%{
          amount: price,
          currency: currency,
          product_name: name,
          status: :created
        })
        |> Ecto.Changeset.put_embed(:agent_actions, agent_actions ++ [budget_check])
        |> Repo.insert()
      end
    end)
  end

  defp pay(transaction, opts) do
    order = %{
      amount: transaction.amount,
      currency: transaction.currency,
      description: transaction.product_name,
      reference_id: "transaction-#{transaction.id}"
    }

    case PayPal.create_order(order, opts) do
      {:ok, %{order_id: order_id}} ->
        created = AgentAction.system(:create_paypal_order, %{"order_id" => order_id})
        capture(transaction, order_id, [created], opts)

      {:error, reason} ->
        fail(transaction, nil, [], :create_order, reason)
    end
  end

  defp capture(transaction, order_id, actions, opts) do
    case PayPal.capture_order(order_id, opts) do
      {:ok, %{capture_id: capture_id} = capture} ->
        captured =
          AgentAction.system(:capture_payment, %{
            "order_id" => order_id,
            "capture_id" => capture_id,
            "simulated" => Map.get(capture, :simulated, false)
          })

        finalize(
          transaction,
          %{status: :completed, paypal_order_id: order_id},
          actions ++ [captured]
        )

      {:error, reason} ->
        fail(transaction, order_id, actions, :capture_order, reason)
    end
  end

  defp fail(transaction, order_id, actions, step, reason) do
    Logger.warning("PayPal #{step} failed for transaction #{transaction.id}: #{inspect(reason)}")

    failed =
      AgentAction.system(:payment_failed, %{
        "step" => to_string(step),
        "reason" => inspect(reason)
      })

    {:ok, _failed} =
      finalize(transaction, %{status: :failed, paypal_order_id: order_id}, actions ++ [failed])

    {:error, :payment_failed}
  end

  defp finalize(transaction, attrs, new_actions) do
    transaction
    |> Transaction.changeset(attrs)
    |> Ecto.Changeset.put_embed(:agent_actions, transaction.agent_actions ++ new_actions)
    |> Repo.update()
  end

  @doc """
  Records how a paid transaction was delivered.
  """
  def record_fulfillment(%Transaction{status: :completed} = transaction, attrs) do
    transaction
    |> Transaction.fulfillment_changeset(%{fulfillment: attrs})
    |> Repo.update()
  end

  def record_fulfillment(%Transaction{}, _attrs), do: {:error, :not_completed}

  defp money(%Decimal{} = amount), do: amount |> Decimal.round(2) |> Decimal.to_string()
end
