defmodule AgentProof.Disputes do
  @moduledoc """
  Customer disputes against agent transactions.
  """

  alias AgentProof.Repo
  alias AgentProof.Disputes.Dispute

  def get_dispute!(id), do: Repo.get!(Dispute, id)
end
