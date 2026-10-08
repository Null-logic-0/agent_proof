defmodule AgentProof.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AgentProofWeb.Telemetry,
      AgentProof.Repo,
      {DNSCluster, query: Application.get_env(:agent_proof, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AgentProof.PubSub},
      # Start a worker by calling: AgentProof.Worker.start_link(arg)
      # {AgentProof.Worker, arg},
      # Start to serve requests, typically the last entry
      AgentProofWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AgentProof.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AgentProofWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
