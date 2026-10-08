defmodule AgentProof.AgentsTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Agents
  alias AgentProof.Agents.Agent

  describe "create_agent/1" do
    test "creates an agent with a name" do
      assert {:ok, %Agent{name: "ShopBot"}} = Agents.create_agent(%{name: "ShopBot"})
    end

    test "rejects a blank name" do
      assert {:error, changeset} = Agents.create_agent(%{name: ""})
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  test "list_agents/0 returns agents in creation order" do
    first = agent_fixture(%{name: "First"})
    second = agent_fixture(%{name: "Second"})

    assert Agents.list_agents() == [first, second]
  end

  test "get_agent!/1 returns the agent or raises" do
    agent = agent_fixture()

    assert Agents.get_agent!(agent.id) == agent
    assert_raise Ecto.NoResultsError, fn -> Agents.get_agent!(-1) end
  end

  test "change_agent/2 returns a changeset for forms" do
    assert %Ecto.Changeset{} = Agents.change_agent(agent_fixture())
  end
end
