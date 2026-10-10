defmodule AgentProof.Authorizations do
  @moduledoc """
  What a user allowed an agent to spend.
  """

  import Ecto.Query, warn: false

  alias Pagex
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
  Lists authorizations, newest first. With pagination params, returns
  `{authorizations, meta}`.
  """
  def list_authorizations(params \\ nil) do
    # Preloading in the query applies it to every page Pagex fetches.
    query =
      from(a in Authorization,
        order_by: [desc: a.id],
        preload: [agent: [], transactions: ^from(t in Transaction, order_by: [desc: t.id])]
      )

    case params do
      nil -> Repo.all(query)
      params -> Pagex.paginate(query, params, Repo)
    end
  end

  @doc """
  Lists up to `limit` authorizations older than `before_id`, as `{authorizations, more?}`.
  Keyset pagination: adding or deleting agents never skips or repeats one.
  """
  def list_authorizations_page(before_id, limit) do
    query =
      from(a in Authorization,
        order_by: [desc: a.id],
        limit: ^(limit + 1),
        preload: [agent: [], transactions: ^from(t in Transaction, order_by: [desc: t.id])]
      )

    query = if before_id, do: where(query, [a], a.id < ^before_id), else: query
    rows = Repo.all(query)

    {Enum.take(rows, limit), length(rows) > limit}
  end

  def preload_activity(authorization_or_authorizations) do
    Repo.preload(authorization_or_authorizations,
      agent: [],
      transactions: from(t in Transaction, order_by: [desc: t.id])
    )
  end

  @doc """
  Form changeset for authorizing a new agent. Errors come from the `Agent` and
  `Authorization` changesets.
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
  Creates the agent and its authorization together.
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
  Form changeset for editing an agent's name, spending limit, and description.
  """
  def change_settings(%Authorization{agent: %Agent{} = agent} = authorization, attrs \\ %{}) do
    data = %{
      agent_name: agent.name,
      max_amount: authorization.max_amount,
      currency: authorization.currency,
      description: authorization.description
    }

    settings =
      Ecto.Changeset.cast({data, @grant_types}, attrs, [:agent_name, :max_amount, :description])

    params = Ecto.Changeset.apply_changes(settings)

    settings
    |> copy_errors(Agent.changeset(agent, %{name: params.agent_name}), name: :agent_name)
    |> copy_errors(
      Authorization.changeset(authorization, Map.take(params, [:max_amount, :description])),
      []
    )
  end

  @doc """
  Saves an agent's new name, limit, and description. Past purchases keep their old terms.
  """
  def update_settings(%Authorization{agent: %Agent{} = agent} = authorization, attrs) do
    changeset = change_settings(authorization, attrs)

    if changeset.valid? do
      settings = Ecto.Changeset.apply_changes(changeset)

      Repo.transact(fn ->
        with {:ok, _agent} <-
               agent |> Agent.changeset(%{name: settings.agent_name}) |> Repo.update(),
             {:ok, authorization} <-
               authorization
               |> Authorization.changeset(Map.take(settings, [:max_amount, :description]))
               |> Repo.update() do
          {:ok, authorization.id |> get_authorization!() |> preload_activity()}
        end
      end)
    else
      {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Deletes an agent, unless it has purchases: they are dispute evidence.
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

  # Copies schema errors onto the form changeset, unless the field already has one.
  defp copy_errors(changeset, source, renames) do
    Enum.reduce(source.errors, changeset, fn {field, {message, opts}}, changeset ->
      field = Keyword.get(renames, field, field)

      if Keyword.has_key?(changeset.errors, field),
        do: changeset,
        else: Ecto.Changeset.add_error(changeset, field, message, opts)
    end)
  end

  @doc """
  Reloads the authorization with a row lock. Call it inside `Repo.transact/2`.
  """
  def lock_authorization!(%Authorization{id: id}) do
    Authorization
    |> where([a], a.id == ^id)
    |> lock("FOR UPDATE")
    |> Repo.one!()
  end

  @doc """
  Creates an authorization for `agent`. The agent id never comes from `attrs`.
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
  Checks whether a purchase fits the budget. Pure: callers must hold the row lock.
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
