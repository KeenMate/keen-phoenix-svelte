defmodule KeenPhoenixSvelte.Apps do
  @moduledoc """
  The app registry: where each island's compiled bundle is loaded from, and
  **how** it is delivered to the browser.

  By default apps are local — `AppsManager` imports `/apps/<name>/main.mjs` from
  your own static path and nothing here is needed. Register an app here only when
  its bundle lives **elsewhere** (a shared CDN, another team's deploy, a
  database-driven catalogue).

  ## Mode of operation — `:direct` vs `:proxy`

  For a registered (external) app you choose who fetches the bytes:

    * `:direct` — the browser `import()`s the configured URL straight from the
      CDN. Fewest moving parts; the CDN must send CORS headers and its origin must
      be allowed by your CSP `script-src`.
    * `:proxy` — the browser imports a **same-origin** path on your Phoenix app,
      and the server fetches the real bundle upstream (see
      `KeenPhoenixSvelte.Apps.Proxy`). No CORS, `script-src 'self'` is enough,
      and you can gate/patch/verify the bundle — the corporate-friendly default.

  The mode only changes *which URL the client imports*; the client itself is
  oblivious. Local apps are never affected.

  ## Configuration

      config :keen_phoenix_svelte,
        # global default mode for registered apps
        load_mode: :proxy,
        # where proxied bundles are served from (must match your router forward).
        # Defaults to the same "/apps" prefix as base_path: local bundles are
        # static files at /apps/<name>/main.mjs (served by Plug.Static, which runs
        # before the router), proxied bundles resolve at /apps/<name> via the
        # forward — the two coexist under one prefix.
        proxy_path: "/apps",
        # local apps load from here
        base_path: "/apps",
        # server-side proxy cache (see `KeenPhoenixSvelte.Apps.Proxy`)
        proxy_cache: [
          ttl: :timer.minutes(5),   # freshness fallback when the origin sends no cache directives
          respect_upstream: true,   # honor upstream Cache-Control / ETag / Last-Modified
          client_cache_control: "public, max-age=60, stale-while-revalidate=300"
        ],
        apps: %{
          # a plain URL uses the global load_mode:
          "org-chart" => "https://cdn.acme.com/islands/org-chart@1.4.2/main.mjs",
          # or override per app (per-app `ttl`/`immutable` tune the proxy cache):
          "report" => %{url: "https://reports.internal/report/main.mjs", mode: :direct},
          "pinned" => %{url: "https://cdn.acme.com/pinned@2.0.0/main.mjs", immutable: true}
        }

  The registry can just as well come from a database — build the same map at
  runtime and set it with `Application.put_env/3`; it's read on every request.
  """

  @doc "The default delivery mode for registered apps (`:direct` or `:proxy`)."
  @spec load_mode() :: :direct | :proxy
  def load_mode, do: get(:load_mode, :direct)

  @doc "Same-origin base path proxied bundles are served under (matches the router forward)."
  @spec proxy_path() :: String.t()
  def proxy_path, do: get(:proxy_path, "/apps")

  @doc "Base path local (unregistered) apps load from."
  @spec base_path() :: String.t()
  def base_path, do: get(:base_path, "/apps")

  @doc "The registered apps, normalized to `%{name => %{url, mode, ttl, immutable}}`."
  @spec registered() :: %{optional(String.t()) => map()}
  def registered do
    :keen_phoenix_svelte
    |> Application.get_env(:apps, %{})
    |> Map.new(fn {name, spec} -> {to_string(name), normalize(spec)} end)
  end

  @doc """
  The client manifest — `%{name => url_the_browser_imports}`.

  Emitted into the page by `<KeenPhoenixSvelte.runtime>` and read by
  `AppsManager`. In `:proxy` mode the URL is a same-origin `proxy_path/<name>`;
  in `:direct` mode it is the configured CDN URL.
  """
  @spec manifest() :: %{optional(String.t()) => String.t()}
  def manifest do
    Map.new(registered(), fn {name, %{url: url, mode: mode}} ->
      {name, client_url(name, url, mode)}
    end)
  end

  @doc "The upstream URL the proxy should fetch for a proxied app, or `nil` if unknown/not proxied."
  @spec upstream(String.t()) :: String.t() | nil
  def upstream(name) do
    case registered()[to_string(name)] do
      %{url: url, mode: :proxy} -> url
      # Allow proxying even a :direct app if someone hits the proxy path directly.
      %{url: url} -> url
      _ -> nil
    end
  end

  @doc """
  The resolved proxy-cache options for `name`, merging the per-app registry entry
  over the global `:proxy_cache` config. Consumed by `KeenPhoenixSvelte.Apps.Proxy`.
  """
  @spec proxy_opts(String.t()) :: %{
          ttl_ms: non_neg_integer(),
          respect_upstream: boolean(),
          immutable: boolean(),
          client_cache_control: String.t() | nil,
          freshness: (map() -> non_neg_integer()) | nil
        }
  def proxy_opts(name) do
    spec = registered()[to_string(name)] || %{}
    cfg = get(:proxy_cache, [])

    %{
      ttl_ms: spec[:ttl] || cfg[:ttl] || :timer.minutes(5),
      respect_upstream: Keyword.get(cfg, :respect_upstream, true),
      immutable: spec[:immutable] || false,
      client_cache_control: cfg[:client_cache_control],
      freshness: cfg[:freshness]
    }
  end

  # ---------------------------------------------------------------------------

  defp client_url(_name, url, :direct), do: url
  defp client_url(name, _url, :proxy), do: proxy_path() <> "/" <> name

  defp normalize(url) when is_binary(url),
    do: %{url: url, mode: load_mode(), ttl: nil, immutable: false}

  defp normalize(%{} = spec) do
    %{
      url: spec[:url] || spec["url"],
      mode: spec[:mode] || spec["mode"] || load_mode(),
      ttl: spec[:ttl] || spec["ttl"],
      immutable: spec[:immutable] || spec["immutable"] || false
    }
  end

  defp get(key, default), do: Application.get_env(:keen_phoenix_svelte, key, default)
end
