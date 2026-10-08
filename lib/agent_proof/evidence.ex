defmodule AgentProof.Evidence do
  @moduledoc """
  Evidence packages generated for disputes.
  """

  alias AgentProof.{AI, Disputes, Repo, Transactions}
  alias AgentProof.Disputes.Dispute
  alias AgentProof.Evidence.Package

  @attempts 2

  def get_package_by_dispute(%Dispute{id: dispute_id}) do
    Repo.get_by(Package, dispute_id: dispute_id)
  end

  @doc """
  Investigates a dispute with the AI and saves a validated evidence package.

    1. The AI is called outside any database transaction: it can take seconds,
       and a transaction would hold a database connection the whole time.
    2. The answer is validated for shape and grounding. An invalid answer is
       retried once, with the problems fed back to the model. Provider errors
       (unreachable, refusal, quota) are returned at once: retrying won't help.
    3. The package and the dispute's `:evidence_ready` status are saved
       atomically.

  Regenerating replaces the package until the dispute is submitted. `opts`
  are passed to `AgentProof.AI` (e.g. `:provider`).
  """
  def generate_for_dispute(dispute_id, opts \\ []) do
    dispute = Disputes.get_case!(dispute_id)

    with :ok <- ensure_not_submitted(dispute),
         facts = Transactions.reconstruct(dispute.transaction, dispute),
         {:ok, changeset} <- attempt(dispute, facts, opts, nil, @attempts) do
      save(changeset, dispute)
    end
  end

  defp ensure_not_submitted(%Dispute{status: :submitted}), do: {:error, :already_submitted}
  defp ensure_not_submitted(%Dispute{}), do: :ok

  defp attempt(dispute, facts, opts, feedback, attempts_left) do
    ai_opts = if feedback, do: Keyword.put(opts, :feedback, feedback), else: opts

    case AI.generate_evidence(dispute.transaction, dispute, ai_opts) do
      {:ok, raw} ->
        changeset =
          %Package{dispute_id: dispute.id, ai_provider: AI.provider_name(opts)}
          |> Package.ai_changeset(raw, facts)

        if changeset.valid? do
          {:ok, changeset}
        else
          retry(
            dispute,
            facts,
            opts,
            feedback_for(changeset),
            attempts_left,
            {:invalid_evidence, changeset}
          )
        end

      {:error, :invalid_json} ->
        retry(
          dispute,
          facts,
          opts,
          "- the answer was not a valid JSON object",
          attempts_left,
          :invalid_json
        )

      {:error, _reason} = error ->
        error
    end
  end

  defp retry(_dispute, _facts, _opts, _feedback, 1, error), do: {:error, error}

  defp retry(dispute, facts, opts, feedback, attempts_left, _error) do
    attempt(dispute, facts, opts, feedback, attempts_left - 1)
  end

  # Turns changeset errors into lines the model can act on, e.g.
  # "- authorization_evidence.statement mentions 249.99, not found in the case facts"
  defp feedback_for(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> flatten_errors(nil)
    |> Enum.map_join("\n", &"- #{&1}")
  end

  defp flatten_errors(errors, prefix) do
    Enum.flat_map(errors, fn
      {field, %{} = nested} -> flatten_errors(nested, path(prefix, field))
      {field, messages} -> Enum.map(messages, &"#{path(prefix, field)} #{&1}")
    end)
  end

  defp path(nil, field), do: to_string(field)
  defp path(prefix, field), do: "#{prefix}.#{field}"

  defp save(changeset, dispute) do
    Repo.transact(fn ->
      with {:ok, package} <-
             Repo.insert(changeset,
               on_conflict: {:replace_all_except, [:id, :dispute_id, :inserted_at]},
               conflict_target: :dispute_id,
               returning: true
             ),
           {:ok, _dispute} <- Disputes.mark_evidence_ready(dispute) do
        {:ok, package}
      end
    end)
  end
end
