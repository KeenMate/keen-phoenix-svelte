defmodule KeenPhoenixSvelte.Apps.ProxyCacheTest do
  # Mutates the global :keen_phoenix_svelte env and uses :persistent_term, so run
  # serially. Every test uses a unique upstream URL, so cache entries never bleed.
  use ExUnit.Case, async: false

  alias KeenPhoenixSvelte.Apps.ProxyCache

  setup do
    orig_apps = Application.get_env(:keen_phoenix_svelte, :apps)

    on_exit(fn ->
      Application.delete_env(:keen_phoenix_svelte, :app_provider)

      if orig_apps,
        do: Application.put_env(:keen_phoenix_svelte, :apps, orig_apps),
        else: Application.delete_env(:keen_phoenix_svelte, :apps)
    end)

    :ok
  end

  defp unique_url, do: "https://cdn.example/pc-#{System.unique_integer([:positive])}.mjs"

  # A fresh entry (long ttl) never re-hits the provider.
  defp fresh_opts,
    do: %{ttl_ms: :timer.minutes(5), respect_upstream: true, immutable: false,
          client_cache_control: nil, freshness: nil}

  # ttl 0 → every read is stale → every read revalidates.
  defp stale_opts, do: %{fresh_opts() | ttl_ms: 0}

  test "a fresh entry is served from cache without re-fetching" do
    url = unique_url()
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v ->
      Agent.update(counter, &(&1 + 1))
      {:ok, %{body: "v1"}}
    end)

    assert {:ok, %{body: "v1"}} = ProxyCache.get(url, fresh_opts())
    assert {:ok, %{body: "v1"}} = ProxyCache.get(url, fresh_opts())

    assert Agent.get(counter, & &1) == 1
  end

  test "a stale entry revalidates; 304 keeps the bytes, 200 replaces them" do
    url = unique_url()
    {:ok, calls} = Agent.start_link(fn -> 0 end)

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, validators ->
      n = Agent.get_and_update(calls, &{&1 + 1, &1 + 1})

      case n do
        1 -> {:ok, %{body: "v1", etag: ~s("v1")}}
        2 -> assert(validators[:etag] == ~s("v1")) && :not_modified
        3 -> {:ok, %{body: "v2", etag: ~s("v2")}}
      end
    end)

    assert {:ok, %{body: "v1"}} = ProxyCache.get(url, stale_opts())
    # stale → conditional GET → 304 → same bytes
    assert {:ok, %{body: "v1"}} = ProxyCache.get(url, stale_opts())
    # stale → conditional GET → 200 → new bytes
    assert {:ok, %{body: "v2"}} = ProxyCache.get(url, stale_opts())

    assert Agent.get(calls, & &1) == 3
  end

  test "upstream error serves the last-good copy fail-open" do
    url = unique_url()
    {:ok, mode} = Agent.start_link(fn -> :ok end)

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v ->
      case Agent.get(mode, & &1) do
        :ok -> {:ok, %{body: "good"}}
        :fail -> {:error, :boom}
      end
    end)

    assert {:ok, %{body: "good"}} = ProxyCache.get(url, stale_opts())

    Agent.update(mode, fn _ -> :fail end)
    # stale → refresh fails → we still serve the cached copy
    assert {:ok, %{body: "good"}} = ProxyCache.get(url, stale_opts())
  end

  test "a first-time upstream error propagates (nothing to fall back to)" do
    url = unique_url()
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v -> {:error, :nxdomain} end)

    assert {:error, :nxdomain} = ProxyCache.get(url, fresh_opts())
  end

  test "concurrent misses collapse into a single upstream fetch (single-flight)" do
    url = unique_url()
    {:ok, calls} = Agent.start_link(fn -> 0 end)

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v ->
      Agent.update(calls, &(&1 + 1))
      Process.sleep(50)
      {:ok, %{body: "once"}}
    end)

    results =
      1..10
      |> Enum.map(fn _ -> Task.async(fn -> ProxyCache.get(url, fresh_opts()) end) end)
      |> Task.await_many(5_000)

    assert Enum.all?(results, &match?({:ok, %{body: "once"}}, &1))
    assert Agent.get(calls, & &1) == 1
  end

  test "the sweep evicts cached URLs no longer in the registry (upsert keeps the rest)" do
    url = unique_url()
    Application.put_env(:keen_phoenix_svelte, :apps, %{"sweeptest" => url})
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v -> {:ok, %{body: "x"}} end)

    assert {:ok, _} = ProxyCache.get(url, fresh_opts())
    assert {:ok, _} = ProxyCache.lookup(url)

    # URL dropped from the registry → the next sweep collects the orphan.
    Application.put_env(:keen_phoenix_svelte, :apps, %{})
    send(ProxyCache, :sweep)
    # Synchronous call flushes the mailbox, so :sweep has been handled by now.
    :sys.get_state(ProxyCache)

    assert ProxyCache.lookup(url) == :miss
  end
end
