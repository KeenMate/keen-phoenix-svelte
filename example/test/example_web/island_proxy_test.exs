defmodule ExampleWeb.IslandProxyTest do
  # Mutates global :keen_phoenix_svelte env (apps + fetcher), so run serially.
  use ExampleWeb.ConnCase, async: false

  setup do
    orig_apps = Application.get_env(:keen_phoenix_svelte, :apps)

    on_exit(fn ->
      Application.delete_env(:keen_phoenix_svelte, :island_fetcher)
      if orig_apps, do: Application.put_env(:keen_phoenix_svelte, :apps, orig_apps)
    end)

    :ok
  end

  test "proxies a registered app's bundle same-origin as JS", %{conn: conn} do
    url = "https://cdn.example/proxied-#{System.unique_integer([:positive])}.mjs"
    Application.put_env(:keen_phoenix_svelte, :apps, %{"proxied" => url})

    Application.put_env(:keen_phoenix_svelte, :island_fetcher, fn ^url ->
      {:ok, "export default 1;"}
    end)

    conn = get(conn, "/keen-islands/proxied")

    assert response(conn, 200) == "export default 1;"
    assert conn |> get_resp_header("content-type") |> hd() =~ "text/javascript"
    assert conn |> get_resp_header("cache-control") |> hd() =~ "immutable"
  end

  test "an unknown island is 404", %{conn: conn} do
    Application.put_env(:keen_phoenix_svelte, :apps, %{})
    conn = get(conn, "/keen-islands/does-not-exist")
    assert response(conn, 404)
  end

  test "an upstream failure is 502", %{conn: conn} do
    url = "https://cdn.example/broken-#{System.unique_integer([:positive])}.mjs"
    Application.put_env(:keen_phoenix_svelte, :apps, %{"broken" => url})
    Application.put_env(:keen_phoenix_svelte, :island_fetcher, fn ^url -> {:error, :nxdomain} end)

    conn = get(conn, "/keen-islands/broken")
    assert response(conn, 502)
  end
end
