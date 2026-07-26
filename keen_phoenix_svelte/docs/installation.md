# Installation & setup

Wiring `keen_phoenix_svelte` into an existing Phoenix (1.8+) app.

## 1. Elixir

Add the dependency (`mix.exs`):

```elixir
{:keen_phoenix_svelte, "~> 1.0"}
```

> **Installing a pre-release (`rc`)?** SemVer ranges like `~> 1.0` (Hex) and
> `^1.0` (npm) **do not match pre-releases**, so during the `rc` phase you must
> pin the exact version on *both* sides — and keep them in lockstep:
> `{:keen_phoenix_svelte, "1.0.0-rc.7"}` in `mix.exs`, and
> `"@keenmate/phoenix_svelte": "1.0.0-rc07"` in `assets/package.json` (note the
> npm rc form is zero-padded, no dot). Once `1.0.0` is out, `~> 1.0` / `^1.0` are
> correct.

Import the components wherever you render HTML — typically `html_helpers/0` in
your `*_web.ex`, so `<.app>` and `<KeenPhoenixSvelte.runtime>` are available
everywhere:

```elixir
import KeenPhoenixSvelte
```

> **Note — the `app/1` name collides with your `Layouts.app/1`.** Phoenix's
> generated `Layouts` module defines its own `app/1` (the app-shell layout), so a
> bare `<.app …>` *inside that one module* is ambiguous with the imported island
> component. Everywhere else (LiveViews, controllers, other components) `<.app>`
> works unqualified; in `Layouts` — the rare case you mount an island in the layout
> itself — call it fully-qualified as `<KeenPhoenixSvelte.app …>`.

Serve the built app bundles by adding `apps` to your static paths (`*_web.ex`):

```elixir
def static_paths, do: ~w(assets apps fonts images favicon.ico robots.txt)
```

Compiled apps are served from `priv/static/apps/<name>/main.mjs`.

> Only needed for **local** apps (bundles you build into `priv/static/apps/`).
> Apps loaded from a CDN — `:direct` (browser → CDN) or `:proxy` (served by the
> router `forward`, see [External apps](external-apps.md)) — aren't served by
> `Plug.Static`, so you can skip this if you use no local apps.

## 2. JavaScript

Add the npm package plus your Svelte toolchain (`assets/package.json`):

```json
{
  "dependencies": { "@keenmate/phoenix_svelte": "^1.0" },
  "devDependencies": {
    "svelte": "^5",
    "@sveltejs/vite-plugin-svelte": "^4",
    "vite": "^5",
    "cross-env": "^7",
    "yargs": "^17"
  }
}
```

Register the hook in your **existing** `assets/js/app.js` — the one `mix phx.new`
generated. You don't rewrite the file; you add just **three** things (marked
`// ← add` below). Everything else here is already in the generated file:

```js
import {Socket} from "phoenix"                                    // already there
import {LiveSocket} from "phoenix_live_view"                      // already there
import { getHooks, mountStatic } from "@keenmate/phoenix_svelte"  // ← add

// already there — Phoenix reads the token from the <meta name="csrf-token">
// tag in root.html.heex. (This is the socket's CSRF; the island `api` helper's
// token is context.csrf_token, emitted separately by <.runtime>.)
const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {                // already there
  params: {_csrf_token: csrfToken},                                // already there
  hooks: { ...getHooks() },                                        // ← add ...getHooks() to your existing hooks
})
liveSocket.connect()                                               // already there

// ← add — mount islands on plain (non-LiveView) pages. Harmless on LiveView
// pages: elements inside a LiveView are skipped and mounted by the hook instead.
mountStatic()
```

To summarize, the three additions are: the `import` line, spreading `...getHooks()`
into your existing `hooks: {}`, and a `mountStatic()` call after `connect()`. (If
your app already has hooks — e.g. `hooks: {...colocatedHooks}` — just add
`...getHooks()` alongside them: `hooks: {...colocatedHooks, ...getHooks()}`.)

## 3. Build the Svelte apps

Each app is built into `priv/static/apps/<name>/main.mjs` as a self-contained ES
module (CSS injected by the JS — no separate stylesheet). Use Vite in library
mode. A config factory is exported as `@keenmate/phoenix_svelte/vite`:

```js
// assets/apps.vite.config.mjs
import { defineConfig } from "vite"
import { appConfig } from "@keenmate/phoenix_svelte/vite"
export default defineConfig(({ mode }) =>
  appConfig({ appName: process.env.SVELTE_APP, mode }))
```

> **Local `file:` dependency?** It is symlinked, so Node resolves the Svelte
> plugin from the library's realpath rather than your app's `node_modules`.
> In that case inline the config (import `svelte`/`vitePreprocess` directly). See
> `example/assets/apps.vite.config.mjs`. Published/hoisted installs use the helper.

A small builder that discovers every folder under `assets/apps/` is in the
example (`example/assets/builder.js`); copy it, then add a dev watcher so apps
rebuild on change (`config/dev.exs`):

```elixir
watchers: [
  # ...esbuild, tailwind...
  node: ["builder.js", "-m", "dev", "-w", cd: Path.expand("../assets", __DIR__)]
]
```

`builder.js` is a plain CommonJS script (it uses `require`), so keep
`assets/package.json` **without** `"type": "module"` — the `.mjs` Vite config is
ESM regardless of that field, so both coexist under the default (CommonJS) package.

### Wire the build into mix (one-shot + production)

The watcher only covers `mix phx.server`. For one-shot builds, `mix setup`, and
**production** (`mix assets.deploy`), add two npm scripts and call them from your
mix asset aliases — otherwise a release ships with **no island bundles**.

`assets/package.json`:

```json
"scripts": {
  "dev": "node builder.js -m dev -w",
  "prod": "node builder.js -m prod"
}
```

`mix.exs` aliases (install the npm deps in setup; build the islands in both
`assets.build` and `assets.deploy`):

```elixir
"assets.setup": [
  "tailwind.install --if-missing",
  "esbuild.install --if-missing",
  "cmd --cd assets npm install"
],
"assets.build": ["compile", "tailwind my_app", "esbuild my_app", "cmd --cd assets npm run prod"],
"assets.deploy": [
  "tailwind my_app --minify",
  "esbuild my_app --minify",
  "cmd --cd assets npm run prod",
  "phx.digest"
]
```

> For `esbuild` to bundle `@keenmate/phoenix_svelte` into your `app.js`, the npm
> package must be installed under `assets/node_modules` — that's what the
> `npm install` in `assets.setup` (and your initial `npm install`) is for.

## 4. (Optional) runtime context

To give apps a user context, a REST helper, and/or channels, render the context
once in your root layout — see [Server communication](server-communication.md).

That's it. Add an app under `assets/apps/` (see [Authoring apps](authoring-apps.md))
and drop a `<.app name="..." id="..." />` into any template.
