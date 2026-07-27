defmodule ExampleWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ExampleWeb, :html

  alias Example.{Directory, I18n}

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  # Site-wide SEO / social metadata, used by the root layout's <head> (meta
  # description + Open Graph + Twitter card). This site is the live demo *for the
  # package*, so the metadata describes keen_phoenix_svelte itself.
  @site_name "keen_phoenix_svelte"
  @og_title "keen_phoenix_svelte — compiled Svelte apps as Phoenix islands"
  @site_description "Auto-mount compiled Svelte — or Lit, React, vanilla-JS — apps into Phoenix, on both LiveView and plain pages, as self-contained islands. Each island gets a standard server boundary (context, live, api, channel) and a client-side event bus. A dual Hex + npm package."

  @keywords "keen_phoenix_svelte, @keenmate/phoenix_svelte, Phoenix, Phoenix LiveView, Svelte, Elixir, islands architecture, Phoenix islands, Svelte islands, Lit, React, web components, Hex package, npm, KeenMate"

  @doc "The app/site name (Open Graph `site_name`, title suffix)."
  def site_name, do: @site_name
  @doc "The social-share title (Open Graph / Twitter)."
  def og_title, do: @og_title
  @doc "The meta description shared by SEO + Open Graph + Twitter."
  def site_description, do: @site_description
  @doc "SEO keywords describing the package."
  def keywords, do: @keywords

  @doc """
  The KeenSpace workspace shell: a fixed sidebar (Chat / Videos / Calendar), a
  top bar with the theme toggle and user switcher, and a content area where the
  page's Svelte island is mounted.

  Used by every workspace LiveView (and the plain calendar page), so the chrome
  is identical whether the island runs inside a LiveView or on a dead page.
  """
  attr :current_user, :map, required: true
  attr :active, :atom, default: nil, doc: "which nav item to highlight"
  attr :title, :string, default: nil
  attr :locale, :string, default: "en"
  attr :flash, :map, default: %{}
  slot :inner_block, required: true
  slot :aside, doc: "optional right-column explainer (see <.info_panel>)"

  def workspace(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-300 text-base-content">
      <%!-- Centered app canvas: capped at 1600px and centered so on wide screens
      it reads as one focused surface. Below `lg` the sidebar collapses into a
      daisyUI drawer toggled by the header burger. --%>
      <div class="mx-auto max-w-[1600px] min-h-screen bg-base-200 shadow-xl">
        <div class="drawer lg:drawer-open">
          <input id="nav-drawer" type="checkbox" class="drawer-toggle" />

          <div class="drawer-content flex flex-col min-w-0 min-h-screen">
            <header class="h-14 shrink-0 bg-base-100 border-b border-base-300 flex items-center justify-between px-4 sm:px-6">
              <div class="flex items-center gap-2 min-w-0">
                <label
                  for="nav-drawer"
                  class="btn btn-ghost btn-sm btn-square lg:hidden"
                  aria-label={I18n.t(@locale, "shell.menu")}
                >
                  <.icon name="hero-bars-3" class="size-5" />
                </label>
                <h1 class="font-semibold truncate">{header_title(@locale, @active, @title)}</h1>
              </div>
              <div class="flex items-center gap-3">
                <a
                  href="https://github.com/KeenMate/keen-phoenix-svelte"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="flex items-center rounded-lg p-1.5 hover:bg-base-200"
                  title={I18n.t(@locale, "shell.github")}
                >
                  <svg viewBox="0 0 16 16" fill="currentColor" class="size-5 opacity-70" aria-hidden="true">
                    <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z" />
                  </svg>
                  <span class="sr-only">GitHub</span>
                </a>
                <.theme_toggle />
                <.language_switcher locale={@locale} />
                <.user_switcher current_user={@current_user} locale={@locale} />
              </div>
            </header>

            <main class="flex-1 overflow-auto">
              <div class="flex gap-6 p-6 min-h-full">
                <div class="flex-1 min-w-0">
                  {render_slot(@inner_block)}
                </div>
                <aside :if={@aside != []} class="hidden lg:block w-80 shrink-0">
                  {render_slot(@aside)}
                </aside>
              </div>
            </main>
          </div>

          <div class="drawer-side z-30">
            <label for="nav-drawer" class="drawer-overlay" aria-label={I18n.t(@locale, "shell.closeMenu")}></label>
            <aside class="w-60 min-h-screen bg-base-100 border-r border-base-300 flex flex-col">
              <.link navigate={~p"/"} class="h-14 px-4 flex items-center gap-2 border-b border-base-300">
                <span class="text-primary text-xl leading-none">◆</span>
                <span class="font-bold tracking-tight">KeenSpace</span>
              </.link>

              <nav class="flex-1 p-2 space-y-1">
                <.nav_item
                  navigate={~p"/"}
                  active={@active == :home}
                  icon="hero-home"
                  label={I18n.t(@locale, "nav.home")}
                />
                <.nav_item
                  navigate={~p"/chat"}
                  active={@active == :chat}
                  icon="hero-chat-bubble-left-right"
                  label={I18n.t(@locale, "nav.chat")}
                />
                <.nav_item
                  navigate={~p"/videos"}
                  active={@active == :videos}
                  icon="hero-play-circle"
                  label={I18n.t(@locale, "nav.videos")}
                />
                <.nav_item
                  navigate={~p"/calendar"}
                  active={@active == :calendar}
                  icon="hero-calendar-days"
                  label={I18n.t(@locale, "nav.calendar")}
                />
                <.nav_item
                  navigate={~p"/proxying"}
                  active={@active == :proxying}
                  icon="hero-globe-alt"
                  label={I18n.t(@locale, "nav.proxying")}
                />
                <.nav_item
                  navigate={~p"/proxying-plain"}
                  active={@active == :proxying_plain}
                  icon="hero-bolt"
                  label={I18n.t(@locale, "nav.proxyingPlain")}
                />
                <.nav_item
                  navigate={~p"/guarding"}
                  active={@active == :guarding}
                  icon="hero-shield-check"
                  label={I18n.t(@locale, "nav.guarding")}
                />
                <.nav_item
                  navigate={~p"/eager"}
                  active={@active == :eager}
                  icon="hero-rocket-launch"
                  label={I18n.t(@locale, "nav.eager")}
                />
                <.nav_item
                  navigate={~p"/stress"}
                  active={@active == :stress}
                  icon="hero-qr-code"
                  label={I18n.t(@locale, "nav.stress")}
                />
                <.nav_item
                  navigate={~p"/widgets"}
                  active={@active == :widgets}
                  icon="hero-squares-2x2"
                  label={I18n.t(@locale, "nav.widgets")}
                />
                <.nav_item
                  navigate={~p"/docs"}
                  active={@active == :docs}
                  icon="hero-book-open"
                  label={I18n.t(@locale, "nav.docs")}
                />
              </nav>

              <p class="p-3 text-xs text-base-content/40">
                {I18n.t(@locale, "shell.tagline")}
              </p>
            </aside>
          </div>
        </div>
      </div>
    </div>

    <%!-- Page-wide toast feed. Its own island; it coordinates with the other
    islands purely through the event bus (no props, no server). Fully-qualified
    because THIS module defines its own `app/1` (the layout), so a bare `<.app>`
    here would be ambiguous — see the note in installation.md. --%>
    <KeenPhoenixSvelte.app name="activity" id="activity-app" props={%{}} />

    <.flash_group flash={@flash} />
    """
  end

  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
        (@active && "bg-primary text-primary-content") || "hover:bg-base-200"
      ]}
    >
      <.icon name={@icon} class="size-5" />
      {@label}
    </.link>
    """
  end

  # The header title: prefer the localized nav label for the four main areas,
  # otherwise fall back to the page-supplied title (e.g. the plain calendar page).
  defp header_title(locale, active, _title)
       when active in [:home, :chat, :videos, :calendar, :proxying, :docs],
       do: I18n.t(locale, "nav.#{active}")

  defp header_title(locale, :eager, _title), do: I18n.t(locale, "nav.eager")
  defp header_title(locale, :stress, _title), do: I18n.t(locale, "nav.stress")
  defp header_title(locale, :widgets, _title), do: I18n.t(locale, "nav.widgets")

  defp header_title(_locale, _active, title), do: title || ""

  @doc """
  The language switcher — a dropdown of supported locales, each a small POST form
  to `SessionController.locale/2`. Submitting reloads the page so the root layout
  re-issues the runtime `context` with the new `locale` for every island.
  """
  attr :locale, :string, required: true

  def language_switcher(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div
        tabindex="0"
        role="button"
        class="flex items-center gap-1.5 cursor-pointer rounded-lg px-2 py-1.5 text-sm hover:bg-base-200"
        title={I18n.t(@locale, "switch.language")}
      >
        <.icon name="hero-language" class="size-4 opacity-70" />
        <span class="font-medium">{String.upcase(@locale)}</span>
        <.icon name="hero-chevron-down-micro" class="size-4 opacity-60" />
      </div>

      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box shadow-lg z-10 w-48 p-2 mt-2 border border-base-300"
      >
        <li class="menu-title text-xs">{I18n.t(@locale, "switch.language")}</li>
        <li :for={loc <- I18n.locales()}>
          <form method="post" action={~p"/session/locale"} class="p-0">
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <input type="hidden" name="locale" value={loc.code} />
            <button
              type="submit"
              class={[
                "flex items-center justify-between gap-2 w-full",
                loc.code == @locale && "active"
              ]}
            >
              <span class="flex items-center gap-2">
                <span class="inline-flex w-7 justify-center text-[0.65rem] font-semibold uppercase px-1.5 py-0.5 rounded bg-base-200 text-base-content/70">
                  {loc.code}
                </span>
                <span class="text-sm">{loc.label}</span>
              </span>
              <.icon :if={loc.code == @locale} name="hero-check-micro" class="size-4 text-primary" />
            </button>
          </form>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  A right-column "what is this / how is it wired" explainer, shown next to each
  island so the demo doubles as annotated reference code. The body slot holds the
  prose; each `:wire` entry is one boundary piece (props / context / live / api /
  channel) with a short note on how this page uses it.

  ## Example

      <.info_panel title="What is this?">
        <p>The chat island is a self-contained Svelte app.</p>
        <:wire label="channel">Joins <code>chat:&lt;room&gt;</code> on the page socket.</:wire>
      </.info_panel>
  """
  attr :title, :string, default: "What is this?"
  slot :inner_block, required: true

  slot :wire, doc: "one boundary piece and how this page uses it" do
    attr :label, :string, required: true
  end

  def info_panel(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 rounded-lg p-4 space-y-4 sticky top-0">
      <div class="flex items-center gap-2">
        <.icon name="hero-information-circle" class="size-5 text-primary" />
        <h2 class="font-semibold text-sm">{@title}</h2>
      </div>

      <div class="text-sm text-base-content/70 leading-relaxed space-y-2 [&_code]:text-primary [&_code]:text-xs [&_strong]:text-base-content">
        {render_slot(@inner_block)}
      </div>

      <div :if={@wire != []} class="space-y-3 pt-3 border-t border-base-300">
        <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">
          How it's connected
        </p>
        <dl class="space-y-3">
          <div :for={w <- @wire} class="grid grid-cols-[5rem_1fr] gap-2 items-baseline">
            <dt>
              <code class="text-xs font-mono px-1.5 py-0.5 rounded bg-primary/10 text-primary">
                {w.label}
              </code>
            </dt>
            <dd class="text-xs text-base-content/70 leading-relaxed [&_code]:text-primary">
              {render_slot(w)}
            </dd>
          </div>
        </dl>
      </div>
    </div>
    """
  end

  @doc """
  A person's profile card, shown in the right column of the Chat page. It is
  rendered by *LiveView* (server-side) when the Svelte chat island pushes a
  `show_profile` event — a small demo of an island and its host LiveView
  cooperating: the island owns realtime, LiveView owns this bit of chrome.
  """
  attr :user, :map, required: true

  def profile_card(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 rounded-lg p-5 sticky top-0">
      <div class="flex items-start justify-between">
        <span
          class="inline-flex items-center justify-center w-16 h-16 rounded-full text-white text-xl font-semibold"
          style={"background:#{@user.color}"}
        >
          {Directory.initials(@user)}
        </span>
        <button
          type="button"
          phx-click="clear_profile"
          class="btn btn-ghost btn-xs btn-circle"
          aria-label="Close profile"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>

      <h2 class="mt-3 text-lg font-semibold">{@user.name}</h2>
      <p class="text-sm text-base-content/60">{@user.title}</p>

      <dl class="mt-4 space-y-2 text-sm">
        <div class="flex items-center gap-2">
          <.icon name="hero-envelope" class="size-4 text-base-content/40" />
          <a href={"mailto:#{@user.email}"} class="link link-primary truncate">{@user.email}</a>
        </div>
        <div class="flex items-center gap-2">
          <.icon name="hero-identification" class="size-4 text-base-content/40" />
          <span class="text-base-content/70">User #{@user.id} · KeenSpace directory</span>
        </div>
      </dl>

      <p class="mt-4 pt-3 border-t border-base-300 text-xs text-base-content/50">
        Loaded by LiveView (<code class="text-primary">handle_event("show_profile", …)</code>)
        when you clicked this avatar in the Svelte island.
      </p>
    </div>
    """
  end

  @doc """
  The demo user switcher. Each entry is a small POST form to
  `SessionController.switch/2`; submitting reloads the page so the root layout
  re-issues the runtime context (socket + Graph tokens) for the chosen user.
  """
  attr :current_user, :map, required: true
  attr :locale, :string, default: "en"

  def user_switcher(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="flex items-center gap-2 cursor-pointer">
        <span
          class="inline-flex items-center justify-center w-7 h-7 rounded-full text-white text-xs font-semibold"
          style={"background:#{@current_user.color}"}
        >
          {Directory.initials(@current_user)}
        </span>
        <span class="text-sm font-medium hidden sm:inline">{@current_user.name}</span>
        <.icon name="hero-chevron-down-micro" class="size-4 opacity-60" />
      </div>

      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box shadow-lg z-10 w-60 p-2 mt-2 border border-base-300"
      >
        <li class="menu-title text-xs">{I18n.t(@locale, "switch.user")}</li>
        <li :for={user <- Directory.list()}>
          <form method="post" action={~p"/session/switch"} class="p-0">
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <input type="hidden" name="user_id" value={user.id} />
            <button
              type="submit"
              class={["flex items-center gap-2 w-full", user.id == @current_user.id && "active"]}
            >
              <span
                class="inline-flex items-center justify-center w-6 h-6 rounded-full text-white text-[0.6rem] font-semibold"
                style={"background:#{user.color}"}
              >
                {Directory.initials(user)}
              </span>
              <span class="flex flex-col items-start leading-tight">
                <span class="text-sm">{user.name}</span>
                <span class="text-xs opacity-60">{user.title}</span>
              </span>
            </button>
          </form>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
