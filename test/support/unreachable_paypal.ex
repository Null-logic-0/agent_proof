defmodule AgentProof.UnreachablePayPal do
  @moduledoc """
  PayPal adapter that fails every call as if PayPal were unreachable.
  """

  @behaviour AgentProof.PayPal.Client

  @impl true
  def name, do: "unreachable"

  @impl true
  def create_order(_order, _opts), do: {:error, {:transport, :econnrefused}}

  @impl true
  def capture_order(_order_id, _opts), do: {:error, {:transport, :econnrefused}}

  @impl true
  def submit_evidence(_dispute_id, _payload, _opts), do: {:error, {:transport, :econnrefused}}
end
