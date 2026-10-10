defmodule AgentProofWeb.DemoModeController do
  use AgentProofWeb, :controller

  @doc """
  Turns Demo Mode on or off for this browser, then reloads the page the switch
  was used on. LiveViews read the choice from the session on mount (see
  `AgentProofWeb.DemoMode`).
  """
  def update(conn, params) do
    conn
    |> put_session(:demo_mode, params["demo_mode"] == "on")
    |> redirect(to: local_path(params["return_to"]))
  end

  # Only paths on this site are followed, so the switch can't be used to send
  # someone elsewhere ("//evil.example" is a link to another site).
  defp local_path("/" <> _ = path) do
    if String.starts_with?(path, ["//", "/\\"]), do: ~p"/", else: path
  end

  defp local_path(_other), do: ~p"/"
end
