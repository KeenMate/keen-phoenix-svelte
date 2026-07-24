# Changelog

All notable changes to `keen_phoenix_svelte` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-rc.6] - 2026-07-24 [PUBLISHED]

### Added

- **Eager mounting — `<.app eager>`** — mount an island *before* the LiveView
  socket connects, so it paints at `app.js` parse time (the same early path a
  plain page uses) instead of waiting for the `KeenSvelte` hook to fire on
  connect. It mounts with `live: null` and `liveStatus: "pending"`; when the
  socket connects the hook hands it the `live` bridge and dispatches a
  `keen:live-ready` event on the element. For islands whose first frame doesn't
  need `live` — they fetch from `api`, a `channel`, or another server entirely.
  A no-op on plain pages (there is no `live` there at all).
- **`liveStatus` in the app boundary** — every island now receives
  `liveStatus: "ready" | "pending" | "none"`, telling it whether `live` is
  available now, arriving on connect (an eager mount), or never present (a plain
  page) — enough to show a loader while `"pending"` and pick its transport.
- **`keen:live-ready` event and optional `setLive(live)` handle method** — the two
  ways an eagerly-mounted island receives its `live` bridge once the socket
  connects: listen for the `CustomEvent` on the island element (`detail.live`), or
  expose a `setLive(live)` method on your mount handle and the hook calls it.
  Server-pushed prop updates (`setProps`) keep working throughout; only the
  imperative `live.*` calls need the bridge.

## [1.0.0-rc.5] - 2026-07-23 [PUBLISHED]

### Removed

- **`framework` attribute on `<.app>`** — it only emitted a `data-framework` tag
  the runtime never read (mounting is identical for every framework via the shared
  contract), so it added markup and API surface for no behavior. Drop it from any
  `<.app framework="…">` call; the app's bundle already is whatever framework it is.

### Added

- **Automatic, page-scoped preloading** — `<.runtime preload={:auto}>` (now the
  **default**) preloads exactly the island bundles a page actually mounts, with no
  per-page list to maintain. Each `<.app>` records itself as it renders; because the
  page body renders before the root layout's `<head>`, `<.runtime>` already knows the
  set and emits `<link rel="modulepreload">` only for those apps. A page with no
  islands preloads nothing. Explicit `preload={[…]}` / `true` / `false` still work
  (a list is the override for preloading an app a later interaction will mount).

### Changed

- **`preload` now defaults to `:auto`** (was `false`). Bundles on a page are
  preloaded during initial HTML parse by default; opt out with `preload={false}`.
  Only apps rendered on the page are ever preloaded, so this is a strict
  load-time improvement — and it silently no-ops (falls back to lazy loading) if
  `<.runtime>` is placed before the page's `<.app>` tags.

### Fixed

- **Vite helper no longer needs `svelte-preprocess`** — `@keenmate/phoenix_svelte/vite`
  (`appConfig`) imported `svelte-preprocess`, which is not a dependency of the
  package and is not installed by the documented `assets/package.json`, so the
  documented published-install build failed with `Cannot find package
  'svelte-preprocess'`. The helper now uses `vitePreprocess` from
  `@sveltejs/vite-plugin-svelte` (already required), matching the example's inlined
  config — no extra dependency, no build break.

### Docs

- **Installation — production/setup build wiring** — `installation.md` now documents
  the `npm` `scripts` (`dev`/`prod`) and the `mix` alias wiring (`assets.setup` →
  `npm install`; `assets.build`/`assets.deploy` → `npm run prod`) needed to build the
  island bundles for one-shot, `mix setup`, and `mix assets.deploy`. Without the
  `assets.deploy` step a release shipped with no island bundles. Also notes that
  `builder.js` is CommonJS, so `assets/package.json` must stay non-`"type": "module"`.

## [1.0.0-rc.4] - 2026-07-22 [PUBLISHED]

### Added

