defmodule AgentProof.AI.Prompt do
  @moduledoc """
  Prompts for evidence generation. The facts carry the case; the system
  prompt carries the rules.
  """

  @system """
  You are a payment-dispute analyst helping a merchant respond to a PayPal dispute about a purchase made by an AI agent.

  Rules:
  1. Use only the facts provided. Never invent names, dates, amounts, order IDs, tracking numbers, or events.
  2. The "checks" were computed by the merchant's system and are authoritative. Do not recompute or contradict them.
  3. If information is missing (for example, no fulfillment record), say so plainly instead of guessing.
  4. Do not overstate. If the payment capture was simulated, say so.
  5. Be neutral and factual. Statements are 1-2 sentences; each fact is one short sentence traceable to the input.
  """

  def system, do: @system

  def user(%{"dispute" => %{"reason" => reason}} = facts) do
    """
    The customer opened a PayPal dispute with reason "#{reason}". #{guidance(reason)}

    Case facts (JSON):
    #{Jason.encode!(facts, pretty: true)}

    Write the evidence package.
    """
  end

  defp guidance("unauthorized"),
    do:
      "Focus on what the customer authorized the agent to do and on the merchant's budget check."

  defp guidance("not_received"),
    do: "Focus on fulfillment: whether and when the order was delivered."

  defp guidance("not_as_described"),
    do: "Focus on what the agent selected and what was actually purchased."

  defp guidance(_other), do: "Cover authorization, payment, and fulfillment evenly."
end
