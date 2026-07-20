defmodule ExampleWeb.Plugs.CurrentUser do
  @moduledoc """
  Resolves the current demo user from the session and assigns it as
  `:current_user` (falling back to the first directory user).

  In a real app this is where you'd load the authenticated user — from the
  session, a bearer token, or an SSO assertion. Here it reads the `user_id` the
  `SessionController` switcher stores in the session so the demo can "become"
  different people.
  """
  import Plug.Conn
  alias Example.Directory

  def init(opts), do: opts

  def call(conn, _opts) do
    user =
      case get_session(conn, "user_id") do
        nil -> Directory.default()
        id -> Directory.get(id) || Directory.default()
      end

    assign(conn, :current_user, user)
  end
end
