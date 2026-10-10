defmodule AgentProof.PayPal.Demo do
  @moduledoc """
  PayPal adapter without network calls: it always succeeds, with IDs based on the order.
  """

  @behaviour AgentProof.PayPal.Client

  @impl true
  def name, do: "demo"

  @impl true
  def create_order(%{reference_id: reference_id}, _opts) do
    {:ok, %{order_id: "DEMO-ORDER-" <> reference_id}}
  end

  @impl true
  def capture_order("DEMO-ORDER-" <> reference_id = order_id, _opts) do
    {:ok, %{order_id: order_id, capture_id: "DEMO-CAPTURE-" <> reference_id, simulated: true}}
  end

  def capture_order(_order_id, _opts), do: {:error, :unknown_order}

  @impl true
  def submit_evidence(_dispute_id, _payload, _opts), do: {:ok, %{simulated: true}}
end
