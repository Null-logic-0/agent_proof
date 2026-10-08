defmodule AgentProof.Transactions do
  @moduledoc """
  What an agent actually purchased.
  """

  import Ecto.Query, warn: false

  alias AgentProof.Repo
  alias AgentProof.Transactions.Transaction

  def list_transactions do
    Transaction
    |> order_by(desc: :id)
    |> Repo.all()
  end

  def get_transaction!(id), do: Repo.get!(Transaction, id)
end
