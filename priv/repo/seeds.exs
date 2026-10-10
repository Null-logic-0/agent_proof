# Demo data: `mix run priv/repo/seeds.exs` (also run by `mix ecto.setup` and on Docker start).
# It only fills an empty database, through the real contexts with the Demo adapters forced.

alias AgentProof.{AI, Authorizations, DemoScenario, PayPal, Repo}
alias AgentProof.Agents.{Agent, ShoppingAgent}

demo = [adapter: PayPal.Demo, provider: AI.Demo]

if Repo.exists?(Agent) do
  IO.puts("Seeds skipped: the database already has data.")
else
  {:ok, office_bot} =
    Authorizations.grant(%{
      "agent_name" => "OfficeBot",
      "max_amount" => "150",
      "description" => "Buy desk accessories (cables, a mouse), up to $150"
    })

  {:ok, _cable} = ShoppingAgent.run(office_bot, "usb cable", demo)
  {:ok, _mouse} = ShoppingAgent.run(office_bot, "mouse", demo)

  # A disputed case ready for review: a backup for the live demo.
  {:ok, _transaction} = DemoScenario.run(demo)

  IO.puts("Seeded OfficeBot with 2 purchases, and a DemoBot case ready for review.")
end
