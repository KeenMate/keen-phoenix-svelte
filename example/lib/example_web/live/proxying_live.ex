defmodule ExampleWeb.ProxyingLive do
  @moduledoc """
  Shows the app registry's two delivery modes against a **genuinely external**
  origin — the CDN at `apps.keen-phoenix-svelte.keenmate.dev` (its own repo,
  `keen-phoenix-svelte-apps`, served by Caddy behind Traefik).

  Both islands are registered in config; the server emits a `name → url` manifest
  and the client imports each from there:

    * `hello`   → `:direct` — the browser imports the CDN URL itself.
    * `metrics` → `:proxy`  — Phoenix fetches the CDN bundle (and its sibling
      stylesheet + data file) and re-serves them same-origin under
      `/apps/metrics/*`, revalidating on a short TTL.

  Nothing here is dev-only: it ships to the live site as an annotated demo.
  """
  use ExampleWeb, :live_view

  @cdn "https://apps.keen-phoenix-svelte.keenmate.dev"

  # Shown verbatim on the page. Kept as a string because literal `%{...}` can't
  # sit inline in a HEEx `<pre>` — the `{}` would be parsed as interpolation.
  @config_snippet """
  config :keen_phoenix_svelte,
    apps: %{
      # one self-contained file → a single URL fully describes it
      "hello" => %{url: "…/hello/main.mjs", mode: :direct},

      # a directory of files → point at the base; siblings proxy under it too
      "metrics" => %{
        base: "…/metrics/",
        entry: "main.mjs",
        mode: :proxy,
        ttl: :timer.seconds(60)
      }
    }
  """

  @hello_tree """
  hello/
  └─ main.mjs   ← markup + behaviour + styles\
  """

  @metrics_tree """
  metrics/
  ├─ main.mjs      ← entry
  ├─ metrics.css   ← <link>ed stylesheet
  └─ metrics.json  ← fetched at mount\
  """

  def mount(_params, _session, socket) do
    # Only render each card if its app is actually registered, so a deployment
    # that omits one from config degrades cleanly instead of 502-ing.
    manifest = KeenPhoenixSvelte.Apps.manifest()

    hello? = Map.has_key?(manifest, "hello")
    metrics? = Map.has_key?(manifest, "metrics")

    # Config for the client-side load-stats hook: which islands to time, the
    # container to watch for first render, and a URL substring to match each
    # bundle's Performance Resource Timing entry.
    watch =
      [
        hello? &&
          %{name: "hello", container: "hello-app", match: "/hello/main.mjs", label: ":direct"},
        metrics? &&
          %{name: "metrics", container: "metrics-app", match: "/apps/metrics/main.mjs", label: ":proxy"}
      ]
      |> Enum.filter(& &1)

    {:ok,
     assign(socket,
       cdn: @cdn,
       config_snippet: @config_snippet,
       hello_tree: @hello_tree,
       metrics_tree: @metrics_tree,
       hello?: hello?,
       metrics?: metrics?,
       watch: watch,
       page_title: "Proxying"
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:proxying}
      title="Proxying"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-4xl mx-auto space-y-10 pb-6">
        <%!-- Intro --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-globe-alt" class="size-7 text-primary" />
            <h1 class="text-2xl font-bold tracking-tight">Islands from a CDN</h1>
          </div>
          <p class="mt-3 text-base-content/70">
            Islands don't have to live under <code>/apps</code>. Both below are hosted on a
            <strong>separate origin</strong>
            —
            <a href={@cdn} target="_blank" rel="noopener" class="link link-primary">
              apps.keen-phoenix-svelte.keenmate.dev
            </a>
            — a plain static server (Caddy behind Traefik) in its own repo. They're
            registered in config; the server publishes a <code>name → url</code>
            manifest and the browser loads each one. What differs is <strong>who fetches the bytes</strong>.
          </p>
        </section>

        <%!-- The two modes, side by side --%>
        <section class="grid gap-6 md:grid-cols-2">
          <%!-- direct --%>
          <div class="card bg-base-100 border border-base-300 rounded-xl p-5 flex flex-col">
            <div class="flex items-center gap-2">
              <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary">:direct</code>
              <span class="text-sm text-base-content/60">browser → CDN</span>
            </div>
            <p class="text-sm text-base-content/70 mt-2">
              The manifest points straight at the CDN, so the browser imports the bundle
              <strong>cross-origin</strong>. Needs CORS on the CDN and a CSP that allows it.
            </p>
            <pre class="mt-3 bg-base-300/50 rounded-lg p-2.5 overflow-x-auto text-[0.7rem]"><code>import("{@cdn}/hello/main.mjs")</code></pre>

            <div class="mt-4 pt-4 border-t border-base-300">
              <%= if @hello? do %>
                <.app name="hello" id="hello-app" props={%{}}>
                  <:placeholder>
                    <div class="skeleton h-28 w-full rounded-xl"></div>
                  </:placeholder>
                </.app>
              <% else %>
                <p class="text-sm text-base-content/50 italic">
                  <code>hello</code> isn't registered in this environment.
                </p>
              <% end %>
            </div>
          </div>

          <%!-- proxy --%>
          <div class="card bg-base-100 border border-base-300 rounded-xl p-5 flex flex-col">
            <div class="flex items-center gap-2">
              <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary">:proxy</code>
              <span class="text-sm text-base-content/60">browser → your app → CDN</span>
            </div>
            <p class="text-sm text-base-content/70 mt-2">
              The manifest points at a <strong>same-origin</strong>
              path; Phoenix fetches the bundle upstream, caches it (ETS), and revalidates it.
              No CORS, CSP <code>'self'</code>. A multi-file bundle — the entry pulls its own
              stylesheet and a <code>metrics.json</code>, both proxied from one <code>base:</code>.
            </p>
            <pre class="mt-3 bg-base-300/50 rounded-lg p-2.5 overflow-x-auto text-[0.7rem]"><code>import("/apps/metrics/main.mjs") → server fetches {@cdn}/metrics/*</code></pre>

            <div class="mt-4 pt-4 border-t border-base-300">
              <%= if @metrics? do %>
                <.app name="metrics" id="metrics-app" props={%{}}>
                  <:placeholder>
                    <div class="skeleton h-28 w-full rounded-xl"></div>
                  </:placeholder>
                </.app>
              <% else %>
                <p class="text-sm text-base-content/50 italic">
                  <code>metrics</code> isn't registered in this environment.
                </p>
              <% end %>
            </div>
          </div>
        </section>

        <%!-- Live, in-browser load timings for the two islands --%>
        <section :if={@watch != []} class="card bg-base-100 border border-base-300 rounded-xl p-6">
          <div class="flex items-center gap-2">
            <.icon name="hero-clock" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">Live load statistics</h2>
          </div>
          <p class="mt-2 text-base-content/70">
            Measured right here in your browser — the <strong>Performance API</strong>
            for when each bundle was requested and finished loading, and a
            <strong>MutationObserver</strong>
            for when the island replaced its placeholder with real DOM. No server
            round-trip, no library hooks. Times are milliseconds since the page
            started loading, so the three stages share one clock. Reload to watch them again.
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

        <%!-- How each app is actually built --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-cube" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">How the two apps are built</h2>
          </div>
          <p class="mt-2 text-base-content/70">
            Neither app is built by this library — they're hand-written
            <strong>vanilla-JS ES modules</strong>
            in the sibling <code>keen-phoenix-svelte-apps</code>
            repo. Both default-export the same mount contract
            <code>(target, {"{ props, context, live, api, channel, bus, el }"}) → {"{ setProps, destroy }"}</code>.
            What actually differs is <strong>how many files each ships</strong>
            — and that one fact dictates how you register it.
          </p>

          <div class="grid gap-6 md:grid-cols-2 mt-4">
            <%!-- hello: one file --%>
            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <code class="text-sm font-mono font-semibold">hello</code>
                <span class="badge badge-sm badge-ghost">one file · vanilla JS</span>
              </div>
              <pre class="mt-3 bg-base-300/50 rounded-lg p-2.5 text-[0.7rem] leading-relaxed"><code>{@hello_tree}</code></pre>
              <ul class="mt-3 text-sm text-base-content/70 space-y-2">
                <li>
                  <strong>Styles ship inside the JS.</strong>
                  On mount it injects a scoped <code>&lt;style id="keen-hello-style"&gt;</code>
                  once — the "CSS-injected-by-JS" pattern. No stylesheet to fetch.
                </li>
                <li>
                  <strong>No companion files</strong>
                  means a single URL fully describes it, so it's registered with a bare
                  <code>url:</code>. Nothing to resolve relative to the module.
                </li>
                <li>
                  That's why <code>:direct</code>
                  is trivial here — one cross-origin <code>import()</code> and it's done.
                </li>
              </ul>
            </div>

            <%!-- metrics: three files --%>
            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <code class="text-sm font-mono font-semibold">metrics</code>
                <span class="badge badge-sm badge-ghost">three files · sibling assets</span>
              </div>
              <pre class="mt-3 bg-base-300/50 rounded-lg p-2.5 text-[0.7rem] leading-relaxed"><code>{@metrics_tree}</code></pre>
              <ul class="mt-3 text-sm text-base-content/70 space-y-2">
                <li>
                  The entry resolves its companions <strong>relative to itself</strong>
                  — <code>new URL("./metrics.css", import.meta.url)</code>
                  and the same for the JSON.
                </li>
                <li>
                  Because those URLs are <strong>origin-relative</strong>, the
                  <em>exact same bundle</em>
                  works unmodified in both modes: <code>import.meta.url</code>
                  is the CDN under <code>:direct</code>, and your same-origin
                  <code>/apps/metrics/main.mjs</code> under <code>:proxy</code>.
                </li>
                <li>
                  It's registered with <code>base:</code>
                  (the directory) + <code>entry:</code>, so all three files proxy
                  under one prefix — no per-file registration.
                </li>
              </ul>
            </div>
          </div>

          <%!-- the registration that ties it together --%>
          <div class="mt-4">
            <p class="text-sm text-base-content/70">
              Both are wired up in one config block — the single-file app gets a
              <code>url:</code>, the multi-file app a <code>base:</code>:
            </p>
            <pre class="mt-2 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@config_snippet}</code></pre>
          </div>
        </section>

        <%!-- See it in the Network tab --%>
        <section class="card bg-base-100 border border-base-300 rounded-xl p-6">
          <div class="flex items-center gap-2">
            <.icon name="hero-magnifying-glass" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">Watch the difference in DevTools</h2>
          </div>
          <p class="mt-2 text-base-content/70">
            Open the Network tab and reload. You'll see the two islands fetched from two
            different origins:
          </p>
          <ul class="mt-3 text-sm text-base-content/70 space-y-2">
            <li class="flex items-start gap-2">
              <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary shrink-0">:direct</code>
              <span>
                one request to <code>{@cdn}/hello/main.mjs</code>
                — a cross-origin document, served by <code>Caddy</code>.
              </span>
            </li>
            <li class="flex items-start gap-2">
              <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary shrink-0">:proxy</code>
              <span>
                three <strong>same-origin</strong>
                requests — <code>/apps/metrics/main.mjs</code>, <code>/apps/metrics/metrics.css</code>
                and <code>/apps/metrics/metrics.json</code>
                — each fetched by Phoenix from the CDN, cached, and served back with a short
                <code>max-age</code> + <code>ETag</code>. Reload again and the upstream answers
                Phoenix's conditional <code>GET</code> with a <code>304</code>.
              </span>
            </li>
          </ul>
        </section>
      </div>

      <:aside>
        <Layouts.info_panel title="External apps & the proxy">
          <p>
            The registry turns a <code>name</code>
            into a URL the browser loads. <code>:direct</code>
            hands out the CDN URL; <code>:proxy</code>
            hands out a <code>/apps/&lt;name&gt;</code>
            path and fetches the bytes server-side.
          </p>
          <:wire label="manifest">
            <code>&lt;KeenPhoenixSvelte.runtime&gt;</code>
            emits <code>name → url</code>; <code>AppsManager</code> imports from it.
          </:wire>
          <:wire label=":direct">
            Browser imports <code>{@cdn}/hello/main.mjs</code>. Needs CORS + a CSP that allows the CDN.
          </:wire>
          <:wire label=":proxy">
            Browser imports <code>/apps/metrics/*</code>; <code>KeenPhoenixSvelte.Apps.Proxy</code>
            fetches upstream. CSP <code>'self'</code>, no CORS.
          </:wire>
          <:wire label="revalidation">
            Cached in ETS; stale entries re-check upstream with a conditional
            <code>GET</code> (304 keep / 200 swap).
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
