defmodule AgentProof.Authorizations do
  @moduledoc """
  What a user allowed an agent to spend.
  """

  import Ecto.Query, warn: false

  alias AgentProof.Repo
  alias AgentProof.Agents.Agent
  alias AgentProof.Authorizations.Authorization

  def get_authorization!(id), do: Repo.get!(Authorization, id)

  @doc """
  Reloads `authorization` with a row lock (`SELECT ... FOR UPDATE`).

  Must be called inside `Repo.transact/2`. Other transactions that try to lock
  the same row wait until this one commits or rolls back.
  """
  def lock_authorization!(%Authorization{id: id}) do
    Authorization
    |> where([a], a.id == ^id)
    |> lock("FOR UPDATE")
    |> Repo.one!()
  end

  @doc """
  Creates an authorization for `agent`.

  `agent_id` comes from the agent struct, never from `attrs`.
  """
  def create_authorization(%Agent{} = agent, attrs) do
    agent
    |> Ecto.build_assoc(:authorizations)
    |> Authorization.changeset(attrs)
    |> Repo.insert()
  end

  def change_authorization(%Authorization{} = authorization, attrs \\ %{}) do
    Authorization.changeset(authorization, attrs)
  end

  @doc """
  Decides whether a purchase fits within `authorization`.

  The budget is cumulative: `spent` (see `AgentProof.Transactions.spent_amount/1`)
  plus `amount` must not exceed `max_amount`. This function is pure; it is not
  safe against concurrent purchases on its own.
  """
  def check_purchase(
        %Authorization{} = authorization,
        %Decimal{} = spent,
        %Decimal{} = amount,
        currency
      ) do
    cond do
      not Decimal.gt?(amount, 0) ->
        {:error, :invalid_amount}

      currency != authorization.currency ->
        {:error, :currency_mismatch}

      Decimal.gt?(Decimal.add(spent, amount), authorization.max_amount) ->
        {:error, :exceeds_budget}

      true ->
        :ok
    end
  end
end
