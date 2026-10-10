defmodule AgentProofWeb.DemoMode do
  @moduledoc """
  Demo Mode: while it is on, purchases and AI investigations use the
  deterministic Demo adapters, whatever the config says.

  The switch lives in the browser's session (set by
  `AgentProofWeb.DemoModeController`), not in a global flag, so every browser
  and every test has its own. This `on_mount` hook copies it into
  `@demo_mode` for each LiveView, and LiveViews pass `opts/1` to the contexts.
  It also keeps `@current_path`, so the switch can return to the same page.
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
  The context options for a LiveView's Demo Mode: the Demo adapters while it
  is on, nothing (the configured adapters) while it is off.
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
