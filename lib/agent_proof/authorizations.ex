defmodule AgentProof.Authorizations do
  @moduledoc """
  What a user allowed an agent to spend.
  """

  alias AgentProof.Repo
  alias AgentProof.Agents.Agent
  alias AgentProof.Authorizations.Authorization

  def get_authorization!(id), do: Repo.get!(Authorization, id)

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
end
