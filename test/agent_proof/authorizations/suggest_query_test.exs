defmodule AgentProof.Authorizations.SuggestQueryTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures
  import ExUnit.CaptureLog

  alias AgentProof.{AI, Authorizations}
  alias AgentProof.AI.TestProvider

  setup do
    %{authorization: authorization_fixture(agent_fixture())}
  end

  defp suggest(authorization, reply),
    do: Authorizations.suggest_query(authorization, provider: TestProvider, reply: reply)

  defp mock(description) do
    {:ok, %{"product" => query}} = AI.suggest_search_query(description, provider: AI.Demo)
    query
  end

  test "AI.Demo's mock query is the product named in the description" do
    assert mock("Buy a good laptop for office work") == "laptop"
    assert mock("Buy a new smartphone for grandmother") == "smartphone"
    assert mock("Buy noise-cancelling headphones, up to $200") == "headphones"
    assert mock("Get a wireless mouse under 100 dollars") == "mouse"
  end

  test "the AI gets the description, the product schema, and the search task" do
    check = fn request ->
      send(self(), {:request, request})
      {:ok, %{"product" => "laptop"}}
    end

    AI.suggest_search_query("Buy a good laptop", provider: TestProvider, reply: check)

    assert_received {:request, %{task: :search_query} = request}
    assert request.facts == %{"description" => "Buy a good laptop"}
    assert request.prompt =~ "Buy a good laptop"
    assert request.schema["required"] == ["product", "details"]
  end

  test "saves the AI's query, tidied, with who suggested it", %{authorization: authorization} do
    assert {:ok, saved} =
             suggest(authorization, {:ok, %{"product" => "  Noise  Cancelling Headphones "}})

    assert {saved.suggested_query, saved.suggested_by} == {"noise cancelling headphones", "test"}
  end

  test "a bad answer or a failing AI gets the demo mock, labelled demo-fallback",
       %{authorization: authorization} do
    for answer <- [
          {:ok, %{"product" => "buy the best headphones you can find"}},
          {:ok, %{"product" => "<script>"}},
          {:ok, %{"query" => "laptop"}},
          {:error, {:transport, :econnrefused}}
        ] do
      log =
        capture_log(fn ->
          assert {:ok, saved} = suggest(authorization, answer)
          assert {saved.suggested_query, saved.suggested_by} == {"headphones", "demo-fallback"}
        end)

      assert log =~ "Search suggestion failed with test"
    end
  end

  test "nothing is saved when even the mock finds no words", %{authorization: authorization} do
    {:ok, authorization} =
      authorization |> Ecto.Changeset.change(description: "123 456") |> Repo.update()

    assert Authorizations.suggest_query(authorization, provider: AI.Demo) ==
             {:error, :invalid_suggestion}

    assert Repo.reload!(authorization).suggested_query == nil
  end

  test "a suggestion for an old description is dropped", %{authorization: authorization} do
    edit_meanwhile = fn _request ->
      authorization |> Ecto.Changeset.change(description: "Buy a laptop") |> Repo.update!()
      {:ok, %{"product" => "headphones"}}
    end

    assert suggest(authorization, edit_meanwhile) == {:error, :stale}
    assert Repo.reload!(authorization).suggested_query == nil
  end

  test "never calls the AI inside a database transaction", %{authorization: authorization} do
    check = fn _request ->
      send(self(), {:in_transaction, Repo.in_transaction?()})
      {:ok, %{"product" => "laptop"}}
    end

    assert {:ok, _} = suggest(authorization, check)
    assert_received {:in_transaction, false}
  end

  describe "editing the authorization" do
    setup %{authorization: authorization} do
      {:ok, _} = suggest(authorization, {:ok, %{"product" => "headphones"}})

      %{
        authorization:
          authorization.id
          |> Authorizations.get_authorization!()
          |> Authorizations.preload_activity()
      }
    end

    test "a new description clears the suggestion", %{authorization: authorization} do
      {:ok, edited} = Authorizations.update_settings(authorization, %{"description" => "Laptops"})

      assert {edited.suggested_query, edited.suggested_by} == {nil, nil}
    end

    test "other edits keep it", %{authorization: authorization} do
      {:ok, edited} = Authorizations.update_settings(authorization, %{"max_amount" => "300"})

      assert edited.suggested_query == "headphones"
    end
  end
end
