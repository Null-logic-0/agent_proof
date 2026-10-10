defmodule AgentProof.Fixtures do
  @moduledoc """
  Builds valid records for tests.
  """

  alias AgentProof.{Agents, Authorizations, Disputes, Repo, Transactions}
  alias AgentProof.Agents.ShoppingAgent
  alias AgentProof.Transactions.Transaction
  alias AgentProof.Disputes.Dispute
  alias AgentProof.Evidence.Package

  def agent_fixture(attrs \\ %{}) do
    {:ok, agent} =
      attrs
      |> Enum.into(%{name: "ShopBot"})
      |> Agents.create_agent()

    agent
  end

  def authorization_fixture(agent, attrs \\ %{}) do
    {:ok, authorization} =
      Authorizations.create_authorization(
        agent,
        Enum.into(attrs, %{
          max_amount: "200.00",
          currency: "USD",
          description: "Buy noise-cancelling headphones, up to $200"
        })
      )

    authorization
  end

  def transaction_fixture(authorization, attrs \\ %{}) do
    %Transaction{authorization_id: authorization.id}
    |> Transaction.changeset(
      Enum.into(attrs, %{
        paypal_order_id: "TEST-ORDER-#{System.unique_integer([:positive])}",
        amount: "189.99",
        currency: "USD",
        product_name: "Sony WH-1000XM5 Headphones",
        status: :completed
      })
    )
    |> Repo.insert!()
  end

  def dispute_fixture(transaction, attrs \\ %{}) do
    %Dispute{transaction_id: transaction.id}
    |> Dispute.changeset(
      Enum.into(attrs, %{
        paypal_dispute_id: "TEST-PP-D-#{System.unique_integer([:positive])}",
        reason: :unauthorized,
        status: :open,
        due_date: ~D[2026-10-18]
      })
    )
    |> Repo.insert!()
  end

  @doc """
  A delivered, then disputed headphone purchase. Options: `:reason` and `:delivered_at`.
  """
  def disputed_case_fixture(opts \\ []) do
    authorization = authorization_fixture(agent_fixture())
    {:ok, transaction} = ShoppingAgent.run(authorization, "headphones")

    default_delivery = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

    transaction =
      case Keyword.get(opts, :delivered_at, default_delivery) do
        nil ->
          transaction

        delivered_at ->
          {:ok, transaction} =
            Transactions.record_fulfillment(transaction, %{
              carrier: "UPS",
              tracking_number: "1Z999AA10123456784",
              delivered_at: delivered_at
            })

          transaction
      end

    {:ok, dispute} =
      Disputes.open_dispute(transaction, %{reason: Keyword.get(opts, :reason, :unauthorized)})

    Disputes.get_case!(dispute.id)
  end

  def evidence_fixture(dispute, attrs \\ %{}) do
    %Package{dispute_id: dispute.id}
    |> Package.changeset(Enum.into(attrs, valid_evidence_attrs()))
    |> Repo.insert!()
  end

  def valid_evidence_attrs do
    %{
      summary: "The purchase was within the agent's authorization.",
      authorization_evidence: %{"statement" => "Authorized up to $200.00", "facts" => []},
      transaction_evidence: %{"statement" => "Charged $189.99", "facts" => []},
      fulfillment_evidence: %{"statement" => "Delivered before dispute", "facts" => []},
      ai_explanation: "Amount and product match the authorization.",
      ai_provider: "demo"
    }
  end
end
