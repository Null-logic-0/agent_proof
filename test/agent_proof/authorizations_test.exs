defmodule AgentProof.AuthorizationsTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Authorizations
  alias AgentProof.Authorizations.Authorization
  alias AgentProof.Agents.Agent

  @valid_attrs %{max_amount: "200.00", currency: "USD", description: "Headphones up to $200"}

  describe "create_authorization/2" do
    test "creates an authorization owned by the given agent" do
      agent = agent_fixture()

      assert {:ok, %Authorization{} = authorization} =
               Authorizations.create_authorization(agent, @valid_attrs)

      assert authorization.agent_id == agent.id
      assert authorization.max_amount == Decimal.new("200.00")
    end

    test "ignores agent_id in attrs" do
      agent = agent_fixture()
      other_agent = agent_fixture(%{name: "Other"})

      {:ok, authorization} =
        Authorizations.create_authorization(
          agent,
          Map.put(@valid_attrs, :agent_id, other_agent.id)
        )

      assert authorization.agent_id == agent.id
    end

    test "requires all fields" do
      assert {:error, changeset} = Authorizations.create_authorization(agent_fixture(), %{})

      assert %{max_amount: ["can't be blank"], currency: ["can't be blank"]} =
               errors_on(changeset)

      assert "can't be blank" in errors_on(changeset).description
    end

    test "rejects a max_amount of zero or less" do
      agent = agent_fixture()

      for amount <- ["0", "-5.00"] do
        assert {:error, changeset} =
                 Authorizations.create_authorization(
                   agent,
                   %{@valid_attrs | max_amount: amount}
                 )

        assert "must be greater than 0" in errors_on(changeset).max_amount
      end
    end

    test "rejects currencies that are not 3 uppercase letters" do
      agent = agent_fixture()

      for currency <- ["usd", "US", "USDT"] do
        assert {:error, changeset} =
                 Authorizations.create_authorization(agent, %{@valid_attrs | currency: currency})

        assert "must be a 3-letter uppercase code" in errors_on(changeset).currency
      end
    end

    test "returns an error instead of raising when the agent does not exist" do
      assert {:error, changeset} =
               Authorizations.create_authorization(%Agent{id: -1}, @valid_attrs)

      assert "does not exist" in errors_on(changeset).agent
    end
  end

  test "get_authorization!/1 returns the authorization" do
    authorization = authorization_fixture(agent_fixture())

    assert Authorizations.get_authorization!(authorization.id) == authorization
  end
end