**Base-path proxy — proxy a whole multi-file bundle (JS + CSS + assets), not just one file**
- A registered app can now name an upstream **directory** with `base:` (and an
  optional `entry:`, default `main.mjs`) instead of a single `url:`. Any sub-path
  is forwarded: `/apps/<name>/<sub-path>` proxies to `<base>/<sub-path>`, so a
  vendor bundle whose JS entry pulls a separate stylesheet, fonts, or images all
  re-serve same-origin from one registration. The client imports the entry
  (`/apps/<name>/<entry>` in `:proxy` mode, `<base>/<entry>` in `:direct`).
- `KeenPhoenixSvelte.Apps.resolve/1` resolves a proxy request path to
  `{name, upstream_url, sub_path}` — matching a base-path app on its first segment
  (rest forwarded) or a single-file app by full name. Path traversal (`..`) and
  empty/`.`/backslash segments are rejected before any upstream fetch.
- `KeenPhoenixSvelte.Apps.Proxy` now types each proxied file by its extension
  (`.mjs`/`.js` → `text/javascript`, `.css` → `text/css`, else `MIME`), so a
  base-path bundle's stylesheet and assets are served with correct `Content-Type`
  while JS is still forced to a module-friendly type regardless of what the origin
  reports.

**Unified app manifest — local + registered apps in one map**
- The client manifest (`Apps.manifest/0`, emitted as `#keen-apps`) now **merges**
  detected **local** apps with **registered** ones. Local apps are found by
  scanning `priv/static/<base_path>/<name>/main.mjs` — set
  `config :keen_phoenix_svelte, otp_app: :my_app` so the library can locate the
  static dir (or point `:apps_static_path` at it directly). Registered entries
  override local ones on a name clash. Without `:otp_app` behavior is unchanged —
  the client still resolves local apps by the naming convention; the manifest entry
  only adds them to `preload` and server-side visibility. New `Apps.local_apps/0`.
- Docs render **Mermaid** diagrams (enabled in ex_doc): external-apps now shows the
  resolution flow (two sources → one manifest → client `import`) and the lazy
  load/preload timeline.

