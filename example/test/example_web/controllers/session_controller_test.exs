defmodule ExampleWeb.SessionControllerTest do
  use ExampleWeb.ConnCase, async: true

  test "switching user stores the id in the session and redirects", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
      |> post(~p"/session/switch", %{user_id: 3})

    assert redirected_to(conn) == "/"
    assert get_session(conn, "user_id") == 3
  end

  test "an unknown user id is ignored", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
      |> post(~p"/session/switch", %{user_id: 999})

    assert redirected_to(conn) == "/"
    assert get_session(conn, "user_id") == nil
  end

  test "switching language stores a supported locale and redirects", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
      |> post(~p"/session/locale", %{locale: "es"})

    assert redirected_to(conn) == "/"
    assert get_session(conn, "locale") == "es"
  end

  test "an unsupported locale falls back to the default", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
      |> post(~p"/session/locale", %{locale: "zz"})

    assert redirected_to(conn) == "/"
    assert get_session(conn, "locale") == "en"
  end
end
