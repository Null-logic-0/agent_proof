defmodule AgentProof.Transactions do
  @moduledoc """
  What an agent actually purchased.
  """

  import Ecto.Query, warn: false

  alias AgentProof.Repo
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
  Reserves budget for `product` by creating a `:created` transaction.

  The lock, budget check, and insert run in one database transaction, so
  concurrent purchases against the same authorization cannot overspend it.

  `agent_actions` is the agent's own log (untrusted input). It is validated,
  stored with the transaction, and followed by a `:budget_check` system action.
  """
  def purchase(
        %Authorization{} = authorization,
        %{name: name, price: %Decimal{} = price, currency: currency},
        agent_actions \\ []
      ) do
    with {:ok, agent_actions} <- AgentAction.from_agent(agent_actions) do
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
