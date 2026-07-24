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

## What's New in v1.0.0-rc.6

- **Eager mounting — paint before the socket connects** — `<.app eager>` mounts an island the instant `app.js` parses instead of waiting for the LiveView hook, collapsing the cold-load gap between the server-rendered placeholder and the live island. It starts without `live` and is upgraded once the socket connects — ideal for islands that draw from `api`, a `channel`, or another server. A no-op on plain pages.
- **`liveStatus` on the boundary** — every island now knows whether `live` is here (`"ready"`), coming (`"pending"`, an eager mount), or never present (`"none"`, a plain page) — enough to show a loader while waiting and choose the right transport.
- **`keen:live-ready`** — a `CustomEvent` (with `detail.live`), plus an optional `setLive(live)` handle method, fired when an eagerly-mounted island's `live` bridge arrives. Server-pushed prop updates keep flowing the whole time; only imperative `live.*` calls need the bridge.

## What's New in v1.0.0-rc.5

- **Automatic, page-scoped preloading — on by default** — `<KeenPhoenixSvelte.runtime>` now defaults to `preload={:auto}`: each `<.app>` records itself as it renders and the runtime emits `<link rel="modulepreload">` for exactly the islands on that page, so bundles download during initial HTML parse with no per-page list to maintain. A page with no islands preloads nothing; opt out with `preload={false}` or override with an explicit list.
- **Vite helper build fix — the documented published install works** — `@keenmate/phoenix_svelte/vite` no longer imports the undeclared `svelte-preprocess` (which failed with `Cannot find package`); it uses `vitePreprocess` from the Svelte plugin you already depend on, so `appConfig` builds with just the documented dependencies.
- **One fewer attribute — `<.app framework="…">` removed** — it only emitted a `data-framework` tag the runtime never read, so it was API surface for no behavior. Drop it; a bundle already *is* whatever framework it is.
- **Install docs — production build wiring (no more missing bundles)** — `installation.md` now documents the npm `scripts` and `mix` alias wiring (`assets.setup`/`build`/`deploy`) that builds islands for `mix setup` and releases — previously `mix assets.deploy` shipped none. Plus a clearer app.js edit (which lines you add vs. Phoenix's generated ones) and a note that `static_paths` `apps` is only needed for local apps.

## How it works

Two cooperating halves:

- **Elixir** — `<.app>` renders a hook-bound `<div>` (`phx-update="ignore"`,
  `data-app`, JSON `data-props`); `<KeenPhoenixSvelte.runtime>` emits the page context.
- **JS** — the `KeenSvelte` hook mounts the island inside a LiveView and `AppsManager`
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
component + hook wiring; the npm side supplies the client runtime (the `KeenSvelte`
hook, `AppsManager`, the `api`/`channel` helpers, and the Vite build helper).

## License

MIT.
