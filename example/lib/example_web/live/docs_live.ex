defmodule ExampleWeb.DocsLive do
  @moduledoc """
  A pocket version of the library docs, rendered inside the workspace shell.

  The full guides live in `keen_phoenix_svelte/docs/*.md` (and on HexDocs); this
  page distills the two questions people actually ask when they first see the demo:
  *"what do I have to write in <framework> to make an app?"* and *"how does the
  proxy / external-app loading work?"* — with the real adapter code the demo apps
  use. No island of its own; pure HEEx.
  """
  use ExampleWeb, :live_view

  # The one object every island's entry receives — the whole coupling to Phoenix.
  @boundary [
    %{name: "target", desc: "The element to mount into. You own everything inside it."},
    %{name: "props", desc: "Small per-island config from <.app props={…}> — config, not payload."},
    %{name: "context", desc: "Page-wide user, CSRF, tokens, api_base and socket — emitted once per page."},
    %{name: "live", desc: "The LiveView bridge: pushEvent / handleEvent / upload. null on plain pages."},
    %{name: "api", desc: "REST helper; attaches x-csrf-token + the session cookie."},
    %{name: "channel", desc: "Promise-based Phoenix channel factory with auto cid correlation."},
    %{name: "bus", desc: "Page-wide client-side event bus for island-to-island messaging — no server."}
  ]

  # One adapter per framework. `code` is the real `assets/apps/<name>/js/main.js`
  # (lightly trimmed) — the only glue between a framework and this library.
  @frameworks [
    %{
      key: "svelte",
      label: "Svelte 5",
      color: "#ff3e00",
      install: "npm i svelte @sveltejs/vite-plugin-svelte",
      note:
        "Runes ($state) must be compiled, so the mount logic lives in a .svelte.js module re-exported from main.js. Mirror server-pushed props into a local $state.",
      code: """
      // main.js — stable entry point
      export { default } from "./mount.svelte.js";

      // mount.svelte.js  (a .svelte.js so $state is compiled)
      import { mount, unmount } from "svelte";
      import App from "./App.svelte";

      export default (target, { props, ...boundary }) => {
        const state = $state({ ...props, ...boundary });
        const app = mount(App, { target, props: state });
        return {
          setProps: (next) => Object.assign(state, next), // server → island
          destroy: () => unmount(app),                    // teardown
        };
      };\
      """
    },
    %{
      key: "react",
      label: "React 18",
      color: "#61dafb",
      install: "npm i react react-dom",
      note:
        "esbuild compiles the JSX (no extra Vite plugin). Create a root, re-render on prop pushes, unmount on destroy.",
      code: """
      import { createElement } from "react";
      import { createRoot } from "react-dom/client";
      import App from "./App.jsx";

      export default (target, { props = {}, bus, context, live }) => {
        const root = createRoot(target);
        let all = { ...props, bus, context, live };
        const render = () => root.render(createElement(App, all));
        render();
        return {
          setProps: (next) => { all = { ...all, ...next }; render(); },
          destroy: () => root.unmount(),
        };
      };\
      """
    },
    %{
      key: "lit",
      label: "Lit / Web Component",
      color: "#324fff",
      install: "npm i lit",
      note:
        "A custom element already has its own lifecycle. Map props onto reactive properties (assigning re-renders) and forward its events to the bus.",
      code: """
      import "./KudosButton.js"; // defines <kudos-button> (extends LitElement)

      export default (target, { props = {}, bus }) => {
        const el = document.createElement("kudos-button");
        Object.assign(el, props);            // props → reactive properties
        el.addEventListener("kudos", (e) =>
          bus?.emit("activity", { title: "Kudos!", text: `Count ${e.detail.count}` }));
        target.appendChild(el);
        return {
          setProps: (next) => Object.assign(el, next),
          destroy: () => el.remove(),
        };
      };\
      """
    },
    %{
      key: "js",
      label: "Vanilla JS",
      color: "#f7df1e",
      install: "nothing — no dependency, no build plugin",
      note:
        "No framework at all. Build DOM, wire listeners, and clean them up in destroy so live navigation doesn't leak.",
      code: """
      export default (target, { props = {}, bus }) => {
        const root = document.createElement("div");
        const render = () => (root.textContent = props.label ?? "Hello");
        render();
        root.onclick = () => bus?.emit("activity", { title: "Vanilla JS" });
        target.appendChild(root);
        return {
          setProps: (next) => { props = { ...props, ...next }; render(); },
          destroy: () => root.remove(), // listeners on root go with it
        };
      };\
      """
    }
  ]

  @contract "(target, { props, context, live, api, channel, bus, el }) => { setProps, destroy }"

  @heex_snippet ~S|<.app name="kudos-lit" id="kudos-1" framework="lit" props={%{label: "Kudos"}} />|

  # `live` — piggyback on the LiveView's own websocket. Request/reply + server
  # pushes, no extra endpoint. `null` on a plain page, so pair it with an `api`
  # fallback (the Videos island does exactly this).
  @live_client """
  // Inside an island hosted by a LiveView — talks over the page's existing socket.
  live.pushEvent("save_video", { id }, (reply) => {
    saved = reply.saved;               // the server reply is authoritative
  });

  // Subscribe to server pushes (handler auto-removed on destroy):
  const ref = live.handleEvent("saved_changed", ({ ids }) => { savedIds = ids; });

  // Not on a LiveView page? `live` is null — fall back to REST over `api`:
  if (live) live.pushEvent("save_video", { id });
  else      await api.post(`/api/videos/${id}/save`, {});\
  """

  @live_server """
  # The host LiveView. The reply is authoritative; an updated assign flows back
  # into the island as a prop change (updated() -> setProps).
  def handle_event("save_video", %{"id" => id}, socket) do
    saved = toggle_saved(socket, id)
    {:reply, %{saved: saved}, assign(socket, saved: saved)}
  end
  """

  # `channel` — a *dedicated* Phoenix topic, independent of any LiveView. The
  # socket connects lazily from context.socket_path + context.socket_token, so it
  # works identically on a plain page. This is the chat island's transport.
  @channel_client """
  // A designated channel — its own topic, its own lifecycle (rooms, presence,
  // pub/sub). The socket connects lazily using context.socket_token.
  const ch = channel(`chat:${roomId}`);

  ch.on("new_message", ({ data }) => { messages = [...messages, data]; }); // server push
  ch.on("presence_diff", (diff) => { presences = applyDiff(presences, diff); });

  await ch.joined;                             // resolves once joined
  const { data } = await ch.push("history");   // push() resolves with the RAW reply
  await ch.push("send_message", { text });     // auto-attaches a `cid` correlation id

  ch.leave();                                  // on room switch / island destroy\
  """

  @channel_server """
  # Your app owns the socket + channels (authenticated with the socket_token).
  # keen_phoenix_svelte ships only the client — any Phoenix.Channel works.

  # user_socket.ex
  channel "chat:*", MyAppWeb.ChatChannel

  # chat_channel.ex — replies are envelope-agnostic; here a {data: …} shape.
  def join("chat:" <> room, _params, socket) do
    {:ok, %{data: %{messages: recent(room)}}, assign(socket, room: room)}
  end

  def handle_in("send_message", %{"text" => text}, socket) do
    msg = save_message(socket.assigns.room, text)
    broadcast!(socket, "new_message", %{data: msg})
    {:reply, {:ok, %{data: msg}}, socket}
  end
  """

  @proxy_config """
  # config/config.exs — register apps whose bundle lives elsewhere
  config :keen_phoenix_svelte,
    load_mode: :proxy,          # :direct (default) | :proxy
    proxy_path: "/apps",        # must match the router forward below
    apps: %{
      "org-chart" => "https://cdn.acme.com/islands/org-chart@1.4.2/main.mjs"
    }

  # router.ex — only needed for :proxy mode
  forward "/apps", KeenPhoenixSvelte.Apps.Proxy
  """

  @proxy_rows [
    %{k: "Who fetches the bytes", direct: "Browser → CDN", proxy: "Browser → your app → CDN"},
    %{k: "Manifest URL", direct: "the CDN URL", proxy: "/apps/<name> (same-origin)"},
    %{k: "CORS", direct: "required on the CDN", proxy: "none"},
    %{k: "CSP script-src", direct: "must allow the CDN", proxy: "'self'"},
    %{k: "Auth / gating / SRI", direct: "hard (public, cross-origin)", proxy: "easy (you serve it)"},
    %{k: "Server load", direct: "none (CDN edge)", proxy: "in path, cached (:persistent_term)"}
  ]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Docs",
       boundary: @boundary,
       frameworks: @frameworks,
       contract: @contract,
       heex_snippet: @heex_snippet,
       live_client: @live_client,
       live_server: @live_server,
       channel_client: @channel_client,
       channel_server: @channel_server,
       proxy_config: @proxy_config,
       proxy_rows: @proxy_rows
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:docs}
      title="Docs"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-4xl mx-auto space-y-12 pb-6">
        <%!-- Intro --%>
        <section class="pt-2">
          <span class="text-primary text-3xl leading-none">◆</span>
          <h1 class="text-3xl font-bold tracking-tight mt-3">How it works</h1>
          <p class="mt-3 text-base-content/70">
            A pocket guide to the two questions the demo raises: <strong>what do I write in each
            framework</strong>
            to make an island, and <strong>how does the app proxy work</strong>?
            The full guides live in
            <a
              href="https://hexdocs.pm/keen_phoenix_svelte"
              target="_blank"
              rel="noopener noreferrer"
              class="link link-primary"
            >the HexDocs</a>
            and in <code>keen_phoenix_svelte/docs/</code>.
          </p>
        </section>

        <%!-- The mount contract --%>
        <section>
          <h2 class="text-xl font-semibold">1 · The mount contract</h2>
          <p class="text-base-content/60 mt-1">
            An app is one folder under <code>assets/apps/&lt;name&gt;/</code>. Its
            <code>main.js</code>
            default-exports a single function. That's the entire API you implement — the same
            shape in every framework:
          </p>
          <pre class="mt-3 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs"><code>{@contract}</code></pre>
          <p class="text-base-content/60 mt-3">
            The library hands you the boundary, calls <code>setProps</code>
            when the server changes props, and <code>destroy</code>
            on teardown (live-nav or page leave). It never assumes a framework — that's why
            React, Lit, Svelte and plain JS all coexist.
          </p>
        </section>

        <%!-- The boundary --%>
        <section>
          <h2 class="text-xl font-semibold">2 · The boundary object</h2>
          <p class="text-base-content/60 mt-1">
            The second argument. Use only what you need — a static island can ignore all of it:
          </p>
          <div class="grid gap-3 sm:grid-cols-2 mt-4">
            <div
              :for={b <- @boundary}
              class="flex gap-3 items-baseline bg-base-100 border border-base-300 rounded-lg p-3"
            >
              <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary shrink-0">
                {b.name}
              </code>
              <p class="text-sm text-base-content/70">{b.desc}</p>
            </div>
          </div>
        </section>

        <%!-- Talking to the server over websockets --%>
        <section>
          <h2 class="text-xl font-semibold">3 · Talking to the server (websockets)</h2>
          <p class="text-base-content/60 mt-1">
            Two of the boundary pieces ride a websocket. Pick by lifetime:
            <code>live</code>
            piggybacks on the LiveView's own socket for request/reply tied to the page;
            <code>channel</code>
            opens a <strong>dedicated topic</strong>
            of your own (rooms, presence, pub/sub) that's independent of LiveView and works
            the same on a plain page.
          </p>

          <div class="mt-5 space-y-6">
            <%!-- live --%>
            <div class="card bg-base-100 border border-base-300 rounded-xl overflow-hidden">
              <div class="flex items-center gap-3 px-5 py-3 border-b border-base-300">
                <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary">
                  live
                </code>
                <h3 class="font-semibold text-sm">The LiveView bridge</h3>
                <span class="ml-auto text-xs text-base-content/50">
                  same socket · <code>null</code> on plain pages
                </span>
              </div>
              <div class="p-5 space-y-4">
                <p class="text-sm text-base-content/70">
                  Available only when the island is hosted in a LiveView. No separate endpoint —
                  <code>pushEvent</code>
                  / <code>handleEvent</code>
                  travel over the socket that's already open. <code>handleEvent</code>
                  subscriptions are removed automatically on <code>destroy</code>.
                </p>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40 mb-1.5">
                    Island (client)
                  </p>
                  <pre class="bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs leading-relaxed"><code>{@live_client}</code></pre>
                </div>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40 mb-1.5">
                    Host LiveView (server)
                  </p>
                  <pre class="bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs leading-relaxed"><code>{@live_server}</code></pre>
                </div>
              </div>
            </div>

            <%!-- channel --%>
            <div class="card bg-base-100 border border-base-300 rounded-xl overflow-hidden">
              <div class="flex items-center gap-3 px-5 py-3 border-b border-base-300">
                <code class="text-xs font-mono px-2 py-0.5 rounded bg-primary/10 text-primary">
                  channel
                </code>
                <h3 class="font-semibold text-sm">A dedicated Phoenix channel</h3>
                <span class="ml-auto text-xs text-base-content/50">
                  own topic · works on plain pages
                </span>
              </div>
              <div class="p-5 space-y-4">
                <p class="text-sm text-base-content/70">
                  A promise-based wrapper over a Phoenix channel. The socket connects lazily from
                  <code>context.socket_path</code>
                  + <code>context.socket_token</code>, so it needs no LiveView.
                  <code>push()</code>
                  is <strong>envelope-agnostic</strong>
                  — it resolves with the raw reply (you read <code>reply.data</code>
                  / <code>reply.error</code>) and auto-attaches a <code>cid</code>
                  correlation id.
                </p>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40 mb-1.5">
                    Island (client)
                  </p>
                  <pre class="bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs leading-relaxed"><code>{@channel_client}</code></pre>
                </div>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40 mb-1.5">
                    Socket + channel (server)
                  </p>
                  <pre class="bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs leading-relaxed"><code>{@channel_server}</code></pre>
                </div>
              </div>
            </div>
          </div>

          <p class="text-sm text-base-content/50 mt-4">
            The <.link navigate={~p"/chat"} class="link link-primary">Chat</.link>
            island runs on <code>channel</code>
            + Presence; <.link navigate={~p"/videos"} class="link link-primary">Videos</.link>
            uses the <code>live</code>/<code>api</code>
            fallback pair above. <code>keen_phoenix_svelte</code>
            provides only the client — it doesn't depend on any particular channel framework.
          </p>
        </section>

        <%!-- Per-framework adapters --%>
        <section>
          <h2 class="text-xl font-semibold">4 · The adapter, per framework</h2>
          <p class="text-base-content/60 mt-1">
            Every framework needs a tiny <code>main.js</code>
            that maps its own render/teardown model onto <code>{"{ setProps, destroy }"}</code>. These
            are the actual adapters the demo islands ship — usually under 15 lines.
          </p>

          <div class="space-y-5 mt-5">
            <div
              :for={f <- @frameworks}
              class="card bg-base-100 border border-base-300 rounded-xl overflow-hidden"
            >
              <div class="flex items-center gap-3 px-5 py-3 border-b border-base-300">
                <span class="size-3 rounded-full shrink-0" style={"background:#{f.color}"} />
                <h3 class="font-semibold">{f.label}</h3>
                <code class="ml-auto text-xs text-base-content/60 hidden sm:block px-2.5 py-1 rounded-md bg-base-200 border border-base-300">
                  {f.install}
                </code>
              </div>
              <div class="p-5 space-y-3">
                <p class="text-sm text-base-content/70">{f.note}</p>
                <pre class="bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs leading-relaxed"><code>{f.code}</code></pre>
              </div>
            </div>
          </div>

          <p class="text-sm text-base-content/50 mt-4">
            No central registration — the builder discovers <code>assets/apps/*</code>
            automatically and each builds to <code>priv/static/apps/&lt;name&gt;/main.mjs</code>,
            a self-contained ES module with its CSS injected by JS. The hook
            <code>import()</code>s it on demand, so a page only fetches the islands it shows.
          </p>
        </section>

        <%!-- Rendering --%>
        <section>
          <h2 class="text-xl font-semibold">5 · Dropping it on a page</h2>
          <p class="text-base-content/60 mt-1">
            Render a mount point anywhere — a LiveView or a plain controller page. On a plain
            page <code>live</code>
            is <code>null</code>
            and the island mounts via <code>mountStatic()</code>; the code above doesn't change.
          </p>
          <pre class="mt-3 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs"><code>{@heex_snippet}</code></pre>
          <ul class="mt-3 text-sm text-base-content/70 list-disc pl-5 space-y-1">
            <li><code>name</code> — the folder under <code>assets/apps/</code>.</li>
            <li><code>id</code> — required, unique and stable (the LiveView hook keys on it).</li>
            <li>
              <code>framework</code>
              — optional, informational only (becomes a <code>data-framework</code>
              attribute).
            </li>
            <li>
              <code>props</code>
              — small config. For big datasets pass an id and let the island fetch/subscribe.
            </li>
          </ul>
        </section>

        <%!-- Proxy / external apps --%>
        <section>
          <h2 class="text-xl font-semibold">6 · External apps & the proxy</h2>
          <p class="text-base-content/60 mt-1">
            By default an island is local — imported from <code>/apps/&lt;name&gt;/main.mjs</code>
            on your own static path, no config. You only <em>register</em>
            an app when its bundle lives <strong>elsewhere</strong>
            (a shared CDN, another team's deploy, a DB-driven catalogue). The server emits a
            <code>name → url</code>
            manifest and the client imports from there.
          </p>

          <p class="text-base-content/60 mt-4">
            The one real choice is <strong>who fetches the bytes</strong>, because
            <code>import(url)</code>
            runs in the browser:
          </p>

          <div class="overflow-x-auto mt-3">
            <table class="table table-sm bg-base-100 border border-base-300 rounded-lg">
              <thead>
                <tr>
                  <th></th>
                  <th><code class="text-primary">:direct</code></th>
                  <th><code class="text-primary">:proxy</code></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={r <- @proxy_rows}>
                  <td class="font-medium text-base-content/70">{r.k}</td>
                  <td class="text-base-content/70">{r.direct}</td>
                  <td class="text-base-content/70">{r.proxy}</td>
                </tr>
              </tbody>
            </table>
          </div>

          <p class="text-base-content/60 mt-4">
            <code>:proxy</code>
            is the corporate-friendly mode: it turns a cross-origin bundle into a first-party
            asset, sidestepping CORS and a strict CSP. Phoenix fetches the upstream once, caches
            it in <code>:persistent_term</code>, and re-serves it same-origin. It's the mode the
            <.link navigate={~p"/"} class="link link-primary">home page</.link>
            demo uses for its externally-loaded <code>greeter</code> island.
          </p>

          <pre class="mt-3 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs"><code>{@proxy_config}</code></pre>

          <p class="text-sm text-base-content/50 mt-3">
            Version your CDN URLs (<code>…/org-chart@1.4.2/…</code>) so a new version is a new
            URL — same name, fresh bundle, no stale cache. The registry is just data: build the
            same map from a database at runtime with
            <code>Application.put_env/3</code>; it's read per request.
          </p>
        </section>

        <%!-- Footer nav --%>
        <section class="flex flex-wrap gap-3 pt-2 border-t border-base-300 text-sm">
          <.link navigate={~p"/"} class="link link-primary">← Back to the overview</.link>
          <span class="text-base-content/30">·</span>
          <a
            href="https://github.com/KeenMate/keen-phoenix-svelte"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >
            Source on GitHub
          </a>
          <span class="text-base-content/30">·</span>
          <a
            href="https://hexdocs.pm/keen_phoenix_svelte"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >
            Full docs on HexDocs
          </a>
        </section>
      </div>
    </Layouts.workspace>
    """
  end
end
