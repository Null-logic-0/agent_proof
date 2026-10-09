defmodule AgentProof.Transactions.Timeline do
  @moduledoc """
  Turns a transaction's stored records into display events, oldest first.

  Pure: it works on a transaction preloaded with `authorization: :agent` and
  `dispute: :evidence` (see `AgentProof.Transactions.get_case!/1`). It reads
  the same records the AI evidence is built from, so the page never shows a
  fact the evidence lacks.

  Each event is a map:

      %{id: "authorization", at: ~U[...], actor: :customer, title: "...",
        details: "..." | nil, status: :ok | :warning | :error, simulated?: false}

  Actors: `:customer`, `:agent`, `:system` (AgentProof itself), `:paypal`,
  `:carrier`, `:ai`.
  """

  alias AgentProof.Agents.Agent
  alias AgentProof.Authorizations.Authorization
  alias AgentProof.Transactions.Transaction

  def build(%Transaction{authorization: %Authorization{agent: %Agent{}}} = transaction) do
    ([authorization_event(transaction)] ++
       Enum.map(transaction.agent_actions, &action_event/1) ++
       fulfillment_events(transaction) ++
       dispute_events(transaction))
    # Stable sort: events in the same instant keep their logical order.
    |> Enum.sort_by(& &1.at, DateTime)
  end

  # Uses the terms recorded when the purchase was checked, like the evidence
  # does, so a later edit of the authorization never rewrites history.
  defp authorization_event(%Transaction{authorization: authorization} = transaction) do
    terms =
      case Enum.find(transaction.agent_actions, &(&1.action == :budget_check)) do
        %{details: details} -> details
        nil -> %{}
      end

    max_amount = terms["max_amount"] || money(authorization.max_amount)
    description = terms["description"] || authorization.description

    event("authorization", authorization.inserted_at, :customer,
      title: "Customer authorized #{authorization.agent.name}",
      details: ~s(Up to #{max_amount} #{authorization.currency}: "#{description}")
    )
  end

  defp action_event(%{action: :search_products, details: d} = action) do
    event("action-#{action.id}", action.at, :agent,
      title: "Searched the catalog",
      details: ~s("#{d["query"]}" · #{pluralize(d["results"], "result")})
    )
  end

  defp action_event(%{action: :select_product, details: d} = action) do
    event("action-#{action.id}", action.at, :agent,
      title: "Selected #{d["product"]}",
      details: d["price"] && "#{d["price"]} USD"
    )
  end

  defp action_event(%{action: :budget_check, details: d} = action) do
    event("action-#{action.id}", action.at, :system,
      title: "Budget check approved by AgentProof",
      details: "Spent #{d["spent"]} + #{d["amount"]} ≤ #{d["max_amount"]} #{d["currency"]}"
    )
  end

  defp action_event(%{action: :create_paypal_order, details: d} = action) do
    event("action-#{action.id}", action.at, :paypal,
      title: "PayPal order created",
      details: d["order_id"]
    )
  end

  defp action_event(%{action: :capture_payment, details: d} = action) do
    event("action-#{action.id}", action.at, :paypal,
      title: "Payment captured",
      details: d["capture_id"],
      simulated?: d["simulated"] == true
    )
  end

  defp action_event(%{action: :payment_failed, details: d} = action) do
    event("action-#{action.id}", action.at, :paypal,
      title: "Payment failed",
      details: d["step"] && "At #{String.replace(d["step"], "_", " ")}",
      status: :error
    )
  end

  defp action_event(action) do
    event("action-#{action.id}", action.at, action.actor,
      title: action.action |> to_string() |> String.replace("_", " ") |> String.capitalize()
    )
  end

  # In the MVP, deliveries are entered with the case page's simulated carrier.
  defp fulfillment_events(%Transaction{fulfillment: nil}), do: []

  defp fulfillment_events(%Transaction{fulfillment: fulfillment}) do
    [
      event("fulfillment", fulfillment.delivered_at, :carrier,
        title: "Delivered by #{fulfillment.carrier}",
        details: "Tracking #{fulfillment.tracking_number}",
        simulated?: true
      )
    ]
  end

  defp dispute_events(%Transaction{dispute: nil}), do: []

  defp dispute_events(%Transaction{dispute: dispute}) do
    opened =
      event("dispute", dispute.inserted_at, :customer,
        title: "Customer opened a dispute",
        details:
          "Reason: #{String.replace(to_string(dispute.reason), "_", " ")}" <>
            if(dispute.due_date,
              do: " · respond by #{Calendar.strftime(dispute.due_date, "%b %-d")}",
              else: ""
            ),
        status: :warning,
        simulated?: true
      )

    [opened | evidence_events(dispute.evidence)]
  end

  defp evidence_events(nil), do: []

  defp evidence_events(evidence) do
    [
      event("evidence", evidence.updated_at, :ai,
        title: "AI reconstructed the transaction and wrote the evidence",
        details: "Validated and saved · #{evidence.ai_provider}"
      )
    ]
  end

  defp event(id, at, actor, fields) do
    Map.merge(
      %{id: id, at: at, actor: actor, details: nil, status: :ok, simulated?: false},
      Map.new(fields)
    )
  end

  defp pluralize(1, word), do: "1 #{word}"
  defp pluralize(count, word), do: "#{count} #{word}s"

  defp money(%Decimal{} = amount), do: amount |> Decimal.round(2) |> Decimal.to_string()
end
