# keen_phoenix_svelte

**🌐 Live demo & docs: [keen-phoenix-svelte.keenmate.dev](https://keen-phoenix-svelte.keenmate.dev)** ·
[Hex](https://hex.pm/packages/keen_phoenix_svelte) ·
[HexDocs](https://hexdocs.pm/keen_phoenix_svelte)

Auto-mount compiled **Svelte** (React, Lit, …) apps into **Phoenix** — on both
**LiveView** and plain controller-rendered pages — as self-contained islands.

Write this in a template:

```heex
<.app name="like" id={"like-#{@id}"} props={%{id: @id, liked: @liked}} />
```

…and the compiled Svelte app in `assets/apps/like/` is mounted into that element,
kept in sync with server state, given a `context`/`api`/`channel`/`live` bridge to
the server (plus a `bus` for island-to-island messaging), and torn down on
navigation — no manual `<script>`/`<link>` wiring. A configurable placeholder
shows while the bundle loads (server-wide default, per-app `<:placeholder>`
override), so there's no flash of empty container.

Svelte is the first-class, tooled path, but the mount boundary is
**framework-neutral** — an island's entry just default-exports
`(target, opts) => { setProps, destroy }`. Because every island mounts through
that one contract, there's a single component, `<.app>`. The demo mounts Svelte,
Lit, React and vanilla-JS islands through it.

> **New here, or comparing this to `live_svelte`?** Start with
> **[Philosophy & comparison](docs/philosophy.md)** — the autonomous-island model,
> what this deliberately doesn't do, and how it differs from `live_svelte`.

## What's New in v1.0.0-rc.7

- **Pick a view with `<.app component="…">`** — a first-class attribute for multi-component islands, desugaring to a `component` prop (it wins over one already in `props`). Keep related views (say a chart and a table) in one app so they share a single imported runtime, and select between them per `<.app>` — instead of separate apps that each inline their own copy of the framework.

## What's New in v1.0.0-rc.6

- **Eager mounting — paint before the socket connects** — `<.app eager>` mounts an island the instant `app.js` parses instead of waiting for the LiveView hook, collapsing the cold-load gap between the server-rendered placeholder and the live island. It starts without `live` and is upgraded once the socket connects — ideal for islands that draw from `api`, a `channel`, or another server. A no-op on plain pages.
- **`liveStatus` on the boundary** — every island now knows whether `live` is here (`"ready"`), coming (`"pending"`, an eager mount), or never present (`"none"`, a plain page) — enough to show a loader while waiting and choose the right transport.
- **`keen:live-ready`** — a `CustomEvent` (with `detail.live`), plus an optional `setLive(live)` handle method, fired when an eagerly-mounted island's `live` bridge arrives. Server-pushed prop updates keep flowing the whole time; only imperative `live.*` calls need the bridge.

## How it works

Two cooperating halves:

- **Elixir** — `<.app>` renders a hook-bound `<div>` (`phx-update="ignore"`,
  `data-app`, JSON `data-props`); `<KeenPhoenixSvelte.runtime>` emits the page context.
- **JS** — the `KeenApp` hook mounts the island inside a LiveView and `AppsManager`
  lazily `import()`s `/apps/<name>/main.mjs` (or a registered URL); `mountStatic()`
  mounts islands on plain pages. Only the bundles on a page are fetched.

Neither half is Svelte-specific: the bundle it mounts can be **Svelte, React, Lit,
Vue, or vanilla JS**, because every island mounts through the same framework-neutral
`(target, opts) => { setProps, destroy }` contract. `<.app>` is the one component for
all of them.

`phx-update="ignore"` keeps LiveView out of the island's subtree; the hook drives
mount / prop-update / teardown across live navigation.

Unlike `live_svelte`, this is the **island** model — no `~V` sigil, no
server-rendered slots, no SSR Node runtime.

## Install

```elixir
{:keen_phoenix_svelte, "~> 1.0"}
```

Plus the npm package `@keenmate/phoenix_svelte` and a Svelte/Vite toolchain. Full
steps in [Installation & setup](docs/installation.md).

## Documentation

- [Installation & setup](docs/installation.md) — wire the library into your app
- [Authoring apps](docs/authoring-apps.md) — folder layout, the mount contract, Svelte 5 & 4
- [Server communication](docs/server-communication.md) — runtime context, `live`, `api`, `channel`, `bus`
- [External apps (CDN, direct vs proxy)](docs/external-apps.md) — load islands from elsewhere, and the `:direct`/`:proxy` delivery modes

A complete, runnable demo (the `like` app on a LiveView route and a plain route,
plus a channel) lives in the
[`example/`](https://github.com/KeenMate/keen-phoenix-svelte/tree/main/example) app.

## Versioning

`keen_phoenix_svelte` is a **dual package**: the Hex library `keen_phoenix_svelte`
and the npm package `@keenmate/phoenix_svelte` are released **in lockstep at the
same version** — install matching versions of both. The Elixir side renders the
component + hook wiring; the npm side supplies the client runtime (the `KeenApp`
hook, `AppsManager`, the `api`/`channel` helpers, and the Vite build helper).

## License

MIT.
