defmodule ExampleWeb.EagerLive do
  @moduledoc """
  Demonstrates **eager mounting** (`<.app eager>`). Two copies of the same island
  (`eager-demo`) sit side by side on this LiveView:

    * **eager** — mounted by `mountStatic()` before the socket connects, so it
      paints immediately (with `liveStatus: "pending"`), then flips to `"ready"`
      when the `KeenApp` hook fires `keen:live-ready`.
    * **default** — mounted the usual way, from the hook after the socket
      connects, so it only appears once `live` is available.

  The load-stats panel (`ProxyLoadStats`, the same hook the proxying demo uses)
  times both, so the `first render` delta shows the difference directly. The
  bundle is shared and preloaded, so the only variable is *when each mounts*.
  """
  use ExampleWeb, :live_view

  def mount(_params, _session, socket) do
    watch = [
      %{
        name: "eager",
        container: "eager-demo-eager",
        match: "/apps/eager-demo/main.mjs",
        label: "eager"
      },
      %{
        name: "default",
        container: "eager-demo-default",
        match: "/apps/eager-demo/main.mjs",
        label: "default"
      }
    ]

    {:ok,
     assign(socket,
       watch: watch,
       # Preload the shared bundle during HTML parse, so the download isn't the
       # variable — only the mount trigger is.
       preload_apps: ["eager-demo"],
       page_title: "Eager mounting"
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:eager}
      title="Eager mounting"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-4xl mx-auto space-y-10 pb-6">
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-bolt" class="size-7 text-primary" />
            <h1 class="text-2xl font-bold tracking-tight">Mount before connect</h1>
          </div>
          <p class="mt-3 text-base-content/70">
            On a LiveView, an island normally mounts from the <code>KeenApp</code>
            hook — which can't run until the socket connects. With
            <code>&lt;.app eager&gt;</code>
            the island is mounted by <code>mountStatic()</code>
            the instant <code>app.js</code>
            parses, so it paints without waiting. It starts with
            <code>live: null</code>
            and <code>liveStatus: "pending"</code>; when the socket connects, the
            hook hands it the <code>live</code>
            bridge and fires a <code>keen:live-ready</code> event.
          </p>
          <p class="mt-3 text-base-content/70">
            Both cards below are the <em>same</em>
            island. Reload and watch: the <strong>eager</strong>
            one appears at once (amber, "waiting for live"), then turns green when
            live connects; the <strong>default</strong>
            one only appears after connect. Compare their <code>first render</code>
            in the stats panel.
          </p>
        </section>

        <section class="grid gap-6 md:grid-cols-2">
          <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
            <div class="flex items-center gap-2 mb-3">
              <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary">eager</code>
              <span class="text-sm text-base-content/60">paints before connect</span>
            </div>
            <.app name="eager-demo" id="eager-demo-eager" eager props={%{}}>
              <:placeholder>
                <div class="skeleton h-14 w-full rounded-xl"></div>
              </:placeholder>
            </.app>
          </div>

          <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
            <div class="flex items-center gap-2 mb-3">
              <code class="text-xs font-mono px-2 py-0.5 rounded bg-base-300 text-base-content/70">default</code>
              <span class="text-sm text-base-content/60">waits for the hook</span>
            </div>
            <.app name="eager-demo" id="eager-demo-default" props={%{}}>
              <:placeholder>
                <div class="skeleton h-14 w-full rounded-xl"></div>
              </:placeholder>
            </.app>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-300 rounded-xl p-6">
          <div class="flex items-center gap-2">
            <.icon name="hero-clock" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">Live load statistics</h2>
          </div>
          <p class="mt-2 text-base-content/70">
            Same shared bundle (requested + loaded once), two containers. The
            <code>first render</code>
            delta is the eager win: the eager card paints at
            <code>app.js</code>
            parse time, the default card only after the socket connects.
          </p>
          <div
            id="proxy-load-stats"
            phx-hook="ProxyLoadStats"
            phx-update="ignore"
            data-apps={Jason.encode!(@watch)}
            class="mt-4 grid gap-4 sm:grid-cols-2"
          >
          </div>
        </section>
      </div>

      <:aside>
        <Layouts.info_panel title="Eager vs default">
          <p>
            Same island, same preload. The only difference is <strong>when it mounts</strong>
            — and whether <code>live</code> is there at first paint.
          </p>
          <:wire label="eager">
            <code>mountStatic()</code>
            mounts it pre-connect with <code>live: null</code>,
            <code>liveStatus: "pending"</code>.
          </:wire>
          <:wire label="keen:live-ready">
            Fired on the island element when the hook upgrades it with the
            <code>live</code> bridge after connect.
          </:wire>
          <:wire label="default">
            Mounts from the hook after connect; <code>live</code>
            present from the first frame (<code>liveStatus: "ready"</code>).
          </:wire>
          <:wire label="when to use">
            Eager suits islands that don't need <code>live</code>
            to render — they fetch from <code>api</code>, a <code>channel</code>, or
            another server.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
