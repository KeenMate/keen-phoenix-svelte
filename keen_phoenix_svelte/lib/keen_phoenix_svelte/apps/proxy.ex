defmodule KeenPhoenixSvelte.Apps.Proxy do
  @moduledoc """
  Serves a registered app's bundle **same-origin** by fetching it upstream on
  the server. This is the `:proxy` mode from `KeenPhoenixSvelte.Apps` — it turns a
  cross-origin CDN bundle into a first-party asset so it isn't subject to CORS or
  a strict CSP `script-src`, and lets you gate or cache it.

  ## Mounting

  Forward the `:proxy_path` (defaults to `/apps`) to this plug in your router:

      forward "/apps", KeenPhoenixSvelte.Apps.Proxy

  A request resolves via `KeenPhoenixSvelte.Apps.resolve/1`, serves the cached
  bundle, and revalidates it upstream when it goes stale. Both shapes are handled:

    * `/apps/<name>` — a **single-file** app (`url:`), served as `text/javascript`.
    * `/apps/<name>/<sub-path>` — a **base-path** app (`base:`); the sub-path is
      appended to the upstream directory, so a whole JS + CSS + assets bundle
      proxies through one registration. Each file's `Content-Type` is derived from
      its extension (`.mjs`/`.js` → `text/javascript`, `.css` → `text/css`, else
      `MIME`), while JS is always forced to a module-friendly type.

  The default prefix is the same `/apps` that local bundles load from. That's
  intentional and safe: `Plug.Static` runs before the router, so local files at
  `/apps/<name>/main.mjs` are served directly, and only unmatched paths
  (`/apps/<name>`, the proxied bundles) fall through to this plug.

  ## Caching & freshness

  The bytes are cached and revalidated by `KeenPhoenixSvelte.Apps.ProxyCache`
  (ETS + single-flight conditional `GET`). Freshness is driven by
  the upstream's own `Cache-Control` / `ETag` / `Last-Modified` when present, and
  falls back to a `:ttl` (default 5 min) otherwise — so **unversioned** upstreams
  (`cdn/app.js`) are re-checked on a cadence instead of being pinned forever. See
  `KeenPhoenixSvelte.Apps` for the `:proxy_cache` config and per-app `ttl` /
  `immutable` overrides.

  On the way out this plug forwards an `ETag` and a revalidate-friendly
  `Cache-Control` (configurable; `immutable` per app), and answers the browser's
  own `If-None-Match` with a `304` — completing a browser → Phoenix → origin
  conditional-request chain.

  ## Fetching

  The upstream fetch uses Erlang's built-in `:httpc` by default. Override it for
  tests or a different client with an `:app_provider` — either a 1-arity
  `fn url -> {:ok, body_binary} end` (legacy; always treated as a fresh `200`) or
  a 2-arity `fn url, validators -> {:ok, resp} | :not_modified | {:error, reason} end`
  that can honor `validators.etag` / `validators.last_modified` for conditional
  revalidation (`resp` is a map with `:body` and optional `:etag`,
  `:last_modified`, `:cache_control`):

      config :keen_phoenix_svelte,
        app_provider: fn _url, _validators -> {:ok, %{body: "export default 1;"}} end
  """
  @behaviour Plug

  import Plug.Conn
  require Logger

  alias KeenPhoenixSvelte.Apps
  alias KeenPhoenixSvelte.Apps.ProxyCache

  @immutable "public, max-age=31536000, immutable"
  @default_client_cc "public, max-age=60, stale-while-revalidate=300"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    # The path after the forward prefix resolves to a registered app: a single-file
    # app (matched by full name) or a base-path app (matched on its first segment,
    # the rest forwarded as a sub-path — so a whole JS+CSS+assets bundle proxies
    # through one registration).
    case Apps.resolve(conn.path_info) do
      nil ->
        conn |> send_resp(404, "unknown app") |> halt()

      {name, url, _sub} ->
        serve(conn, name, url)
    end
  end

  defp serve(conn, name, url) do
    opts = Apps.proxy_opts(name)

    case ProxyCache.get(url, opts) do
      {:ok, entry} ->
        respond(conn, entry, opts, url)

      {:error, reason} ->
        Logger.error("[keen_phoenix_svelte] app proxy failed for #{url}: #{inspect(reason)}")
        conn |> send_resp(502, "app upstream error") |> halt()
    end
  end

  defp respond(conn, entry, opts, url) do
    conn = put_validators(conn, entry, opts)

    if browser_current?(conn, entry) do
      conn |> send_resp(304, "") |> halt()
    else
      conn
      |> put_resp_content_type(content_type(url))
      |> send_resp(200, entry.body)
    end
  end

  # JS is forced to a module-friendly type regardless of what a (possibly
  # mislabeling) origin reports; CSS and other assets in a base-path bundle keep
  # their own type, derived from the sub-path extension.
  defp content_type(url) do
    case url |> URI.parse() |> Map.get(:path) |> to_string() |> Path.extname() |> String.downcase() do
      ext when ext in [".mjs", ".js"] -> "text/javascript"
      ".css" -> "text/css"
      "" -> "text/javascript"
      "." <> ext -> MIME.type(ext)
    end
  end

  defp put_validators(conn, entry, opts) do
    conn
    |> put_resp_header("cache-control", client_cache_control(opts))
    |> maybe_put_etag(entry.etag)
  end

  defp maybe_put_etag(conn, nil), do: conn
  defp maybe_put_etag(conn, etag), do: put_resp_header(conn, "etag", etag)

  defp client_cache_control(%{immutable: true}), do: @immutable
  defp client_cache_control(%{client_cache_control: cc}) when is_binary(cc), do: cc
  defp client_cache_control(_opts), do: @default_client_cc

  defp browser_current?(_conn, %{etag: nil}), do: false

  defp browser_current?(conn, %{etag: etag}) do
    conn
    |> get_req_header("if-none-match")
    |> Enum.any?(&(&1 == etag or &1 == "*"))
  end
end
