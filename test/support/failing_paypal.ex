defmodule AgentProof.FailingPayPal do
  @moduledoc """
  PayPal adapter whose evidence submission always fails as if PayPal were
  unreachable, used to test the submission's error state. Orders behave like
  `AgentProof.PayPal.Demo`.
  """

  @behaviour AgentProof.PayPal.Client

  alias AgentProof.PayPal.Demo

  @impl true
  def name, do: "failing"

  @impl true
  defdelegate create_order(order, opts), to: Demo

  @impl true
  defdelegate capture_order(order_id, opts), to: Demo

  @impl true
  def submit_evidence(_dispute_id, _payload, _opts), do: {:error, {:transport, :econnrefused}}
end
