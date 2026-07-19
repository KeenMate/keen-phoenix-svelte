# CLAUDE.md

Guidance for working in this repository.

## What this is

This repo develops **`keen_phoenix_svelte`** — a library that auto-mounts
compiled **Svelte 5** apps into **Phoenix (LiveView and plain pages)** as
self-contained islands. It is a *dual package*: a Hex library + a bundled npm
package (`@keenmate/phoenix_svelte`). The `example/` app is a runnable demo and
the integration test bed.

The design philosophy (important): Svelte apps here are **autonomous islands**
(dashboards, org-structure browsers with charts) — initialized with config +
given a server connection, then fully self-owning. We do **not** interleave
Elixir and Svelte (no `~V` sigil, no server-rendered slots, no SSR). This is the
opposite of `live_svelte`. Keep it that way.

## Layout

```
keen_phoenix_svelte/   # the library (publishable)
  lib/keen_phoenix_svelte.ex        # <.svelte> + <.runtime> function components
  assets/js/keen_phoenix_svelte/    # KeenSvelte hook, AppsManager, runtime, channel
  assets/vite/config.js             # shared Vite config helper (appConfig)
example/               # Phoenix 1.8 LiveView demo app depending on it via path:/file:
Makefile               # root task runner
```

## Commands

Use the Makefile at the repo root (wraps `mix`/`npm` in `example/`):

- `make setup` — deps + npm install + build assets
- `make dev` / `make server` — start Phoenix (http://localhost:4000)
- `make build-assets` — build Svelte apps + JS + CSS (`mix assets.build`)
- `make test` — `mix test`
- `make clean` — remove build artifacts, deps, node_modules

Underneath: `mix phx.server`, `mix test`, and `cd example/assets && npm run dev`
(Svelte watcher) / `npm run prod`. The dev server also runs the Svelte builder
as a watcher (see `example/config/dev.exs`).

## Architecture

Two cooperating halves:

- **Elixir** — `<.svelte name id props>` renders a `<div>` with `phx-hook`,
  `phx-update="ignore"`, `data-app`, JSON `data-props`. `<KeenPhoenixSvelte.runtime
  context={...}>` emits the once-per-page context.
- **JS** — the `KeenSvelte` hook mounts the app inside a LiveView; `AppsManager`
  lazily `import()`s `/apps/<name>/main.mjs`. On plain pages, `mountStatic()`
  scans `[data-app]` (skipping `[data-phx-session]`) and mounts with `live: null`.

**Mount contract** — every app's entry default-exports
`(target, { props, context, live, api, channel, el }) => handle`, where `handle`
is `{ setProps, destroy }` (Svelte-version-agnostic; the hook falls back to
`$set`/`$destroy` for Svelte 4). Apps live in `example/assets/apps/<name>/js/`.

**The app boundary** (what an island gets):
- `props` — small per-component config (config, **not** payload)
- `context` — page-wide user/tokens/csrf/api_base/socket
- `live` — LiveView bridge (`pushEvent`/`handleEvent`+auto-cleanup/`upload`), or `null` on plain pages
- `api` — REST helper (attaches `x-csrf-token` + session cookie)
- `channel` — Phoenix channel factory (envelope-agnostic; auto `cid`)

Pattern: `if (live) { live.pushEvent(...) } else { api.post(...) }`.

## Conventions & gotchas (learned the hard way)

- **HEEx `<script>` bodies disable `{}` interpolation.** Use `<%= %>` to inject
  into a `<script>` (that's how `<.runtime>` embeds the context JSON).
- **Svelte 5 `$state` needs a `.svelte.js` module.** The mount logic that makes
  props reactive lives in `apps/<name>/js/mount.svelte.js`, re-exported by
  `main.js`. Reassigning a `$props()` var warns — use a local `$state` + `$effect`
  to mirror server-pushed props (see `apps/like/js/App.svelte`).
- **The Vite config is inlined in `example/assets/apps.vite.config.mjs`**, not
  imported from the library helper, because a local `file:` dep is symlinked and
  Node resolves the Svelte plugin from the library's realpath. Published/hoisted
  installs can use `@keenmate/phoenix_svelte/vite`.
- **`.mjs` MIME** is `text/javascript` in the installed `mime` version — dynamic
  `import()` works. `apps` is in `static_paths()` so Plug.Static serves it.
- **CSS is injected by JS** (`emitCss: false`) — no per-app stylesheet.
- Per-app bundles duplicate the Svelte 5 runtime (~71 kB each). Externalize
  `svelte` into a shared chunk if many apps.
- The Windows "Failed to symlink node_modules for ColocatedJS :eperm" warning at
  compile is harmless (a Phoenix feature we don't use).

## Independence

`keen_phoenix_svelte` does **not** depend on `simplificator_3000_phoenix`
(`C:\Git\KM\simplificator_3000_phoenix`), which provides `Simplificator3000Phoenix.Channel`
(`message`/`msg`/`sub` macros, a `{data, requestId, metadata}`/`{error}` camelCase
envelope, Tarams validation, `cid` correlation). The keen `channel` client helper
is designed to *fit* that envelope (raw replies + auto `cid`) without depending on it.

## More context

- Full library/API docs: `keen_phoenix_svelte/README.md`
- Design decisions & open items: agent memory note `keen-phoenix-svelte-scope`
