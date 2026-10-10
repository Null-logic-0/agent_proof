defmodule AgentProof.AuthorizationsTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Authorizations
  alias AgentProof.Authorizations.Authorization
  alias AgentProof.Agents.Agent

  @valid_attrs %{max_amount: "200.00", currency: "USD", description: "Headphones up to $200"}

  @usd_200 %Authorization{max_amount: Decimal.new("200.00"), currency: "USD"}

  defp check(authorization, spent, amount, currency \\ "USD") do
    Authorizations.check_purchase(
      authorization,
      Decimal.new(spent),
      Decimal.new(amount),
      currency
    )
  end

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

  describe "check_purchase/4" do
    test "allows a purchase within the budget" do
      assert check(@usd_200, "0", "189.99") == :ok
    end

    test "allows spending exactly up to the limit, not a cent more" do
      assert check(@usd_200, "0", "200.00") == :ok
      assert check(@usd_200, "0", "200.01") == {:error, :exceeds_budget}
    end

    test "counts what was already spent" do
      assert check(@usd_200, "150.00", "50.00") == :ok
      assert check(@usd_200, "150.00", "50.01") == {:error, :exceeds_budget}
    end

    test "compares amounts numerically, not structurally" do
      # With `>`, Decimal.new("200.00") > Decimal.new("1000") is true:
      # structs compare field by field, and 200.00 is stored as coef 20000.
      usd_1000 = %Authorization{max_amount: Decimal.new("1000"), currency: "USD"}

      assert check(usd_1000, "0", "200.00") == :ok
    end

    test "rejects a currency that differs from the authorization" do
      assert check(@usd_200, "0", "10.00", "EUR") == {:error, :currency_mismatch}
    end

    test "rejects zero and negative amounts" do
      assert check(@usd_200, "0", "0") == {:error, :invalid_amount}
      assert check(@usd_200, "0", "-1.00") == {:error, :invalid_amount}
    end
  end

  describe "grant/1" do
    @grant %{
      "agent_name" => "ShopBot",
      "max_amount" => "200",
      "currency" => "USD",
      "description" => "Headphones up to $200"
    }

    test "creates the agent and its authorization together" do
      assert {:ok, %Authorization{} = authorization} = Authorizations.grant(@grant)

      assert authorization.agent.name == "ShopBot"
      assert authorization.transactions == []
      assert Decimal.equal?(authorization.max_amount, "200")
    end

    test "uses the schema changesets' rules and creates nothing when invalid" do
      assert {:error, changeset} =
               Authorizations.grant(%{@grant | "agent_name" => "", "max_amount" => "0"})

      assert "can't be blank" in errors_on(changeset).agent_name
      assert "must be greater than 0" in errors_on(changeset).max_amount
      assert AgentProof.Agents.list_agents() == []
    end

    test "change_grant/1 reports a cast error once, not twice" do
      changeset = Authorizations.change_grant(%{@grant | "max_amount" => "lots"})

      assert errors_on(changeset).max_amount == ["is invalid"]
    end
  end

  test "rejects a max_amount too large for the database column" do
    assert {:error, changeset} =
             Authorizations.create_authorization(agent_fixture(), %{
               @valid_attrs
               | max_amount: "10000000000"
             })

    assert "must be less than 10000000000" in errors_on(changeset).max_amount
  end

  describe "update_settings/2" do
    setup do
      authorization = authorization_fixture(agent_fixture()) |> Authorizations.preload_activity()
      %{authorization: authorization}
    end

    test "updates the agent's name and the authorization's limit and description together",
         %{authorization: authorization} do
      assert {:ok, updated} =
               Authorizations.update_settings(authorization, %{
                 "agent_name" => "ShopBot Pro",
                 "max_amount" => "500",
                 "description" => "Any audio gear up to $500"
               })

      assert updated.agent.name == "ShopBot Pro"
      assert Decimal.equal?(updated.max_amount, "500")
      assert updated.description == "Any audio gear up to $500"
      assert updated.currency == "USD"
    end

    test "is allowed after purchases", %{authorization: authorization} do
      transaction_fixture(authorization)

      assert {:ok, updated} =
               Authorizations.update_settings(authorization, %{"max_amount" => "300"})

      assert Decimal.equal?(updated.max_amount, "300")
    end

    test "invalid input changes nothing", %{authorization: authorization} do
      assert {:error, changeset} =
               Authorizations.update_settings(authorization, %{
                 "agent_name" => "",
                 "max_amount" => "0"
               })

      assert "can't be blank" in errors_on(changeset).agent_name
      assert "must be greater than 0" in errors_on(changeset).max_amount

      reloaded =
        authorization.id
        |> Authorizations.get_authorization!()
        |> Authorizations.preload_activity()

      assert reloaded.agent.name == "ShopBot"
      assert Decimal.equal?(reloaded.max_amount, "200.00")
    end

    test "the currency cannot be changed", %{authorization: authorization} do
      {:ok, updated} = Authorizations.update_settings(authorization, %{"currency" => "EUR"})

      assert updated.currency == "USD"
    end
  end

  describe "delete_agent/1" do
    test "deletes an unused agent together with its authorizations" do
      agent = agent_fixture()
      authorization = authorization_fixture(agent)

      assert {:ok, %{agent: deleted, authorization_ids: ids}} = Authorizations.delete_agent(agent)

      assert deleted.id == agent.id
      assert ids == [authorization.id]
      assert AgentProof.Agents.list_agents() == []
      assert Authorizations.list_authorizations() == []
    end

    test "keeps agents with purchase records, even failed ones" do
      for status <- [:completed, :failed] do
        agent = agent_fixture(%{name: "Agent #{status}"})
        authorization = authorization_fixture(agent)
        transaction_fixture(authorization, %{status: status})

        assert Authorizations.delete_agent(agent) == {:error, :has_purchases}
        assert Authorizations.get_authorization!(authorization.id)
      end
    end
  end

  describe "list_authorizations_page/2" do
    setup do
      # One agent per authorization, as the dashboard creates them.
      %{
        authorizations:
          for(n <- 1..5, do: authorization_fixture(agent_fixture(%{name: "Bot #{n}"})))
      }
    end

    test "pages newest first and says whether more exist", %{authorizations: auths} do
      [a1, a2, a3, a4, a5] = auths

      {page_one, more?} = Authorizations.list_authorizations_page(nil, 3)
      assert Enum.map(page_one, & &1.id) == [a5.id, a4.id, a3.id]
      assert more?
      assert hd(page_one).agent.name == "Bot 5"

      {page_two, more?} = Authorizations.list_authorizations_page(a3.id, 3)
      assert Enum.map(page_two, & &1.id) == [a2.id, a1.id]
      refute more?
    end

    test "agents added or deleted between loads are never skipped or repeated",
         %{authorizations: auths} do
      [a1, a2, a3, _a4, _a5] = auths
      {_page_one, _more?} = Authorizations.list_authorizations_page(nil, 3)

      authorization_fixture(agent_fixture(%{name: "Newcomer"}))
      {:ok, _} = Authorizations.delete_agent(Repo.preload(a3, :agent).agent)

      {page_two, _more?} = Authorizations.list_authorizations_page(a3.id, 3)
      assert Enum.map(page_two, & &1.id) == [a2.id, a1.id]
    end
  end

  test "list_authorizations/1 paginates and still preloads activity" do
    agent = agent_fixture()
    older = authorization_fixture(agent)
    newer = authorization_fixture(agent)
    transaction_fixture(newer)

    {[only], meta} = Authorizations.list_authorizations(%{"page" => "1", "page_size" => "1"})

    assert only.id == newer.id
    assert only.agent.id == agent.id
    assert length(only.transactions) == 1
    assert %{total: 2, total_pages: 2} = meta

    {[last], _meta} = Authorizations.list_authorizations(%{"page" => "2", "page_size" => "1"})
    assert last.id == older.id
  end

  test "list_authorizations/0 returns newest first with activity preloaded" do
    agent = agent_fixture()
    older = authorization_fixture(agent)
    newer = authorization_fixture(agent)
    transaction = transaction_fixture(newer)

    assert [first, second] = Authorizations.list_authorizations()
    assert {first.id, second.id} == {newer.id, older.id}
    assert first.agent.id == agent.id
    assert Enum.map(first.transactions, & &1.id) == [transaction.id]
  end

  test "get_authorization!/1 returns the authorization" do
    authorization = authorization_fixture(agent_fixture())

    assert Authorizations.get_authorization!(authorization.id) == authorization
  end
end
