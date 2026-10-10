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

  # The history's sort options. Only these keys are accepted, so input never picks a column.
  @history_sorts %{
    "newest" => [desc: :inserted_at, desc: :id],
    "oldest" => [asc: :inserted_at, asc: :id],
    "amount_desc" => [desc: :amount, desc: :id],
    "amount_asc" => [asc: :amount, desc: :id],
    "status_asc" => [asc: :status, desc: :id],
    "status_desc" => [desc: :status, desc: :id]
  }

  @doc """
  One page of transactions with their agent. `params` may hold a search (`"q"`: product,
  agent, or PayPal order ID), a `"status"`, and a sort (`"sort"`, newest first by default).
  Returns `{transactions, meta}`.
  """
  def list_transaction_history(params) do
    Transaction
    |> search(params["q"])
    |> with_status(params["status"])
    |> order_by(^Map.get(@history_sorts, params["sort"], @history_sorts["newest"]))
    |> preload(authorization: :agent)
    |> Pagex.paginate(params, Repo)
  end

  def history_sorts, do: Map.keys(@history_sorts)

  def history_statuses, do: Ecto.Enum.dump_values(Transaction, :status)

  defp with_status(query, status) do
    if status in history_statuses(), do: where(query, [t], t.status == ^status), else: query
  end

  defp search(query, term) when is_binary(term) do
    case String.trim(term) do
      "" ->
        query

      term ->
        pattern = "%" <> escape_like(term) <> "%"

        from t in query,
          join: a in assoc(t, :authorization),
          join: g in assoc(a, :agent),
          where:
            ilike(t.product_name, ^pattern) or ilike(g.name, ^pattern) or
              ilike(t.paypal_order_id, ^pattern)
    end
  end

  defp search(query, _term), do: query

  # "%" and "_" in a search are plain characters, not wildcards.
  defp escape_like(term), do: String.replace(term, ["\\", "%", "_"], &("\\" <> &1))

  def get_transaction!(id), do: Repo.get!(Transaction, id)

  @doc """
  Loads a transaction with its agent, dispute, and evidence.
  """
  def get_case!(id) do
    Transaction
    |> Repo.get!(id)
    |> Repo.preload([authorization: :agent, dispute: :evidence], force: true)
  end

  defdelegate timeline(transaction), to: AgentProof.Transactions.Timeline, as: :build

  @doc """
  Rebuilds a disputed transaction as plain facts and checks.
  """
  defdelegate reconstruct(transaction, dispute),
    to: AgentProof.Transactions.Reconstruction,
    as: :facts

  @doc """
  Total amount committed against the authorization. Failed purchases don't count.
  """
  def spent_amount(%Authorization{id: authorization_id}) do
    Transaction
    |> where([t], t.authorization_id == ^authorization_id)
    |> where([t], t.status in ^[:created, :completed])
    |> select([t], coalesce(sum(t.amount), 0))
    |> Repo.one()
  end

  @doc """
  Buys a product for an agent: locks and checks the budget, pays with PayPal, then saves the
  result. Pass `fallback: false` to stop PayPal.Demo taking over when PayPal fails.
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
            "currency" => currency,
            # The terms this purchase was checked against, kept if the authorization changes.
            "description" => authorization.description
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

  defp pay(transaction, opts, actions \\ []) do
    order = %{
      amount: transaction.amount,
      currency: transaction.currency,
      description: transaction.product_name,
      reference_id: "transaction-#{transaction.id}"
    }

    case PayPal.create_order(order, opts) do
      {:ok, %{order_id: order_id}} ->
        created = AgentAction.system(:create_paypal_order, %{"order_id" => order_id})
        capture(transaction, order_id, actions ++ [created], opts)

      {:error, reason} ->
        if fallback_allowed?(opts) do
          fall_back(transaction, reason, opts, actions)
        else
          fail(transaction, nil, actions, :create_order, reason)
        end
    end
  end

  # PayPal.Demo takes the payment and the switch is recorded. Capture isn't retried this
  # way: by then a real order exists.
  defp fall_back(transaction, reason, opts, actions) do
    adapter = PayPal.adapter_name(opts)

    Logger.warning(
      "PayPal create_order failed for transaction #{transaction.id} with #{adapter}, " <>
        "paying through PayPal.Demo: #{inspect(reason)}"
    )

    switched =
      AgentAction.system(:paypal_fallback, %{"adapter" => adapter, "reason" => inspect(reason)})

    pay(transaction, Keyword.put(opts, :adapter, PayPal.Demo), actions ++ [switched])
  end

  defp fallback_allowed?(opts),
    do: Keyword.get(opts, :fallback, true) and PayPal.adapter(opts) != PayPal.Demo

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
  Whether PayPal.Demo took the payment because PayPal failed.
  """
  def paypal_fallback?(%Transaction{agent_actions: actions}),
    do: Enum.any?(actions, &(&1.action == :paypal_fallback))

  def record_fulfillment(%Transaction{status: :completed} = transaction, attrs) do
    transaction
    |> Transaction.fulfillment_changeset(%{fulfillment: attrs})
    |> Repo.update()
  end

  def record_fulfillment(%Transaction{}, _attrs), do: {:error, :not_completed}

  defp money(%Decimal{} = amount), do: amount |> Decimal.round(2) |> Decimal.to_string()
end
