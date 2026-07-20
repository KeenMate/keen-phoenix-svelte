defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase, async: true

  test "GET /calendar-plain renders a plain page that mounts the calendar island", %{conn: conn} do
    html = conn |> get(~p"/calendar-plain") |> html_response(200)

    assert html =~ "plain controller-rendered page"
    # the <.svelte> mount point + the once-per-page runtime context (with a token)
    assert html =~ ~s(data-app="calendar")
    assert html =~ ~s(id="keen-context")
  end
end
