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

  # A throwaway localhost TCP server that answers every request with a 302 to
  # `/target`. Lets the real `:httpc` path run so we can prove it does NOT follow
  # the redirect. Returns the ephemeral port; torn down on test exit.
  defp start_redirect_server do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    pid = spawn_link(fn -> redirect_accept_loop(listen, port) end)

    on_exit(fn ->
      Process.exit(pid, :kill)
      :gen_tcp.close(listen)
    end)

    port
  end

  defp redirect_accept_loop(listen, port) do
    case :gen_tcp.accept(listen) do
      {:ok, socket} ->
        # Let the client finish sending its request, then reply and close.
        :gen_tcp.recv(socket, 0, 2_000)

        :gen_tcp.send(
          socket,
          "HTTP/1.1 302 Found\r\n" <>
            "Location: http://127.0.0.1:#{port}/target\r\n" <>
            "Content-Length: 0\r\n\r\n"
        )

        :gen_tcp.close(socket)
        redirect_accept_loop(listen, port)

      _ ->
        :ok
    end
  end

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

  test "a definitive upstream 404 is negative-cached (not re-fetched)" do
    url = unique_url()
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v ->
      Agent.update(counter, &(&1 + 1))
      {:error, {:status, 404}}
    end)

    assert {:error, {:status, 404}} = ProxyCache.get(url, fresh_opts())
    # second identical request is served from the tombstone — no upstream hit
    assert {:error, {:status, 404}} = ProxyCache.get(url, fresh_opts())
    assert Agent.get(counter, & &1) == 1
  end

  test "a transient upstream error is NOT negative-cached (stays retryable)" do
    url = unique_url()
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v ->
      Agent.update(counter, &(&1 + 1))
      {:error, :timeout}
    end)

    assert {:error, :timeout} = ProxyCache.get(url, fresh_opts())
    assert {:error, :timeout} = ProxyCache.get(url, fresh_opts())
    # re-fetched each time — a timeout must not stick
    assert Agent.get(counter, & &1) == 2
  end

  test "manifest_set parses a JSON array and memoizes by etag" do
    url = "https://cdn.example/manifest-#{System.unique_integer([:positive])}.json"
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v ->
      Agent.update(counter, &(&1 + 1))
      {:ok, %{body: ~s(["main.mjs", "./chunk-a.js", "assets/x.css"]), etag: ~s("m1")}}
    end)

    assert {:ok, set} = ProxyCache.manifest_set(url, fresh_opts())
    assert MapSet.member?(set, "main.mjs")
    # leading "./" is normalized away to match a request sub-path
    assert MapSet.member?(set, "chunk-a.js")
    assert MapSet.member?(set, "assets/x.css")
    refute MapSet.member?(set, "evil.js")

    # cached bytes + memoized parse → provider hit once
    assert {:ok, _} = ProxyCache.manifest_set(url, fresh_opts())
    assert Agent.get(counter, & &1) == 1
  end

  test "manifest_set collects output files from a Vite-style object manifest" do
    url = "https://cdn.example/vite-#{System.unique_integer([:positive])}.json"
    body = ~s({"src/main.js": {"file": "assets/main-abc.js", "css": ["assets/main-abc.css"]}})
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v -> {:ok, %{body: body, etag: ~s("v")}} end)

    assert {:ok, set} = ProxyCache.manifest_set(url, fresh_opts())
    assert MapSet.member?(set, "assets/main-abc.js")
    assert MapSet.member?(set, "assets/main-abc.css")
  end

  test "manifest_set parses a newline text manifest (blanks and # comments ignored)" do
    url = "https://cdn.example/files-#{System.unique_integer([:positive])}.txt"

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url, _v ->
      {:ok, %{body: "main.mjs\n# a comment\n\n  assets/x.js  \n", etag: ~s("t1")}}
    end)

    assert {:ok, set} = ProxyCache.manifest_set(url, fresh_opts())
    assert MapSet.member?(set, "main.mjs")
    # surrounding whitespace trimmed
    assert MapSet.member?(set, "assets/x.js")
    refute MapSet.member?(set, "# a comment")
    refute MapSet.member?(set, "")
  end

  test "at the fetch ceiling, an extra distinct request sheds with :overloaded" do
    orig = Application.get_env(:keen_phoenix_svelte, :proxy_cache)

    on_exit(fn ->
      if orig,
        do: Application.put_env(:keen_phoenix_svelte, :proxy_cache, orig),
        else: Application.delete_env(:keen_phoenix_svelte, :proxy_cache)
    end)

    Application.put_env(:keen_phoenix_svelte, :proxy_cache, max_concurrent_fetches: 1)

    url1 = unique_url()
    url2 = unique_url()
    test_pid = self()

    # The first fetch blocks in the provider, holding the only slot until released.
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn url, _v ->
      if url == url1 do
        send(test_pid, {:in_flight, self()})
        receive do: (:release -> :ok)
      end

      {:ok, %{body: "x"}}
    end)

    first = Task.async(fn -> ProxyCache.get(url1, fresh_opts()) end)
    assert_receive {:in_flight, worker}, 1_000

    # The slot is occupied → a second, distinct URL can't start a fetch.
    assert {:error, :overloaded} = ProxyCache.get(url2, fresh_opts())

    send(worker, :release)
    assert {:ok, %{body: "x"}} = Task.await(first)
  end

  test "max_concurrent_fetches honors config, with a positive default" do
    orig = Application.get_env(:keen_phoenix_svelte, :proxy_cache)

    on_exit(fn ->
      if orig,
        do: Application.put_env(:keen_phoenix_svelte, :proxy_cache, orig),
        else: Application.delete_env(:keen_phoenix_svelte, :proxy_cache)
    end)

    assert ProxyCache.max_concurrent_fetches() > 0
    Application.put_env(:keen_phoenix_svelte, :proxy_cache, max_concurrent_fetches: 4)
    assert ProxyCache.max_concurrent_fetches() == 4
  end

  test "ssl_opts pins certificate verification on (system trust store + hostname check)" do
    opts = ProxyCache.ssl_opts()

    assert opts[:verify] == :verify_peer
    assert is_list(opts[:cacerts]) and opts[:cacerts] != []
    assert Keyword.has_key?(opts, :customize_hostname_check)
  end

  test "the built-in fetcher does not follow upstream redirects (SSRF guard)" do
    port = start_redirect_server()
    url = "http://127.0.0.1:#{port}/redirect"

    # No :app_provider → the real :httpc path runs (autoredirect: false), so the
    # 302 surfaces as an error instead of the redirected body being fetched.
    assert {:error, {:status, 302}} = ProxyCache.get(url, fresh_opts())
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
