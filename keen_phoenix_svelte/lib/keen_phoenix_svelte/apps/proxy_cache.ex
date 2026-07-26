defmodule KeenPhoenixSvelte.Apps.ProxyCache do
  @moduledoc """
  Server-side cache and single-flight refresher for `:proxy`-mode app bundles.

  Each fetched bundle is held in a `:public` ETS table keyed by its upstream URL,
  together with its validators (`ETag` / `Last-Modified`), the upstream
  `Cache-Control`, and a computed freshness window. A **fresh** read never touches
  this process — it's a direct, concurrent ETS read straight from the plug (bundle
  bodies are large refc binaries, so ETS shares them by reference rather than
  copying), so the hot path stays as fast as a static file. Only a **stale** (or
  missing) entry routes through the GenServer, where concurrent refreshes for the
  same URL are collapsed into a single upstream request (no cache stampede).

  ## Freshness

  When an entry goes stale it is **revalidated**, not blindly re-downloaded: the
  refresh sends a conditional `GET` (`If-None-Match` / `If-Modified-Since`). A
  `304 Not Modified` just bumps the timestamp and keeps the cached bytes; a `200`
  replaces them. How long an entry stays fresh (`Apps.proxy_opts/1`):

    * `respect_upstream: true` (default) — the upstream `Cache-Control: max-age`
      (or `s-maxage`) sets the window; `no-cache`/`no-store` forces revalidation
      on every request. When the origin says nothing, the `:ttl` fallback applies.
    * a per-app `immutable: true` pins the entry (never revalidated server-side).
    * a `freshness: fn ctx -> seconds end` config hook overrides everything.

  This is what makes the proxy correct for **unversioned** upstreams
  (`cdn/app.js` with no version in the path): they can't be cache-busted by URL,
  so the proxy polls/revalidates them on the `:ttl` cadence instead.

  ## Fetching & TLS

  The built-in fetcher is Erlang's `:httpc`. Because its bytes end up running
  same-origin in users' browsers, the fetch leg is locked down: TLS certificates
  are **verified** against the system trust store (`verify: :verify_peer` with
  hostname checking) and upstream **redirects are not followed**
  (`autoredirect: false`, closing an SSRF path where a 30x could point the fetch
  at an internal address). Override the TLS options with `:proxy_cache`
  `:ssl_options` (e.g. a custom CA bundle), or replace the client entirely — and
  its policy — via the `:app_provider` hook (see `KeenPhoenixSvelte.Apps.Proxy`).

  ## Memory

  Entries are keyed by upstream URL, so a refresh **upserts** in place — the table
  never grows from re-fetching. The only growth is *orphaned* URLs: ones cached
  before the registry pointed a name at a new URL (or dropped the app). A periodic
  sweep (`:proxy_cache` `:sweep_interval`, default 1h; set `false` to disable)
  evicts any cached URL no longer in `KeenPhoenixSvelte.Apps.registered/0`, so a
  rotating DB-driven registry stays bounded to its current working set.
  """
  use GenServer
  require Logger

  alias KeenPhoenixSvelte.Apps

  @type entry :: %{
          body: binary() | nil,
          etag: String.t() | nil,
          last_modified: String.t() | nil,
          cache_control: String.t() | nil,
          fetched_at: integer(),
          fresh_for: non_neg_integer(),
          # present only on a *tombstone* — a briefly-cached upstream "not found",
          # so a flood of guaranteed-miss sub-paths isn't re-fetched every request.
          negative: term()
        }

  @call_timeout 15_000
  @task_supervisor KeenPhoenixSvelte.Apps.ProxyTaskSupervisor
  @table __MODULE__
  @manifest_table Module.concat(__MODULE__, Manifests)
  @default_sweep_interval :timer.hours(1)
  @default_max_fetches 32
  @default_negative_ttl :timer.seconds(10)

  # ── public API ────────────────────────────────────────────────────────────

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Ceiling on concurrent in-flight upstream fetches (`:proxy_cache`
  `:max_concurrent_fetches`, default #{@default_max_fetches}). Read at boot by the
  `Task.Supervisor` and per-refresh by the GenServer.
  """
  @spec max_concurrent_fetches() :: pos_integer()
  def max_concurrent_fetches do
    case cfg()[:max_concurrent_fetches] do
      n when is_integer(n) and n > 0 -> n
      _ -> @default_max_fetches
    end
  end

  @doc """
  Return a cache entry for `url`, fetching or revalidating upstream if the cached
  copy is missing or stale. `opts` is a resolved `Apps.proxy_opts/1` map. On an
  upstream error a still-cached (stale) copy is served fail-open.
  """
  @spec get(String.t(), map()) :: {:ok, entry()} | {:error, term()}
  def get(url, opts) do
    case lookup(url) do
      {:ok, entry} ->
        if fresh?(entry), do: from_entry(entry), else: refresh(url, opts, entry)

      :miss ->
        refresh(url, opts, nil)
    end
  end

  @doc """
  The set of file paths an app's `manifest` lists (its servable allowlist), fetched
  and cached like any bundle and parsed once per content change. `url` is the
  resolved manifest source, `opts` the app's `Apps.proxy_opts/1`.
  """
  @spec manifest_set(String.t(), map()) :: {:ok, MapSet.t(String.t())} | {:error, term()}
  def manifest_set(url, opts) do
    with {:ok, entry} <- get(url, opts) do
      case :ets.lookup(@manifest_table, url) do
        [{^url, {etag, set}}] when not is_nil(etag) and etag == entry.etag ->
          {:ok, set}

        _ ->
          set = parse_manifest(url, entry.body)
          :ets.insert(@manifest_table, {url, {entry.etag, set}})
          {:ok, set}
      end
    end
  end

  # A tombstone (negative cache) surfaces as the original error, never as a body.
  defp from_entry(%{negative: reason}), do: {:error, reason}
  defp from_entry(entry), do: {:ok, entry}

  @doc false
  @spec lookup(String.t()) :: {:ok, entry()} | :miss
  def lookup(url) do
    case :ets.lookup(@table, url) do
      [{^url, entry}] -> {:ok, entry}
      [] -> :miss
    end
  end

  # ── freshness helpers ─────────────────────────────────────────────────────

  defp refresh(url, opts, stale) do
    case GenServer.call(__MODULE__, {:refresh, url, opts}, @call_timeout) do
      {:ok, entry} ->
        {:ok, entry}

      {:error, reason} when not is_nil(stale) ->
        Logger.warning(
          "[keen_phoenix_svelte] proxy refresh failed for #{url} " <>
            "(#{inspect(reason)}); serving stale copy"
        )

        # A stale *tombstone* re-surfaces as its error, not an empty 200.
        from_entry(stale)

      {:error, _} = err ->
        err
    end
  end

  defp fresh?(%{fetched_at: at, fresh_for: for_ms}), do: now() - at < for_ms
  defp now, do: System.monotonic_time(:millisecond)

  # ── server ────────────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    # :public so the fetch task can write and plug processes can read directly
    # (concurrent reads never route through this process).
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    # Parsed manifest allowlists, keyed by manifest source URL → {etag, MapSet}.
    :ets.new(@manifest_table, [:named_table, :public, :set, read_concurrency: true])
    schedule_sweep()
    {:ok, %{waiters: %{}, refs: %{}}}
  end

  @impl true
  def handle_call({:refresh, url, opts}, from, state) do
    # A fresh entry may have landed while this call was queued — short-circuit.
    case lookup(url) do
      {:ok, entry} ->
        if fresh?(entry),
          do: {:reply, from_entry(entry), state},
          else: dispatch(state, url, opts, from)

      :miss ->
        dispatch(state, url, opts, from)
    end
  end

  # Start a fetch, or reject when already at the concurrency ceiling.
  defp dispatch(state, url, opts, from) do
    case enqueue(state, url, opts, from) do
      {:ok, state} -> {:noreply, state}
      {:overloaded, state} -> {:reply, {:error, :overloaded}, state}
    end
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {url, refs} = Map.pop(state.refs, ref)
    {waiters, wmap} = Map.pop(state.waiters, url, [])
    Enum.each(waiters, &GenServer.reply(&1, result))
    {:noreply, %{state | refs: refs, waiters: wmap}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    # Task crashed before sending its result (async_nolink → no linked exit).
    {url, refs} = Map.pop(state.refs, ref)
    {waiters, wmap} = Map.pop(state.waiters, url, [])
    Enum.each(waiters, &GenServer.reply(&1, {:error, {:refresh_crashed, reason}}))
    {:noreply, %{state | refs: refs, waiters: wmap}}
  end

  def handle_info(:sweep, state) do
    sweep(registered_urls())
    schedule_sweep()
    {:noreply, state}
  end

  # ── orphan sweep ──────────────────────────────────────────────────────────

  # Drop cached URLs that are no longer registered — deleting the current key
  # during a `:set` traversal is safe. Local `file*:` sources are left alone: their
  # per-asset keys are dynamic (can't appear in the registered set) and re-reading
  # from disk is cheap, so there's nothing to reclaim by evicting them.
  defp sweep(keep) do
    :ets.foldl(
      fn {url, entry}, _acc ->
        if evictable?(url, entry, keep) do
          :ets.delete(@table, url)
          :ets.delete(@manifest_table, url)
        end

        nil
      end,
      nil,
      @table
    )
  end

  # An expired tombstone is always reclaimable (this is what bounds `file:` negative
  # entries, whose keys are dynamic and so never appear in the registered set).
  defp evictable?(_url, %{negative: _} = entry, _keep), do: not fresh?(entry)
  defp evictable?("file-glob:" <> _, _entry, _keep), do: false
  defp evictable?("file:" <> _, _entry, _keep), do: false
  defp evictable?(url, _entry, keep), do: not MapSet.member?(keep, url)

  defp registered_urls do
    Apps.registered() |> Map.values() |> MapSet.new(& &1.url)
  end

  defp schedule_sweep do
    case Application.get_env(:keen_phoenix_svelte, :proxy_cache, [])[:sweep_interval] do
      false -> :noop
      nil -> Process.send_after(self(), :sweep, @default_sweep_interval)
      ms when is_integer(ms) and ms > 0 -> Process.send_after(self(), :sweep, ms)
      _ -> :noop
    end
  end

  # Add `from` to the waiter list for `url`. If a fetch for this URL is already in
  # flight, just attach (single-flight). Otherwise start one — unless we're already
  # at the concurrency ceiling, in which case reject so the caller serves stale or
  # 503 instead of spawning an unbounded task. Spawns are serialized through this
  # process and refs tracked precisely, so `map_size(refs)` is an exact in-flight
  # count and never races the `Task.Supervisor`'s own `max_children`.
  defp enqueue(state, url, opts, from) do
    cond do
      Map.has_key?(state.waiters, url) ->
        {:ok, %{state | waiters: Map.update!(state.waiters, url, &[from | &1])}}

      map_size(state.refs) >= max_concurrent_fetches() ->
        {:overloaded, state}

      true ->
        task = Task.Supervisor.async_nolink(@task_supervisor, fn -> do_fetch(url, opts) end)

        {:ok,
         %{
           state
           | waiters: Map.put(state.waiters, url, [from]),
             refs: Map.put(state.refs, task.ref, url)
         }}
    end
  end

  # ── fetch + store (runs in the task) ──────────────────────────────────────

  defp do_fetch(url, opts) do
    prior =
      case lookup(url) do
        {:ok, entry} -> entry
        :miss -> nil
      end

    validators =
      case prior do
        %{etag: e, last_modified: lm} -> %{etag: e, last_modified: lm}
        _ -> %{}
      end

    case fetch(url, validators) do
      :not_modified when not is_nil(prior) ->
        store(url, %{prior | fetched_at: now(), fresh_for: fresh_for(prior.cache_control, opts)})

      {:ok, resp} ->
        store(url, build_entry(resp, opts))

      :not_modified ->
        # 304 with nothing cached — shouldn't happen; treat as an error.
        {:error, :not_modified_without_cache}

      {:error, reason} ->
        # Briefly remember a *definitive* not-found so a flood of guaranteed-miss
        # sub-paths isn't re-fetched every request. Transient errors (timeout, 5xx,
        # DNS) are NOT cached — they stay retryable and fail-open on stale.
        if negative_cacheable?(reason), do: store_negative(url, reason), else: {:error, reason}
    end
  end

  defp store(url, entry) do
    :ets.insert(@table, {url, entry})
    {:ok, entry}
  end

  # Cache the miss as a short-lived tombstone (skipped entirely when the negative
  # TTL is 0), returning the original error either way.
  defp store_negative(url, reason) do
    case negative_ttl() do
      0 ->
        {:error, reason}

      ttl ->
        :ets.insert(
          @table,
          {url,
           %{
             negative: reason,
             body: nil,
             etag: nil,
             last_modified: nil,
             cache_control: nil,
             fetched_at: now(),
             fresh_for: ttl
           }}
        )

        {:error, reason}
    end
  end

  # A 404/410 (URL) or a missing local file/glob is "this file doesn't exist" —
  # safe to remember briefly. Everything else is transient and stays uncached.
  defp negative_cacheable?({:status, s}), do: s in [404, 410]
  defp negative_cacheable?({:enoent, _}), do: true
  defp negative_cacheable?({:no_match, _}), do: true
  defp negative_cacheable?(_), do: false

  defp build_entry(resp, opts) do
    body = resp.body

    %{
      body: body,
      etag: resp[:etag] || weak_etag(body),
      last_modified: resp[:last_modified],
      cache_control: resp[:cache_control],
      fetched_at: now(),
      fresh_for: fresh_for(resp[:cache_control], opts)
    }
  end

  # A stable weak validator so the browser→Phoenix conditional-GET chain works
  # even when the origin ships no ETag of its own.
  defp weak_etag(body),
    do: ~s(W/") <> Base.encode16(:crypto.hash(:md5, body), case: :lower) <> ~s(")

  # ── freshness policy ──────────────────────────────────────────────────────

  defp fresh_for(cache_control, opts) do
    cond do
      opts.immutable -> :timer.hours(24 * 365)
      is_function(opts.freshness, 1) -> opts.freshness.(%{cache_control: cache_control}) * 1000
      opts.respect_upstream -> from_cache_control(cache_control, opts.ttl_ms)
      true -> opts.ttl_ms
    end
  end

  defp from_cache_control(nil, ttl_ms), do: ttl_ms

  defp from_cache_control(cc, ttl_ms) do
    cond do
      String.contains?(cc, "no-cache") or String.contains?(cc, "no-store") -> 0
      secs = max_age(cc) -> secs * 1000
      true -> ttl_ms
    end
  end

  defp max_age(cc) do
    case Regex.run(~r/(?:s-maxage|max-age)\s*=\s*(\d+)/i, cc) do
      [_, n] -> String.to_integer(n)
      _ -> nil
    end
  end

  # ── upstream fetch (conditional GET) ──────────────────────────────────────

  # A local `:dir` app resolves to a `file*:`-scheme "url" (see `Apps.resolve/1`)
  # and reads from disk instead of fetching over HTTP — but the rest of the cache
  # (single-flight, ETS, freshness window, conditional revalidation, browser
  # ETag/304) is identical. The file's signature (name + mtime + size) plays the
  # role of the upstream ETag: unchanged → `:not_modified` keeps the cached bytes.
  defp fetch("file-glob:" <> pattern, validators), do: local_glob_fetch(pattern, validators)
  defp fetch("file:" <> path, validators), do: local_file_fetch(path, validators)

  # Injectable via `:app_provider`:
  #   * 2-arity `fn url, validators -> {:ok, resp} | :not_modified | {:error, r} end`
  #   * 1-arity `fn url -> {:ok, body} | {:error, r} end`  (legacy; always a 200)
  # Otherwise the built-in `:httpc` client is used.
  defp fetch(url, validators) do
    case Application.get_env(:keen_phoenix_svelte, :app_provider) do
      fun when is_function(fun, 2) -> fun.(url, validators)
      fun when is_function(fun, 1) -> wrap_legacy(fun.(url))
      _ -> httpc_fetch(url, validators)
    end
  end

  # ── local filesystem source (glob newest-match / literal file) ────────────

  # Glob the pattern and take the newest by mtime — so a hashed bundle
  # (`bundle.a1b2c3.js`) resolves to the latest build without knowing the hash.
  defp local_glob_fetch(pattern, validators) do
    case newest_match(pattern) do
      nil -> {:error, {:no_match, pattern}}
      {path, sig} -> serve_local(path, sig, validators)
    end
  end

  defp local_file_fetch(path, validators) do
    case file_sig(path) do
      nil -> {:error, {:enoent, path}}
      stat -> serve_local(path, sig_string(path, stat), validators)
    end
  end

  # Unchanged signature → the browser/cache copy is current (the mtime "304").
  defp serve_local(path, sig, validators) do
    if validators[:last_modified] == sig do
      :not_modified
    else
      case File.read(path) do
        # etag: nil → the cache mints a weak content ETag (as for an ETag-less
        # origin); `sig` rides in `last_modified` as the opaque revalidator.
        {:ok, body} -> {:ok, %{body: body, etag: nil, last_modified: sig, cache_control: nil}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp newest_match(pattern) do
    pattern
    # `Path.wildcard/1` reads `\` as an escape, so a Windows dir (`C:\...`) never
    # matches — normalize separators to `/` first (File.stat/read accept either).
    |> String.replace("\\", "/")
    |> Path.wildcard()
    |> Enum.map(fn p -> {p, file_sig(p)} end)
    |> Enum.reject(fn {_p, sig} -> is_nil(sig) end)
    |> case do
      [] ->
        nil

      entries ->
        {path, {_m, _s} = stat} = Enum.max_by(entries, fn {_p, {mtime, _size}} -> mtime end)
        {path, sig_string(path, stat)}
    end
  end

  defp file_sig(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{type: :regular, mtime: mtime, size: size}} -> {mtime, size}
      _ -> nil
    end
  end

  # Include the basename so a hash-renamed file (same mtime/size) still counts as
  # changed; mtime + size catch an in-place rewrite.
  defp sig_string(path, {mtime, size}),
    do: Path.basename(path) <> ":" <> Integer.to_string(mtime) <> ":" <> Integer.to_string(size)

  defp wrap_legacy({:ok, body}),
    do: {:ok, %{body: body, etag: nil, last_modified: nil, cache_control: nil}}

  defp wrap_legacy(other), do: other

  defp httpc_fetch(url, validators) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    headers =
      [{~c"accept", ~c"*/*"}]
      |> maybe_header(~c"if-none-match", validators[:etag])
      |> maybe_header(~c"if-modified-since", validators[:last_modified])

    request = {String.to_charlist(url), headers}

    # `autoredirect: false` — a server-side fetcher must not follow upstream 30x
    # blindly: a redirect to `169.254.169.254`/`localhost`/an internal host would
    # be fetched and then served same-origin (SSRF). A 30x surfaces as
    # `{:error, {:status, 3xx}}` and, if a stale copy exists, is served fail-open.
    # `ssl:` pins TLS verification on (httpc does NOT verify certs by default), so
    # the Phoenix→origin leg — whose bytes we execute in users' browsers — can't be
    # MITM'd. Callers needing a redirect-following or custom client use `:app_provider`.
    http_opts = [autoredirect: false, timeout: 10_000, connect_timeout: 5_000, ssl: ssl_opts()]

    case :httpc.request(:get, request, http_opts, body_format: :binary) do
      {:ok, {{_v, 200, _r}, resp_headers, body}} ->
        {:ok,
         %{
           body: body,
           etag: header(resp_headers, "etag"),
           last_modified: header(resp_headers, "last-modified"),
           cache_control: header(resp_headers, "cache-control")
         }}

      {:ok, {{_v, 304, _r}, _headers, _body}} ->
        :not_modified

      {:ok, {{_v, status, _r}, _headers, _body}} ->
        {:error, {:status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Verify the origin's certificate against the system trust store and check the
  # hostname (OTP 25+ `:public_key.cacerts_get/0`; the lib requires OTP 26+). An
  # operator can override the whole list via `:proxy_cache` `:ssl_options`.
  @doc false
  def ssl_opts do
    case Application.get_env(:keen_phoenix_svelte, :proxy_cache, [])[:ssl_options] do
      opts when is_list(opts) ->
        opts

      _ ->
        [
          verify: :verify_peer,
          cacerts: :public_key.cacerts_get(),
          depth: 3,
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]
    end
  end

  # ── manifest parsing (servable-file allowlist) ────────────────────────────

  # A `.json` manifest is either a flat array of paths or an object whose string
  # leaves are collected (so a Vite `manifest.json` — `{ "src": { "file": … } }` —
  # works as-is). Anything else is a newline list (blank / `#`-comment lines
  # ignored). Paths are normalized to the same shape a request sub-path has.
  defp parse_manifest(url, body) when is_binary(body) do
    entries =
      if json_manifest?(url) do
        case Jason.decode(body) do
          {:ok, data} -> collect_paths(data)
          {:error, _} -> []
        end
      else
        body
        |> String.split(~r/\r?\n/)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      end

    entries |> Enum.map(&normalize_manifest_path/1) |> MapSet.new()
  end

  defp parse_manifest(_url, _body), do: MapSet.new()

  defp json_manifest?(url), do: url |> strip_scheme() |> String.downcase() |> String.ends_with?(".json")

  defp strip_scheme("file-glob:" <> p), do: p
  defp strip_scheme("file:" <> p), do: p
  defp strip_scheme(url), do: url

  defp collect_paths(list) when is_list(list), do: Enum.flat_map(list, &collect_paths/1)
  defp collect_paths(map) when is_map(map), do: map |> Map.values() |> Enum.flat_map(&collect_paths/1)
  defp collect_paths(str) when is_binary(str), do: [str]
  defp collect_paths(_), do: []

  defp normalize_manifest_path(path),
    do: path |> String.trim() |> String.trim_leading("./") |> String.trim_leading("/")

  # ── config helpers ────────────────────────────────────────────────────────

  defp cfg, do: Application.get_env(:keen_phoenix_svelte, :proxy_cache, [])

  defp negative_ttl do
    case cfg()[:negative_ttl] do
      n when is_integer(n) and n >= 0 -> n
      _ -> @default_negative_ttl
    end
  end

  defp maybe_header(headers, _name, nil), do: headers
  defp maybe_header(headers, name, value), do: [{name, String.to_charlist(value)} | headers]

  defp header(resp_headers, name) do
    Enum.find_value(resp_headers, fn {k, v} ->
      if to_string(k) |> String.downcase() == name, do: to_string(v)
    end)
  end
end
