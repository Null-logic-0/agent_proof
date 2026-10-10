defmodule AgentProof.FailingSource do
  @moduledoc """
  Stand-in for the contexts whose list queries always fail.
  """

  def list_transaction_history(_params), do: raise("database unavailable")
  def list_authorizations_page(_before_id, _limit), do: raise("database unavailable")
end
