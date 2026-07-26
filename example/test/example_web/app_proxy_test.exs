defmodule ExampleWeb.AppProxyTest do
  # Mutates global :keen_phoenix_svelte env (apps + app_provider), so run serially.
  use ExampleWeb.ConnCase, async: false

  setup do
    orig_apps = Application.get_env(:keen_phoenix_svelte, :apps)

    on_exit(fn ->
      Application.delete_env(:keen_phoenix_svelte, :app_provider)
      if orig_apps, do: Application.put_env(:keen_phoenix_svelte, :apps, orig_apps)
    end)

    :ok
  end

  test "proxies a registered app's bundle same-origin as JS, with a revalidate-friendly cache",
       %{conn: conn} do
    url = "https://cdn.example/proxied-#{System.unique_integer([:positive])}.mjs"
    Application.put_env(:keen_phoenix_svelte, :apps, %{"proxied" => url})

    # A legacy 1-arity provider still works (treated as a fresh 200, no ETag →
    # the cache synthesizes a weak one).
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url ->
      {:ok, "export default 1;"}
    end)

    conn = get(conn, "/apps/proxied")

    assert response(conn, 200) == "export default 1;"
    assert conn |> get_resp_header("content-type") |> hd() =~ "text/javascript"
    assert conn |> get_resp_header("cache-control") |> hd() =~ "max-age"
    refute conn |> get_resp_header("cache-control") |> hd() =~ "immutable"
    assert conn |> get_resp_header("x-content-type-options") == ["nosniff"]
    assert [_etag] = get_resp_header(conn, "etag")
  end

  test "a per-app immutable bundle is served with a long immutable cache", %{conn: conn} do
    url = "https://cdn.example/pinned-#{System.unique_integer([:positive])}.mjs"
    Application.put_env(:keen_phoenix_svelte, :apps, %{"pinned" => %{url: url, immutable: true}})
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url -> {:ok, "export default 2;"} end)

    conn = get(conn, "/apps/pinned")

    assert response(conn, 200) == "export default 2;"
    assert conn |> get_resp_header("cache-control") |> hd() =~ "immutable"
  end

  test "a per-app client_cache_control string wins over immutable and the global default",
       %{conn: conn} do
    orig_cache = Application.get_env(:keen_phoenix_svelte, :proxy_cache)
    on_exit(fn -> restore_proxy_cache(orig_cache) end)

    Application.put_env(:keen_phoenix_svelte, :proxy_cache,
      client_cache_control: "public, max-age=60"
    )

    url = "https://cdn.example/hourly-#{System.unique_integer([:positive])}.mjs"
    # Both `immutable` and an explicit per-app string set — the explicit string wins.
    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "hourly" => %{url: url, immutable: true, client_cache_control: "public, max-age=3600"}
    })

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url -> {:ok, "export default 4;"} end)

    conn = get(conn, "/apps/hourly")
    cc = conn |> get_resp_header("cache-control") |> hd()

    assert cc == "public, max-age=3600"
    refute cc =~ "immutable"
  end

  test "the global immutable_cache_control overrides what `immutable: true` emits",
       %{conn: conn} do
    orig_cache = Application.get_env(:keen_phoenix_svelte, :proxy_cache)
    on_exit(fn -> restore_proxy_cache(orig_cache) end)

    Application.put_env(:keen_phoenix_svelte, :proxy_cache,
      immutable_cache_control: "public, max-age=604800, immutable"
    )

    url = "https://cdn.example/weekly-#{System.unique_integer([:positive])}.mjs"
    Application.put_env(:keen_phoenix_svelte, :apps, %{"weekly" => %{url: url, immutable: true}})
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url -> {:ok, "export default 5;"} end)

    conn = get(conn, "/apps/weekly")

    assert conn |> get_resp_header("cache-control") |> hd() == "public, max-age=604800, immutable"
  end

  test "a base app with an inline manifest serves listed files and 404s the rest", %{conn: conn} do
    base = "https://cdn.example/mf-#{System.unique_integer([:positive])}/"

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "mf" => %{base: base, mode: :proxy, entry: "main.mjs", manifest: ["main.mjs", "chunk-a.js"]}
    })

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn url -> {:ok, "/* #{url} */"} end)

    assert response(get(conn, "/apps/mf/chunk-a.js"), 200) =~ "chunk-a.js"
    # not in the manifest → rejected before any fetch
    assert response(get(conn, "/apps/mf/evil.js"), 404)
  end

  test "a base app with a manifest file rejects unlisted sub-paths before fetching", %{conn: conn} do
    base = "https://cdn.example/mff-#{System.unique_integer([:positive])}/"
    {:ok, hits} = Agent.start_link(fn -> [] end)

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "mff" => %{base: base, mode: :proxy, manifest: "manifest.json"}
    })

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn url ->
      Agent.update(hits, &[url | &1])

      if String.ends_with?(url, "manifest.json"),
        do: {:ok, ~s(["main.mjs", "assets/x.js"])},
        else: {:ok, "/* #{url} */"}
    end)

    assert response(get(conn, "/apps/mff/assets/x.js"), 200)
    assert response(get(conn, "/apps/mff/nope.js"), 404)

    # the bundle was fetched for the listed file + the manifest, never for the
    # unlisted path — the allowlist rejected it upstream of any fetch.
    urls = Agent.get(hits, & &1)
    assert Enum.any?(urls, &String.ends_with?(&1, "assets/x.js"))
    refute Enum.any?(urls, &String.ends_with?(&1, "nope.js"))
  end

  test "the declared entry is served even when absent from the manifest", %{conn: conn} do
    base = "https://cdn.example/mfe-#{System.unique_integer([:positive])}/"

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      # entry intentionally NOT in the manifest list
      "mfe" => %{base: base, mode: :proxy, entry: "main.mjs", manifest: ["chunk-a.js"]}
    })

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn url -> {:ok, "/* #{url} */"} end)

    assert response(get(conn, "/apps/mfe/main.mjs"), 200) =~ "main.mjs"
    assert response(get(conn, "/apps/mfe/other.js"), 404)
  end

  test "a base app whose manifest can't be loaded fails open (still serves)", %{conn: conn} do
    base = "https://cdn.example/mfo-#{System.unique_integer([:positive])}/"

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "mfo" => %{base: base, mode: :proxy, manifest: "manifest.json"}
    })

    Application.put_env(:keen_phoenix_svelte, :app_provider, fn url ->
      if String.ends_with?(url, "manifest.json"),
        do: {:error, :nxdomain},
        else: {:ok, "/* #{url} */"}
    end)

    # manifest unavailable → allowlist bypassed rather than 404-ing the whole app
    assert response(get(conn, "/apps/mfo/whatever.js"), 200) =~ "whatever.js"
  end

  test "a local :dir app honors a manifest file on disk", %{conn: conn} do
    dir = tmp_app_dir()
    File.write!(Path.join(dir, "main.mjs"), "//entry")
    File.write!(Path.join(dir, "chunk-a.js"), "//chunk")
    File.write!(Path.join(dir, "secret.js"), "//secret")
    File.write!(Path.join(dir, "manifest.json"), ~s(["main.mjs", "chunk-a.js"]))

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "dd" => %{dir: dir, entry: "main.mjs", manifest: "manifest.json"}
    })

    assert response(get(conn, "/apps/dd/chunk-a.js"), 200) == "//chunk"
    # present on disk, but not in the manifest → rejected, never read
    assert response(get(conn, "/apps/dd/secret.js"), 404)
  end

  test "a browser conditional request (If-None-Match) gets a 304", %{conn: conn} do
    url = "https://cdn.example/etag-#{System.unique_integer([:positive])}.mjs"
    Application.put_env(:keen_phoenix_svelte, :apps, %{"etagged" => url})
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url -> {:ok, "export default 3;"} end)

    first = get(conn, "/apps/etagged")
    assert response(first, 200)
    etag = first |> get_resp_header("etag") |> hd()

    second = conn |> put_req_header("if-none-match", etag) |> get("/apps/etagged")
    assert response(second, 304) == ""
  end

  test "a base-path app proxies sub-paths, typing each file by extension", %{conn: conn} do
    base = "https://cdn.example/vendor-#{System.unique_integer([:positive])}/"
    Application.put_env(:keen_phoenix_svelte, :apps, %{"vendor" => %{base: base, mode: :proxy}})
    # The provider sees the full resolved URL (base <> sub-path).
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn url -> {:ok, "/* #{url} */"} end)

    js = get(conn, "/apps/vendor/player.mjs")
    assert response(js, 200) =~ "player.mjs"
    assert js |> get_resp_header("content-type") |> hd() =~ "text/javascript"

    css = get(conn, "/apps/vendor/player.css")
    assert response(css, 200) =~ "player.css"
    assert css |> get_resp_header("content-type") |> hd() =~ "text/css"
  end

  test "a local :dir app serves the newest glob match same-origin as JS", %{conn: conn} do
    dir = tmp_app_dir()
    File.write!(Path.join(dir, "bundle.old.js"), "export const v = 'old';")
    File.write!(Path.join(dir, "bundle.new.js"), "export const v = 'new';")
    # Make `new` strictly newer so newest-mtime wins.
    File.touch!(Path.join(dir, "bundle.old.js"), 1_700_000_000)
    File.touch!(Path.join(dir, "bundle.new.js"), 1_700_000_100)

    Application.put_env(:keen_phoenix_svelte, :apps, %{"dash" => %{dir: dir, entry: "bundle.*.js"}})

    conn = get(conn, "/apps/dash")
    assert response(conn, 200) == "export const v = 'new';"
    assert conn |> get_resp_header("content-type") |> hd() =~ "text/javascript"
    assert [_etag] = get_resp_header(conn, "etag")
  end

  test "a local :dir app serves sub-path assets typed by extension", %{conn: conn} do
    dir = tmp_app_dir()
    File.write!(Path.join(dir, "bundle.abc.js"), "//js")
    File.write!(Path.join(dir, "style.css"), ".x{color:red}")
    Application.put_env(:keen_phoenix_svelte, :apps, %{"dash" => %{dir: dir, entry: "bundle.*.js"}})

    css = get(conn, "/apps/dash/style.css")
    assert response(css, 200) == ".x{color:red}"
    assert css |> get_resp_header("content-type") |> hd() =~ "text/css"
  end

  test "a local :dir app answers a browser If-None-Match with 304", %{conn: conn} do
    dir = tmp_app_dir()
    File.write!(Path.join(dir, "bundle.v1.js"), "//v1")
    # ttl 0 → every request revalidates; an unchanged file 304s and keeps the ETag.
    Application.put_env(:keen_phoenix_svelte, :apps, %{"dash" => %{dir: dir, entry: "bundle.*.js", ttl: 0}})

    first = get(conn, "/apps/dash")
    assert response(first, 200)
    etag = first |> get_resp_header("etag") |> hd()

    second = conn |> put_req_header("if-none-match", etag) |> get("/apps/dash")
    assert response(second, 304) == ""
  end

  test "a local :dir app picks up a newer build on revalidation", %{conn: conn} do
    dir = tmp_app_dir()
    File.write!(Path.join(dir, "bundle.1.js"), "//one")
    File.touch!(Path.join(dir, "bundle.1.js"), 1_700_000_000)
    Application.put_env(:keen_phoenix_svelte, :apps, %{"dash" => %{dir: dir, entry: "bundle.*.js", ttl: 0}})

    assert response(get(conn, "/apps/dash"), 200) == "//one"

    # A new hashed build lands, strictly newer → newest-match flips to it.
    File.write!(Path.join(dir, "bundle.2.js"), "//two")
    File.touch!(Path.join(dir, "bundle.2.js"), 1_700_000_200)

    assert response(get(conn, "/apps/dash"), 200) == "//two"
  end

  test "a local :dir app with no matching file is a 502", %{conn: conn} do
    dir = tmp_app_dir()
    Application.put_env(:keen_phoenix_svelte, :apps, %{"dash" => %{dir: dir, entry: "bundle.*.js"}})
    assert response(get(conn, "/apps/dash"), 502)
  end

  test "an unknown app is 404", %{conn: conn} do
    Application.put_env(:keen_phoenix_svelte, :apps, %{})
    conn = get(conn, "/apps/does-not-exist")
    assert response(conn, 404)
  end

  test "an upstream failure is 502", %{conn: conn} do
    url = "https://cdn.example/broken-#{System.unique_integer([:positive])}.mjs"
    Application.put_env(:keen_phoenix_svelte, :apps, %{"broken" => url})
    Application.put_env(:keen_phoenix_svelte, :app_provider, fn ^url -> {:error, :nxdomain} end)

    conn = get(conn, "/apps/broken")
    assert response(conn, 502)
  end

  defp restore_proxy_cache(nil), do: Application.delete_env(:keen_phoenix_svelte, :proxy_cache)
  defp restore_proxy_cache(orig), do: Application.put_env(:keen_phoenix_svelte, :proxy_cache, orig)

  # A throwaway dir per test — unique, so ProxyCache's ETS keys never bleed.
  defp tmp_app_dir do
    dir = Path.join(System.tmp_dir!(), "kps-app-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end
end
