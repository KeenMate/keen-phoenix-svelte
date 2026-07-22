# External apps: CDNs, a registry, and `:direct` vs `:proxy`

By default an island is *local*: `AppsManager` imports `/apps/<name>/main.mjs`
from your own static path and you configure nothing. Register an app only when
its compiled bundle lives **elsewhere** — a shared CDN, another team's deploy, or
a database-driven catalogue.

> This guide is about *where the bytes come from*. It assumes the bundle is already
> an island — it follows the [mount contract](authoring-apps.md#the-mount-contract)
> and is built to be embeddable. A third-party bundle that owns the page (auto-mounts,
> absolute asset paths, page globals) can't be proxied into an island; see
> [Island-able vs page-owning apps](packaging-apps.md) for how to tell, and what to
> do instead.

## The one thing that changes: the URL

`AppsManager.resolve(name)` decides where to import a bundle from. The server
emits a `name → url` **manifest** into the page (via
`<KeenPhoenixSvelte.runtime>`, read from `#keen-apps`); registered apps import
from that URL, everything else falls back to the base path. So the entire
external-app story is *"put the right URL in the manifest."*

```elixir
config :keen_phoenix_svelte,
  apps: %{
    "org-chart" => "https://cdn.acme.com/islands/org-chart@1.4.2/main.mjs"
  }
```

```heex
<.svelte name="org-chart" id="org-chart" props={%{unit: @unit_id}} />
```

The registry is just data — build the same map from a database at runtime and set
it with `Application.put_env(:keen_phoenix_svelte, :apps, map)`; it's read per
request.

## Mode of operation: `:direct` vs `:proxy`

Because `import(url)` runs in the **browser**, the URL decides *who fetches the
bytes*. That's the only real choice, and it's a config value:

```elixir
config :keen_phoenix_svelte,
  load_mode: :proxy,            # :direct (default) | :proxy
  proxy_path: "/apps"           # must match your router forward (defaults to /apps)
```

| | `:direct` | `:proxy` |
|---|---|---|
| Who fetches | Browser → CDN | Browser → your app → CDN |
| Manifest URL | the CDN URL | `"/apps/<name>"` (same-origin) |
| CORS | **required** on the CDN | none |
| CSP | must allow the CDN in `script-src` | `script-src 'self'` |
| Auth / gating / SRI | hard (public, cross-origin) | easy (you serve it) |
| Server load | none (CDN edge-caches) | in the path → cached + revalidated (`ProxyCache`) |

`:proxy` is the corporate-friendly default: it turns a cross-origin bundle into a
first-party asset, sidestepping CORS and a strict CSP. It needs the proxy plug:

```elixir
# router.ex
forward "/apps", KeenPhoenixSvelte.Apps.Proxy
```

`KeenPhoenixSvelte.Apps.Proxy` resolves `/apps/<name>` to the registered
upstream URL, fetches it (built-in `:httpc`, or an injectable `:app_provider`),
and caches it in ETS — see `KeenPhoenixSvelte.Apps.ProxyCache`.

The cache **revalidates** rather than pinning forever: a stale entry triggers a
single-flight conditional `GET` (`If-None-Match`/`If-Modified-Since`), so a `304`
costs nothing and a `200` swaps the bytes in. Freshness follows the upstream's
own `Cache-Control`/`ETag` when present, and a `:ttl` (default 5 min) otherwise —
so this works for **unversioned** upstreams (`.../server-status.js`) that can't be
busted by URL, not just versioned ones. Tune it globally or per app:

```elixir
config :keen_phoenix_svelte,
  proxy_cache: [
    ttl: :timer.minutes(5),   # fallback when the origin sends no cache directives
    respect_upstream: true,   # honor upstream Cache-Control / ETag / Last-Modified
    client_cache_control: "public, max-age=60, stale-while-revalidate=300"
  ],
  apps: %{
    # a truly versioned, immutable URL can skip revalidation entirely:
    "org-chart" => %{url: "https://cdn.acme.com/org-chart@1.4.2/main.mjs", immutable: true},
    # a bare, unversioned file is re-checked every minute:
    "status" => %{url: "https://cdn.acme.com/status.js", ttl: :timer.minutes(1)}
  }
```

The proxy also forwards an `ETag` and answers the browser's `If-None-Match` with
a `304`, so the browser → Phoenix → origin conditional chain revalidates cheaply
end-to-end.

Per-app override, if some apps should stay direct:

```elixir
apps: %{
  "org-chart" => %{url: "https://cdn.acme.com/.../main.mjs", mode: :direct},
  "report"    => "https://reports.internal/report/main.mjs"   # uses load_mode
}
```

## Multi-file bundles: a base-path app

Some bundles aren't a single self-contained module — a vendor player might ship a
JS entry **plus** a separate stylesheet, fonts, or images. Point the registry at
the upstream **directory** with `base:` (and, if the entry isn't `main.mjs`, an
`entry:`), and every sub-path proxies through one registration:

```elixir
config :keen_phoenix_svelte,
  load_mode: :proxy,
  apps: %{
    "player" => %{base: "https://cdn.acme.com/player@3/", entry: "player.mjs"}
  }
```

The client imports the entry (`/apps/player/player.mjs` in `:proxy` mode), and any
sibling the bundle references re-serves same-origin under the same prefix:

| Request | Proxied to upstream |
|---|---|
| `/apps/player/player.mjs` | `https://cdn.acme.com/player@3/player.mjs` |
| `/apps/player/player.css` | `https://cdn.acme.com/player@3/player.css` |
| `/apps/player/fonts/x.woff2` | `https://cdn.acme.com/player@3/fonts/x.woff2` |

Each file is typed by its extension (`.mjs`/`.js` → `text/javascript`, `.css` →
`text/css`, otherwise `MIME`), while JS is always forced to a module-friendly type
regardless of what the origin reports. `..` and other unsafe segments are rejected
before any upstream fetch. Every file shares the app's cache/revalidation and
`ttl`/`immutable` settings. A single-file app (`url:`) is unchanged — it's just the
one-file case.

> A bundle whose entry doesn't ESM-`export default` a mount function (e.g. a UMD
> build that sets `window.SomethingCreate`) still can't mount directly — write a
> thin adapter entry that imports the vendor files (now same-origin) and adapts
> them to `(target, opts) => { setProps, destroy }`. Base-path proxying is what
> gets all those files delivered.

## Notes

- The app boundary is unchanged — an externally-loaded island receives the same
  `(target, { props, context, live, api, channel, bus, el }) => handle`. It only
  needs to be a self-contained ES module honoring that contract; it doesn't have
  to be built with this library (see the `greeter` demo in `example/`, which is
  hand-written vanilla JS).
- Cross-origin `import()` sends **no credentials**, so a `:direct` CDN never sees
  your cookies; and module fetches are governed by CSP `script-src`, not
  `connect-src`.
- `SRI` isn't available for dynamic `import()`; if you need integrity, use
  `:proxy` and verify the bundle server-side before caching.
