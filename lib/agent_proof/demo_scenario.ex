defmodule AgentProof.DemoScenario do
  @moduledoc """
  The one-click demo story, built through the same contexts as the real flow:

    1. a customer authorizes DemoBot to spend up to $200 on headphones
    2. the agent searches the catalog and buys a pair
    3. PayPal records the order (a `DEMO-ORDER-` id with the Demo adapter)
    4. the carrier delivers it
    5. the customer disputes the charge as unauthorized
    6. the facts are reconstructed and
    7. the AI writes the evidence package

  Approving and submitting the evidence are left to the merchant. `opts` go
  to the purchase and the investigation, so with
  `[adapter: PayPal.Demo, provider: AI.Demo]` nothing external is called.
  No database transaction wraps the story: the AI is never called inside one.
  """

  alias AgentProof.{Authorizations, Disputes, Evidence, Transactions}
  alias AgentProof.Agents.ShoppingAgent

  @grant %{
    "agent_name" => "DemoBot",
    "max_amount" => "200",
    "description" => "Buy noise-cancelling headphones, up to $200"
  }

  @doc """
  Runs the story and returns the disputed transaction, with its evidence
  ready for review. Takes about two seconds: see `next_second/0`.
  """
  def run(opts \\ []) do
    with {:ok, authorization} <- Authorizations.grant(@grant),
         {:ok, transaction} <- ShoppingAgent.run(authorization, "headphones", opts),
         :ok <- next_second(),
         {:ok, transaction} <- Transactions.record_fulfillment(transaction, delivery(transaction)),
         :ok <- next_second(),
         {:ok, dispute} <- Disputes.open_dispute(transaction, %{reason: :unauthorized}),
         {:ok, _evidence} <- Evidence.generate_for_dispute(dispute.id, opts) do
      {:ok, transaction}
    end
  end

  # The same simulated UPS delivery as the case page's "Mark as delivered".
  defp delivery(transaction) do
    %{
      carrier: "UPS",
      tracking_number: "1ZDEMO" <> String.pad_leading(to_string(transaction.id), 10, "0"),
      delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  # Timestamps are stored to the second. Starting the delivery and the dispute
  # each in a new second keeps the timeline in order and makes "delivered
  # before the dispute" true, as it is when these happen days apart.
  defp next_second do
    Process.sleep(1000 - rem(System.system_time(:millisecond), 1000))
  end
end
