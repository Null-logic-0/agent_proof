defmodule AgentProof.TransactionsTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures

  alias AgentProof.Transactions
  alias AgentProof.Transactions.{Fulfillment, Transaction}

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

  defp product(price, currency \\ "USD") do
    %{name: "Sony WH-1000XM5 Headphones", price: Decimal.new(price), currency: currency}
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

    test "agent_actions round-trip through Postgres", %{authorization: authorization} do
      actions = [
        %{"action" => "search_product", "at" => "2026-10-08T12:00:00Z"},
        %{"action" => "select_product", "details" => %{"price" => "189.99"}}
      ]

      transaction =
        %Transaction{authorization_id: authorization.id, agent_actions: actions}
        |> Transaction.changeset(@valid_attrs)
        |> Repo.insert!()

      assert Transactions.get_transaction!(transaction.id).agent_actions == actions
    end

    test "atom keys in plain maps come back as string keys", %{authorization: authorization} do
      transaction =
        %Transaction{authorization_id: authorization.id, agent_actions: [%{action: "search"}]}
        |> Transaction.changeset(@valid_attrs)
        |> Repo.insert!()

      assert Transactions.get_transaction!(transaction.id).agent_actions == [
               %{"action" => "search"}
             ]
    end
  end

  describe "purchase/2" do
    test "reserves budget with a :created transaction", %{authorization: authorization} do
      assert {:ok, %Transaction{} = transaction} =
               Transactions.purchase(authorization, product("189.99"))

      assert transaction.status == :created
      assert transaction.authorization_id == authorization.id
      assert transaction.product_name == "Sony WH-1000XM5 Headphones"
      assert Decimal.equal?(transaction.amount, "189.99")
      assert transaction.paypal_order_id == nil
    end

    test "rejects a purchase over the budget and writes nothing",
         %{authorization: authorization} do
      assert Transactions.purchase(authorization, product("250.00")) ==
               {:error, :exceeds_budget}

      assert Transactions.list_transactions() == []
    end

    test "the budget is cumulative across purchases", %{authorization: authorization} do
      assert {:ok, _} = Transactions.purchase(authorization, product("150.00"))

      assert Transactions.purchase(authorization, product("60.00")) ==
               {:error, :exceeds_budget}

      assert {:ok, _} = Transactions.purchase(authorization, product("50.00"))
    end

    test "rejects a currency that differs from the authorization",
         %{authorization: authorization} do
      assert Transactions.purchase(authorization, product("10.00", "EUR")) ==
               {:error, :currency_mismatch}
    end
  end

  describe "record_fulfillment/2" do
    @delivery %{
      carrier: "UPS",
      tracking_number: "1Z999AA10123456784",
      delivered_at: ~U[2026-10-10 14:00:00Z]
    }

    test "stores typed fulfillment that survives a reload", %{authorization: authorization} do
      transaction = transaction_fixture(authorization, %{status: :completed})

      assert {:ok, transaction} = Transactions.record_fulfillment(transaction, @delivery)

      expected = %Fulfillment{
        carrier: "UPS",
        tracking_number: "1Z999AA10123456784",
        delivered_at: ~U[2026-10-10 14:00:00Z]
      }

      assert transaction.fulfillment == expected
      assert Transactions.get_transaction!(transaction.id).fulfillment == expected
    end

    test "requires every fulfillment field", %{authorization: authorization} do
      transaction = transaction_fixture(authorization, %{status: :completed})

      assert {:error, changeset} =
               Transactions.record_fulfillment(transaction, %{carrier: "UPS"})

      assert %{
               fulfillment: %{
                 tracking_number: ["can't be blank"],
                 delivered_at: ["can't be blank"]
               }
             } = errors_on(changeset)
    end

    test "refuses to fulfill a transaction that was not paid", %{authorization: authorization} do
      transaction = transaction_fixture(authorization, %{status: :created})

      assert Transactions.record_fulfillment(transaction, @delivery) ==
               {:error, :not_completed}
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
