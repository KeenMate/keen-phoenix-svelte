# External apps: CDNs, a registry, and `:direct` vs `:proxy`

By default an island is *local*: `AppsManager` imports `/apps/<name>/main.mjs`
from your own static path and you configure nothing. Register an app only when
its compiled bundle lives **elsewhere** — a shared CDN, another team's deploy, or
a database-driven catalogue.

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
  proxy_path: "/keen-islands"   # must match your router forward
```

| | `:direct` | `:proxy` |
|---|---|---|
| Who fetches | Browser → CDN | Browser → your app → CDN |
| Manifest URL | the CDN URL | `"/keen-islands/<name>"` (same-origin) |
| CORS | **required** on the CDN | none |
| CSP | must allow the CDN in `script-src` | `script-src 'self'` |
| Auth / gating / SRI | hard (public, cross-origin) | easy (you serve it) |
| Server load | none (CDN edge-caches) | in the path → cached (`:persistent_term`) |

`:proxy` is the corporate-friendly default: it turns a cross-origin bundle into a
first-party asset, sidestepping CORS and a strict CSP. It needs the proxy plug:

```elixir
# router.ex
forward "/keen-islands", KeenPhoenixSvelte.IslandProxy
```

`KeenPhoenixSvelte.IslandProxy` resolves `/keen-islands/<name>` to the registered
upstream URL, fetches it once (built-in `:httpc`, or an injectable
`:island_fetcher`), caches it in `:persistent_term`, and serves it as
`text/javascript` with a long immutable cache header. **Version your CDN URLs**
(`.../org-chart@1.4.2/...`) so a new version is a new URL — same name, fresh
bundle, no stale cache.

Per-app override, if some apps should stay direct:

```elixir
apps: %{
  "org-chart" => %{url: "https://cdn.acme.com/.../main.mjs", mode: :direct},
  "report"    => "https://reports.internal/report/main.mjs"   # uses load_mode
}
```

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
