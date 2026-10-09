defmodule AgentProof.Disputes do
  @moduledoc """
  Customer disputes against agent transactions.
  """

  alias AgentProof.Repo
  alias AgentProof.Disputes.Dispute
  alias AgentProof.Transactions.Transaction

  # Simulated seller response window.
  @response_window_days 10

  def get_dispute!(id), do: Repo.get!(Dispute, id)

  @doc """
  Opens a customer dispute against a paid transaction.

  Disputes are simulated: merchants cannot create PayPal disputes through the
  API, so the PayPal dispute id is a recognizable `DEMO-PP-D-` id. Only
  `reason` is taken from `attrs`.

  Options:

    * `:today` - the date the dispute opens (defaults to today, UTC)
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
  Marks a dispute as submitted to PayPal. Final: nothing changes a submitted
  dispute or its evidence afterwards.
  """
  def mark_submitted(%Dispute{} = dispute) do
    dispute
    |> Ecto.Changeset.change(
      status: :submitted,
      submitted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.update()
  end

  @doc """
  Marks a dispute as having a validated evidence package.
  """
  def mark_evidence_ready(%Dispute{} = dispute) do
    dispute
    |> Ecto.Changeset.change(status: :evidence_ready)
    |> Repo.update()
  end

  @doc """
  Loads a dispute with everything an investigation needs: its transaction,
  the authorization, the agent, and the evidence package (if any).
  """
  def get_case!(id) do
    Dispute
    |> Repo.get!(id)
    |> Repo.preload([:evidence, transaction: [authorization: :agent]])
  end
end
