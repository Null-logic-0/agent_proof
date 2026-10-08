defmodule AgentProof.Transactions do
  @moduledoc """
  What an agent actually purchased.
  """

  import Ecto.Query, warn: false

  alias AgentProof.Repo
  alias AgentProof.Authorizations.Authorization
  alias AgentProof.Transactions.Transaction

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
end
