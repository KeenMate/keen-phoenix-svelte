defmodule ExampleWeb.Plugs.Locale do
  @moduledoc """
  Resolves the current locale from the session and assigns it as `:locale`
  (falling back to the default). Also sets the Gettext locale so any framework
  strings in the dead-rendered shell follow suit.

  The `SessionController.locale/2` action stores the choice in the session; this
  plug reads it back on every request so the root layout can put `locale` into
  the page-wide `context` for the islands.
  """
  import Plug.Conn
  alias Example.I18n

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = I18n.locale(get_session(conn, "locale"))
    Gettext.put_locale(ExampleWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end
end
