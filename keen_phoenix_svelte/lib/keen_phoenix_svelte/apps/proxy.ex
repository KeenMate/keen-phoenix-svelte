defmodule KeenPhoenixSvelte.Apps.Proxy do
  @moduledoc """
  Serves a registered app's bundle **same-origin** by fetching it upstream on
  the server. This is the `:proxy` mode from `KeenPhoenixSvelte.Apps` — it turns a
  cross-origin CDN bundle into a first-party asset so it isn't subject to CORS or
  a strict CSP `script-src`, and lets you gate or cache it.

  ## Mounting

  Forward the `:proxy_path` (defaults to `/apps`) to this plug in your router:

      forward "/apps", KeenPhoenixSvelte.Apps.Proxy

  A request to `/apps/<name>` resolves `<name>` via
  `KeenPhoenixSvelte.Apps.upstream/1`, fetches it once, caches it, and serves it
  as `text/javascript` with a long immutable cache header (so version your CDN
  URLs — same name, new URL busts the cache).

  The default prefix is the same `/apps` that local bundles load from. That's
  intentional and safe: `Plug.Static` runs before the router, so local files at
  `/apps/<name>/main.mjs` are served directly, and only unmatched paths
  (`/apps/<name>`, the proxied bundles) fall through to this plug.

  ## Fetching & caching

  Bundles are cached in `:persistent_term` keyed by upstream URL (write-once,
  read-heavy — a handful of small entries). The upstream fetch uses Erlang's
  built-in `:httpc` by default; override it for tests or a different client with
  an `:app_provider` — a 1-arity function returning `{:ok, body_binary}` or
  `{:error, reason}` (the response is always served as `text/javascript`, so no
  content type is needed):

      config :keen_phoenix_svelte,
        app_provider: fn _url -> {:ok, "export default 1;"} end
  """
  @behaviour Plug

  import Plug.Conn
  require Logger

  alias KeenPhoenixSvelte.Apps

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    # Everything after the forward prefix is the app name (single, self-contained
    # bundle — the library's apps are one file each).
    name = Enum.join(conn.path_info, "/")

    case Apps.upstream(name) do
      nil ->
        conn |> send_resp(404, "unknown app") |> halt()

      url ->
        serve(conn, url)
    end
  end

  defp serve(conn, url) do
    case cached_get_bundle(url) do
      {:ok, body} ->
        conn
        # Force a module-friendly type regardless of what upstream reports.
        |> put_resp_content_type("text/javascript")
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_resp(200, body)

      {:error, reason} ->
        Logger.error("[keen_phoenix_svelte] app proxy failed for #{url}: #{inspect(reason)}")
        conn |> send_resp(502, "app upstream error") |> halt()
    end
  end

  defp cached_get_bundle(url) do
    key = {__MODULE__, url}

    case :persistent_term.get(key, nil) do
      nil ->
        with {:ok, body} <- get_bundle(url) do
          :persistent_term.put(key, body)
          {:ok, body}
        end

      body ->
        {:ok, body}
    end
  end

  defp get_bundle(url) do
    case Application.get_env(:keen_phoenix_svelte, :app_provider) do
      fun when is_function(fun, 1) -> fun.(url)
      _ -> httpc_get_bundle(url)
    end
  end

  defp httpc_get_bundle(url) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    request = {String.to_charlist(url), [{~c"accept", ~c"*/*"}]}
    http_opts = [autoredirect: true, timeout: 10_000, connect_timeout: 5_000]

    case :httpc.request(:get, request, http_opts, body_format: :binary) do
      {:ok, {{_v, 200, _r}, _headers, body}} -> {:ok, body}
      {:ok, {{_v, status, _r}, _headers, _body}} -> {:error, {:status, status}}
      {:error, reason} -> {:error, reason}
    end
  end
end
