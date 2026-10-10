defmodule AgentProof.Transactions.AgentAction do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :action, Ecto.Enum,
      values: [
        :search_products,
        :select_product,
        :budget_check,
        :create_paypal_order,
        :capture_payment,
        :payment_failed,
        :paypal_fallback
      ]

    field :actor, Ecto.Enum, values: [:agent, :system]
    field :at, :utc_datetime_usec
    field :details, :map, default: %{}
  end

  @doc """
  Validates the agent's own action log. Everything in it is recorded as done by the agent.
  """
  def from_agent(actions) when is_list(actions) do
    changesets = Enum.map(actions, &agent_changeset(%__MODULE__{}, &1))

    case Enum.find(changesets, &(not &1.valid?)) do
      nil -> {:ok, Enum.map(changesets, &apply_changes/1)}
      invalid -> {:error, invalid}
    end
  end

  @doc """
  An action done by AgentProof itself, now.
  """
  def system(action, details) do
    %__MODULE__{action: action, actor: :system, at: DateTime.utc_now(), details: details}
  end

  defp agent_changeset(action, attrs) do
    action
    |> cast(attrs, [:action, :at, :details])
    |> validate_required([:action, :at])
    |> put_change(:actor, :agent)
  end
end
