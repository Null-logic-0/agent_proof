defmodule AgentProof.TransactionsTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Transactions
  alias AgentProof.Transactions.Transaction

  @valid_attrs %{
    paypal_order_id: "ORDER-1",
    amount: "189.99",
    currency: "USD",
    product_name: "Sony WH-1000XM5 Headphones",
    status: :completed
  }

  setup do
    %{authorization: authorization_fixture(agent_fixture())}
  end

  describe "Transaction.changeset/2" do
    test "accepts valid attrs and casts the amount to Decimal" do
      changeset = Transaction.changeset(%Transaction{}, @valid_attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :amount) == Decimal.new("189.99")
    end

    test "rejects a status outside the enum" do
      changeset = Transaction.changeset(%Transaction{}, %{@valid_attrs | status: :refunded})

      assert "is invalid" in errors_on(changeset).status
    end

    test "rejects an amount of zero or less" do
      changeset = Transaction.changeset(%Transaction{}, %{@valid_attrs | amount: "0"})

      assert "must be greater than 0" in errors_on(changeset).amount
    end
  end

  describe "database constraints" do
    test "a duplicate paypal_order_id becomes a changeset error", %{authorization: authorization} do
      transaction_fixture(authorization, %{paypal_order_id: "ORDER-DUP"})

      assert {:error, changeset} =
               %Transaction{authorization_id: authorization.id}
               |> Transaction.changeset(%{@valid_attrs | paypal_order_id: "ORDER-DUP"})
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).paypal_order_id
    end

    test "many transactions may have no paypal_order_id yet", %{authorization: authorization} do
      transaction_fixture(authorization, %{paypal_order_id: nil, status: :failed})
      transaction_fixture(authorization, %{paypal_order_id: nil, status: :failed})

      assert length(Transactions.list_transactions()) == 2
    end
  end

  describe "JSONB fields" do
    test "agent_actions defaults to an empty list", %{authorization: authorization} do
      assert transaction_fixture(authorization).agent_actions == []
    end

    test "agent_actions and fulfillment round-trip through Postgres",
         %{authorization: authorization} do
      actions = [
        %{"action" => "search_product", "at" => "2026-10-08T12:00:00Z"},
        %{"action" => "select_product", "details" => %{"price" => "189.99"}}
      ]

      fulfillment = %{"carrier" => "UPS", "tracking_number" => "1Z999AA10123456784"}

      transaction =
        %Transaction{
          authorization_id: authorization.id,
          agent_actions: actions,
          fulfillment: fulfillment
        }
        |> Transaction.changeset(@valid_attrs)
        |> Repo.insert!()

      reloaded = Transactions.get_transaction!(transaction.id)

      assert reloaded.agent_actions == actions
      assert reloaded.fulfillment == fulfillment
    end

    test "atom keys come back as string keys", %{authorization: authorization} do
      transaction =
        %Transaction{authorization_id: authorization.id, fulfillment: %{carrier: "UPS"}}
        |> Transaction.changeset(@valid_attrs)
        |> Repo.insert!()

      assert Transactions.get_transaction!(transaction.id).fulfillment == %{"carrier" => "UPS"}
    end
  end

  describe "spent_amount/1" do
    test "is zero when nothing was bought", %{authorization: authorization} do
      assert Decimal.equal?(Transactions.spent_amount(authorization), 0)
    end

    test "sums created and completed transactions, ignoring failed ones",
         %{authorization: authorization} do
      transaction_fixture(authorization, %{amount: "100.00", status: :completed})
      transaction_fixture(authorization, %{amount: "40.50", status: :created})
      transaction_fixture(authorization, %{amount: "999.00", status: :failed})

      assert Decimal.equal?(Transactions.spent_amount(authorization), "140.50")
    end

    test "only counts the given authorization's transactions", %{authorization: authorization} do
      other_authorization = authorization_fixture(agent_fixture(%{name: "Other"}))
      transaction_fixture(other_authorization, %{amount: "75.00"})

      assert Decimal.equal?(Transactions.spent_amount(authorization), 0)
    end
  end

  test "list_transactions/0 returns newest first", %{authorization: authorization} do
    older = transaction_fixture(authorization)
    newer = transaction_fixture(authorization)

    assert Enum.map(Transactions.list_transactions(), & &1.id) == [newer.id, older.id]
  end
end
