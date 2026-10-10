defmodule AgentProof.AI do
  @moduledoc """
  Entry point for AI calls. The provider comes from `opts[:provider]` or config.
  """

  alias AgentProof.AI.{EvidenceSchema, Prompt}
  alias AgentProof.Transactions

  # "details" gives the model somewhere to put adjectives, so "product" stays a plain noun.
  @search_query_schema %{
    "type" => "object",
    "properties" => %{
      "product" => %{
        "type" => "string",
        "description" => "The product noun only, singular, lowercase. No adjectives or features."
      },
      "details" => %{
        "type" => "array",
        "items" => %{"type" => "string"},
        "description" => "Everything else: features, adjectives, brands, budget, who it is for."
      }
    },
    "required" => ["product", "details"],
    "additionalProperties" => false
  }

  @doc """
  Asks the AI provider for evidence about a dispute. The answer is not validated yet.
  """
  def generate_evidence(transaction, dispute, opts \\ []) do
    facts = Transactions.reconstruct(transaction, dispute)

    generate(
      %{
        task: :evidence,
        system: Prompt.system(),
        prompt: Prompt.user(facts, opts[:feedback]),
        schema: EvidenceSchema.json_schema(),
        facts: facts
      },
      opts
    )
  end

  @doc """
  Asks the AI provider for a product search query that fits a shopping description.
  The answer is not validated yet.
  """
  def suggest_search_query(description, opts \\ []) do
    generate(
      %{
        task: :search_query,
        system: Prompt.search_system(),
        prompt: Prompt.search_user(description),
        schema: @search_query_schema,
        facts: %{"description" => description}
      },
      opts
    )
  end

  def search_query_schema, do: @search_query_schema

  def generate(request, opts \\ []), do: provider(opts).generate(request, opts)

  def provider_name(opts \\ []), do: provider(opts).name()

  def provider(opts \\ []) do
    Keyword.get_lazy(opts, :provider, fn ->
      Application.fetch_env!(:agent_proof, :ai_provider)
    end)
  end
end
