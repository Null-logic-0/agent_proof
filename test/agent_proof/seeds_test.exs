defmodule AgentProof.SeedsTest do
  use AgentProof.DataCase, async: true

  import AgentProof.Fixtures
  import ExUnit.CaptureIO

  alias AgentProof.{Authorizations, Transactions}

  defp run_seeds, do: capture_io(fn -> Code.eval_file("priv/repo/seeds.exs") end)

  test "an empty database gets OfficeBot's purchases and a DemoBot case ready for review" do
    assert run_seeds() =~ "Seeded OfficeBot"

    assert ~w(DemoBot OfficeBot) =
             Enum.map(Authorizations.list_authorizations(), & &1.agent.name)

    assert [demo_case, mouse, cable] = Transactions.list_transactions()

    assert {cable.product_name, mouse.product_name} ==
             {"Anker USB-C Cable (6 ft)", "Logitech MX Master 3S Mouse"}

    disputed = Transactions.get_case!(demo_case.id)
    assert disputed.dispute.status == :evidence_ready
    assert disputed.dispute.evidence.ai_provider == "demo"
  end

  test "a database with data is left alone" do
    existing = authorization_fixture(agent_fixture())

    assert run_seeds() =~ "Seeds skipped"
    assert [%{id: id}] = Authorizations.list_authorizations()
    assert id == existing.id
  end
end