**`<.runtime preload={…}>` — fetch island bundles during initial HTML parse**
- `KeenPhoenixSvelte.runtime` gained a `preload` attribute that emits
  `<link rel="modulepreload">` for app bundles, so the browser downloads them in
  parallel with the page instead of waiting for the LiveView hook to fire the
  lazy `import()` (which on a LiveView can't run until the socket connects). Accepts
  a **list of app names** (scope it to the islands on this page; registered apps use
  their manifest URL, an unregistered local app falls back to
  `base_path/<name>/main.mjs`) or `true` (every manifest app); default `false`.
  A cross-origin (`:direct`) URL gets `crossorigin="anonymous"` so the preload's
  credentials mode matches the module import and the fetch is actually reused.

**Local `dir:` source — proxy a content-hashed bundle from a directory on disk**
- A registered app can now name a **local directory** with `dir:` (a mounted
  volume another process rebuilds) instead of a remote `url:`/`base:`. The `entry:`
  is treated as a **glob** (default `main.mjs`); the **newest match wins**, so a
  content-hashed entry (`bundle.a1b2c3.js`) resolves without knowing the hash. The
  client imports a stable `/apps/<name>`; sibling/hashed chunks are served as
  literal files under the same prefix.
- Implemented by **reusing the existing `ProxyCache`** rather than a new mechanism:
  a `file*:`-scheme source reads from disk, with the file's signature
  (name + mtime + size) acting as the validator — an unchanged file is the `304`
  (cached bytes kept), a newer file swaps them in and mints a fresh weak `ETag`.
  The `:ttl` is the folder re-scan cadence (fresh reads are pure ETS, no I/O);
  `immutable: true` pins it. Local `file*:` cache entries are exempt from the
  orphan sweep. Local only — you can't glob a URL.

**Docs**
- New guide **"Island-able vs page-owning apps"** (`docs/packaging-apps.md`): the
  one question that decides whether a bundle can be mounted inline at all — built
  to mount into a target vs. built to be the whole page — with the island-able
  checklist, the page-owning anti-pattern, and the iframe fallback for apps you
  can't repackage. Cross-linked from the authoring and external-apps guides.
- **Authoring apps** guide (`docs/authoring-apps.md`) expanded from a Svelte-only
  walkthrough to cover **any framework** — the Vite library-mode config that emits
  one self-contained `main.mjs` (single `.mjs`, runtime bundled in, CSS inlined),
  per-framework `main.js` adapter recipes for **React, Lit, Vue, and plain JS**
  mapping each lifecycle onto `{ setProps, destroy }`, the three single-file CSS
  strategies, optional runtime-sharing, and an authoring checklist.

### Removed

- **The `<.svelte>` component alias is gone** — there is now one island component,
  `<.app>`. `svelte/1` was a thin back-compat alias for the rc.1 name; keeping two
  names for the same framework-neutral component only invited confusion (and reads
  wrong in a React/Lit/Vue example). Replace `<.svelte …>` with `<.app …>` — the
  attributes are identical (pass `framework="svelte"` if you want the informational
  `data-framework` tag). All docs and the demo now use `<.app>`.

## [1.0.0-rc.3] - 2026-07-21 [PUBLISHED]

### Added

**Proxy cache with revalidation — `:proxy` mode now works for unversioned upstreams**
- `KeenPhoenixSvelte.Apps.ProxyCache` — a single-flight cache/refresher backing
  the app proxy. Bundles are held in a `:public` ETS table (direct concurrent
  reads on the hot path; large bodies are refc binaries, shared not copied), and
  a **stale** entry triggers a conditional `GET`
  (`If-None-Match`/`If-Modified-Since`): a `304` keeps the cached bytes, a `200`
  swaps them. Concurrent requests for the same stale URL collapse into one
  upstream fetch (no cache stampede); an upstream error serves the last-good copy
  fail-open.
- **Freshness policy** — `respect_upstream: true` (default) honors the upstream
  `Cache-Control`/`ETag`/`Last-Modified`, falling back to a `:ttl` (default
  5 min) when the origin is silent. This is what makes the proxy correct for
  **unversioned** upstreams (`cdn/app.js`, `.../server-status.js`) that can't be
  cache-busted by URL — they're re-checked on the TTL cadence instead of being
  pinned forever. Config via a `:proxy_cache` keyword, with per-app `ttl` and
  `immutable` overrides (`KeenPhoenixSvelte.Apps.proxy_opts/1`).
- **Bounded memory** — cache entries upsert by URL, so refreshes never grow the
  table; a periodic sweep (`:sweep_interval`, default 1h, `false` to disable)
  evicts orphaned URLs no longer in the registry, so a rotating DB-driven registry
  stays bounded to its current working set.
- **End-to-end conditional chain** — the proxy forwards an `ETag` (synthesizing a
  weak one when the origin ships none) and a revalidate-friendly `Cache-Control`
  (configurable; per-app `immutable` opt-in for truly versioned URLs), and
  answers the browser's `If-None-Match` with a `304`. So browser → Phoenix →
  origin all revalidate cheaply. Replaces the previous fixed 1-year `immutable`
  header, which pinned proxied bundles in browsers for up to a year even after
  the upstream changed.
- The injectable `:app_provider` gains a 2-arity form
  `fn url, validators -> {:ok, resp} | :not_modified | {:error, reason} end` for
  conditional revalidation; the 1-arity `fn url -> {:ok, body} end` still works
  (treated as a fresh `200`).
- The library now starts a small supervision tree (`mod:` in `mix.exs`) for the
  cache and its `Task.Supervisor` — idle unless the proxy is mounted and hit.

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

[1.0.0-rc.6]: https://github.com/KeenMate/keen-phoenix-svelte/releases/tag/v1.0.0-rc.6
[1.0.0-rc.5]: https://github.com/KeenMate/keen-phoenix-svelte/releases/tag/v1.0.0-rc.5
[1.0.0-rc.4]: https://github.com/KeenMate/keen-phoenix-svelte/releases/tag/v1.0.0-rc.4
[1.0.0-rc.3]: https://github.com/KeenMate/keen-phoenix-svelte/releases/tag/v1.0.0-rc.3
[1.0.0-rc.2]: https://github.com/KeenMate/keen-phoenix-svelte/releases/tag/v1.0.0-rc.2
[1.0.0-rc.1]: https://github.com/KeenMate/keen-phoenix-svelte/releases/tag/v1.0.0-rc.1
