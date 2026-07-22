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
        # your app, so local apps under priv/static/<base_path> are detected and
        # merged into the manifest (enables `preload` + server-side visibility).
        otp_app: :my_app,
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
          "pinned" => %{url: "https://cdn.acme.com/pinned@2.0.0/main.mjs", immutable: true},
          # a multi-file bundle (JS + CSS + assets) — give a `base:` directory and
          # (optionally) the `entry:` the client imports (defaults to "main.mjs").
          # Any sub-path is proxied: `/apps/player/player.css` → `<base>/player.css`.
          "player" => %{base: "https://cdn.acme.com/player@3/", entry: "player.mjs"},
          # a LOCAL directory on disk (e.g. a mounted volume another process writes
          # to). `entry:` is a glob; the newest match wins, so a content-hashed
          # bundle (`bundle.a1b2c3.js`) resolves without knowing the hash. Served
          # same-origin through the proxy, cached/revalidated like any other source
          # (the file's mtime is the validator, the `:ttl` the re-scan cadence).
          # Local only — you can't glob a URL.
          "dash" => %{dir: "/srv/apps/dash", entry: "bundle.*.js", ttl: :timer.seconds(30)}
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
  The client manifest — `%{name => url_the_browser_imports}` — merging **detected
  local apps** with **registered** ones.

  Emitted into the page by `<KeenPhoenixSvelte.runtime>` and read by `AppsManager`.
  Two sources are collected into one map:

    * **local apps** (`local_apps/0`) — folders built to
      `priv/static/<base_path>/<name>/main.mjs`. Each maps to its convention URL
      `base_path/<name>/main.mjs` (the same URL the client would fall back to).
    * **registered apps** (`registered/0`) — the `:apps` config, whose URL points
      elsewhere (CDN `:direct`, same-origin `:proxy`, a base-path or local `dir:`).

  Registered entries **override** local ones on a name clash (so registering an app
  to a CDN wins over a stray same-named folder). For a registered app the URL is:
  in `:proxy` mode a same-origin `proxy_path/<name>` (base-path app:
  `proxy_path/<name>/<entry>`); in `:direct` mode the configured CDN URL (or
  `<base>/<entry>`).

  Local detection requires `config :keen_phoenix_svelte, otp_app: :my_app` so the
  library can locate your static dir; without it only registered apps appear (the
  client still resolves local apps by the same convention — the manifest entry only
  adds them to `preload` and server-side visibility).
  """
  @spec manifest() :: %{optional(String.t()) => String.t()}
  def manifest do
    registered_map = Map.new(registered(), fn {name, spec} -> {name, client_url(name, spec)} end)
    Map.merge(local_manifest(), registered_map)
  end

  @doc """
  Names of **local** apps — subdirectories of the built static apps dir that
  contain a `main.mjs`. Needs no per-app registration (they're discovered by
  folder), but the library must be told where to look via
  `config :keen_phoenix_svelte, otp_app: :my_app` (its `priv/static/<base_path>`),
  or an explicit `:apps_static_path`. Returns `[]` when neither is set.
  """
  @spec local_apps() :: [String.t()]
  def local_apps do
    case local_apps_dir() do
      nil ->
        []

      dir ->
        case File.ls(dir) do
          {:ok, entries} ->
            entries
            |> Enum.filter(&File.regular?(Path.join([dir, &1, "main.mjs"])))
            |> Enum.sort()

          _ ->
            []
        end
    end
  end

  @doc "The upstream URL the proxy should fetch for a single-file app, or `nil` if unknown/not proxied."
  @spec upstream(String.t()) :: String.t() | nil
  def upstream(name) do
    case registered()[to_string(name)] do
      %{url: url, mode: :proxy} when is_binary(url) -> url
      # Allow proxying even a :direct app if someone hits the proxy path directly.
      %{url: url} when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc """
  Resolve the proxy request path (the segments after the forward prefix) to
  `{name, upstream_url, sub_path}`, or `nil` if nothing matches.

    * a **base-path** app matches on its first segment; the remaining segments are
      appended to its `:base` (empty → the app's `:entry`), so a whole directory of
      files (`player.mjs`, `player.css`, fonts…) proxies through one registration.
    * a **single-file** app matches when the entire path equals its name.

  Path traversal (`..`) and empty/`.`/backslash segments are rejected.
  """
  @spec resolve([String.t()]) :: {String.t(), String.t(), String.t()} | nil
  def resolve([]), do: nil

  def resolve([first | rest] = segments) do
    apps = registered()
    app = apps[first]

    cond do
      # A local `:dir` app matches on its first segment (like a base-path app), but
      # resolves against the filesystem: a bare hit globs `:entry` for the newest
      # match, a sub-path names a literal file. Both become a `file*:`-scheme source
      # that `ProxyCache` reads instead of fetching over HTTP.
      match?(%{dir: d} when is_binary(d), app) and safe_subpath?(rest) ->
        local_source(first, app, rest)

      match?(%{base: b} when is_binary(b), app) and safe_subpath?(rest) ->
        sub = if rest == [], do: entry_of(app), else: Enum.join(rest, "/")
        {first, join_url(app.base, sub), sub}

      (full = Enum.join(segments, "/")) && match?(%{url: u} when is_binary(u), apps[full]) ->
        {full, apps[full].url, ""}

      true ->
        nil
    end
  end

  # A bare hit → glob the entry pattern (the plug/cache picks the newest match);
  # a sub-path → a literal file under the dir (hashed sibling chunks, CSS, assets).
  # The `file-glob:` / `file:` scheme tells `ProxyCache.fetch/2` to read from disk.
  defp local_source(name, %{dir: dir} = spec, []),
    do: {name, "file-glob:" <> Path.join(dir, entry_of(spec)), ""}

  defp local_source(name, %{dir: dir}, rest) do
    sub = Enum.join(rest, "/")
    {name, "file:" <> Path.join(dir, sub), sub}
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

  # Local apps → `%{name => convention_url}`. The URL is exactly what the client
  # would fall back to, so adding it to the manifest changes nothing about how the
  # app mounts — it just makes local apps visible server-side (for `preload`, etc.).
  defp local_manifest do
    Map.new(local_apps(), fn name -> {name, base_path() <> "/" <> name <> "/main.mjs"} end)
  end

  # Where built local bundles live: an explicit `:apps_static_path`, else the
  # `:otp_app`'s `priv/static/<base_path>`. `nil` disables local detection.
  defp local_apps_dir do
    case get(:apps_static_path, nil) do
      path when is_binary(path) ->
        path

      _ ->
        case get(:otp_app, nil) do
          otp when is_atom(otp) and not is_nil(otp) ->
            Application.app_dir(otp, Path.join(["priv", "static", String.trim_leading(base_path(), "/")]))

          _ ->
            nil
        end
    end
  end

  # The URL the browser imports for an app: the CDN URL in :direct mode, a
  # same-origin proxy path in :proxy mode (base apps point at their entry file).
  #
  # A local `:dir` app is always served through the proxy plug (you can't import a
  # filesystem path in the browser) and its entry is a *glob*, so it emits a bare,
  # stable `proxy_path/<name>` — the plug resolves the current file at request time.
  defp client_url(name, %{dir: dir}) when is_binary(dir), do: proxy_path() <> "/" <> name

  defp client_url(_name, %{mode: :direct} = spec), do: direct_url(spec)

  defp client_url(name, %{base: base} = spec) when is_binary(base),
    do: proxy_path() <> "/" <> name <> "/" <> entry_of(spec)

  defp client_url(name, _spec), do: proxy_path() <> "/" <> name

  defp direct_url(%{url: url}) when is_binary(url), do: url
  defp direct_url(%{base: base} = spec) when is_binary(base), do: join_url(base, entry_of(spec))

  defp entry_of(%{entry: entry}) when is_binary(entry), do: entry
  defp entry_of(_spec), do: "main.mjs"

  defp join_url(base, ""), do: base

  defp join_url(base, sub),
    do: String.trim_trailing(base, "/") <> "/" <> String.trim_leading(sub, "/")

  defp safe_subpath?(segments) do
    Enum.all?(segments, fn seg ->
      seg not in ["", ".", ".."] and not String.contains?(seg, "\\")
    end)
  end

  defp normalize(url) when is_binary(url),
    do: %{url: url, base: nil, dir: nil, entry: nil, mode: load_mode(), ttl: nil, immutable: false}

  defp normalize(%{} = spec) do
    %{
      url: spec[:url] || spec["url"],
      base: spec[:base] || spec["base"],
      dir: spec[:dir] || spec["dir"],
      entry: spec[:entry] || spec["entry"],
      mode: spec[:mode] || spec["mode"] || load_mode(),
      ttl: spec[:ttl] || spec["ttl"],
      immutable: spec[:immutable] || spec["immutable"] || false
    }
  end

  defp get(key, default), do: Application.get_env(:keen_phoenix_svelte, key, default)
end
