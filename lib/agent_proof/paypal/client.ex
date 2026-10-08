defmodule AgentProof.PayPal.Client do
  @moduledoc """
  The contract every PayPal adapter implements.

  Adapters return AgentProof's own small maps, never PayPal's raw JSON.
  """

  @type order :: %{
          amount: Decimal.t(),
          currency: String.t(),
          description: String.t(),
          reference_id: String.t()
        }

  @callback create_order(order(), opts :: keyword()) ::
              {:ok, %{order_id: String.t()}} | {:error, term()}

  @callback capture_order(order_id :: String.t(), opts :: keyword()) ::
              {:ok, %{order_id: String.t(), capture_id: String.t()}} | {:error, term()}
end
