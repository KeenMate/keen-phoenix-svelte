# Worked example: a page of islands

The single-app snippets elsewhere in these docs show the mechanics. This page
shows the point of the library: **several independent apps on one page**, each
lazily loaded, each handed the same page context, each choosing its own transport
to the server — with no coordination between them and no per-app `<script>`/`<link>`
wiring.

The scenario is a **team dashboard** with four islands:

| App | What it is | Reaches its data via |
| --- | --- | --- |
| `kpi-cards` | A row of headline stat cards | `api` (REST to your backend, fetch on mount) |
| `org-browser` | An org tree with charts (lots of data) | `channel` (join a topic, stream) |
| `graph-calendar` | Upcoming meetings from **Microsoft Graph** | its **own `fetch`** + a shared Entra token from `context.tokens` |
| `activity-feed` | A live-updating event feed | `live` (LiveView push/handle) |

Four jobs, four different ways to reach data — one page. And note the third one
doesn't call *your* server at all: it calls a **different service** directly.

## 1. Folder layout — one folder per app

Apps are discovered by folder; there is no central registry. Add three folders
under `assets/apps/`:

```
assets/apps/
  kpi-cards/
    js/{ App.svelte, main.js, mount.svelte.js }
  org-browser/
    js/{ App.svelte, main.js, mount.svelte.js }
  graph-calendar/
    js/{ App.svelte, main.js, mount.svelte.js }
  activity-feed/
    js/{ App.svelte, main.js, mount.svelte.js }
```

Each builds to `priv/static/apps/<name>/main.mjs` — a self-contained ES module.
See [Authoring apps](authoring-apps.md) for what goes in each folder.

## 2. The page — drop in the mount points

Each app is one `<.svelte>` tag. `name` picks the folder; `id` must be unique and
stable; `props` is small **config, not payload** — an org id, a date range, a
count — never the data itself.

```heex
<!-- lib/my_app_web/live/dashboard_live.ex (render/1) -->
<div class="dashboard">
  <.svelte name="kpi-cards" id="kpi-cards" props={%{team_id: @team_id}} />

  <.svelte
    name="org-browser"
    id="org-browser"
    props={%{root_id: @team_id, depth: 3}}
  />

  <.svelte name="graph-calendar" id="graph-calendar" props={%{days: 7}} />

  <.svelte
    name="activity-feed"
    id="activity-feed"
    props={%{team_id: @team_id, page_size: 25}}
  />
</div>
```

That's the whole server side. Each `<.svelte>` renders a hook-bound `<div>` with
`phx-update="ignore"`, `data-app`, and JSON `data-props`. When the page loads,
`AppsManager` `import()`s **only** these four bundles — an app you don't place is
never fetched.

## 3. One context for the whole page

The per-page context is emitted **once** in the root layout, and every island on
the page receives the same object as `context`. You render it a single time no
matter how many apps the page has:

```heex
<!-- root.html.heex -->
<KeenPhoenixSvelte.runtime context={
  %{
    user: %{id: @current_user.id, name: @current_user.name, roles: @current_user.roles},
    csrf_token: get_csrf_token(),
    api_base: "/api",
    socket_path: "/socket",
    socket_token: Phoenix.Token.sign(MyAppWeb.Endpoint, "user socket", @current_user.id),
    # Shared token for a *different* service (see graph-calendar in §4).
    tokens: %{graph: MyApp.Entra.on_behalf_of_token(@current_user, ~w(Calendars.Read))}
  }
} />
```

Every app reads the shared page-wide facts it needs — `context.user`,
`context.api_base`, `context.socket_*`, and here `context.tokens.graph`. See
[Server communication](server-communication.md) for the full boundary.

## 4. Each app picks its transport

