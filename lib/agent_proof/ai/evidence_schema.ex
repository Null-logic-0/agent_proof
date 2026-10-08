defmodule AgentProof.AI.EvidenceSchema do
  @moduledoc """
  JSON Schema for the evidence package a model must return.

  Written for OpenAI's strict Structured Outputs (every property required,
  `additionalProperties: false` on every object); Ollama accepts it as is.
  Models read the `description`s, so they are part of the prompt.
  """

  def json_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => [
        "summary",
        "authorization_evidence",
        "transaction_evidence",
        "fulfillment_evidence",
        "ai_explanation"
      ],
      "properties" => %{
        "summary" => %{
          "type" => "string",
          "description" =>
            "2-3 sentences for the merchant: what happened and whether the purchase was authorized."
        },
        "authorization_evidence" =>
          section(
            "What the customer authorized the agent to do, and the merchant's budget check."
          ),
        "transaction_evidence" =>
          section(
            "The PayPal order and the agent's recorded actions, in order. Include the PayPal order ID."
          ),
        "fulfillment_evidence" =>
          section("Whether and when the order was delivered. Say so if there is no record."),
        "ai_explanation" => %{
          "type" => "string",
          "description" => "1-2 sentences on how these conclusions follow from the facts."
        }
      }
    }
  end

  defp section(description) do
    %{
      "type" => "object",
      "description" => description,
      "additionalProperties" => false,
      "required" => ["statement", "facts"],
      "properties" => %{
        "statement" => %{"type" => "string", "description" => "1-2 sentences."},
        "facts" => %{
          "type" => "array",
          "description" => "Short sentences, each traceable to the case facts.",
          "items" => %{"type" => "string"}
        }
      }
    }
  end
end
