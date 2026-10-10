defmodule AgentProof.TransactionsTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures
  import ExUnit.CaptureLog

  alias AgentProof.Transactions
  alias AgentProof.Transactions.{AgentAction, Fulfillment, Transaction}
  alias AgentProof.PayPal.TestClient

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

    test "atom keys in plain maps come back as string keys", %{authorization: authorization} do
      searched = %{action: :search_products, at: DateTime.utc_now(), details: %{query: "cable"}}

      {:ok, transaction} = Transactions.purchase(authorization, product("19.99"), [searched])

      [reloaded_search | _system_actions] =
        Transactions.get_transaction!(transaction.id).agent_actions

      assert reloaded_search.details == %{"query" => "cable"}
    end
  end

  describe "purchase/2" do
    test "completes the purchase with a PayPal order", %{authorization: authorization} do
      assert {:ok, %Transaction{} = transaction} =
               Transactions.purchase(authorization, product("189.99"))

      assert transaction.status == :completed
      assert transaction.authorization_id == authorization.id
      assert transaction.product_name == "Sony WH-1000XM5 Headphones"
      assert Decimal.equal?(transaction.amount, "189.99")
      assert transaction.paypal_order_id == "DEMO-ORDER-transaction-#{transaction.id}"
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

  describe "purchase/3 agent actions" do
    test "without agent actions, only system actions are logged",
         %{authorization: authorization} do
      {:ok, transaction} = Transactions.purchase(authorization, product("189.99"))

      assert [
               %AgentAction{action: :budget_check, actor: :system} = check,
               %AgentAction{action: :create_paypal_order, actor: :system},
               %AgentAction{action: :capture_payment, actor: :system} = captured
             ] = transaction.agent_actions

      assert captured.details == %{
               "order_id" => "DEMO-ORDER-transaction-#{transaction.id}",
               "capture_id" => "DEMO-CAPTURE-transaction-#{transaction.id}",
               "simulated" => true
             }

      assert check.details == %{
               "result" => "approved",
               "spent" => "0.00",
               "amount" => "189.99",
               "max_amount" => "200.00",
               "currency" => "USD",
               "description" => "Buy noise-cancelling headphones, up to $200"
             }
    end

    test "an agent cannot forge a system action", %{authorization: authorization} do
      forged = %{
        action: :budget_check,
        actor: :system,
        at: DateTime.utc_now(),
        details: %{"result" => "approved"}
      }

      {:ok, transaction} = Transactions.purchase(authorization, product("19.99"), [forged])

      assert [
               %AgentAction{actor: :agent},
               %AgentAction{action: :budget_check, actor: :system} | _
             ] =
               transaction.agent_actions
    end

    test "rejects invalid agent actions and stores nothing", %{authorization: authorization} do
      unknown = %{action: :wire_money, at: DateTime.utc_now()}
      undated = %{action: :search_products}

      assert {:error, changeset} =
               Transactions.purchase(authorization, product("19.99"), [unknown])

      assert "is invalid" in errors_on(changeset).action

      assert {:error, changeset} =
               Transactions.purchase(authorization, product("19.99"), [undated])

      assert "can't be blank" in errors_on(changeset).at
      assert Transactions.list_transactions() == []
    end
  end

  test "purchase/4 works end to end with the Sandbox adapter (stubbed HTTP)",
       %{authorization: authorization} do
    Req.Test.stub(AgentProof.PayPal.Sandbox, fn
      %{request_path: "/v1/oauth2/token"} = conn ->
        Req.Test.json(conn, %{"access_token" => "test-token"})

      %{request_path: "/v2/checkout/orders"} = conn ->
        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"id" => "5O190127TN364715T", "status" => "CREATED"})
    end)

    assert {:ok, transaction} =
             Transactions.purchase(authorization, product("189.99"), [],
               adapter: AgentProof.PayPal.Sandbox
             )

    assert transaction.status == :completed
    assert transaction.paypal_order_id == "5O190127TN364715T"

    assert %AgentAction{action: :capture_payment} =
             captured = List.last(transaction.agent_actions)

    assert captured.details["simulated"] == true
  end

  describe "purchase/4 payment failures" do
    test "a failed order creation marks the transaction :failed and releases the budget",
         %{authorization: authorization} do
      log =
        capture_log(fn ->
          assert Transactions.purchase(authorization, product("189.99"), [],
                   adapter: TestClient,
                   fail: :create,
                   fallback: false
                 ) == {:error, :payment_failed}
        end)

      assert log =~ "PayPal create_order failed"

      assert [%Transaction{status: :failed, paypal_order_id: nil} = failed] =
               Transactions.list_transactions()

      assert %AgentAction{action: :payment_failed, details: %{"step" => "create_order"}} =
               List.last(failed.agent_actions)

      assert Decimal.equal?(Transactions.spent_amount(authorization), 0)
      assert {:ok, _} = Transactions.purchase(authorization, product("189.99"))
    end

    test "a failed order creation falls back to PayPal.Demo and records why",
         %{authorization: authorization} do
      log =
        capture_log(fn ->
          assert {:ok, %Transaction{status: :completed} = transaction} =
                   Transactions.purchase(authorization, product("189.99"), [],
                     adapter: TestClient,
                     fail: :create
                   )

          assert transaction.paypal_order_id == "DEMO-ORDER-transaction-#{transaction.id}"
          assert Transactions.paypal_fallback?(transaction)

          assert [:budget_check, :paypal_fallback, :create_paypal_order, :capture_payment] =
                   Enum.map(transaction.agent_actions, & &1.action)

          assert %AgentAction{
                   actor: :system,
                   details: %{"adapter" => "test", "reason" => ":sandbox_unavailable"}
                 } = Enum.at(transaction.agent_actions, 1)

          assert List.last(transaction.agent_actions).details["simulated"] == true
        end)

      assert log =~ "paying through PayPal.Demo"
    end

    test "a payment made through the configured adapter is not a fallback",
         %{authorization: authorization} do
      {:ok, transaction} = Transactions.purchase(authorization, product("189.99"))

      refute Transactions.paypal_fallback?(transaction)
    end

    test "a failed capture keeps the PayPal order id for the record",
         %{authorization: authorization} do
      log =
        capture_log(fn ->
          assert Transactions.purchase(authorization, product("189.99"), [],
                   adapter: TestClient,
                   fail: :capture
                 ) == {:error, :payment_failed}
        end)

      assert log =~ "PayPal capture_order failed"

      [failed] = Transactions.list_transactions()

      assert failed.status == :failed
      assert failed.paypal_order_id == "DEMO-ORDER-transaction-#{failed.id}"

      assert [:budget_check, :create_paypal_order, :payment_failed] =
               Enum.map(failed.agent_actions, & &1.action)
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

  describe "list_transaction_history/1" do
    test "returns one page, newest first, with the agent preloaded",
         %{authorization: authorization} do
      [first, second, third] = for _ <- 1..3, do: transaction_fixture(authorization)

      {page_one, meta} =
        Transactions.list_transaction_history(%{"page" => "1", "page_size" => "2"})

      assert Enum.map(page_one, & &1.id) == [third.id, second.id]
      assert hd(page_one).authorization.agent.name == "ShopBot"
      assert %{page: 1, total: 3, total_pages: 2, has_next: true, has_prev: false} = meta

      {page_two, meta} =
        Transactions.list_transaction_history(%{"page" => "2", "page_size" => "2"})

      assert Enum.map(page_two, & &1.id) == [first.id]
      assert %{has_next: false, has_prev: true} = meta
    end

    test "an empty history has zero pages" do
      assert {[], %{total: 0, total_pages: 0}} =
               Transactions.list_transaction_history(%{"page" => "1"})
    end
  end

  test "list_transactions/0 returns newest first", %{authorization: authorization} do
    older = transaction_fixture(authorization)
    newer = transaction_fixture(authorization)

    assert Enum.map(Transactions.list_transactions(), & &1.id) == [newer.id, older.id]
  end
end
