# Philosophy & how it compares

`keen_phoenix_svelte` has one governing idea: a Svelte app is an **autonomous
island**, not a template fragment. The page mounts it, hands it config and a
connection to the server, and then gets out of the way. Everything the app does
after that — rendering, local state, data fetching, charts, drag-and-drop — is the
app's own business.

This page explains that model, what it deliberately refuses to do, and how it
differs from [`live_svelte`](https://github.com/woutdp/live_svelte).

## The island model

An island is a self-contained Svelte app (a dashboard, an org-structure browser, a
map, a data grid) mounted into one element on the page. Its lifecycle is:

1. **Initialize with config.** The server renders `<.app name id props>`; the
   `props` are small per-component **configuration** — an org id, a feature flag,
   an initial toggle — *not* a payload. Big data is fetched by the island, not
   serialized into the DOM.
2. **Hand it a connection.** Through the [app boundary](server-communication.md#the-app-boundary)
   the island receives `context` (user, csrf, tokens, api base, socket), and —
   depending on the page — `live`, `api`, and `channel` to talk to the server.
3. **Let it own itself.** `phx-update="ignore"` keeps LiveView out of the
   island's DOM subtree. The app renders and re-renders on its own terms; the only
   thing that crosses the boundary afterward is data.

The page's job is to *place* islands and route them a server connection. The
island's job is everything inside its own box. That separation is the whole point.

## What we deliberately don't do

This library is opinionated by omission. It does **not**:

- **No `~V` sigil / no Svelte-in-HEEx.** You never write Svelte markup inside an
  Elixir template. An app is authored as a normal Svelte project under
  `assets/apps/<name>/` and compiled; Elixir only emits a mount point.
- **No server-rendered slots.** The server does not render Svelte content and pass
  it in (`@inner_block` → component). An island renders itself, top to bottom.
- **No SSR / no Node render runtime.** Islands mount and hydrate client-side. There
  is no Node process rendering Svelte on the server, and no server render pass to
  keep in sync with the client.
- **No interleaving of Elixir and Svelte.** The two sides meet only at the boundary
  — `props`, `context`, `live`, `api`, `channel` — never in the same template.

The payoff: no Node in your production render path, no server/client hydration
mismatch class of bugs, a hard boundary that keeps a complex Svelte app from
leaking into (or being disturbed by) LiveView's DOM patching, and the *same* app
running unchanged on a LiveView route or a plain controller page.

The cost is the flip side: this is the wrong tool for sprinkling a little
reactivity into otherwise server-rendered markup. That's not an island — and for
that, `live_svelte` is the better fit.

## How it compares to `live_svelte`

`live_svelte` and `keen_phoenix_svelte` sit at opposite ends of the
Phoenix-plus-Svelte design space. `live_svelte` **interleaves**: you render Svelte
from Elixir with the `~V` sigil, it does SSR through a Node runtime, and props flow
through LiveView's diff on every update — Svelte becomes a reactive view layer for
your server-rendered pages. `keen_phoenix_svelte` **isolates**: you mount compiled,
self-owning apps and talk to them through a narrow boundary.

| | `keen_phoenix_svelte` | `live_svelte` |
| --- | --- | --- |
| **Mental model** | Autonomous islands | Svelte as a LiveView view layer |
| **Authoring** | Normal Svelte project under `assets/apps/` | `~V` sigil / `.svelte` rendered from Elixir |
| **SSR** | None — client-side mount/hydrate | Yes, via a Node render runtime |
| **Server-rendered slots** | No | Yes |
| **DOM ownership** | The app owns its subtree (`phx-update="ignore"`) | LiveView patches the Svelte-rendered DOM |
| **Data flow** | Small `props` config + `live`/`api`/`channel` for data | Props diffed through LiveView on every change |
| **Plain (non-LiveView) pages** | First-class — `mountStatic()` mounts + `api`/`channel` | LiveView-centric |
| **Production deps** | No Node at render time | Node runtime for SSR |
| **Best for** | Rich, self-contained apps (dashboards, browsers, charts) | Reactive sprinkles in server-rendered markup |

Neither is "better" — they optimize for different things. Reach for `live_svelte`
when you want Svelte woven into LiveView-rendered pages with SSR. Reach for
`keen_phoenix_svelte` when the Svelte side is a substantial app that should own its
own world and merely needs a clean line to the server — including on pages that
aren't LiveView at all.

## When islands are the right call

Good signs you want this model:

- The Svelte side is a **real app**, not a widget — it has its own internal state,
  views, and lifecycle.
- You want the **same component** on both LiveView and plain controller pages, with
  the transport (`live.pushEvent` vs `api.post`) as the only difference.
- You don't want **Node in your production render path**, and you'd rather not
  reason about SSR hydration.
- You want a **hard boundary**: LiveView drives the page and navigation; the island
  owns its box; data crosses a small, explicit interface.

If instead you're enhancing mostly-server-rendered HTML with pockets of
reactivity, that's the interleaved model — and `live_svelte` is built for it.
