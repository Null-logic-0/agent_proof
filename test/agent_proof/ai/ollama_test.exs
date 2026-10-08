defmodule AgentProof.AI.OllamaTest do
  # No model needed: Req.Test stubs answer every HTTP call (see config/test.exs).
  use ExUnit.Case, async: true

  alias AgentProof.AI.Ollama

  @schema %{
    "type" => "object",
    "properties" => %{"summary" => %{"type" => "string"}},
    "required" => ["summary"]
  }

  @request %{
    system: "You write dispute evidence.",
    prompt: "Summarize the case.",
    schema: @schema,
    facts: %{}
  }

  defp reply(conn, content) do
    Req.Test.json(conn, %{"model" => "test-model", "message" => %{"content" => content}})
  end

  test "sends a structured chat request and decodes the model's JSON" do
    Req.Test.stub(Ollama, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "model" => "test-model",
               "messages" => [
                 %{"role" => "system", "content" => "You write dispute evidence."},
                 %{"role" => "user", "content" => "Summarize the case."}
               ],
               "format" => @schema,
               "stream" => false,
               "options" => %{"temperature" => 0}
             } = Jason.decode!(body)

      reply(conn, ~s({"summary": "Within budget."}))
    end)

    assert Ollama.generate(@request, []) == {:ok, %{"summary" => "Within budget."}}
  end

  test "an answer that is not a JSON object is an error" do
    for content <- ["Sure! Here is the evidence:", ~s(["a list"])] do
      Req.Test.stub(Ollama, &reply(&1, content))

      assert Ollama.generate(@request, []) == {:error, :invalid_json}
    end
  end

  test "a missing model gives a clean error" do
    Req.Test.stub(Ollama, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{"error" => ~s(model "test-model" not found, try pulling it first)})
    end)

    assert Ollama.generate(@request, []) ==
             {:error, {:ollama, 404, ~s(model "test-model" not found, try pulling it first)}}
  end

  test "Ollama not running is a transport error" do
    Req.Test.stub(Ollama, &Req.Test.transport_error(&1, :econnrefused))

    assert Ollama.generate(@request, []) == {:error, {:transport, :econnrefused}}
  end

  test "name/0 includes the model" do
    assert Ollama.name() == "ollama:test-model"
  end
end
