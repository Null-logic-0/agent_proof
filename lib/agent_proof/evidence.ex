defmodule AgentProof.Evidence do
  @moduledoc """
  Evidence packages generated for disputes.
  """

  require Logger

  alias AgentProof.{AI, Disputes, PayPal, Repo, Transactions}
  alias AgentProof.Disputes.Dispute
  alias AgentProof.PayPal.EvidencePayload
  alias AgentProof.Evidence.Package

  @attempts 2

  @fallback_provider "demo-fallback"

  def get_package_by_dispute(%Dispute{id: dispute_id}) do
    Repo.get_by(Package, dispute_id: dispute_id)
  end

  @doc """
  Asks the AI for evidence, validates it, and saves it. The AI is never called inside a
  database transaction. If the AI fails, AI.Demo writes the evidence (`fallback: false`
  returns the error instead).
  """
  def generate_for_dispute(dispute_id, opts \\ []) do
    dispute = Disputes.get_case!(dispute_id)

    with :ok <- ensure_not_submitted(dispute),
         facts = Transactions.reconstruct(dispute.transaction, dispute),
         {:ok, changeset} <- investigate(dispute, facts, opts) do
      save(changeset, dispute)
    end
  end

  @doc """
  Whether AI.Demo wrote this evidence because the real AI failed.
  """
  def fallback?(%Package{ai_provider: ai_provider}), do: ai_provider == @fallback_provider

  @doc """
  Approves the evidence so it can be submitted. Refused once the dispute is submitted.
  """
  def approve(%Package{} = package) do
    package = Repo.preload(package, :dispute)

    with :ok <- ensure_not_submitted(package.dispute) do
      package
      |> Ecto.Changeset.change(approved_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update()
    end
  end

  def withdraw_approval(%Package{} = package) do
    package = Repo.preload(package, :dispute)

    with :ok <- ensure_not_submitted(package.dispute) do
      package |> Ecto.Changeset.change(approved_at: nil) |> Repo.update()
    end
  end

  @doc """
  Returns exactly what `submit/2` would send to PayPal.
  """
  def prepare_submission(%Package{} = package) do
    package = Repo.preload(package, dispute: :transaction)
    dispute = package.dispute

    %{
      dispute_id: dispute.paypal_dispute_id,
      payload: EvidencePayload.build(package, dispute.transaction),
      simulated?: Dispute.simulated?(dispute)
    }
  end

  @doc """
  Sends approved evidence to PayPal and marks the dispute submitted. On failure it stays
  approved.
  """
  def submit(%Package{} = package, opts \\ []) do
    package = Repo.preload(package, dispute: :transaction)

    with :ok <- ensure_not_submitted(package.dispute),
         :ok <- ensure_approved(package) do
      submission = prepare_submission(package)

      # PayPal doesn't know simulated disputes, so they always go to PayPal.Demo.
      opts =
        if submission.simulated?,
          do: Keyword.put_new(opts, :adapter, PayPal.Demo),
          else: opts

      with {:ok, %{simulated: simulated?}} <-
             PayPal.submit_evidence(submission.dispute_id, submission.payload, opts),
           {:ok, dispute} <- Disputes.mark_submitted(package.dispute) do
        {:ok, %{dispute: dispute, simulated?: simulated?}}
      end
    end
  end

  defp ensure_approved(%Package{approved_at: nil}), do: {:error, :not_approved}
  defp ensure_approved(%Package{}), do: :ok

  defp ensure_not_submitted(%Dispute{status: :submitted}), do: {:error, :already_submitted}
  defp ensure_not_submitted(%Dispute{}), do: :ok

  defp investigate(dispute, facts, opts) do
    case attempt(dispute, facts, opts, nil, @attempts) do
      {:error, reason} = error ->
        if fallback_allowed?(opts), do: fall_back(dispute, facts, opts, reason), else: error

      ok ->
        ok
    end
  end

  # Labelled "demo-fallback". If even AI.Demo fails, the original error is returned.
  defp fall_back(dispute, facts, opts, reason) do
    Logger.warning(
      "AI investigation failed with #{AI.provider_name(opts)}, writing the evidence " <>
        "with AI.Demo: #{inspect(reason, limit: 10)}"
    )

    case attempt(dispute, facts, Keyword.put(opts, :provider, AI.Demo), nil, 1) do
      {:ok, changeset} ->
        {:ok, Ecto.Changeset.put_change(changeset, :ai_provider, @fallback_provider)}

      {:error, _demo_reason} ->
        {:error, reason}
    end
  end

  defp fallback_allowed?(opts),
    do: Keyword.get(opts, :fallback, true) and AI.provider(opts) != AI.Demo

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

  # Turns changeset errors into lines the model can act on.
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
               # A regenerated package is new: fresh inserted_at, approval cleared.
               on_conflict: {:replace_all_except, [:id, :dispute_id]},
               conflict_target: :dispute_id,
               returning: true
             ),
           {:ok, _dispute} <- Disputes.mark_evidence_ready(dispute) do
        {:ok, package}
      end
    end)
  end
end
