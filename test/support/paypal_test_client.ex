defmodule AgentProof.PayPal.TestClient do
  @moduledoc """
  PayPal adapter for tests that fails on demand.

  Pass `fail: :create`, `fail: :capture`, or `fail: :submit` in opts;
  otherwise it behaves like `AgentProof.PayPal.Demo`.
  """

  @behaviour AgentProof.PayPal.Client

  alias AgentProof.PayPal.Demo

  @impl true
  def name, do: "test"

  @impl true
  def create_order(order, opts) do
    if opts[:fail] == :create,
      do: {:error, :sandbox_unavailable},
      else: Demo.create_order(order, opts)
  end

  @impl true
  def capture_order(order_id, opts) do
    if opts[:fail] == :capture,
      do: {:error, :capture_declined},
      else: Demo.capture_order(order_id, opts)
  end

  @impl true
  def submit_evidence(dispute_id, payload, opts) do
    if opts[:fail] == :submit,
      do: {:error, {:paypal, 422, "UNPROCESSABLE_ENTITY"}},
      else: Demo.submit_evidence(dispute_id, payload, opts)
  end
end
