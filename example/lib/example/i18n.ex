defmodule Example.I18n do
  @moduledoc """
  A tiny, in-memory translation table for the demo **shell** (sidebar, switchers,
  headers).

  A real app would use Gettext (already available here as `ExampleWeb.Gettext`)
  with `.po` files. This keeps the demo self-contained and makes the *locale flow*
  obvious end-to-end:

    1. the locale is chosen in the session (the language switcher),
    2. put into the page-wide `context` by the root layout, and
    3. each autonomous Svelte island localizes **itself** from `context.locale`
       using its own small dictionary (see `assets/apps/*/js/i18n.js`).

  The islands never receive translated strings from the server — only the locale.
  That keeps them self-contained, exactly like the rest of the boundary.
  """

  @default "en"

  @locales [
    %{code: "en", label: "English"},
    %{code: "es", label: "Español"}
  ]

  @strings %{
    "en" => %{
      "nav.home" => "Welcome",
      "nav.chat" => "Chat",
      "nav.videos" => "Videos",
      "nav.calendar" => "Calendar",
      "nav.proxying" => "Proxying",
      "nav.proxyingPlain" => "Proxying (plain)",
      "nav.eager" => "Eager mount",
      "nav.docs" => "Docs",
      "shell.tagline" => "Built with keen_phoenix_svelte",
      "shell.github" => "View source on GitHub",
      "shell.menu" => "Menu",
      "shell.closeMenu" => "Close menu",
      "switch.user" => "Switch user (demo)",
      "switch.language" => "Language"
    },
    "es" => %{
      "nav.home" => "Bienvenido",
      "nav.chat" => "Chat",
      "nav.videos" => "Vídeos",
      "nav.calendar" => "Calendario",
      "nav.proxying" => "Proxying",
      "nav.proxyingPlain" => "Proxying (plano)",
      "nav.eager" => "Montaje eager",
      "nav.docs" => "Docs",
      "shell.tagline" => "Hecho con keen_phoenix_svelte",
      "shell.github" => "Ver el código en GitHub",
      "shell.menu" => "Menú",
      "shell.closeMenu" => "Cerrar menú",
      "switch.user" => "Cambiar usuario (demo)",
      "switch.language" => "Idioma"
    }
  }

  @doc "The fallback locale."
  @spec default() :: String.t()
  def default, do: @default

  @doc "All supported locales (code + label), for the switcher."
  @spec locales() :: [map()]
  def locales, do: @locales

  @doc "Whether `code` is a supported locale."
  @spec known?(term()) :: boolean()
  def known?(code), do: Enum.any?(@locales, &(&1.code == code))

  @doc "Normalize any input to a supported locale code, falling back to the default."
  @spec locale(term()) :: String.t()
  def locale(code) when is_binary(code), do: (known?(code) && code) || @default
  def locale(_), do: @default

  @doc "The locale's display metadata (code/label/flag)."
  @spec locale_meta(String.t()) :: map()
  def locale_meta(code), do: Enum.find(@locales, hd(@locales), &(&1.code == code))

  @doc "Translate `key` in `locale`, falling back to English then the key itself."
  @spec t(String.t(), String.t()) :: String.t()
  def t(locale, key) do
    strings = Map.get(@strings, locale, @strings[@default])
    Map.get(strings, key) || Map.get(@strings[@default], key) || key
  end
end
