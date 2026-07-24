defmodule ExampleWeb.PageController do
  use ExampleWeb, :controller

  @doc """
  A plain, non-LiveView page that hosts the calendar island.

  Demonstrates the `mountStatic()` path: the island mounts with `live: null` and
  still works, because it reaches the mock Graph service over its own `fetch`
  using the token from `context`.
  """
  def calendar_plain(conn, _params) do
    render(conn, :calendar_plain)
  end

  @doc """
  Plain-page twin of `ProxyingLive`, and a permanent demo of island **mount
  timing**. Renders the same two islands (`hello` + `metrics`) and the same
  load-stats panel, but as a dead controller page — so the islands mount via
  `mountStatic()` the instant `app.js` runs, instead of waiting for the LiveView
  hook to fire after the socket connects.

  The `watch` / `preload_apps` assigns are built exactly as in `ProxyingLive`,
  so the only variable between the two pages is *what triggers the mount* — which
  the `first render` delta in the load-stats panel makes visible. See the
  "First render: LiveView vs a plain page" section of `docs/external-apps.md`.
  """
  def proxying_plain(conn, _params) do
    manifest = KeenPhoenixSvelte.Apps.manifest()

    hello? = Map.has_key?(manifest, "hello")
    metrics? = Map.has_key?(manifest, "metrics")

    watch =
      [
        hello? &&
          %{name: "hello", container: "hello-app", match: "/hello/main.mjs", label: ":direct"},
        metrics? &&
          %{name: "metrics", container: "metrics-app", match: "/apps/metrics/main.mjs", label: ":proxy"}
      ]
      |> Enum.filter(& &1)

    conn
    |> assign(:hello?, hello?)
    |> assign(:metrics?, metrics?)
    |> assign(:watch, watch)
    |> assign(:preload_apps, Enum.map(watch, & &1.name))
    |> assign(:page_title, "Proxying (plain)")
    |> render(:proxying_plain)
  end
end
