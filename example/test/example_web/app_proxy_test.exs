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

  # A throwaway dir per test — unique, so ProxyCache's ETS keys never bleed.
  defp tmp_app_dir do
    dir = Path.join(System.tmp_dir!(), "kps-app-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end
end
