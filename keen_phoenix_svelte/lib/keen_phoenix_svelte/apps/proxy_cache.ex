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
          body: binary(),
          etag: String.t() | nil,
          last_modified: String.t() | nil,
          cache_control: String.t() | nil,
          fetched_at: integer(),
          fresh_for: non_neg_integer()
        }

  @call_timeout 15_000
  @task_supervisor KeenPhoenixSvelte.Apps.ProxyTaskSupervisor
  @table __MODULE__
  @default_sweep_interval :timer.hours(1)

  # ── public API ────────────────────────────────────────────────────────────

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Return a cache entry for `url`, fetching or revalidating upstream if the cached
  copy is missing or stale. `opts` is a resolved `Apps.proxy_opts/1` map. On an
  upstream error a still-cached (stale) copy is served fail-open.
  """
  @spec get(String.t(), map()) :: {:ok, entry()} | {:error, term()}
  def get(url, opts) do
    case lookup(url) do
      {:ok, entry} ->
        if fresh?(entry), do: {:ok, entry}, else: refresh(url, opts, entry)

      :miss ->
        refresh(url, opts, nil)
    end
  end

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

        {:ok, stale}

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
    schedule_sweep()
    {:ok, %{waiters: %{}, refs: %{}}}
  end

  @impl true
  def handle_call({:refresh, url, opts}, from, state) do
    # A fresh entry may have landed while this call was queued — short-circuit.
    case lookup(url) do
      {:ok, entry} ->
        if fresh?(entry),
          do: {:reply, {:ok, entry}, state},
          else: {:noreply, enqueue(state, url, opts, from)}

      :miss ->
        {:noreply, enqueue(state, url, opts, from)}
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
  # during a `:set` traversal is safe.
  defp sweep(keep) do
    :ets.foldl(
      fn {url, _entry}, _acc ->
        unless MapSet.member?(keep, url), do: :ets.delete(@table, url)
        nil
      end,
      nil,
      @table
    )
  end

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

  # Add `from` to the waiter list for `url`; start a fetch task only if one is not
  # already in flight (presence in `waiters` is the in-flight flag).
  defp enqueue(state, url, opts, from) do
    in_flight? = Map.has_key?(state.waiters, url)
    waiters = Map.update(state.waiters, url, [from], &[from | &1])
    state = %{state | waiters: waiters}

    if in_flight? do
      state
    else
      task =
        Task.Supervisor.async_nolink(@task_supervisor, fn -> do_fetch(url, opts) end)

      %{state | refs: Map.put(state.refs, task.ref, url)}
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

      {:error, _} = err ->
        err
    end
  end

  defp store(url, entry) do
    :ets.insert(@table, {url, entry})
    {:ok, entry}
  end

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
    http_opts = [autoredirect: true, timeout: 10_000, connect_timeout: 5_000]

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

  defp maybe_header(headers, _name, nil), do: headers
  defp maybe_header(headers, name, value), do: [{name, String.to_charlist(value)} | headers]

  defp header(resp_headers, name) do
    Enum.find_value(resp_headers, fn {k, v} ->
      if to_string(k) |> String.downcase() == name, do: to_string(v)
    end)
  end
end
