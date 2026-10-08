defmodule AgentProof.AI.OpenAITest do
  # No network: Req.Test stubs answer every HTTP call (see config/test.exs).
  use ExUnit.Case, async: true

  alias AgentProof.AI.OpenAI

  @schema %{
    "type" => "object",
    "properties" => %{"summary" => %{"type" => "string"}},
    "required" => ["summary"],
    "additionalProperties" => false
  }

  @request %{
    system: "You write dispute evidence.",
    prompt: "Summarize the case.",
    schema: @schema,
    facts: %{}
  }

  defp respond(conn, content, extra \\ %{}) do
    Req.Test.json(
      conn,
      Map.merge(
        %{
          "status" => "completed",
          "output" => [
            %{"type" => "reasoning", "summary" => []},
            %{"type" => "message", "role" => "assistant", "content" => content}
          ]
        },
        extra
      )
    )
  end

  defp error(conn, status, error) do
    conn
    |> Plug.Conn.put_status(status)
    |> Req.Test.json(%{"error" => error})
  end

  test "sends a strict structured-output request and decodes the answer" do
    Req.Test.stub(OpenAI, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/responses"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-openai-key"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "model" => "test-model",
               "input" => [
                 %{"role" => "system", "content" => "You write dispute evidence."},
                 %{"role" => "user", "content" => "Summarize the case."}
               ],
               "text" => %{
                 "format" => %{
                   "type" => "json_schema",
                   "name" => "dispute_evidence",
                   "schema" => @schema,
                   "strict" => true
                 }
               }
             }

      respond(conn, [%{"type" => "output_text", "text" => ~s({"summary": "Within budget."})}])
    end)

    assert OpenAI.generate(@request, []) == {:ok, %{"summary" => "Within budget."}}
  end

  test "a refusal gets its own error" do
    Req.Test.stub(OpenAI, &respond(&1, [%{"type" => "refusal", "refusal" => "I can't help."}]))

    assert OpenAI.generate(@request, []) == {:error, {:refusal, "I can't help."}}
  end

  test "a truncated response is reported as incomplete" do
    Req.Test.stub(OpenAI, fn conn ->
      respond(conn, [], %{
        "status" => "incomplete",
        "incomplete_details" => %{"reason" => "max_output_tokens"}
      })
    end)

    assert OpenAI.generate(@request, []) == {:error, {:incomplete, "max_output_tokens"}}
  end

  test "text that is not a JSON object is an error" do
    Req.Test.stub(OpenAI, &respond(&1, [%{"type" => "output_text", "text" => "Here you go!"}]))

    assert OpenAI.generate(@request, []) == {:error, :invalid_json}
  end

  test "API errors are normalized and never contain the key" do
    Req.Test.stub(OpenAI, fn conn ->
      error(conn, 401, %{
        "message" => "Incorrect API key provided: test-ope****",
        "type" => "invalid_request_error",
        "code" => "invalid_api_key"
      })
    end)

    result = OpenAI.generate(@request, [])

    assert result == {:error, {:openai, 401, "invalid_api_key"}}
    refute inspect(result) =~ "test-openai-key"

    Req.Test.stub(OpenAI, fn conn ->
      error(conn, 429, %{"message" => "Quota exceeded", "type" => "insufficient_quota"})
    end)

    assert OpenAI.generate(@request, []) == {:error, {:openai, 429, "insufficient_quota"}}
  end

  test "network failures are transport errors" do
    Req.Test.stub(OpenAI, &Req.Test.transport_error(&1, :timeout))

    assert OpenAI.generate(@request, []) == {:error, {:transport, :timeout}}
  end

  test "name/0 includes the model" do
    assert OpenAI.name() == "openai:test-model"
  end
end