The apps never talk to each other directly. Each is the **same mount boilerplate**
plus an `App.svelte` that reaches for the one piece of the
[boundary](server-communication.md#the-app-boundary) its job needs. They're mounted
by the same hook but are otherwise strangers.

Every app's `mount.svelte.js` is identical — it just hands the boundary to the
component (exactly as in [Authoring apps](authoring-apps.md)). Write it once and
copy it into each app:

```js
// <app>/js/mount.svelte.js — the same for every app
import { mount, unmount } from "svelte";
import App from "./App.svelte";

export default (target, { props, context, live, api, channel }) => {
  const state = $state({ ...props, context, live, api, channel });
  const instance = mount(App, { target, props: state });
  return {
    setProps: (next) => Object.assign(state, next),
    destroy: () => unmount(instance),
  };
};
```

So each `App.svelte` receives its `props` **plus** `context` / `live` / `api` /
`channel` through `$props()`. The distinctive part of every app is just the
component — here is the data-loading slice of each:

**`kpi-cards` — REST to your backend (`api`):**

```svelte
<!-- kpi-cards/js/App.svelte -->
<script>
  let { team_id, api } = $props();
  let cards = $state([]);

  // Runs on mount, and re-fetches if the server pushes a new team_id.
  $effect(() => {
    api.get(`/api/teams/${team_id}/kpis`).then((c) => (cards = c));
  });
</script>

{#each cards as card}
  <KpiCard {...card} />
{/each}
```

**`org-browser` — stream a big tree over a channel (`channel`):**

```svelte
<!-- org-browser/js/App.svelte -->
<script>
  let { root_id, depth, channel } = $props();
  let nodes = $state([]);

  $effect(() => {
    const org = channel(`org:${root_id}`, { depth });
    org.joined.then(() => org.push("load", {}).then((reply) => (nodes = reply.nodes)));
    org.on("node_changed", ({ node }) => upsert(nodes, node));
    return () => org.leave();          // cleanup on prop change / unmount
  });
</script>
```

Note the channel teardown lives in the component's `$effect` cleanup — nothing
app-specific leaks back into `mount.svelte.js`.

**`graph-calendar` — call a *different* service with a shared Entra token (`context.tokens`):**

Here our Phoenix app and Microsoft Graph both authenticate against **Microsoft
Entra ID**, so a token minted for the signed-in user is accepted by Graph. The
server does the on-behalf-of exchange and drops a short-lived, narrowly-scoped
access token into `context.tokens.graph` (see the runtime context in §3). The
component calls Graph **directly with its own `fetch`** — it never routes through
your Phoenix backend:

```svelte
<!-- graph-calendar/js/App.svelte -->
<script>
  let { days, context } = $props();
  let events = $state([]);

  $effect(() => {
    const now = new Date().toISOString();
    const end = new Date(Date.now() + days * 864e5).toISOString();
    fetch(
      `https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=${now}&endDateTime=${end}`,
      { headers: { Authorization: `Bearer ${context.tokens.graph}` } },  // Entra token
    )
      .then((r) => r.json())
      .then(({ value }) => (events = value));
  });
</script>
```

Three things to notice:

- **It uses `context` only** — not `live`, `api`, or `channel`. The library's job
  ends at handing the island a token; the call to the third party is the app's own.
- **Don't use `api` for this.** `api` is glued to *your* Phoenix origin — it
  attaches your CSRF token and same-origin session cookie, which mean nothing to
  `graph.microsoft.com` and must not be sent to it. Cross-service calls are a raw
  `fetch` with the bearer token.
- **Token hygiene.** That token lands in the page's context JSON, readable by
  client JS — which is fine for an access token an SPA-style island uses, *if* you
  mint it **short-lived and least-privilege** (only the scopes this widget needs,
  here `Calendars.Read`) and let it expire rather than issuing a long-lived one.

Because it depends on nothing LiveView-specific, `graph-calendar` also works
**unchanged** on a plain page (next section) — `context` is delivered there too.

**`activity-feed` — live updates over the LiveView socket (`live`):**

```svelte
<!-- activity-feed/js/App.svelte -->
<script>
  let { team_id, page_size, live } = $props();
  let events = $state([]);

  $effect(() => {
    live.pushEvent("feed:load", { team_id, limit: page_size }, (r) => (events = r.events));
    live.handleEvent("feed:new", ({ event }) => events.unshift(event));  // auto-removed on destroy
  });
</script>
```

`activity-feed` uses `live`, which only exists inside a LiveView — which brings us
to the same page *without* one.

## 5. The same four apps on a plain page

Put the identical mount points on a controller-rendered page and they mount just
the same — `mountStatic()` scans `[data-app]` and mounts each with `live: null`:

```heex
<!-- lib/my_app_web/controllers/page_html/dashboard.html.heex -->
<div class="dashboard">
  <.svelte name="kpi-cards" id="kpi-cards" props={%{team_id: @team_id}} />
  <.svelte name="org-browser" id="org-browser" props={%{root_id: @team_id, depth: 3}} />
  <.svelte name="graph-calendar" id="graph-calendar" props={%{days: 7}} />
  <.svelte name="activity-feed" id="activity-feed" props={%{team_id: @team_id, page_size: 25}} />
</div>
```

`kpi-cards` (REST), `org-browser` (channel), and `graph-calendar` (its own `fetch`
+ Entra token) work unchanged — none of them depends on LiveView. Only
`activity-feed` must feature-detect and degrade, because `live` is `null` here:

```svelte
<!-- activity-feed/js/App.svelte — works on both LiveView and plain pages -->
<script>
  let { team_id, page_size, live, channel } = $props();
  let events = $state([]);

  $effect(() => {
    if (live) {
      live.pushEvent("feed:load", { team_id, limit: page_size }, (r) => (events = r.events));
      live.handleEvent("feed:new", ({ event }) => events.unshift(event));
    } else {
      const feed = channel(`feed:${team_id}`);        // fall back to a channel
      feed.joined.then(() => feed.push("load", { limit: page_size }).then((r) => (events = r.events)));
      feed.on("new", ({ event }) => events.unshift(event));
      return () => feed.leave();
    }
  });
</script>
```

That `if (live) … else …` is the core pattern (the §4 version assumed a LiveView;
the both-pages version just adds the `else`): an island runs anywhere, and the only
thing that changes is how it reaches the server.

## 6. What you get — and the one cost

- **Independent lifecycles.** Each app mounts, updates, and tears down on its own.
  One app throwing on mount doesn't take the others down.
- **Lazy, per-page loading.** Only the bundles actually on the page are fetched;
  a four-app dashboard and a one-app page share nothing but the context.
- **No cross-app coupling.** Apps coordinate through the *server* (a channel
  broadcast, a LiveView event), never by reaching into each other's DOM or state.
  That's what keeps a busy page debuggable. And an island isn't limited to your
  server — `graph-calendar` reaches a wholly separate service on its own.

The cost to know about: **each app bundle includes its own copy of the Svelte
runtime (~71 kB).** Four apps on a page means four copies. For a handful of
islands that's fine; if you ship many apps on one page, externalize `svelte` into
a shared chunk (see the note in the project README / CHANGELOG). Everything else
about the model scales linearly — add a folder, add a `<.svelte>` tag, done.
