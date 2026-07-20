defmodule ExampleWeb.VideoControllerTest do
  use ExampleWeb.ConnCase, async: true

  test "GET /api/videos lists the catalogue with categories", %{conn: conn} do
    body = conn |> get(~p"/api/videos") |> json_response(200)

    assert length(body["videos"]) > 0
    assert is_list(body["categories"])

    video = hd(body["videos"])
    assert video["src"] =~ "https://"
    assert video["poster"] =~ "https://"
  end

  test "GET /api/videos/:id returns one video", %{conn: conn} do
    body = conn |> get(~p"/api/videos/all-hands-q3") |> json_response(200)
    assert body["video"]["id"] == "all-hands-q3"
  end

  test "GET /api/videos/:id 404s for an unknown id", %{conn: conn} do
    body = conn |> get(~p"/api/videos/nope") |> json_response(404)
    assert body["error"] == "not_found"
  end

  test "POST /api/videos/:id/save echoes the saved state", %{conn: conn} do
    body =
      conn
      # /api is CSRF-protected; skip the check in the test as the client sends a token.
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
      |> post(~p"/api/videos/all-hands-q3/save", %{saved: true})
      |> json_response(200)

    assert body == %{"id" => "all-hands-q3", "saved" => true}
  end
end
