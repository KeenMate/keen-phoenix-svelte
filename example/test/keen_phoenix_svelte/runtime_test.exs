defmodule KeenPhoenixSvelte.RuntimeTest do
  # Mutates the global :keen_phoenix_svelte :apps env, so run serially.
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  setup do
    orig = Application.get_env(:keen_phoenix_svelte, :apps)
    orig_otp = Application.get_env(:keen_phoenix_svelte, :otp_app)

    # Keep these tests about registered apps only (no local-folder detection).
    Application.delete_env(:keen_phoenix_svelte, :otp_app)
    Application.delete_env(:keen_phoenix_svelte, :apps_static_path)

    on_exit(fn ->
      if orig, do: Application.put_env(:keen_phoenix_svelte, :apps, orig),
      else: Application.delete_env(:keen_phoenix_svelte, :apps)

      if orig_otp, do: Application.put_env(:keen_phoenix_svelte, :otp_app, orig_otp)
    end)

    :ok
  end

  test "preload: false (default) emits no modulepreload links" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{"x" => "https://cdn/x.mjs"})
    html = render_component(&KeenPhoenixSvelte.runtime/1, context: %{})
    refute html =~ "modulepreload"
  end

  test "preload: a list emits a modulepreload per named app" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{
      # :direct → cross-origin absolute URL
      "hello" => %{url: "https://cdn/hello.mjs", mode: :direct},
      # :proxy → same-origin /apps path
      "metrics" => %{base: "https://cdn/metrics/", entry: "main.mjs", mode: :proxy}
    })

    html = render_component(&KeenPhoenixSvelte.runtime/1, context: %{}, preload: ["hello", "metrics"])

    assert html =~ ~s(rel="modulepreload")
    # cross-origin bundle: absolute URL + crossorigin so the preload is reused
    assert html =~ ~s(href="https://cdn/hello.mjs")
    assert html =~ ~s(crossorigin="anonymous")
    # same-origin proxy bundle: no crossorigin
    assert html =~ ~s(href="/apps/metrics/main.mjs")
  end

  test "preload: an unregistered local app falls back to base_path/<name>/main.mjs" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{})
    html = render_component(&KeenPhoenixSvelte.runtime/1, context: %{}, preload: ["chat"])

    assert html =~ ~s(rel="modulepreload")
    assert html =~ ~s(href="/apps/chat/main.mjs")
    refute html =~ "crossorigin"
  end

  test "preload: true emits a link for every manifest app" do
    Application.put_env(:keen_phoenix_svelte, :apps, %{
      "a" => %{url: "https://cdn/a.mjs", mode: :direct},
      "b" => %{url: "https://cdn/b.mjs", mode: :direct}
    })

    html = render_component(&KeenPhoenixSvelte.runtime/1, context: %{}, preload: true)

    assert html =~ ~s(href="https://cdn/a.mjs")
    assert html =~ ~s(href="https://cdn/b.mjs")
  end
end
