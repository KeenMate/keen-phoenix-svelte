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

## What's New in v1.0.0-rc.4

- **Base-path proxy — proxy a whole multi-file bundle** — A registered app can name an upstream *directory* with `base:` (+ optional `entry:`); every sub-path re-serves same-origin, so a vendor bundle's JS entry plus its stylesheet, fonts, and images all proxy through one registration.
- **Local `dir:` source — serve a content-hashed bundle from disk** — Point an app at a local directory (a mounted volume another process rebuilds) with an `entry:` glob; the newest match wins, so `bundle.a1b2c3.js` resolves without knowing the hash. It reuses the proxy cache — the file's mtime is the validator, `:ttl` the re-scan cadence.
- **Unified app manifest — local and registered apps in one map** — `Apps.manifest/0` now merges folder-detected local apps with registered ones (set `otp_app:` so the library can locate them). One authoritative map for the client, `preload`, and tooling; a registered entry wins on a name clash.
- **`<.runtime preload={…}>` — fetch island bundles during initial HTML parse** — Emit `<link rel="modulepreload">` for on-page islands so the browser downloads them in parallel instead of waiting for the LiveView hook's lazy `import()`. Cross-origin bundles get `crossorigin` so the preload is actually reused.
- **One island component, `<.app>`** — The `<.svelte>` alias is removed; every island (Svelte, React, Lit, vanilla) mounts through the single framework-neutral `<.app>`. In your `Layouts` module (which defines its own `app/1`), call it fully-qualified as `<KeenPhoenixSvelte.app>`.
- **Docs — one authoring guide, a packaging litmus, and diagrams** — "Authoring apps" now covers building an island in *any* framework (Vite library mode + React/Lit/Vue/vanilla recipes); a new "Island-able vs page-owning apps" guide draws the line on what can be an island; and the guides render Mermaid diagrams of how apps resolve and load.

## What's New in v1.0.0-rc.3

- **Proxy cache with revalidation — `:proxy` mode now works for unversioned upstreams** — Registered proxied bundles are cached in ETS and *revalidated* rather than pinned forever: a stale entry triggers a single-flight conditional `GET` (`If-None-Match`/`If-Modified-Since`), so a `304` keeps the bytes and a `200` swaps them, with concurrent requests collapsed into one upstream fetch. Freshness follows the upstream's `Cache-Control`/`ETag`, falling back to a `:ttl` (default 5 min) — so a bare `cdn/app.js` with no version in its URL is re-checked on a cadence instead of cached for a year.
- **End-to-end conditional-request chain** — The proxy forwards an `ETag` (synthesizing a weak one when the origin ships none) and answers the browser's `If-None-Match` with a `304`, so browser → Phoenix → origin all revalidate cheaply. This replaces the old fixed 1-year `immutable` header; a per-app `immutable: true` opts truly-versioned URLs back into it.
- **Bounded proxy memory** — Cache entries upsert by URL (refreshes never grow the table) and a periodic sweep evicts URLs no longer in the registry, so a rotating DB-driven app registry stays bounded to its working set.
- **Renamed to speak "app", not "island"** — `KeenPhoenixSvelte.IslandProxy` → `KeenPhoenixSvelte.Apps.Proxy`, config `:island_provider` → `:app_provider` (which now also accepts a 2-arity conditional-fetch form), and the proxy-path default `/keen-islands` → `/apps` (it shares the `base_path` prefix). Update your router `forward`.
- **Package metadata / links** — corrected the `:source_url` casing, added `homepage_url`, and a `Website` link to the live demo.

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
