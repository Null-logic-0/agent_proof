defmodule AgentProof.AI do
  @moduledoc """
  Entry point for AI calls. The provider comes from `opts[:provider]` or config.
  """

  alias AgentProof.AI.{EvidenceSchema, Prompt}
  alias AgentProof.Transactions

  @doc """
  Asks the AI provider for evidence about a dispute. The answer is not validated yet.
  """
  def generate_evidence(transaction, dispute, opts \\ []) do
    facts = Transactions.reconstruct(transaction, dispute)

    generate(
      %{
        system: Prompt.system(),
        prompt: Prompt.user(facts, opts[:feedback]),
        schema: EvidenceSchema.json_schema(),
        facts: facts
      },
      opts
    )
  end

  def generate(request, opts \\ []), do: provider(opts).generate(request, opts)

  def provider_name(opts \\ []), do: provider(opts).name()

  def provider(opts \\ []) do
    Keyword.get_lazy(opts, :provider, fn ->
      Application.fetch_env!(:agent_proof, :ai_provider)
    end)
  end
end
