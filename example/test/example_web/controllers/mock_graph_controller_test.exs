defmodule ExampleWeb.MockGraphControllerTest do
  use ExampleWeb.ConnCase, async: true

  test "401 without a bearer token", %{conn: conn} do
    body = conn |> get(~p"/mock-graph/v1.0/me/calendarView") |> json_response(401)
    assert body["error"]["code"] == "InvalidAuthenticationToken"
  end

  test "401 with an invalid bearer token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer not-a-real-token")
      |> get(~p"/mock-graph/v1.0/me/calendarView")

    assert json_response(conn, 401)
  end

  test "200 with a valid graph token returns Graph-shaped events", %{conn: conn} do
    token = Phoenix.Token.sign(ExampleWeb.Endpoint, "graph token", 1)

    body =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/mock-graph/v1.0/me/calendarView")
      |> json_response(200)

    assert is_list(body["value"])
    event = hd(body["value"])
    assert event["subject"]
    assert event["start"]["dateTime"]
  end
end
