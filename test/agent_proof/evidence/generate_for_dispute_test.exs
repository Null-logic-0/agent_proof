defmodule AgentProof.Evidence.GenerateForDisputeTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures
  import ExUnit.CaptureLog

  alias AgentProof.{AI, Disputes, Evidence, Transactions}
  alias AgentProof.AI.TestProvider
  alias AgentProof.Evidence.{Package, Section}

  setup do
    %{dispute: disputed_case_fixture()}
  end

  defp valid_answer(dispute) do
    {:ok, answer} = AI.generate_evidence(dispute.transaction, dispute, provider: AI.Demo)
    answer
  end

  # Grounded, but the transaction evidence never quotes the PayPal order ID.
  defp incomplete_answer(dispute) do
    put_in(valid_answer(dispute), ["transaction_evidence"], %{
      "statement" => "The agent completed the purchase through PayPal.",
      "facts" => []
    })
  end

  defp ungrounded_answer(dispute) do
    Map.update!(valid_answer(dispute), "summary", &(&1 <> " A refund of 249.99 was issued."))
  end

  # Replies to successive AI calls in order, reporting each prompt it receives.
  defp scripted(replies) do
    Enum.each(replies, &send(self(), {:reply, &1}))

    fn request ->
      send(self(), {:prompt, request.prompt})

      receive do
        {:reply, reply} -> reply
      end
    end
  end

  # Without the fallback to AI.Demo, so the provider's own errors come back.
  defp generate(dispute, replies) do
    Evidence.generate_for_dispute(dispute.id,
      provider: TestProvider,
      reply: scripted(replies),
      fallback: false
    )
  end

  describe "Package.ai_changeset/3" do
    defp ai_changeset(dispute, answer) do
      facts = Transactions.reconstruct(dispute.transaction, dispute)

      %Package{dispute_id: dispute.id, ai_provider: "test"}
      |> Package.ai_changeset(answer, facts)
    end

    test "accepts a complete, grounded answer", %{dispute: dispute} do
      assert ai_changeset(dispute, valid_answer(dispute)).valid?
    end

    test "rejects missing sections, blank statements, and non-string facts",
         %{dispute: dispute} do
      answer = valid_answer(dispute)

      assert "can't be blank" in errors_on(
               ai_changeset(dispute, Map.delete(answer, "fulfillment_evidence"))
             ).fulfillment_evidence

      blank = put_in(answer, ["authorization_evidence", "statement"], " ")

      assert "can't be blank" in errors_on(ai_changeset(dispute, blank)).authorization_evidence.statement

      numbers = put_in(answer, ["transaction_evidence", "facts"], [1, 2])

      assert "is invalid" in errors_on(ai_changeset(dispute, numbers)).transaction_evidence.facts
    end

    test "rejects amounts that are not in the facts", %{dispute: dispute} do
      assert errors_on(ai_changeset(dispute, ungrounded_answer(dispute))).summary == [
               "mentions 249.99, not found in the case facts"
             ]
    end

    test "requires the transaction evidence to quote the PayPal order ID", %{dispute: dispute} do
      order_id = dispute.transaction.paypal_order_id

      assert errors_on(ai_changeset(dispute, incomplete_answer(dispute))).transaction_evidence.statement ==
               ["must include the PayPal order ID #{order_id}"]
    end

    test "accepts the order ID in a fact instead of the statement", %{dispute: dispute} do
      order_id = dispute.transaction.paypal_order_id

      answer =
        incomplete_answer(dispute)
        |> put_in(["transaction_evidence", "facts"], ["PayPal order #{order_id} was created."])

      assert ai_changeset(dispute, answer).valid?
    end
  end

  describe "generate_for_dispute/2" do
    test "saves a typed package and marks the dispute :evidence_ready", %{dispute: dispute} do
      assert {:ok, %Package{} = package} = Evidence.generate_for_dispute(dispute.id)

      assert package.ai_provider == "demo"

      assert %Section{statement: "The customer authorized ShopBot" <> _} =
               package.authorization_evidence

      assert Disputes.get_dispute!(dispute.id).status == :evidence_ready
      assert Evidence.get_package_by_dispute(dispute) == package
    end

    test "retries an ungrounded answer once, telling the model what was wrong",
         %{dispute: dispute} do
      assert {:ok, package} =
               generate(dispute, [{:ok, ungrounded_answer(dispute)}, {:ok, valid_answer(dispute)}])

      assert_received {:prompt, first_prompt}
      assert_received {:prompt, second_prompt}
      refute first_prompt =~ "rejected"
      assert second_prompt =~ "Your previous answer was rejected"
      assert second_prompt =~ "- summary mentions 249.99, not found in the case facts"
      assert package.ai_provider == "test"
    end

    test "gives up after a second invalid answer and saves nothing", %{dispute: dispute} do
      answer = {:ok, ungrounded_answer(dispute)}

      assert {:error, {:invalid_evidence, %Ecto.Changeset{}}} =
               generate(dispute, [answer, answer])

      assert Evidence.get_package_by_dispute(dispute) == nil
      assert Disputes.get_dispute!(dispute.id).status == :open
    end

    test "retries an incomplete answer, naming the missing order ID", %{dispute: dispute} do
      assert {:ok, _package} =
               generate(dispute, [{:ok, incomplete_answer(dispute)}, {:ok, valid_answer(dispute)}])

      assert_received {:prompt, _first}
      assert_received {:prompt, second_prompt}

      assert second_prompt =~
               "- transaction_evidence.statement must include the PayPal order ID " <>
                 dispute.transaction.paypal_order_id
    end

    test "retries an answer that was not JSON", %{dispute: dispute} do
      assert {:ok, _package} =
               generate(dispute, [{:error, :invalid_json}, {:ok, valid_answer(dispute)}])

      assert_received {:prompt, _first}
      assert_received {:prompt, second_prompt}
      assert second_prompt =~ "not a valid JSON object"
    end

    test "does not retry provider errors: retrying won't help", %{dispute: dispute} do
      assert generate(dispute, [
               {:error, {:transport, :econnrefused}},
               {:ok, valid_answer(dispute)}
             ]) ==
               {:error, {:transport, :econnrefused}}

      assert_received {:prompt, _only_call}
      refute_received {:prompt, _second_call}
    end

    test "never calls the AI inside a database transaction", %{dispute: dispute} do
      answer = valid_answer(dispute)

      check = fn _request ->
        send(self(), {:in_transaction, AgentProof.Repo.in_transaction?()})
        {:ok, answer}
      end

      assert {:ok, _} =
               Evidence.generate_for_dispute(dispute.id, provider: TestProvider, reply: check)

      assert_received {:in_transaction, false}
    end

    test "regenerating replaces the package in place", %{dispute: dispute} do
      {:ok, first} = Evidence.generate_for_dispute(dispute.id)

      updated = Map.put(valid_answer(dispute), "summary", "Regenerated after review.")
      {:ok, second} = generate(dispute, [{:ok, updated}])

      assert second.id == first.id
      assert second.summary == "Regenerated after review."
      assert Repo.aggregate(Package, :count) == 1
    end

    test "evidence is frozen once the dispute is submitted", %{dispute: dispute} do
      dispute |> Ecto.Changeset.change(status: :submitted) |> Repo.update!()

      assert Evidence.generate_for_dispute(dispute.id) == {:error, :already_submitted}
    end
  end

  describe "falling back to AI.Demo" do
    defp generate_with_fallback(dispute, reply) do
      Evidence.generate_for_dispute(dispute.id, provider: TestProvider, reply: reply)
    end

    test "an unreachable AI gets demo evidence, labelled demo-fallback", %{dispute: dispute} do
      log =
        capture_log(fn ->
          assert {:ok, %Package{ai_provider: "demo-fallback"} = package} =
                   generate_with_fallback(dispute, {:error, {:transport, :econnrefused}})

          assert Evidence.fallback?(package)
          assert package.ai_explanation =~ "No language model was used"
          assert Disputes.get_dispute!(dispute.id).status == :evidence_ready
        end)

      assert log =~ "AI investigation failed with test"
      assert log =~ "econnrefused"
    end

    test "so does an AI whose answers fail validation twice", %{dispute: dispute} do
      capture_log(fn ->
        assert {:ok, %Package{ai_provider: "demo-fallback"}} =
                 generate_with_fallback(dispute, {:ok, ungrounded_answer(dispute)})
      end)
    end

    test "evidence the real AI wrote is not a fallback", %{dispute: dispute} do
      {:ok, package} = generate_with_fallback(dispute, {:ok, valid_answer(dispute)})

      assert package.ai_provider == "test"
      refute Evidence.fallback?(package)
    end

    test "a submitted dispute is refused, not handed to the fallback", %{dispute: dispute} do
      dispute |> Ecto.Changeset.change(status: :submitted) |> Repo.update!()

      assert generate_with_fallback(dispute, {:error, {:transport, :econnrefused}}) ==
               {:error, :already_submitted}
    end
  end
end
