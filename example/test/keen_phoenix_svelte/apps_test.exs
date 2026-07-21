defmodule KeenPhoenixSvelte.AppsTest do
  # Mutates the global :keen_phoenix_svelte app env, so run serially.
  use ExUnit.Case, async: false

  alias KeenPhoenixSvelte.Apps

  setup do
    orig_apps = Application.get_env(:keen_phoenix_svelte, :apps)
    orig_mode = Application.get_env(:keen_phoenix_svelte, :load_mode)

    on_exit(fn ->
      restore(:apps, orig_apps)
      restore(:load_mode, orig_mode)
    end)

    :ok
  end

  test "direct mode: the manifest is the raw URL and upstream keeps it" do
    Application.put_env(:keen_phoenix_svelte, :load_mode, :direct)
    Application.put_env(:keen_phoenix_svelte, :apps, %{"x" => "https://cdn/x.mjs"})

    assert Apps.manifest() == %{"x" => "https://cdn/x.mjs"}
    assert Apps.upstream("x") == "https://cdn/x.mjs"
  end

  test "proxy mode: the manifest points same-origin; upstream keeps the real URL" do
    Application.put_env(:keen_phoenix_svelte, :load_mode, :proxy)
    Application.put_env(:keen_phoenix_svelte, :apps, %{"x" => "https://cdn/x.mjs"})

    assert Apps.manifest() == %{"x" => "/apps/x"}
    assert Apps.upstream("x") == "https://cdn/x.mjs"
  end

  test "a per-app mode overrides the global default" do
    Application.put_env(:keen_phoenix_svelte, :load_mode, :proxy)

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "x" => %{url: "https://cdn/x.mjs", mode: :direct}
    })

    assert Apps.manifest() == %{"x" => "https://cdn/x.mjs"}
  end

  test "an unregistered app has no upstream (client falls back to base_path)" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{})
    assert Apps.upstream("nope") == nil
    assert Apps.manifest() == %{}
  end

  test "proxy_opts merges per-app ttl/immutable over the global :proxy_cache config" do
    orig_cache = Application.get_env(:keen_phoenix_svelte, :proxy_cache)
    on_exit(fn -> restore(:proxy_cache, orig_cache) end)

    Application.put_env(:keen_phoenix_svelte, :proxy_cache, ttl: 1_000, respect_upstream: false)

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "plain" => "https://cdn/plain.mjs",
      "quick" => %{url: "https://cdn/quick.mjs", ttl: 250},
      "pinned" => %{url: "https://cdn/pinned.mjs", immutable: true}
    })

    assert %{ttl_ms: 1_000, respect_upstream: false, immutable: false} = Apps.proxy_opts("plain")
    assert %{ttl_ms: 250} = Apps.proxy_opts("quick")
    assert %{immutable: true} = Apps.proxy_opts("pinned")
  end

  defp restore(_key, nil), do: :ok
  defp restore(key, val), do: Application.put_env(:keen_phoenix_svelte, key, val)
end
