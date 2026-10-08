import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :agent_proof, AgentProof.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "agent_proof_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :agent_proof, AgentProofWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "dH2kpx8zsGKWT3P6x3crTUWBR3uWZNuDmW0iGivNlcGKVcSooHxT+3WvbvKHDD7A",
  server: false

# PayPal Sandbox adapter tests answer its HTTP calls with Req.Test stubs.
config :agent_proof, AgentProof.PayPal.Sandbox,
  base_url: "https://paypal.test",
  client_id: "test-client-id",
  client_secret: "test-client-secret",
  req_options: [plug: {Req.Test, AgentProof.PayPal.Sandbox}, retry: false]

# Ollama provider tests answer its HTTP calls with Req.Test stubs.
config :agent_proof, AgentProof.AI.Ollama,
  base_url: "http://ollama.test",
  model: "test-model",
  req_options: [plug: {Req.Test, AgentProof.AI.Ollama}, retry: false]

# In test we don't send emails
config :agent_proof, AgentProof.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
