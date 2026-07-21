defmodule KeenPhoenixSvelteComponentTest do
  # Mutates the global :keen_phoenix_svelte :placeholder env, so run serially.
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  setup do
    orig = Application.fetch_env(:keen_phoenix_svelte, :placeholder)
    on_exit(fn -> restore(orig) end)
    :ok
  end

  test "renders the hook-bound wrapper with data attributes" do
    html =
      render_component(&KeenPhoenixSvelte.app/1, %{name: "like", id: "like-1", props: %{a: 1}})

    assert html =~ ~s(phx-hook="KeenSvelte")
    assert html =~ ~s(phx-update="ignore")
    assert html =~ ~s(data-app="like")
    assert html =~ ~s(data-props="{&quot;a&quot;:1}")
  end

  test "with no config, injects the built-in skeleton placeholder" do
    Application.delete_env(:keen_phoenix_svelte, :placeholder)
    html = render_component(&KeenPhoenixSvelte.app/1, %{name: "like", id: "like-1"})

    assert html =~ "keen-island-pulse"
  end

  test "a configured HTML string becomes the placeholder" do
    Application.put_env(:keen_phoenix_svelte, :placeholder, ~s(<div class="skel"></div>))
    html = render_component(&KeenPhoenixSvelte.app/1, %{name: "like", id: "like-1"})

    assert html =~ ~s(<div class="skel"></div>)
    refute html =~ "keen-island-pulse"
  end

  test "a configured function receives the app name" do
    Application.put_env(:keen_phoenix_svelte, :placeholder, fn name ->
      "<p>loading #{name}</p>"
    end)

    html = render_component(&KeenPhoenixSvelte.app/1, %{name: "chart", id: "c-1"})

    assert html =~ "<p>loading chart</p>"
  end

  test "config false disables the placeholder globally" do
    Application.put_env(:keen_phoenix_svelte, :placeholder, false)
    html = render_component(&KeenPhoenixSvelte.app/1, %{name: "like", id: "like-1"})

    refute html =~ "keen-island-pulse"
  end

  test "an empty <:placeholder /> slot opts out, even with a server default set" do
    Application.put_env(:keen_phoenix_svelte, :placeholder, ~s(<div class="skel"></div>))

    # A self-closing slot has an entry but no inner_block — must render nothing,
    # not raise (regression: render_slot/1 raises on a contentless slot).
    html =
      render_component(&KeenPhoenixSvelte.app/1, %{
        name: "like",
        id: "like-1",
        placeholder: [%{__slot__: :placeholder}]
      })

    refute html =~ "skel"
    refute html =~ "keen-island-pulse"
  end

  test "a :placeholder slot overrides the server default" do
    Application.put_env(:keen_phoenix_svelte, :placeholder, ~s(<div class="skel"></div>))

    html =
      render_component(&KeenPhoenixSvelte.app/1, %{
        name: "like",
        id: "like-1",
        placeholder: [%{inner_block: fn _, _ -> "custom loader" end}]
      })

    assert html =~ "custom loader"
    refute html =~ "skel"
  end

  defp restore(:error), do: Application.delete_env(:keen_phoenix_svelte, :placeholder)
  defp restore({:ok, val}), do: Application.put_env(:keen_phoenix_svelte, :placeholder, val)
end
