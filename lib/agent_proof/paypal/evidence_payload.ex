defmodule AgentProof.PayPal.EvidencePayload do
  @moduledoc """
  Turns an evidence package into the body of PayPal's provide-evidence request.
  """

  # PayPal's docs state no limit for notes; this is a conservative cap.
  @max_notes 2000

  alias AgentProof.Evidence.{Package, Section}
  alias AgentProof.Transactions.Transaction

  def build(%Package{} = package, %Transaction{} = transaction) do
    %{"evidences" => fulfillment_evidence(package, transaction) ++ [agent_evidence(package)]}
  end

  def max_notes, do: @max_notes

  defp fulfillment_evidence(_package, %Transaction{fulfillment: nil}), do: []

  defp fulfillment_evidence(package, %Transaction{fulfillment: fulfillment}) do
    [
      %{
        "evidence_type" => "PROOF_OF_FULFILLMENT",
        "evidence_info" => %{
          "tracking_info" => [
            %{
              "carrier_name" => fulfillment.carrier,
              "tracking_number" => fulfillment.tracking_number
            }
          ]
        },
        "notes" => notes([section("Fulfillment", package.fulfillment_evidence)])
      }
    ]
  end

  # PayPal has no evidence type for an agent's authorization, so it goes in the notes.
  defp agent_evidence(package) do
    %{
      "evidence_type" => "OTHER",
      "notes" =>
        notes([
          package.summary,
          section("Authorization", package.authorization_evidence),
          section("Transaction", package.transaction_evidence)
        ])
    }
  end

  defp section(label, %Section{statement: statement, facts: facts}) do
    Enum.join(["#{label}: #{statement}" | Enum.map(facts, &"- #{&1}")], "\n")
  end

  defp notes(parts) do
    text = Enum.join(parts, "\n\n")

    if String.length(text) > @max_notes,
      do: String.slice(text, 0, @max_notes - 1) <> "…",
      else: text
  end
end
