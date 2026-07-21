# keen_phoenix_svelte

Auto-mount compiled **Svelte** apps into **Phoenix** — on both **LiveView** and
plain controller-rendered pages — as self-contained islands.

Write this in a template:

```heex
<.svelte name="like" id={"like-#{@id}"} props={%{id: @id, liked: @liked}} />
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
that one contract, there's a single component, `<.app>` (an optional
`framework="…"` attribute just tags `data-framework` for debugging). The demo
mounts Svelte, Lit, React and vanilla-JS islands through it. `<.svelte>` remains
as a back-compat alias.

> **New here, or comparing this to `live_svelte`?** Start with
> **[Philosophy & comparison](docs/philosophy.md)** — the autonomous-island model,
> what this deliberately doesn't do, and how it differs from `live_svelte`.

## What's New in v1.0.0-rc.2

- **Framework-neutral `<.app>` — one component mounts any island** — Every island mounts through the same `(target, opts) => { setProps, destroy }` contract, so there is now a single `app/1` component regardless of whether the bundle is Svelte, Lit, React, or hand-written vanilla JS. An optional `framework` attribute just emits an informational `data-framework` tag. `<.svelte>` remains as a back-compat alias for the rc.1 name.
- **Placeholder / loader — no flash of empty container** — `<.app>` renders a placeholder that the client clears the instant the bundle mounts (after the fetch, so it stays visible the whole time). Resolution is a per-call `<:placeholder>` slot › the server-wide `config :keen_phoenix_svelte, :placeholder` › a built-in, dependency-free skeleton. The server default accepts an HTML string, a function, `{mod, fun}`, or `false` to disable.
- **Event bus — island-to-island messaging without the server** — A `bus` joins the app boundary: a page-wide, client-side pub/sub (`emit`/`on`/`once`) over a DOM `EventTarget`, wired into both the LiveView hook and `mountStatic()`, so independent islands coordinate without a round-trip and without importing each other.
- **External apps — a registry with `:direct`/`:proxy` delivery** — `KeenPhoenixSvelte.Apps` registers islands whose bundle lives elsewhere (a CDN, another deploy); `<.runtime>` emits a `name → url` manifest and `AppsManager.resolve/1` loads them. Pick `:direct` (browser imports the CDN URL) or `:proxy` (Phoenix fetches and re-serves same-origin via `KeenPhoenixSvelte.Apps.Proxy` — no CORS, CSP `'self'`).
- **Example reworked into "KeenSpace"** — the demo is now a Teams-style workspace that doubles as reference code: chat over channel + Presence, a video catalogue over the REST helper, a calendar over `context.tokens`, a bus-driven activity toast, simulated i18n, a plain (non-LiveView) route, and Lit/React/vanilla islands alongside the Svelte ones.

## What's New in v1.0.0-rc.1

- **Islands for Phoenix — `<.svelte>` mounts compiled Svelte apps with zero per-page wiring** — The initial release ships the core mounting path: a `<.svelte name id props>` function component renders a hook-bound `<div>` (`phx-update="ignore"`, `data-app`, JSON `data-props`), and the `KeenSvelte` LiveView hook mounts the app on `mounted()`, pushes prop changes on `updated()`, and tears it down on `destroyed()`. `AppsManager` lazily `import()`s `/apps/<name>/main.mjs` and caches it, so only the bundles actually present on a page are fetched — no manual `<script>`/`<link>` tags per app.
- **One component, two transports — LiveView socket or plain-page REST** — Apps mount identically inside a LiveView or on a plain controller-rendered page. `mountStatic()` scans `[data-app]` on non-LiveView pages (skipping `[data-phx-session]`) and mounts with `live: null`, so the same app talks over `live.pushEvent` when a socket is present and falls back to the `api` REST helper when it isn't.
- **A standardized app boundary — `props`, `context`, `live`, `api`, `channel`, `bus`** — Every app's entry receives `(target, { props, context, live, api, channel, bus, el }) => handle`. `context` (emitted once per page by `<KeenPhoenixSvelte.runtime>`) carries user/csrf/tokens/api_base/socket; `live` bridges `pushEvent`/`handleEvent` (with automatic subscription cleanup)/`upload`; `api` attaches `x-csrf-token` + session cookie to REST calls; `channel` is a promise-based, envelope-agnostic Phoenix channel factory with auto `cid` correlation; and `bus` is a page-wide client-side event bus (`emit`/`on`/`once`) for island-to-island messaging that works identically with or without LiveView.
- **Svelte-version-agnostic mount contract** — The mount handle is `{ setProps, destroy }`, so the hook drives Svelte 5 (`mount`/`unmount` + `$state`) and transparently falls back to `$set`/`$destroy` on Svelte 4. Prop updates are diffed in `updated()` to skip redundant re-renders when `data-props` is unchanged.
- **Dual package — Hex library + bundled npm package** — Ships as both `keen_phoenix_svelte` on Hex and `@keenmate/phoenix_svelte` on npm, released in lockstep at the same version. A Vite config helper (`@keenmate/phoenix_svelte/vite`) builds one self-contained ES module per app with CSS injected by JS. A runnable Phoenix 1.8 demo (the `like` app on both a LiveView route and a plain route, plus a channel) lives in `example/`.

## How it works

Two cooperating halves:

- **Elixir** — `<.svelte>` renders a hook-bound `<div>` (`phx-update="ignore"`,
  `data-app`, JSON `data-props`); `<KeenPhoenixSvelte.runtime>` emits the page context.
- **JS** — the `KeenSvelte` hook mounts the app inside a LiveView and `AppsManager`
  lazily `import()`s `/apps/<name>/main.mjs`; `mountStatic()` mounts apps on plain
  pages. Only the bundles on a page are fetched.

`phx-update="ignore"` keeps LiveView out of the Svelte-owned subtree; the hook
drives mount / prop-update / teardown across live navigation.

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
