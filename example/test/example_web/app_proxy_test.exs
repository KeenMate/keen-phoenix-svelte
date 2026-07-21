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
end
