defmodule AgentProof.Disputes do
  @moduledoc """
  Customer disputes against agent transactions.
  """

  alias AgentProof.Repo
  alias AgentProof.Disputes.Dispute
  alias AgentProof.Transactions.Transaction

  @response_window_days 10

  def get_dispute!(id), do: Repo.get!(Dispute, id)

  @doc """
  Opens a simulated dispute on a paid transaction. Only `reason` is read from `attrs`.
  """
  def open_dispute(transaction, attrs, opts \\ [])

  def open_dispute(%Transaction{status: :completed} = transaction, attrs, opts) do
    today = Keyword.get_lazy(opts, :today, &Date.utc_today/0)

    %Dispute{
      transaction_id: transaction.id,
      paypal_dispute_id: "DEMO-PP-D-#{transaction.id}",
      status: :open,
      due_date: Date.add(today, @response_window_days)
    }
    |> Dispute.open_changeset(attrs)
    |> Repo.insert()
  end

  def open_dispute(%Transaction{}, _attrs, _opts), do: {:error, :not_disputable}

  @doc """
  Marks the dispute as submitted. This is final.
  """
  def mark_submitted(%Dispute{} = dispute) do
    dispute
    |> Ecto.Changeset.change(
      status: :submitted,
      submitted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.update()
  end

  def mark_evidence_ready(%Dispute{} = dispute) do
    dispute
    |> Ecto.Changeset.change(status: :evidence_ready)
    |> Repo.update()
  end

  @doc """
  Loads a dispute with its transaction, agent, and evidence.
  """
  def get_case!(id) do
    Dispute
    |> Repo.get!(id)
    |> Repo.preload([:evidence, transaction: [authorization: :agent]])
  end
end
