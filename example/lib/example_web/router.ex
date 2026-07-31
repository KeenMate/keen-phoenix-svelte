defmodule ExampleWeb.Router do
  use ExampleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ExampleWeb.Plugs.CurrentUser
    plug ExampleWeb.Plugs.Locale
  end

  # JSON API for same-origin calls from Svelte islands: session + CSRF, no bearer
  # token. Matches what the client `api` helper sends.
  pipeline :browser_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
  end

  # Simulates a *different* service (Microsoft Graph): a bearer token only, no
  # session or CSRF. See `ExampleWeb.Plugs.RequireGraphToken`.
  pipeline :graph_api do
    plug :accepts, ["json"]
    plug ExampleWeb.Plugs.RequireGraphToken
  end

  # Unauthenticated maintenance hook (demo only): no session/CSRF so it can be
  # curled or hit by a cron. Safe because it only re-seeds throwaway demo data
  # (the same reset also runs automatically every 15 minutes).
  pipeline :maintenance_api do
    plug :accepts, ["json"]
  end

  scope "/", ExampleWeb do
    pipe_through :browser

    live_session :workspace, on_mount: ExampleWeb.CurrentUserHook do
      live "/", HomeLive, :index
      live "/chat", ChatLive, :index
      live "/videos", VideosLive, :index
      live "/calendar", CalendarLive, :index
      live "/proxying", ProxyingLive, :index
      live "/guarding", GuardingLive, :index
      live "/eager", EagerLive, :index
      live "/stress", StressLive, :index
      live "/widgets", WidgetsLive, :index
      live "/inline-edit", InlineEditLive, :index
      live "/docs", DocsLive, :index
    end

    # Plain (non-LiveView) page — the calendar island mounts via mountStatic().
    get "/calendar-plain", PageController, :calendar_plain

    # Plain-page twin of /proxying — same islands + load-stats panel, but the
    # islands mount via mountStatic() instead of the LiveView hook. A permanent
    # demo of mount timing: how much of "first render" is the LiveView connect +
    # mount round-trip vs the island's own module-eval + render cost.
    get "/proxying-plain", PageController, :proxying_plain

    # Demo-only identity switch (not authentication).
    post "/session/switch", SessionController, :switch
    # Language switch — stores the locale in the session.
    post "/session/locale", SessionController, :locale
    # Clears persisted inline-edit blocks from the session (see /inline-edit).
    post "/inline-edit/reset", InlineEditController, :reset
  end

  scope "/api", ExampleWeb do
    pipe_through :browser_api

    get "/videos", VideoController, :index
    get "/videos/:id", VideoController, :show
    post "/videos/:id/save", VideoController, :save

    # Persists an inline-edit block into the session so edits survive a reload.
    post "/inline-edit/blocks", InlineEditController, :save
  end

  scope "/api/maintenance", ExampleWeb do
    pipe_through :maintenance_api

    post "/reset", MaintenanceController, :reset
  end

  # Mock Microsoft Graph. In a real app the calendar island would call
  # https://graph.microsoft.com/v1.0/... instead of this same-origin stand-in.
  scope "/mock-graph", ExampleWeb do
    pipe_through :graph_api

    get "/v1.0/me/calendarView", MockGraphController, :calendar_view
  end

  # Same-origin app proxy (KeenPhoenixSvelte `:proxy` mode). A request to
  # /apps/<name> is fetched upstream by the server and re-served here — so an
  # external/CDN bundle isn't subject to CORS or a strict CSP. Local bundles at
  # /apps/<name>/main.mjs are served by Plug.Static first; only registered
  # (proxied) apps fall through here. The `greeter` demo is proxied in dev,
  # loaded direct in prod.
  forward "/apps", KeenPhoenixSvelte.Apps.Proxy

  # Enable LiveDashboard in development
  if Application.compile_env(:example, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ExampleWeb.Telemetry
    end
  end
end
