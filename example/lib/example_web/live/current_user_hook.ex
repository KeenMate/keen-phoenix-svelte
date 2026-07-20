defmodule ExampleWeb.CurrentUserHook do
  @moduledoc """
  `on_mount` hook that resolves the current demo user from the session and
  assigns `:current_user` for every LiveView in the workspace `live_session`.

  The dead-render side is handled by `ExampleWeb.Plugs.CurrentUser` (so the root
  layout can render the runtime context); this is its LiveView counterpart.
  """
  import Phoenix.Component
  alias Example.{Directory, I18n}

  def on_mount(:default, _params, session, socket) do
    user =
      case session["user_id"] do
        nil -> Directory.default()
        id -> Directory.get(id) || Directory.default()
      end

    locale = I18n.locale(session["locale"])
    Gettext.put_locale(ExampleWeb.Gettext, locale)

    {:cont, socket |> assign(:current_user, user) |> assign(:locale, locale)}
  end
end
