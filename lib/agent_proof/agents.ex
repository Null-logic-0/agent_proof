defmodule AgentProof.Agents do
  @moduledoc """
  The AI agents that make purchases on a user's behalf.
  """

  import Ecto.Query, warn: false

  alias AgentProof.Repo
  alias AgentProof.Agents.Agent

  def list_agents do
    Agent
    |> order_by(:id)
    |> Repo.all()
  end

  def get_agent!(id), do: Repo.get!(Agent, id)

  def create_agent(attrs) do
    %Agent{}
    |> Agent.changeset(attrs)
    |> Repo.insert()
  end

  def change_agent(%Agent{} = agent, attrs \\ %{}) do
    Agent.changeset(agent, attrs)
  end
end
