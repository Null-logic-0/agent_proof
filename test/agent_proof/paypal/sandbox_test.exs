defmodule AgentProof.PayPal.SandboxTest do
  # No network: Req.Test stubs answer every HTTP call (see config/test.exs).
  use ExUnit.Case, async: true

  alias AgentProof.PayPal.Sandbox

  @order %{
    amount: Decimal.new("189.99"),
    currency: "USD",
    description: "Sony WH-1000XM5 Headphones",
    reference_id: "transaction-42"
  }

  # Answers the OAuth token request, then hands other requests to `orders_api`.
  defp stub_paypal(orders_api) do
    Req.Test.stub(Sandbox, fn
      %{request_path: "/v1/oauth2/token"} = conn ->
        Req.Test.json(conn, %{"access_token" => "test-token", "expires_in" => 32_400})

      conn ->
        orders_api.(conn)
    end)
  end

  defp json_body(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end

  defp header(conn, name), do: conn |> Plug.Conn.get_req_header(name) |> List.first()

  describe "create_order/2" do
    test "gets a token with Basic auth, then creates the order with it" do
      Req.Test.stub(Sandbox, fn
        %{request_path: "/v1/oauth2/token"} = conn ->
          assert "Basic " <> credentials = header(conn, "authorization")
          assert Base.decode64!(credentials) == "test-client-id:test-client-secret"
          assert {:ok, "grant_type=client_credentials", conn} = Plug.Conn.read_body(conn)

          Req.Test.json(conn, %{"access_token" => "test-token"})

        %{request_path: "/v2/checkout/orders"} = conn ->
          assert conn.method == "POST"
          assert header(conn, "authorization") == "Bearer test-token"
          assert {:ok, _uuid} = Ecto.UUID.cast(header(conn, "paypal-request-id"))

          assert json_body(conn) == %{
                   "intent" => "CAPTURE",
                   "purchase_units" => [
                     %{
                       "reference_id" => "transaction-42",
                       "description" => "Sony WH-1000XM5 Headphones",
                       "amount" => %{"currency_code" => "USD", "value" => "189.99"}
                     }
                   ]
                 }

          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{"id" => "5O190127TN364715T", "status" => "CREATED"})
      end)

      assert Sandbox.create_order(@order, []) == {:ok, %{order_id: "5O190127TN364715T"}}
    end

    test "normalizes PayPal API errors" do
      stub_paypal(fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{"name" => "UNPROCESSABLE_ENTITY", "details" => []})
      end)

      assert Sandbox.create_order(@order, []) ==
               {:error, {:paypal, 422, "UNPROCESSABLE_ENTITY"}}
    end

    test "bad credentials give a clean error that never contains the secret" do
      Req.Test.stub(Sandbox, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => "invalid_client", "error_description" => "Bad client"})
      end)

      result = Sandbox.create_order(@order, [])

      assert result == {:error, {:paypal, 401, "invalid_client"}}
      refute inspect(result) =~ "test-client-secret"
    end

    test "normalizes network failures" do
      Req.Test.stub(Sandbox, &Req.Test.transport_error(&1, :econnrefused))

      assert Sandbox.create_order(@order, []) == {:error, {:transport, :econnrefused}}
    end
  end

  test "capture_order/2 is simulated and says so" do
    assert Sandbox.capture_order("5O190127TN364715T", []) ==
             {:ok,
              %{
                order_id: "5O190127TN364715T",
                capture_id: "SIMULATED-CAPTURE-5O190127TN364715T",
                simulated: true
              }}
  end

  test "get_order/1 fetches the order's status from PayPal" do
    stub_paypal(fn %{request_path: "/v2/checkout/orders/5O190127TN364715T"} = conn ->
      assert conn.method == "GET"
      Req.Test.json(conn, %{"id" => "5O190127TN364715T", "status" => "CREATED"})
    end)

    assert Sandbox.get_order("5O190127TN364715T") ==
             {:ok, %{order_id: "5O190127TN364715T", status: "CREATED"}}
  end
end
