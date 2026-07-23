# keen_phoenix_svelte

**🌐 Live demo & docs: [keen-phoenix-svelte.keenmate.dev](https://keen-phoenix-svelte.keenmate.dev)** ·
[Hex](https://hex.pm/packages/keen_phoenix_svelte) ·
[HexDocs](https://hexdocs.pm/keen_phoenix_svelte)

Auto-mount compiled **Svelte** (React, Lit, …) apps into **Phoenix** — on both
**LiveView** and plain controller-rendered pages — as self-contained islands, each
handed a user context and a standardized way to talk to the server.

You write:

```heex
<.app name="org-browser" id="org-42" props={%{org_id: 42}} />
```

…and the compiled Svelte app in `assets/apps/org-browser/` is mounted into that
element, kept in sync with server state, given a `context`/`api`/`channel`/`live`
bridge, and torn down on navigation — no manual `<script>`/`<link>` wiring per page.

This is the **island** model: the page says *"mount this app here, hand it config
and a server connection"*, and the Svelte app owns everything after that. It is
deliberately *not* `live_svelte` — no `~V` sigil, no server-rendered slots, no SSR
Node runtime.

## Repository layout

```
keen_phoenix_svelte/   # the library: Hex package + npm @keenmate/phoenix_svelte
example/               # runnable Phoenix 1.8 LiveView demo using it
Makefile               # task runner
```

## Requirements

- Elixir ~> 1.15 and Phoenix ~> 1.8 (Erlang/OTP 26+)
- Node 18+ / npm (for the Svelte/Vite build)

## Quick start

```bash
make setup     # deps + npm install + build assets
make dev       # start the server on http://localhost:4000
```

Then open:

- **http://localhost:4000/** — the demo `like` app inside a **LiveView**; clicks
  go over the socket (`live.pushEvent`), state owned by the server.
- **http://localhost:4000/plain** — the *same* app on a **plain controller page**;
  no LiveView, so it talks to the backend over **REST** (`api.post`, CSRF+session).

Same component, different transport — that's the point.

## How it works

Two cooperating halves:

| Half | Responsibility |
| --- | --- |
| **Elixir** | `<.app>` renders a hook-bound `<div>` (`phx-update="ignore"`, `data-app`, JSON `data-props`); `<KeenPhoenixSvelte.runtime>` emits the page context. |
| **JS** | The `KeenSvelte` hook mounts the island inside a LiveView; `AppsManager` lazily `import()`s `/apps/<name>/main.mjs` (or a registered URL); `mountStatic()` mounts islands on plain pages. Any framework's bundle mounts through the same contract. |

Because LiveView owns the DOM, `phx-update="ignore"` keeps it out of the
Svelte-owned subtree, and the hook drives mount / prop-update / teardown across
live navigation. Only the bundles actually on a page are ever fetched.

### What an app receives

Each app's entry is `(target, { props, context, live, api, channel, el }) => handle`:

- `props` — small per-component config (config, not payload)
- `context` — page-wide user / csrf / tokens / api_base / socket
- `live` — LiveView bridge (`pushEvent`/`handleEvent`/`upload`), or `null` on plain pages
- `api` — REST helper to your Phoenix backend (CSRF token + session cookie attached)
- `channel` — Phoenix channel factory (promise join/push/on; envelope-agnostic; auto `cid`)

```js
if (live) {
  live.pushEvent("toggle_like", { id });                  // LiveView socket
} else {
  const { liked } = await api.post("/api/like", { id });  // REST, CSRF+session
}
```

## Documentation

The library and its guides live in [`keen_phoenix_svelte/`](keen_phoenix_svelte):

- [Installation & setup](keen_phoenix_svelte/docs/installation.md) — wire it into your app
- [Authoring apps](keen_phoenix_svelte/docs/authoring-apps.md) — folder layout, mount contract, Svelte 5 & 4
- [Server communication](keen_phoenix_svelte/docs/server-communication.md) — context, `live`, `api`, `channel`

## Commands

| `make …` | Runs |
| --- | --- |
| `setup` | deps + `npm install` + build assets |
| `dev` / `server` | `mix phx.server` |
| `build-assets` | build Svelte apps + JS + CSS (`mix assets.build`) |
| `test` | `mix test` |
| `clean` | remove `_build`, `deps`, `node_modules`, built assets |

During development, `make dev` also runs the Svelte builder as a file watcher, so
editing an app under `assets/apps/` rebuilds its bundle automatically.

## Versioning

The library ships as a **dual package** — the Hex library `keen_phoenix_svelte`
and the npm package `@keenmate/phoenix_svelte` — released **in lockstep at the same
version**. Install matching versions of both.

## License

MIT.
