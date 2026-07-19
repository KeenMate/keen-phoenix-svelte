defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase

  test "GET /plain renders a static page that mounts a Svelte app", %{conn: conn} do
    conn = get(conn, ~p"/plain")
    html = html_response(conn, 200)
    assert html =~ "Plain (non-LiveView) page"
    # the <.svelte> mount point + the once-per-page runtime context
    assert html =~ ~s(data-app="like")
    assert html =~ ~s(id="keen-context")
  end
end
