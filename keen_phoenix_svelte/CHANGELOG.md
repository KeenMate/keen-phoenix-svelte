# Changelog

All notable changes to `keen_phoenix_svelte` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-rc.3] - 2026-07-21

### Changed

**Naming aligned with `<.app>`** — the proxy and its config now speak "app", not
"island" (the concept stays "island" in prose; the identifiers match the
component). These are renames from `1.0.0-rc.2`:

- `KeenPhoenixSvelte.IslandProxy` → **`KeenPhoenixSvelte.Apps.Proxy`**. Update
  your `forward` in `router.ex`.
- The injectable bundle fetcher config `:island_provider` → **`:app_provider`**
  (still a 1-arity `fn url -> {:ok, body_binary} end`).
- `proxy_path` default `"/keen-islands"` → **`"/apps"`**, so it shares the
  `base_path` prefix: local bundles are static files at `/apps/<name>/main.mjs`
  (served by Plug.Static, which runs before the router) and proxied bundles
  resolve at `/apps/<name>` via the forward — the two coexist under one prefix.
- Built-in placeholder skeleton keyframe `keen-island-pulse` → `keen-app-pulse`,
  and the doc example `&MyApp.island_loader/1` → `&MyApp.app_loader/1`
  (cosmetic; no API change).

### Fixed

- **Package metadata / links** — corrected `:source_url` to
  `KeenMate/keen-phoenix-svelte` (was `keenmate/keen_phoenix_svelte`, wrong
  casing and underscores), added `homepage_url`, and added a `Website` link to
  the live demo at <https://keen-phoenix-svelte.keenmate.dev> alongside the
  existing GitHub link.

## [1.0.0-rc.2] - 2026-07-20 [PUBLISHED]

### Added

**Framework-neutral component**
- A single **`app/1`** component for every island, regardless of framework. The
  mount boundary was always framework-agnostic — the entry just default-exports
  `(target, opts) => { setProps, destroy }` — so islands can be built with Svelte,
  Lit, React, or hand-written vanilla JS, and all mount identically. An optional
  `framework` attribute emits a `data-framework` tag for debugging (informational
  only; the runtime never reads it). **`svelte/1`** is retained as a back-compat
  alias for the `1.0.0-rc.1` name (no break).

**Placeholder / loader — no flash of empty container**
- `app/1` now renders a **placeholder** inside the wrapper that the client clears
  the instant it mounts the island (after the bundle loads, so it stays visible
  for the whole fetch). Because the wrapper is `phx-update="ignore"`, it's
  rendered once and never re-diffed. Resolution is: a per-call `<:placeholder>`
  slot › the server-wide `config :keen_phoenix_svelte, :placeholder` › a built-in
  dependency-free skeleton. The server default accepts a raw HTML string, a
  0/1-arity function (1-arity gets the app name), `{mod, fun}`, or `false` to
  disable globally. On the client, `AppsManager.create` clears the target
  (`replaceChildren`) right before mount, so this works for every framework.

**Event bus — island-to-island messaging**
- `bus` added to the app boundary: a page-wide, client-side pub/sub built on a DOM
  `EventTarget`. `bus.emit(type, detail)`, `bus.on(type, handler)` and
  `bus.once(type, handler)` (the latter two return an unsubscribe function, ideal
  for a Svelte `$effect` cleanup). Lets independent islands on a page coordinate
  **without the server and without importing each other**.
- `getBus()` exported from the package and wired into **both** mount paths — the
  `KeenSvelte` hook and `mountStatic()` — so the bus is present with or without
  LiveView (unlike `live`, which is `null` on plain pages).
- The mount boundary is now
  `(target, { props, context, live, api, channel, bus, el }) => handle`.

**External apps — registry + `:direct`/`:proxy` delivery**
- `KeenPhoenixSvelte.Apps` — a config- (or DB-) driven registry for apps whose
  bundle lives elsewhere (a CDN, another deploy). `<KeenPhoenixSvelte.runtime>`
  now also emits a `name → url` **manifest** (`#keen-apps`), and `AppsManager`
  gained `resolve(name)` to load registered apps from that URL (unlisted apps
  still use `basePath`). `getAppsManifest()` exported.
- A per-app/global **mode of operation**: `:direct` (browser imports the CDN URL
  — needs CORS + a permissive CSP) or `:proxy` (browser imports a same-origin
  path and Phoenix fetches the bundle upstream — no CORS, `script-src 'self'`,
  the corporate-friendly mode).
- `KeenPhoenixSvelte.Apps.Proxy` — a `Plug` for the proxy mode: fetches the
  upstream bundle (built-in `:httpc`, or an injectable `:app_provider`), caches
  it in `:persistent_term`, and serves it as `text/javascript` with an immutable
  cache header.

### Changed

