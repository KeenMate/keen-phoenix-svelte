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

## What's New in v1.0.0-rc.9

- **Cleaner proxy not-found** — a missing sub-path on a proxied `base:`/`dir:` app now returns a genuine `404` (and `410 Gone`) instead of a blanket `502`, so a browser can tell "file not found" apart from a real upstream failure. Other upstream errors still surface as `502`, and misses stay negative-cached.

## What's New in v1.0.0-rc.8

- **Hook renamed `KeenSvelte` → `KeenApp`** — the island hook mounts any framework (Svelte, React, Lit, vanilla JS), so the name now matches the neutral vocabulary (`<.app>`, `data-app`, `AppsManager`). `getHooks()` still returns it, so `hooks: getHooks()` needs no change — **breaking only** if you registered the hook by its literal name.
- **App proxy hardened** — the built-in `:httpc` fetcher now verifies TLS against the system trust store (no MITM on the Phoenix→origin leg), refuses upstream redirects (SSRF guard), sends `X-Content-Type-Options: nosniff`, and confirms local `:dir` sub-paths resolve inside their directory. See the new "Security & trust model" section in the external-apps guide.
- **Sub-path fan-out is bounded** — concurrent upstream fetches are capped (`max_concurrent_fetches`, excess sheds `503 + Retry-After`) and definitive upstream 404s are briefly negative-cached (`negative_ttl`), so a flood of guaranteed-miss paths can't drive unbounded outbound requests.
- **`manifest:` allowlist for base/dir apps** — register the exact files an app ships (an inline list, or a JSON/text manifest in the bundle — a Vite `manifest.json` is parsed as-is), and any other sub-path is a `404` decided *before* any upstream fetch.
- **`keenManifest()` Vite plugin** (`@keenmate/phoenix_svelte/vite/manifest`) — generates that allowlist by scanning the build output, so it also covers `public/` assets (fonts, images, favicons) Vite's own graph-only manifest misses.
- **Configurable proxy `Cache-Control`** — tune the browser-facing header globally or per app (`client_cache_control`, `immutable_cache_control`), resolved most-specific-first.

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
- [Runtime context (user & tokens)](docs/runtime-context.md) — relay user identity and a shared JWT to islands
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
