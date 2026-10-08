defmodule AgentProof.AI do
  @moduledoc """
  The AI boundary. Business logic calls these functions, never a provider
  directly.

  The provider is chosen per call: `opts[:provider]`, otherwise
  `config :agent_proof, :ai_provider`. The remaining `opts` are passed
  through to the provider.
  """

  alias AgentProof.AI.{EvidenceSchema, Prompt}
  alias AgentProof.Transactions

  @doc """
  Generates an evidence package for a disputed transaction.

  `transaction` must have `authorization: :agent` preloaded, as returned
  inside `AgentProof.Disputes.get_case!/1`. Returns the provider's raw,
  unvalidated evidence map.
  """
  def generate_evidence(transaction, dispute, opts \\ []) do
    facts = Transactions.reconstruct(transaction, dispute)

    generate(
      %{
        system: Prompt.system(),
        prompt: Prompt.user(facts),
        schema: EvidenceSchema.json_schema(),
        facts: facts
      },
      opts
    )
  end

  def generate(request, opts \\ []), do: provider(opts).generate(request, opts)

  def provider_name(opts \\ []), do: provider(opts).name()

  defp provider(opts) do
    Keyword.get_lazy(opts, :provider, fn ->
      Application.fetch_env!(:agent_proof, :ai_provider)
    end)
  end
end
