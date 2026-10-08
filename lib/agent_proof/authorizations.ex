defmodule AgentProof.Authorizations do
  @moduledoc """
  What a user allowed an agent to spend.
  """

  import Ecto.Query, warn: false

  alias AgentProof.{Agents, Repo}
  alias AgentProof.Agents.Agent
  alias AgentProof.Authorizations.Authorization
  alias AgentProof.Transactions.Transaction

  @grant_types %{
    agent_name: :string,
    max_amount: :decimal,
    currency: :string,
    description: :string
  }

  def get_authorization!(id), do: Repo.get!(Authorization, id)

  @doc """
  Lists authorizations, newest first, with their agent and transactions.
  """
  def list_authorizations do
    Authorization
    |> order_by(desc: :id)
    |> Repo.all()
    |> preload_activity()
  end

  @doc """
  Preloads an authorization's agent and transactions (newest first).
  """
  def preload_activity(authorization_or_authorizations) do
    Repo.preload(authorization_or_authorizations,
      agent: [],
      transactions: from(t in Transaction, order_by: [desc: t.id])
    )
  end

  @doc """
  Changeset for the form that authorizes a new agent: one form, two tables.

  It is schemaless, because it does not map to a single schema. Its errors
  come from the real `Agent` and `Authorization` changesets, so the rules are
  defined once.
  """
  def change_grant(attrs \\ %{}) do
    grant = Ecto.Changeset.cast({%{currency: "USD"}, @grant_types}, attrs, Map.keys(@grant_types))
    params = Ecto.Changeset.apply_changes(grant)

    grant
    |> copy_errors(Agent.changeset(%Agent{}, %{name: params[:agent_name]}), name: :agent_name)
    |> copy_errors(
      Authorization.changeset(%Authorization{}, Map.drop(params, [:agent_name])),
      []
    )
  end

  @doc """
  Creates an agent and its authorization atomically from the grant form.
  Returns the authorization with its activity preloaded.
  """
  def grant(attrs) do
    changeset = change_grant(attrs)

    if changeset.valid? do
      grant = Ecto.Changeset.apply_changes(changeset)

      Repo.transact(fn ->
        with {:ok, agent} <- Agents.create_agent(%{name: grant.agent_name}),
             {:ok, authorization} <-
               create_authorization(agent, Map.drop(grant, [:agent_name])) do
          {:ok, preload_activity(authorization)}
        end
      end)
    else
      {:error, %{changeset | action: :insert}}
    end
  end

  @doc """
  Deletes an agent and its authorizations, but only if none of them has any
  transaction: purchase records are dispute evidence and are always kept.

  The authorizations are locked first, so a purchase cannot start while the
  agent is being deleted. Returns the deleted agent and the ids of the
  deleted authorizations.
  """
  def delete_agent(%Agent{id: agent_id} = agent) do
    Repo.transact(fn ->
      authorizations = from(a in Authorization, where: a.agent_id == ^agent_id)

      authorizations |> lock("FOR UPDATE") |> Repo.all()

      has_transactions? =
        authorizations
        |> join(:inner, [a], t in assoc(a, :transactions))
        |> Repo.exists?()

      if has_transactions? do
        {:error, :has_purchases}
      else
        {_count, ids} = Repo.delete_all(select(authorizations, [a], a.id))

        with {:ok, agent} <- Repo.delete(agent) do
          {:ok, %{agent: agent, authorization_ids: ids}}
        end
      end
    end)
  end

  # Copies errors from a schema changeset onto the form changeset (renaming
  # fields where needed), unless the field already has an error, e.g. from cast.
  defp copy_errors(changeset, source, renames) do
    Enum.reduce(source.errors, changeset, fn {field, {message, opts}}, changeset ->
      field = Keyword.get(renames, field, field)

      if Keyword.has_key?(changeset.errors, field),
        do: changeset,
        else: Ecto.Changeset.add_error(changeset, field, message, opts)
    end)
  end

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
