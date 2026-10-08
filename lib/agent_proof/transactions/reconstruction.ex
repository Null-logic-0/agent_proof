defmodule AgentProof.Transactions.Reconstruction do
  @moduledoc """
  Rebuilds a disputed transaction as plain, JSON-friendly facts.

  Pure: it works only on preloaded structs, with no database and no AI. The
  `"checks"` are computed here, by code, so no model ever decides them. The
  output shape is documented in `AgentProof.AI.Provider`.
  """

  alias AgentProof.Agents.Agent
  alias AgentProof.Authorizations.Authorization
  alias AgentProof.Disputes.Dispute
  alias AgentProof.Transactions.{Fulfillment, Transaction}

  def facts(
        %Transaction{authorization: %Authorization{agent: %Agent{} = agent} = authorization} =
          transaction,
        %Dispute{} = dispute
      ) do
    budget_check = find_action(transaction, :budget_check)
    capture = find_action(transaction, :capture_payment)

    %{
      "agent_name" => agent.name,
      "authorization" => %{
        "max_amount" => money(authorization.max_amount),
        "currency" => authorization.currency,
        "description" => authorization.description,
        "authorized_at" => DateTime.to_iso8601(authorization.inserted_at)
      },
      "transaction" => %{
        "product_name" => transaction.product_name,
        "amount" => money(transaction.amount),
        "currency" => transaction.currency,
        "status" => to_string(transaction.status),
        "paypal_order_id" => transaction.paypal_order_id,
        # nil when no capture was recorded: unknown, not "real".
        "capture_simulated" => capture && capture.details["simulated"] == true,
        "purchased_at" => DateTime.to_iso8601(transaction.inserted_at)
      },
      "fulfillment" => fulfillment(transaction.fulfillment),
      "dispute" => %{
        "reason" => to_string(dispute.reason),
        "opened_at" => DateTime.to_iso8601(dispute.inserted_at),
        "due_date" => dispute.due_date && Date.to_iso8601(dispute.due_date)
      },
      "checks" => %{
        "within_budget" => within_budget?(budget_check, transaction, authorization),
        "system_budget_check_logged" => budget_check != nil,
        "currency_matches" => transaction.currency == authorization.currency,
        "authorized_before_purchase" =>
          DateTime.compare(authorization.inserted_at, transaction.inserted_at) != :gt,
        "delivered_before_dispute" => delivered_before?(transaction.fulfillment, dispute)
      },
      "agent_actions" => Enum.map(transaction.agent_actions, &action/1)
    }
  end

  defp find_action(transaction, name),
    do: Enum.find(transaction.agent_actions, &(&1.action == name))

  # The verdict recorded at purchase time reflects the cumulative budget at that
  # moment. Without it, fall back to comparing this purchase alone.
  defp within_budget?(%{details: details}, _transaction, _authorization),
    do: details["result"] == "approved"

  defp within_budget?(nil, transaction, authorization),
    do: Decimal.compare(transaction.amount, authorization.max_amount) != :gt

  defp delivered_before?(nil, _dispute), do: nil

  defp delivered_before?(%Fulfillment{delivered_at: delivered_at}, dispute),
    do: DateTime.compare(delivered_at, dispute.inserted_at) == :lt

  defp fulfillment(nil), do: nil

  defp fulfillment(%Fulfillment{} = fulfillment) do
    %{
      "carrier" => fulfillment.carrier,
      "tracking_number" => fulfillment.tracking_number,
      "delivered_at" => DateTime.to_iso8601(fulfillment.delivered_at)
    }
  end

  defp action(action) do
    %{
      "action" => to_string(action.action),
      "actor" => to_string(action.actor),
      "at" => DateTime.to_iso8601(action.at),
      "details" => action.details
    }
  end

  defp money(%Decimal{} = amount), do: amount |> Decimal.round(2) |> Decimal.to_string()
end
