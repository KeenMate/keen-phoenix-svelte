defmodule ExampleWeb.GuardingLive do
  @moduledoc """
  Shows how a `base:` app's sub-path fan-out is *bounded* — the `manifest:`
  allowlist and negative caching. The same origin is registered twice:

    * `catalog-guarded` — `manifest: "manifest.json"`, so only the listed files
      (`main.mjs`, `panel.js`, `panel.css`) may be served; any other sub-path is a
      `404` decided **before** any upstream fetch.
    * `catalog-open` — no manifest, so any sub-path is proxied; a genuine miss hits
      upstream once and is then negative-cached.

  The `ProxyProbe` hook fetches a handful of sub-paths against both and shows which
  are served vs blocked, and how fast — dev-only (the origin is our own
  `/external/catalog/` static dir standing in for a CDN).
  """
  use ExampleWeb, :live_view

  @config_snippet """
  config :keen_phoenix_svelte,
    apps: %{
      # only the files in keen-manifest.json may be served — else 404, no fetch
      "dashboard-guarded" => %{
        base: "…/dashboard/",
        entry: "main.mjs",
        manifest: "keen-manifest.json"
      },

      # no manifest — any sub-path is proxied (misses hit upstream, then cache)
      "dashboard-open" => %{base: "…/dashboard/", entry: "main.mjs"}
    }
  """

  @manifest_snippet """
  // dashboard/keen-manifest.json — the exact files this app ships
  ["main.mjs", "dashboard.css", "icon.svg", "data.json",
   "views/overview.mjs", "views/charts.mjs", "views/table.mjs"]
  """

  @probe [
    %{group: "guarded", name: "dashboard-guarded", sub: "main.mjs", note: "entry — always allowed"},
    %{
      group: "guarded",
      name: "dashboard-guarded",
      sub: "views/charts.mjs",
      note: "lazy chunk (nested) — in manifest"
    },
    %{
      group: "guarded",
      name: "dashboard-guarded",
      sub: "secret.js",
      note: "exists upstream, NOT in manifest → blocked"
    },
    %{
      group: "guarded",
      name: "dashboard-guarded",
      sub: "views/ghost.mjs",
      note: "does not exist → blocked (no fetch)"
    },
    %{
      group: "open",
      name: "dashboard-open",
      sub: "secret.js",
      note: "no manifest → served (the same file the guarded app blocks)"
    },
    %{
      group: "open",
      name: "dashboard-open",
      sub: "views/ghost.mjs",
      note: "no manifest → upstream 404, then negative-cached"
    }
  ]

  def mount(_params, _session, socket) do
    manifest = KeenPhoenixSvelte.Apps.manifest()
    guarded? = Map.has_key?(manifest, "dashboard-guarded")
    open? = Map.has_key?(manifest, "dashboard-open")

    {:ok,
     assign(socket,
       config_snippet: @config_snippet,
       manifest_snippet: @manifest_snippet,
       probe: @probe,
       guarded?: guarded?,
       open?: open?,
       registered?: guarded? and open?,
       preload_apps: if(guarded?, do: ["dashboard-guarded"], else: []),
       page_title: "Guarding"
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:guarding}
      title="Guarding"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-4xl mx-auto space-y-10 pb-6">
        <%!-- Motivation --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-shield-check" class="size-7 text-primary" />
            <h1 class="text-2xl font-bold tracking-tight">Guarding the proxy</h1>
          </div>
          <p class="mt-3 text-base-content/70">
            A <code>base:</code>/<code>dir:</code>
            app proxies <strong>any</strong>
            sub-path under its prefix — that's what lets a whole multi-file bundle
            work from one registration. But it also means an unauthenticated client
            can ask for paths that don't exist, or ones you never meant to expose.
            Left unchecked, a flood of guaranteed-miss names would drive an
            <strong>unbounded stream of outbound fetches</strong>. Two defenses keep it bounded:
          </p>
          <div class="grid gap-4 md:grid-cols-2 mt-4">
            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary">manifest:</code>
                <span class="text-sm text-base-content/60">opt-in · exact</span>
              </div>
              <p class="text-sm text-base-content/70 mt-2">
                Declare the exact files an app ships. Anything else is a
                <code>404</code>
                decided locally, <strong>before</strong>
                any upstream fetch. You choose precisely what's reachable.
              </p>
            </div>
            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary">negative cache</code>
                <span class="text-sm text-base-content/60">always on</span>
              </div>
              <p class="text-sm text-base-content/70 mt-2">
                Even with no manifest, a definitive upstream <code>404</code>
                is briefly remembered (<code>negative_ttl</code>), so a repeated miss
                isn't re-fetched — and concurrent upstream fetches are capped.
              </p>
            </div>
          </div>
        </section>

        <%= if @registered? do %>
          <%!-- The interactive probe --%>
          <section class="card bg-base-100 border border-base-300 rounded-xl p-6">
            <div class="flex items-center gap-2">
              <.icon name="hero-beaker" class="size-6 text-primary" />
              <h2 class="text-lg font-semibold">Probe it</h2>
            </div>
            <p class="mt-2 text-base-content/70">
              Each row fetches <code>/apps/&lt;name&gt;/&lt;path&gt;</code>
              through the proxy and shows the status. Watch
              <code>secret.js</code>: the <strong>guarded</strong>
              app blocks it (it's not in the manifest) while the <strong>open</strong>
              app serves the very same file. The non-existent
              <code>views/ghost.mjs</code>
              is a <code>404</code>
              either way — but the guarded app never fetches it, and the open app
              negative-caches the miss (re-run and its latency drops).
            </p>
            <div
              id="proxy-probe"
              phx-hook="ProxyProbe"
              phx-update="ignore"
              data-probe={Jason.encode!(@probe)}
              class="mt-4"
            >
            </div>
          </section>

          <%!-- The allowed files really do mount as a working island --%>
          <section>
            <div class="flex items-center gap-2">
              <.icon name="hero-check-badge" class="size-6 text-primary" />
              <h2 class="text-lg font-semibold">The allowed files still make a working island</h2>
            </div>
            <p class="mt-2 text-base-content/70">
              The manifest only blocks what isn't listed — the entry, its lazy view
              chunks, stylesheet, icon and data file are all allowed, so
              <code>dashboard-guarded</code>
              mounts as a real code-split island (click the tabs to stream each
              chunk in through the proxy):
            </p>
            <div class="mt-4">
              <.app name="dashboard-guarded" id="dashboard-guarded-app" props={%{}}>
                <:placeholder>
                  <div class="skeleton h-40 w-full max-w-[30rem] rounded-xl"></div>
                </:placeholder>
              </.app>
            </div>
          </section>
        <% else %>
          <section class="card bg-base-100 border border-warning/40 rounded-xl p-5">
            <p class="text-sm text-base-content/70">
              The <code>dashboard-guarded</code> / <code>dashboard-open</code>
              apps aren't registered in this environment (they're a dev-only demo
              against the local <code>/external/dashboard/</code> origin), so the
              probe is hidden here.
            </p>
          </section>
        <% end %>

        <%!-- How it's wired --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-cog-6-tooth" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">How it's wired</h2>
          </div>
          <p class="mt-2 text-base-content/70">
            Same origin, registered twice — the only difference is the
            <code>manifest:</code> key:
          </p>
          <pre class="mt-2 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@config_snippet}</code></pre>
          <p class="mt-3 text-base-content/70">
            The manifest is just the list of servable files (a flat JSON array here;
            a Vite <code>manifest.json</code>
            or the <code>keenManifest()</code> plugin's output work too):
          </p>
          <pre class="mt-2 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@manifest_snippet}</code></pre>
        </section>
      </div>

      <:aside>
        <Layouts.info_panel title="Bounding the fan-out">
          <p>
            A <code>base:</code>
            app proxies any sub-path. Two things keep an unauthenticated flood from
            driving unbounded outbound fetches.
          </p>
          <:wire label="manifest:">
            Opt-in exact allowlist — unlisted files <code>404</code> before any fetch.
          </:wire>
          <:wire label="negative_ttl">
            A definitive upstream <code>404</code>/<code>410</code> is briefly tombstoned; repeat misses don't re-fetch.
          </:wire>
          <:wire label="max_concurrent_fetches">
            Concurrent upstream fetches are capped; excess sheds with <code>503 + Retry-After</code>.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
