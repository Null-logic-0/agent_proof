defmodule AgentProofWeb.DemoMode do
  @moduledoc """
  Reads Demo Mode from the session for every LiveView and turns it into context options.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  alias AgentProof.{AI, PayPal}

  def on_mount(:default, _params, session, socket) do
    {:cont,
     socket
     |> assign(:demo_mode, session["demo_mode"] == true)
     |> assign(:current_path, "/")
     |> attach_hook(:current_path, :handle_params, fn _params, uri, socket ->
       {:cont, assign(socket, :current_path, path_with_query(uri))}
     end)}
  end

  @doc """
  The Demo adapters when Demo Mode is on; none (the configured adapters) when off.
  """
  def opts(true = _demo_mode), do: [adapter: PayPal.Demo, provider: AI.Demo]
  def opts(false = _demo_mode), do: []

  defp path_with_query(uri) do
    case URI.parse(uri) do
      %URI{path: path, query: nil} -> path
      %URI{path: path, query: query} -> path <> "?" <> query
    end
  end
end
