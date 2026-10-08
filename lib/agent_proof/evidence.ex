defmodule AgentProof.Evidence do
  @moduledoc """
  Evidence packages generated for disputes.
  """

  alias AgentProof.Repo
  alias AgentProof.Disputes.Dispute
  alias AgentProof.Evidence.Package

  def get_package_by_dispute(%Dispute{id: dispute_id}) do
    Repo.get_by(Package, dispute_id: dispute_id)
  end
end
