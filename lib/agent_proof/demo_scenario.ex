defmodule AgentProof.DemoScenario do
  @moduledoc """
  Builds a complete disputed case in one call, through the same contexts as the real flow.
  """

  alias AgentProof.{Authorizations, Disputes, Evidence, Transactions}
  alias AgentProof.Agents.ShoppingAgent

  @grant %{
    "agent_name" => "DemoBot",
    "max_amount" => "200",
    "description" => "Buy noise-cancelling headphones, up to $200"
  }

  @doc """
  Returns the disputed transaction, with its evidence ready for review.
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

  defp delivery(transaction) do
    %{
      carrier: "UPS",
      tracking_number: "1ZDEMO" <> String.pad_leading(to_string(transaction.id), 10, "0"),
      delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  # Timestamps are stored to the second. Waiting for a new second keeps the timeline in
  # order and makes "delivered before the dispute" true.
  defp next_second do
    Process.sleep(1000 - rem(System.system_time(:millisecond), 1000))
  end
end
