defmodule ExampleWeb.HomeLive do
  @moduledoc """
  Welcome page — a full-width explainer of what KeenSpace demonstrates: the
  island model, the app boundary, and the client-side event bus. No island of its
  own; pure HEEx chrome (the shell + this content).
  """
  use ExampleWeb, :live_view

  # The three feature areas, each showcasing a different way an island reaches
  # back to the server.
  @areas [
    %{
      to: "/chat",
      icon: "hero-chat-bubble-left-right",
      title: "Chat",
      transport: "channel + Presence",
      blurb:
        "Team rooms with live messages and an online-presence list, over a Phoenix channel. Click an avatar and the host LiveView loads that person's profile beside the island."
    },
    %{
      to: "/videos",
      icon: "hero-play-circle",
      title: "Videos",
      transport: "api + live",
      blurb:
        "A catalogue loaded over REST with an in-page Plyr player. \"Save\" pushes over the LiveView socket — or falls back to api.post on a plain page."
    },
    %{
      to: "/calendar",
      icon: "hero-calendar-days",
      title: "Calendar",
      transport: "context.tokens + fetch + channel",
      blurb:
        "Today's agenda from a simulated Microsoft Graph via a bearer token. \"Join online\" opens a per-meeting chat over a channel — one island, two transports."
    }
  ]

  # The one object every island's entry receives — the only coupling to Phoenix.
  @boundary [
    %{name: "props", desc: "Small per-island config, rendered by <.svelte props={…}>."},
    %{
      name: "context",
      desc: "Page-wide user, CSRF, tokens, api_base and socket — emitted once per page."
    },
    %{
      name: "live",
      desc: "The LiveView bridge: pushEvent / handleEvent / upload. null on plain pages."
    },
    %{name: "api", desc: "REST helper; attaches x-csrf-token + the session cookie."},
    %{name: "channel", desc: "Promise-based Phoenix channel factory with auto cid correlation."},
    %{
      name: "bus",
      desc: "Page-wide client-side event bus for island-to-island messaging — no server."
    }
  ]

  def mount(_params, _session, socket) do
    # Only show the external-island demo when a "greeter" app is registered
    # (config-driven). Lets prod omit it cleanly if it isn't configured.
    greeter? = Map.has_key?(KeenPhoenixSvelte.Apps.manifest(), "greeter")

    {:ok,
     assign(socket,
       areas: @areas,
       boundary: @boundary,
       greeter?: greeter?,
       page_title: "Welcome"
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:home}
      title="Welcome"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-4xl mx-auto space-y-12 pb-6">
        <%!-- Hero --%>
        <section class="text-center pt-2">
          <span class="text-primary text-4xl leading-none">◆</span>
          <h1 class="text-3xl font-bold tracking-tight mt-3">
            Welcome to KeenSpace, {@current_user.name |> String.split() |> hd()}
          </h1>
          <p class="mt-3 text-base-content/70 max-w-2xl mx-auto">
            A Teams-style workspace demo for <code>keen_phoenix_svelte</code>
            — a library that auto-mounts compiled <strong>Svelte 5</strong>
            apps into <strong>Phoenix</strong>
            (LiveView <em>and</em>
            plain pages) as
            self-contained <strong>islands</strong>.
          </p>
          <p class="mt-2 text-sm text-base-content/50 max-w-2xl mx-auto">
            Each area is an autonomous Svelte app: configured, handed a connection, then fully
            self-owning. No <code>~V</code>
            sigil, no server-rendered slots, no SSR — the opposite of interleaving Elixir and Svelte.
          </p>
        </section>

        <%!-- Feature areas --%>
        <section>
          <h2 class="text-xl font-semibold">Three areas, three transports</h2>
          <p class="text-base-content/60 mt-1">
            Every island is a separate compiled bundle, mounted into a plain <code>&lt;div&gt;</code>.
            What differs is how each one talks to the server.
          </p>

          <div class="grid gap-4 sm:grid-cols-3 mt-5">
            <.link
              :for={a <- @areas}
              navigate={a.to}
              class="card bg-base-100 border border-base-300 hover:border-primary hover:shadow-md transition p-5 flex flex-col"
            >
              <.icon name={a.icon} class="size-8 text-primary" />
              <h3 class="font-semibold mt-3">{a.title}</h3>
              <code class="text-[0.7rem] text-primary mt-1">{a.transport}</code>
              <p class="text-sm text-base-content/60 mt-2 flex-1">{a.blurb}</p>
              <span class="text-sm text-primary font-medium mt-3 inline-flex items-center gap-1">
                Open <.icon name="hero-arrow-right-micro" class="size-4" />
              </span>
            </.link>
          </div>
        </section>

        <%!-- The boundary --%>
        <section>
          <h2 class="text-xl font-semibold">The app boundary</h2>
          <p class="text-base-content/60 mt-1">
            Every island's entry receives one object — that's the entire coupling to Phoenix:
          </p>
          <pre class="mt-3 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-xs"><code>{"(target, { props, context, live, api, channel, bus, el }) => handle"}</code></pre>

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

        <%!-- Any framework — same boundary --%>
        <section>
          <h2 class="text-xl font-semibold">Any framework — same boundary</h2>
          <p class="text-base-content/60 mt-1">
            The three areas above are <strong>Svelte</strong>, but the mount contract is
            framework-neutral. Below are three more islands — Lit, React and vanilla JS —
            each mounted through the same <code>&lt;.app&gt;</code>
            component. There are no per-framework variants; the optional <code>framework</code>
            attribute is just an informational <code>data-framework</code>
            tag. Click them — they all reach the activity bus.
          </p>
          <p class="text-base-content/50 text-sm mt-1">
            Each passes its own <code>&lt;:placeholder&gt;</code>
            shaped like the control it's loading — a pill for Kudos, four buttons for
            reactions, a bar for the ticker — instead of the server-wide skeleton. Throttle
            your network (DevTools → Slow 3G) and reload to watch them resolve.
          </p>

          <div class="grid gap-4 sm:grid-cols-3 mt-5">
            <div class="card bg-base-100 border border-base-300 rounded-lg p-5">
              <code class="text-xs text-primary">&lt;.app framework="lit"&gt;</code>
              <div class="mt-3">
                <.app name="kudos-lit" id="kudos-lit-app" framework="lit" props={%{label: "Kudos"}}>
                  <:placeholder>
                    <div class="skeleton h-9 w-32 rounded-full"></div>
                  </:placeholder>
                </.app>
              </div>
              <p class="text-sm text-base-content/60 mt-3">
                A Lit web component (shadow-DOM styles).
              </p>
            </div>

            <div class="card bg-base-100 border border-base-300 rounded-lg p-5">
              <code class="text-xs text-primary">&lt;.app framework="react"&gt;</code>
              <div class="mt-3">
                <.app name="reactions-react" id="reactions-react-app" framework="react" props={%{}}>
                  <:placeholder>
                    <div class="flex gap-2">
                      <div class="skeleton h-9 w-14 rounded-lg"></div>
                      <div class="skeleton h-9 w-14 rounded-lg"></div>
                      <div class="skeleton h-9 w-14 rounded-lg"></div>
                      <div class="skeleton h-9 w-14 rounded-lg"></div>
                    </div>
                  </:placeholder>
                </.app>
              </div>
              <p class="text-sm text-base-content/60 mt-3">React 18 + hooks, JSX built by esbuild.</p>
            </div>

            <div class="card bg-base-100 border border-base-300 rounded-lg p-5">
              <code class="text-xs text-primary">&lt;.app framework="js"&gt;</code>
              <div class="mt-3">
                <.app name="hello-js" id="hello-js-app" framework="js" props={%{}}>
                  <:placeholder>
                    <div class="skeleton h-14 w-full rounded-lg"></div>
                  </:placeholder>
                </.app>
              </div>
              <p class="text-sm text-base-content/60 mt-3">Plain JavaScript — no framework at all.</p>
            </div>
          </div>

          <p class="text-sm mt-4">
            <.link navigate={~p"/docs"} class="link link-primary inline-flex items-center gap-1">
              See the adapter each framework needs <.icon name="hero-arrow-right-micro" class="size-4" />
            </.link>
          </p>
        </section>

        <%!-- Event bus + activity toasts (the highlight) --%>
        <section class="card bg-base-100 border border-base-300 rounded-xl p-6">
          <div class="flex items-center gap-2">
            <.icon name="hero-bolt" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">Islands talking to each other — the event bus</h2>
          </div>
          <p class="mt-2 text-base-content/70">
            <code>live</code>, <code>api</code>
            and <code>channel</code>
            all reach the <em>server</em>. The <code>bus</code>
            is different: a page-wide, <strong>client-side</strong>
            event bus so independent islands can coordinate <strong>without the server and without knowing about each other</strong>. It behaves
            identically with or without LiveView.
          </p>

          <div class="grid gap-4 md:grid-cols-3 mt-5">
            <div class="rounded-lg border border-primary/30 bg-primary/5 p-4">
              <p class="font-mono text-xs text-primary">activity island</p>
              <p class="text-sm text-base-content/70 mt-1">
                Mounted once in the shell. Knows nothing about the others — it just
                <code>bus.on("activity", …)</code>
                and shows a toast.
              </p>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <p class="font-mono text-xs text-base-content/70">video-catalogue</p>
              <p class="text-sm text-base-content/70 mt-1">
                On save →<br />
                <code>{~s|bus.emit("activity", {title: "Saved…"})|}</code>
              </p>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <p class="font-mono text-xs text-base-content/70">calendar</p>
              <p class="text-sm text-base-content/70 mt-1">
                On "Join online" →<br />
                <code>{~s|bus.emit("activity", {title: "Joined meeting"})|}</code>
              </p>
            </div>
          </div>

          <p class="mt-4 text-sm text-base-content/50">
            Try it: <.link navigate={~p"/videos"} class="link link-primary">save a video</.link>
            or <.link navigate={~p"/calendar"} class="link link-primary">join a meeting</.link>
            and watch the toast fire in the corner — three separate bundles, coordinating over the bus.
          </p>
        </section>

        <%!-- Externally-loaded island (app registry + proxy vs direct) --%>
        <section :if={@greeter?} class="card bg-base-100 border border-base-300 rounded-xl p-6">
          <div class="flex items-center gap-2">
            <.icon name="hero-globe-alt" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">An island loaded from elsewhere</h2>
          </div>
          <p class="mt-2 text-base-content/70">
            Islands don't have to live under <code>/apps</code>. The one below is a
            framework-free bundle registered in config; the server emits a <code>name → url</code>
            manifest and the client imports it from there. A config toggle picks the <strong>mode of operation</strong>:
          </p>
          <ul class="mt-2 text-sm text-base-content/70 list-disc pl-5 space-y-1">
            <li>
              <code>:direct</code>
              — the browser imports the CDN URL itself (needs CORS + a permissive CSP).
            </li>
            <li>
              <code>:proxy</code>
              — the browser imports a same-origin path and Phoenix fetches the bundle
              upstream (<code>KeenPhoenixSvelte.Apps.Proxy</code>) — no CORS, CSP <code>'self'</code>, the corporate-friendly mode.
              <strong>Active here in dev.</strong>
            </li>
          </ul>

          <div class="mt-4">
            <.svelte name="greeter" id="greeter-app" props={%{via: "the app registry (proxy mode)"}} />
          </div>
        </section>

        <%!-- Plain pages --%>
        <section class="text-sm text-base-content/60">
          <h2 class="text-xl font-semibold text-base-content">Works without LiveView, too</h2>
          <p class="mt-1">
            The very same island runs on a plain, controller-rendered page via
            <code>mountStatic()</code>
            with <code>live: null</code>
            — proof the apps don't depend on LiveView. See <.link
              navigate={~p"/calendar-plain"}
              class="link link-primary"
            >the plain calendar page</.link>,
            where the agenda and meeting chat work unchanged.
          </p>
        </section>
      </div>
    </Layouts.workspace>
    """
  end
end
