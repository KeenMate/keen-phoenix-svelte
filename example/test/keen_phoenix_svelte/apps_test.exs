defmodule KeenPhoenixSvelte.AppsTest do
  # Mutates the global :keen_phoenix_svelte app env, so run serially.
  use ExUnit.Case, async: false

  alias KeenPhoenixSvelte.Apps

  setup do
    orig_apps = Application.get_env(:keen_phoenix_svelte, :apps)
    orig_mode = Application.get_env(:keen_phoenix_svelte, :load_mode)
    orig_otp = Application.get_env(:keen_phoenix_svelte, :otp_app)
    orig_path = Application.get_env(:keen_phoenix_svelte, :apps_static_path)

    # Turn off local-app detection by default so manifest assertions are about the
    # registered apps only; the merge tests opt back in with :apps_static_path.
    Application.delete_env(:keen_phoenix_svelte, :otp_app)
    Application.delete_env(:keen_phoenix_svelte, :apps_static_path)

    on_exit(fn ->
      restore(:apps, orig_apps)
      restore(:load_mode, orig_mode)
      restore(:otp_app, orig_otp)
      restore(:apps_static_path, orig_path)
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

  test "local :dir app allows a legit nested sub-path (containment doesn't over-block)" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{"dash" => %{dir: "/srv/apps/dash"}})

    assert Apps.resolve(["dash", "assets", "x.css"]) ==
             {"dash", "file:" <> Path.join("/srv/apps/dash", "assets/x.css"), "assets/x.css"}
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

  test "proxy_opts surfaces per-app + global cache-control overrides separately" do
    orig_cache = Application.get_env(:keen_phoenix_svelte, :proxy_cache)
    on_exit(fn -> restore(:proxy_cache, orig_cache) end)

    Application.put_env(:keen_phoenix_svelte, :proxy_cache,
      client_cache_control: "public, max-age=60",
      immutable_cache_control: "public, max-age=604800, immutable"
    )

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "plain" => "https://cdn/plain.mjs",
      "hourly" => %{url: "https://cdn/hourly.mjs", client_cache_control: "public, max-age=3600"}
    })

    assert %{
             client_cache_control: nil,
             global_cache_control: "public, max-age=60",
             immutable_cache_control: "public, max-age=604800, immutable"
           } = Apps.proxy_opts("plain")

    assert %{client_cache_control: "public, max-age=3600"} = Apps.proxy_opts("hourly")
  end

  test "local apps are detected and merged into the manifest with convention URLs" do
    dir = tmp_apps_dir(["chat", "videos"])
    Application.put_env(:keen_phoenix_svelte, :apps_static_path, dir)

    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "metrics" => %{url: "https://cdn/m.mjs", mode: :direct}
    })

    assert Apps.local_apps() == ["chat", "videos"]

    manifest = Apps.manifest()
    # local folders → the convention URL the client would fall back to
    assert manifest["chat"] == "/apps/chat/main.mjs"
    assert manifest["videos"] == "/apps/videos/main.mjs"
    # ...merged with the registered (external) app
    assert manifest["metrics"] == "https://cdn/m.mjs"
  end

  test "a registered app overrides a same-named local folder" do
    dir = tmp_apps_dir(["chat"])
    Application.put_env(:keen_phoenix_svelte, :apps_static_path, dir)
    # Explicit :direct so the manifest URL is the CDN one regardless of any
    # load_mode left set by an earlier (serial) test.
    Application.put_env(:keen_phoenix_svelte, :apps, %{"chat" => %{url: "https://cdn/chat.mjs", mode: :direct}})

    assert Apps.manifest()["chat"] == "https://cdn/chat.mjs"
  end

  test "a folder without main.mjs is not a local app" do
    dir = tmp_apps_dir(["real"])
    File.mkdir_p!(Path.join(dir, "empty"))
    Application.put_env(:keen_phoenix_svelte, :apps_static_path, dir)

    assert Apps.local_apps() == ["real"]
  end

  test "local detection is off without :otp_app / :apps_static_path" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{})
    assert Apps.local_apps() == []
    assert Apps.manifest() == %{}
  end

  defp tmp_apps_dir(names) do
    base = Path.join(System.tmp_dir!(), "kps-apps-#{System.unique_integer([:positive])}")

    Enum.each(names, fn name ->
      File.mkdir_p!(Path.join(base, name))
      File.write!(Path.join([base, name, "main.mjs"]), "export default 0;")
    end)

    on_exit(fn -> File.rm_rf(base) end)
    base
  end

  # Reset to the original state: delete when it was unset (so a value set mid-test
  # doesn't leak into the next serial test), else put the original back.
  defp restore(key, nil), do: Application.delete_env(:keen_phoenix_svelte, key)
  defp restore(key, val), do: Application.put_env(:keen_phoenix_svelte, key, val)
end
