defmodule KeenPhoenixSvelte do
  @moduledoc """
  Auto-mount compiled client apps ("islands") inside Phoenix — LiveView or plain
  pages.

  Svelte is the first-class, tooled path (hence the name), but the mount boundary
  is **framework-neutral**: any island whose JS entry default-exports
  `(target, { props, context, live, api, channel, bus, el }) => { setProps, destroy }`
  works — Svelte, Lit, React, or hand-written vanilla JS. Because every island
  mounts through that one contract, there is a **single** component, `app/1` — the
  framework makes no difference to how it's rendered or mounted.

  This library ships two cooperating halves:

    * an Elixir **function component** (`app/1`) that renders a placeholder `<div>`
      carrying a LiveView hook, and
    * a JavaScript **hook + `AppsManager`** (published as the npm package
      `@keenmate/phoenix_svelte`) that lazily imports the compiled bundle for
      the requested app and mounts it into that div.

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

      <.app name="like" id={"like-\#{@id}"} props={%{id: @id, liked: @liked}} />

  The `id` must be unique and stable (required by LiveView hooks). Props are
  JSON-encoded into a data attribute and parsed back on the client, so nested
  maps, numbers and booleans survive the trip.
  """

  use Phoenix.Component

  @doc """
  Renders a mount point for the compiled client app ("island") named `name`.

  This is the one and only island component. It is **framework-neutral**: the
  bundle can be Svelte, Lit, React or vanilla JS, and it is rendered and mounted
  identically regardless — the framework never changes the wiring. Set the
  optional `framework` attribute only if you want a `data-framework` tag for
  debugging/inspection; it has no effect on behavior.

  ## Attributes

    * `name` (required) - the app folder name under `assets/apps/`, resolved at
      runtime to `/apps/<name>/main.mjs` (or a registered/CDN URL — see
      `KeenPhoenixSvelte.Apps`).
    * `id` (required) - unique, stable DOM id (LiveView hooks require it).
    * `props` - a map passed to the app. Defaults to `%{}`.
    * `framework` - optional label emitted as `data-framework` (informational
      only; the runtime never reads it).
    * `class` - optional class list on the wrapper div.
    * `tag` - wrapper element, defaults to `"div"`.

  Any other attribute (e.g. `data-*`, `style`) is forwarded to the wrapper via
  the `:global` attribute.

  ## Placeholder / loader (no flash of empty container)

  Until the compiled bundle is fetched and mounted, the wrapper would otherwise
  be empty. To avoid that flash, the wrapper is rendered with a **placeholder**
  that the client clears the instant it mounts the app (after the bundle loads,
  so it stays visible for the whole fetch). Because the wrapper is
  `phx-update="ignore"`, the placeholder is rendered once and never re-diffed.

  Resolution, most specific first:

    1. A `<:placeholder>` slot on this call — full HEEx, overrides everything.
       An empty slot (`<:placeholder />`) disables the placeholder for this app.
    2. The server-wide default, `config :keen_phoenix_svelte, :placeholder`.
    3. A built-in, dependency-free skeleton (used when nothing is configured).

  Configure the server-wide default once (e.g. in `config/config.exs`):

      # raw HTML string
      config :keen_phoenix_svelte, placeholder: ~s(<div class="my-skeleton"></div>)

      # or a function (1-arity gets the app name), or false to disable globally
      config :keen_phoenix_svelte, placeholder: &MyApp.app_loader/1
      config :keen_phoenix_svelte, placeholder: false

  Per app, override with the slot:

      <.app name="chart" id="chart" props={@cfg}>
        <:placeholder>
          <div class="skeleton h-64 w-full"></div>
        </:placeholder>
      </.app>
  """
  attr :name, :string, required: true
  attr :id, :string, required: true
  attr :props, :map, default: %{}
  attr :framework, :string, default: nil
  attr :class, :any, default: nil
  attr :tag, :string, default: "div"
  attr :rest, :global

  slot :placeholder,
    doc: "Markup shown until the island mounts. Overrides the server-wide default."

  def app(assigns) do
    # Normalize the slot so app/1 is safe to call directly (as a plain function),
    # where the placeholder slot may never be set.
    placeholder = Map.get(assigns, :placeholder, [])
    # A slot with actual inner content wins. A given-but-empty slot
    # (`<:placeholder />`) is an explicit opt-out: render nothing. No slot at all
    # falls back to the server-wide default.
    render_slot? = Enum.any?(placeholder, &(Map.get(&1, :inner_block) != nil))

    assigns =
      assigns
      |> assign(:render_placeholder_slot?, render_slot?)
      |> assign(
        :default_placeholder,
        if(placeholder == [], do: resolve_placeholder(assigns.name))
      )
      |> assign(:placeholder, placeholder)

    ~H"""
    <.dynamic_tag
      tag_name={@tag}
      id={@id}
      class={@class}
      phx-hook="KeenSvelte"
      phx-update="ignore"
      data-app={@name}
      data-framework={@framework}
      data-props={Jason.encode!(@props)}
      {@rest}
    >
      <%= cond do %>
        <% @render_placeholder_slot? -> %>
          {render_slot(@placeholder)}
        <% @default_placeholder -> %>
          {Phoenix.HTML.raw(@default_placeholder)}
        <% true -> %>
      <% end %>
    </.dynamic_tag>
    """
  end

  # The built-in loader: a neutral skeleton block that fills the container with a
  # gentle opacity pulse. Inline styles + `currentColor` so it renders identically
  # (and theme-adaptively) on LiveView and plain pages — islands carry no Tailwind.
  # `min-height` keeps it visible when the container has no intrinsic size; the
  # pulse stays subtle so it reads as "content loading", not "app busy".
  @default_placeholder ~s|<div aria-hidden="true" style="width:100%;height:100%;min-height:2.5rem;border-radius:.5rem;background:currentColor;opacity:.12;animation:keen-app-pulse 1.4s ease-in-out infinite"></div><style>@keyframes keen-app-pulse{0%,100%{opacity:.1}50%{opacity:.2}}</style>|

  # Resolves the server-wide placeholder for `name`. Unset -> built-in skeleton;
  # `false`/`nil` -> none; a string -> raw HTML; a function or {mod, fun} -> its
  # result (a 1-arity function/`{mod, fun}` receives the app name).
  defp resolve_placeholder(name) do
    case Application.get_env(:keen_phoenix_svelte, :placeholder, :__builtin__) do
      :__builtin__ -> @default_placeholder
      builtin when builtin in [true, :default] -> @default_placeholder
      falsy when falsy in [false, nil] -> nil
      html when is_binary(html) -> html
      fun when is_function(fun, 0) -> fun.()
      fun when is_function(fun, 1) -> fun.(name)
      {mod, fun} -> apply(mod, fun, [name])
    end
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
  belongs in each `<.app props={...} />`.

  The context is JSON-encoded with HTML-safe escaping so it is safe to embed in
  the `<script type="application/json">` tag.

  ## Preloading bundles

  An island's bundle is normally fetched *lazily* by the client — on a LiveView
  page that `import()` doesn't fire until the socket connects and the hook mounts,
  so the download starts hundreds of ms into the page. Set `preload` to have the
  browser fetch the bundles **during initial HTML parse** instead, via
  `<link rel="modulepreload">`, so the bytes are cached by the time the hook runs
  (the render still waits on mount — you're only moving the *download* earlier):

      <KeenPhoenixSvelte.runtime context={@ctx} preload={["metrics", "chat"]} />

  `preload` accepts:

    * `false` (default) — emit nothing.
    * a **list of app names** — preload exactly those (scope it to the islands on
      *this* page). Registered apps use their manifest URL; an unregistered local
      app falls back to `base_path/<name>/main.mjs`.
    * `true` — preload every app in the manifest. Only registered/external apps are
      known server-side, so this can't cover unregistered local apps; and it
      over-fetches if the registry holds apps not on this page. Prefer the list.

  A cross-origin (`:direct`) URL gets `crossorigin="anonymous"` so the preload's
  credentials mode matches the module `import()` and the fetch is actually reused.

  Only the **entry** bundle is preloaded. A multi-file island's sibling assets
  (a stylesheet or data file it pulls via `new URL("./x.css", import.meta.url)`) are
  discovered *inside* the bundle at mount time, so the server can't know their URLs
  to preload them. If a sibling's early load matters, inline it into the JS
  (single-file island) or add your own `<link rel="preload">` for a known filename.
  """
  attr :context, :map, default: %{}
  attr :id, :string, default: "keen-context"

  attr :preload, :any,
    default: false,
    doc:
      "Emit <link rel=modulepreload> for app bundles: `false` (none), a list of app names, or `true` (all manifest apps)."

  def runtime(assigns) do
    manifest = KeenPhoenixSvelte.Apps.manifest()

    assigns =
      assigns
      |> assign(:apps_manifest, manifest)
      |> assign(:preloads, preload_links(manifest, assigns.preload))

    ~H"""
    <link
      :for={p <- @preloads}
      rel="modulepreload"
      href={p.href}
      crossorigin={p.crossorigin}
    />
    <script type="application/json" id={@id}>
      <%= Phoenix.HTML.raw(Jason.encode!(@context, escape: :html_safe)) %>
    </script>
    <script
      :if={@apps_manifest != %{}}
      type="application/json"
      id="keen-apps"
    >
      <%= Phoenix.HTML.raw(Jason.encode!(@apps_manifest, escape: :html_safe)) %>
    </script>
    """
  end

  # Resolve `preload` into `[%{href, crossorigin}]`. A list scopes to named apps
  # (registered → manifest URL, else the local base-path fallback, mirroring
  # `AppsManager.resolve`); `true` takes the whole manifest.
  defp preload_links(manifest, true),
    do: manifest |> Map.values() |> Enum.uniq() |> Enum.map(&preload_link/1)

  defp preload_links(manifest, names) when is_list(names) do
    base = KeenPhoenixSvelte.Apps.base_path()

    names
    |> Enum.map(fn name ->
      name = to_string(name)
      manifest[name] || base <> "/" <> name <> "/main.mjs"
    end)
    |> Enum.uniq()
    |> Enum.map(&preload_link/1)
  end

  defp preload_links(_manifest, _preload), do: []

  defp preload_link(url), do: %{href: url, crossorigin: crossorigin(url)}

  # An absolute http(s) URL is a cross-origin (:direct) bundle; a `/…` URL is
  # same-origin (:proxy / local). Match the module import's credentials mode so the
  # preload is reused rather than fetched twice.
  defp crossorigin("http://" <> _), do: "anonymous"
  defp crossorigin("https://" <> _), do: "anonymous"
  defp crossorigin(_url), do: nil
end
