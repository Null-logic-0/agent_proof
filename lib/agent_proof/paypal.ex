defmodule AgentProof.PayPal do
  @moduledoc """
  Entry point for PayPal calls. The adapter comes from `opts[:adapter]` or config.
  """

  def create_order(order, opts \\ []), do: adapter(opts).create_order(order, opts)

  def capture_order(order_id, opts \\ []), do: adapter(opts).capture_order(order_id, opts)

  def submit_evidence(dispute_id, payload, opts \\ []),
    do: adapter(opts).submit_evidence(dispute_id, payload, opts)

  def adapter_name(opts \\ []), do: adapter(opts).name()

  def adapter(opts \\ []) do
    Keyword.get_lazy(opts, :adapter, fn ->
      Application.fetch_env!(:agent_proof, :paypal_adapter)
    end)
  end
end
