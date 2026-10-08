defmodule AgentProof.PayPal do
  @moduledoc """
  The PayPal boundary. The rest of the app calls these functions, never an
  adapter directly.

  The adapter is chosen per call: `opts[:adapter]`, otherwise
  `config :agent_proof, :paypal_adapter`. The remaining `opts` are passed
  through to the adapter.
  """

  def create_order(order, opts \\ []), do: adapter(opts).create_order(order, opts)

  def capture_order(order_id, opts \\ []), do: adapter(opts).capture_order(order_id, opts)

  def adapter_name(opts \\ []), do: adapter(opts).name()

  defp adapter(opts) do
    Keyword.get_lazy(opts, :adapter, fn ->
      Application.fetch_env!(:agent_proof, :paypal_adapter)
    end)
  end
end
