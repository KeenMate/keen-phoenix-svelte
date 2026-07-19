defmodule KeenPhoenixSvelte do
  @moduledoc """
  Auto-mount compiled Svelte components inside Phoenix LiveView.

  This library ships two cooperating halves:

    * an Elixir **function component** (`svelte/1`) that renders a placeholder
      `<div>` carrying a LiveView hook, and
    * a JavaScript **hook + `AppsManager`** (published as the npm package
      `@keenmate/phoenix_svelte`) that lazily imports the compiled bundle for
      the requested app and mounts the Svelte component into that div.

  ## Why a hook (and not `data-app` + `window.load`)

  LiveView owns the DOM. A component mounted by hand on `window.load` fights
  morphdom on the next patch and never re-mounts across live navigation. The
  hook instead:

    * uses `phx-update="ignore"` so LiveView never touches the Svelte-owned
      subtree,
    * mounts in `mounted()`, pushes fresh props via `$set` in `updated()`, and
      tears the component down in `destroyed()`,
    * hands the component a `live` object (`pushEvent`, `handleEvent`, ...) so it
      talks to the server over the existing LiveView socket.

  ## Usage

      <.svelte name="like" id={"like-\#{@id}"} props={%{id: @id, liked: @liked}} />

  The `id` must be unique and stable (required by LiveView hooks). Props are
  JSON-encoded into a data attribute and parsed back on the client, so nested
  maps, numbers and booleans survive the trip.
  """

  use Phoenix.Component

  @doc """
  Renders a mount point for the compiled Svelte app named `name`.

  ## Attributes

    * `name` (required) - the app folder name under `assets/apps/`, resolved at
      runtime to `/apps/<name>/main.mjs`.
    * `id` (required) - unique, stable DOM id (LiveView hooks require it).
    * `props` - a map passed to the Svelte component. Defaults to `%{}`.
    * `class` - optional class list on the wrapper div.
    * `tag` - wrapper element, defaults to `"div"`.

  Any other attribute (e.g. `data-*`, `style`) is forwarded to the wrapper via
  the `:global` attribute.
  """
  attr :name, :string, required: true
  attr :id, :string, required: true
  attr :props, :map, default: %{}
  attr :class, :any, default: nil
  attr :tag, :string, default: "div"
  attr :rest, :global

  def svelte(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@tag}
      id={@id}
      class={@class}
      phx-hook="KeenSvelte"
      phx-update="ignore"
      data-app={@name}
      data-props={Jason.encode!(@props)}
      {@rest}
    ></.dynamic_tag>
    """
  end

  @doc """
  Emits the page-wide runtime context, read once by the client and injected into
  every mounted app as `context`.

  Render it once per page (e.g. in your root layout), on both LiveView and plain
  controller-rendered pages:

      <KeenPhoenixSvelte.runtime context={%{
        user: %{id: @current_user.id, name: @current_user.name, roles: @roles},
        csrf_token: get_csrf_token(),
        api_base: "/api"
      }} />

  Keep this to *context*, not payload — user identity, a CSRF token for the `api`
  helper, an `api_base`, locale, and any tokens the app needs. Per-app data
  belongs in each `<.svelte props={...} />`.

  The context is JSON-encoded with HTML-safe escaping so it is safe to embed in
  the `<script type="application/json">` tag.
  """
  attr :context, :map, default: %{}
  attr :id, :string, default: "keen-context"

  def runtime(assigns) do
    ~H"""
    <script type="application/json" id={@id}><%= Phoenix.HTML.raw(Jason.encode!(@context, escape: :html_safe)) %></script>
    """
  end
end
