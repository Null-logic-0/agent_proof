defmodule AgentProof.PayPal.Client do
  @moduledoc """
  Behaviour every PayPal adapter implements.
  """

  @type order :: %{
          amount: Decimal.t(),
          currency: String.t(),
          description: String.t(),
          reference_id: String.t()
        }

  @doc ~s(Label for the UI, e.g. "demo" or "sandbox".)
  @callback name() :: String.t()

  @callback create_order(order(), opts :: keyword()) ::
              {:ok, %{order_id: String.t()}} | {:error, term()}

  @typedoc "`simulated: true` means no real money movement was captured at PayPal."
  @type capture :: %{
          required(:order_id) => String.t(),
          required(:capture_id) => String.t(),
          optional(:simulated) => boolean()
        }

  @callback capture_order(order_id :: String.t(), opts :: keyword()) ::
              {:ok, capture()} | {:error, term()}

  @doc """
  Sends dispute evidence to PayPal. `simulated: true` means nothing was sent.
  """
  @callback submit_evidence(dispute_id :: String.t(), payload :: map(), opts :: keyword()) ::
              {:ok, %{simulated: boolean()}} | {:error, term()}
end
