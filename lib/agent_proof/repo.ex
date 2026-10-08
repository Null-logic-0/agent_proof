defmodule AgentProof.Repo do
  use Ecto.Repo,
    otp_app: :agent_proof,
    adapter: Ecto.Adapters.Postgres
end
