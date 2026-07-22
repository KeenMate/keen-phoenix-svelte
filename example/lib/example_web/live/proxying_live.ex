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

  def mount(_params, _session, socket) do
    # Only render each card if its app is actually registered, so a deployment
    # that omits one from config degrades cleanly instead of 502-ing.
    manifest = KeenPhoenixSvelte.Apps.manifest()

    {:ok,
     assign(socket,
       cdn: @cdn,
       hello?: Map.has_key?(manifest, "hello"),
       metrics?: Map.has_key?(manifest, "metrics"),
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
