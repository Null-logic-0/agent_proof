defmodule AgentProofWeb.DemoModeControllerTest do
  use AgentProofWeb.ConnCase, async: true

  test "turns Demo Mode on and returns to the page it was used on", %{conn: conn} do
    conn = post(conn, ~p"/demo-mode", %{"demo_mode" => "on", "return_to" => "/history?page=2"})

    assert redirected_to(conn) == "/history?page=2"
    assert get_session(conn, :demo_mode) == true
  end

  test "turns it off", %{conn: conn} do
    conn =
      conn
      |> init_test_session(demo_mode: true)
      |> post(~p"/demo-mode", %{"demo_mode" => "off", "return_to" => "/"})

    assert get_session(conn, :demo_mode) == false
  end

  test "only returns to pages on this site", %{conn: conn} do
    for return_to <- ["https://evil.example", "//evil.example", "/\\evil.example", nil] do
      conn = post(conn, ~p"/demo-mode", %{"demo_mode" => "on", "return_to" => return_to})

      assert redirected_to(conn) == "/"
    end
  end
end
