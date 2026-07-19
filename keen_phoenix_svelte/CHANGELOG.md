# Changelog

All notable changes to `keen_phoenix_svelte` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0-rc.1]: https://github.com/keenmate/keen_phoenix_svelte/releases/tag/v1.0.0-rc.1
