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

  test "resolve/1 maps a single-file app path to its upstream URL" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{"x" => "https://cdn/x.mjs"})
    assert Apps.resolve(["x"]) == {"x", "https://cdn/x.mjs", ""}
    assert Apps.resolve(["nope"]) == nil
    assert Apps.resolve([]) == nil
  end

  test "base-path app: manifest points at the entry; resolve forwards sub-paths" do
    Application.put_env(:keen_phoenix_svelte, :load_mode, :proxy)

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "player" => %{base: "https://cdn/player/", entry: "player.mjs"}
    })

    # The client imports the entry, same-origin.
    assert Apps.manifest() == %{"player" => "/apps/player/player.mjs"}

    # A bare hit resolves to the entry; a sub-path is appended to the base.
    assert Apps.resolve(["player"]) == {"player", "https://cdn/player/player.mjs", "player.mjs"}

    assert Apps.resolve(["player", "player.css"]) ==
             {"player", "https://cdn/player/player.css", "player.css"}

    assert Apps.resolve(["player", "assets", "logo.svg"]) ==
             {"player", "https://cdn/player/assets/logo.svg", "assets/logo.svg"}
  end

  test "base-path app in :direct mode imports the entry straight from the base" do
    Application.put_env(:keen_phoenix_svelte, :load_mode, :direct)
    Application.put_env(:keen_phoenix_svelte, :apps, %{"player" => %{base: "https://cdn/player/"}})

    # No entry given → defaults to main.mjs.
    assert Apps.manifest() == %{"player" => "https://cdn/player/main.mjs"}
  end

  test "resolve/1 rejects path traversal in a base-path sub-path" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{"player" => %{base: "https://cdn/player/"}})
    assert Apps.resolve(["player", "..", "secret"]) == nil
    assert Apps.resolve(["player", "ok.css"]) == {"player", "https://cdn/player/ok.css", "ok.css"}
  end

  test "local :dir app: manifest is a stable same-origin path; resolve globs the entry" do
    Application.put_env(:keen_phoenix_svelte, :load_mode, :proxy)

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "dash" => %{dir: "/srv/apps/dash", entry: "bundle.*.js"}
    })

    # The browser imports a bare, stable path — never the resolved (hashed) file.
    assert Apps.manifest() == %{"dash" => "/apps/dash"}

    # A bare hit becomes a glob source; a sub-path becomes a literal file source.
    assert Apps.resolve(["dash"]) ==
             {"dash", "file-glob:" <> Path.join("/srv/apps/dash", "bundle.*.js"), ""}

    assert Apps.resolve(["dash", "chunk.abc.js"]) ==
             {"dash", "file:" <> Path.join("/srv/apps/dash", "chunk.abc.js"), "chunk.abc.js"}
  end

  test "local :dir app defaults the entry glob to main.mjs and rejects traversal" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{"dash" => %{dir: "/srv/apps/dash"}})

    assert Apps.resolve(["dash"]) ==
             {"dash", "file-glob:" <> Path.join("/srv/apps/dash", "main.mjs"), ""}

    assert Apps.resolve(["dash", "..", "secret"]) == nil
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