- **Example app reworked into "KeenSpace"** — a Teams-style workspace that doubles
  as production-quality reference code:
  - **Chat** over a Phoenix channel + `Presence`; clicking an avatar asks the host
    LiveView to render a profile card beside the island.
  - **Video catalogue** over the `api` REST helper with an in-page Plyr player and
    the canonical `live`-or-`api` "save" fallback.
  - **Calendar** from a simulated Microsoft Graph via `context.tokens` + its own
    `fetch`; "Join online" opens a per-meeting chat over a `channel`.
  - A bus-driven **activity toast** island, a **Welcome** page, a plain
    (non-LiveView) route exercising `mountStatic()`, a user switcher, and a
    simulated **i18n** (English / Spanish) with the locale delivered through
    `context`.
  - A framework-free **`greeter`** island loaded from *outside* `/apps` via the
    app registry — proxied in dev, direct in prod — demonstrating both delivery
    modes.
  - **Lit**, **React**, and **vanilla-JS** islands (`kudos-lit`,
    `reactions-react`, `hello-js`) mounted through the same boundary as the Svelte
    apps, showing the components are framework-neutral.
  - Deploy tooling: root `Dockerfile` + `.dockerignore`, `Makefile` `container-*`
    targets, and a prod `runtime.exs`.

## [1.0.0-rc.1] - 2026-07-19 [PUBLISHED]

Initial version. Auto-mounts compiled Svelte apps into Phoenix as self-contained
islands, on both LiveView and plain controller-rendered pages.

### Added

**Core mounting**
- `<.svelte name id props>` function component — renders a hook-bound `<div>`
  with `phx-update="ignore"`, `data-app`, and JSON-encoded `data-props`.
- `KeenSvelte` LiveView hook — mounts the app in `mounted()`, pushes prop changes
  via the mount handle in `updated()`, tears down in `destroyed()`.
- `AppsManager` — lazily `import()`s `/apps/<name>/main.mjs` on demand and caches
  it; only bundles present on a page are fetched. `register()` escape hatch for
  pre-bundled apps.
- Vite config helper (`@keenmate/phoenix_svelte/vite`) building one self-contained
  ES module per app with CSS injected by JS (`emitCss: false`).

**Svelte version independence**
- Mount contract is `(target, opts) => handle` where `handle` is
  `{ setProps, destroy }`. Works with Svelte 5 (`mount`/`unmount` + `$state`) and
  falls back to `$set`/`$destroy` for Svelte 4.

**Dual mount trigger (LiveView + plain pages)**
- `mountStatic()` scans `[data-app]` on plain pages and mounts apps that are not
  managed by a LiveView (skips `[data-phx-session]`), with `live: null`.

**Runtime context & the app boundary**
- `<KeenPhoenixSvelte.runtime context={...}>` emits a once-per-page
  `<script type="application/json" id="keen-context">`, read by the client and
  injected into every app as `context`.
- The mount options object provides `props`, `context`, `live`, `api`, `channel`,
  and `el`.

**Server communication**
- `live` bridge: `pushEvent`, `pushEventTo` (defaults to the app's own root for
  LiveComponents), `handleEvent` with automatic subscription cleanup on destroy,
  `removeHandleEvent`, `upload`/`uploadTo`.
- `api` REST helper: `get`/`post`/`put`/`patch`/`delete` to your Phoenix backend
  with `x-csrf-token` + `credentials: same-origin` attached (CSRF + session).
- `channel` helper: promise-based `joined`/`push`/`on`/`leave` over a Phoenix
  socket (lazy connect from `context.socket_path`/`socket_token`). Envelope-
  agnostic (resolves the raw reply) and auto-attaches a `cid` correlation id.

**Performance**
- Prop-change diffing — `updated()` skips redundant re-renders when `data-props`
  is unchanged.

**Example app**
- Phoenix 1.8 LiveView demo with the `like` app running on a LiveView route
  (`/`, via `pushEvent`) and a plain controller route (`/plain`, via REST).
- `/api/like` behind a `fetch_session` + `protect_from_forgery` pipeline.
- `UserSocket` (signed `Phoenix.Token` auth) + `DemoChannel` at `/socket`, with
  channel and socket-auth tests.

**Tooling**
- Root `Makefile`: `setup`, `dev`/`server`, `build-assets`, `test`, `clean`.

### Notes

- Independent of `simplificator_3000_phoenix`; the `channel` helper is designed to
  fit its channel-macro envelope (`{data, requestId, metadata}` + `cid`) without
  depending on it.

### Known limitations / deferred

- No SSR (islands mount client-side; brief empty container before hydration).
- Per-app bundles duplicate the Svelte 5 runtime (~71 kB/app); externalize
  `svelte` into a shared chunk if you ship many apps.
- Server-rendered slots (`@inner_block` → component) intentionally out of scope.
- External-service token delivery (a server-minted token for a *different*
  service in `context.tokens.*`) — planned, not yet implemented.

[1.0.0-rc.2]: https://github.com/KeenMate/keen-phoenix-svelte/releases/tag/v1.0.0-rc.2
[1.0.0-rc.1]: https://github.com/KeenMate/keen-phoenix-svelte/releases/tag/v1.0.0-rc.1
