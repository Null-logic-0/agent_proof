defmodule AgentProof.AI.Provider do
  @moduledoc """
  The contract every AI provider implements (Demo, Ollama, OpenAI).

  A request carries the same case twice: as prompt text for language models,
  and as structured `facts` for `AgentProof.AI.Demo`. Providers return the
  decoded JSON unvalidated; validation happens in one place for all of them.

  ## Facts (input)

      %{
        "agent_name" => "ShopBot",
        "authorization" => %{
          "max_amount" => "200.00", "currency" => "USD",
          "description" => "Headphones up to $200", "authorized_at" => "2026-10-08T12:00:00Z"
        },
        "transaction" => %{
          "product_name" => "Sony WH-1000XM5 Headphones", "amount" => "189.99",
          "currency" => "USD", "paypal_order_id" => "6CF36743HA4658629",
          "capture_simulated" => true, "purchased_at" => "2026-10-08T12:00:05Z"
        },
        "fulfillment" => %{
          "carrier" => "UPS", "tracking_number" => "1Z999AA10123456784",
          "delivered_at" => "2026-10-10T14:00:00Z"
        },
        "dispute" => %{
          "reason" => "unauthorized", "opened_at" => "2026-10-12T09:00:00Z",
          "due_date" => "2026-10-22"
        },
        "checks" => %{
          "within_budget" => true, "currency_matches" => true,
          "system_budget_check_logged" => true, "delivered_before_dispute" => true
        },
        "agent_actions" => [
          %{"action" => "search_products", "actor" => "agent", "at" => "2026-10-08T12:00:01Z"}
        ]
      }

  `"fulfillment"` is `nil` when nothing was delivered. `"checks"` are computed
  by AgentProof, never by a model.

  ## Evidence (output)

      %{
        "summary" => "...",
        "authorization_evidence" => %{"statement" => "...", "facts" => ["..."]},
        "transaction_evidence" => %{"statement" => "...", "facts" => ["..."]},
        "fulfillment_evidence" => %{"statement" => "...", "facts" => ["..."]},
        "ai_explanation" => "..."
      }
  """

  @type request :: %{system: String.t(), prompt: String.t(), schema: map(), facts: map()}

  @doc "Generates evidence for `request`. Returns the decoded JSON, unvalidated."
  @callback generate(request(), opts :: keyword()) :: {:ok, map()} | {:error, term()}

  @doc ~s(Label stored in `evidence.ai_provider`, e.g. "demo" or "ollama:llama3.2".)
  @callback name() :: String.t()
end
