# Installation & setup

Wiring `keen_phoenix_svelte` into an existing Phoenix (1.8+) app.

## 1. Elixir

Add the dependency (`mix.exs`):

```elixir
{:keen_phoenix_svelte, "~> 1.0"}
```

Import the components wherever you render HTML — typically `html_helpers/0` in
your `*_web.ex`, so `<.svelte>` and `<KeenPhoenixSvelte.runtime>` are available
everywhere:

```elixir
import KeenPhoenixSvelte
```

Serve the built app bundles by adding `apps` to your static paths (`*_web.ex`):

```elixir
def static_paths, do: ~w(assets apps fonts images favicon.ico robots.txt)
```

Compiled apps are served from `priv/static/apps/<name>/main.mjs`.

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

Register the hook (`assets/js/app.js`):

```js
import { getHooks, mountStatic } from "@keenmate/phoenix_svelte"

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { ...getHooks() },
})
liveSocket.connect()

// Mount apps on plain (non-LiveView) pages. Harmless on LiveView pages —
// elements inside a LiveView are skipped and mounted by the hook instead.
mountStatic()
```

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

## 4. (Optional) runtime context

To give apps a user context, a REST helper, and/or channels, render the context
once in your root layout — see [Server communication](server-communication.md).

That's it. Add an app under `assets/apps/` (see [Authoring apps](authoring-apps.md))
and drop a `<.svelte name="..." id="..." />` into any template.
