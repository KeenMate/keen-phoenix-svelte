defmodule ExampleWeb.SessionController do
  @moduledoc """
  Lets the demo "become" different directory users so the multi-user features
  (chat, presence) are believable from a single machine.

  This is **not** authentication — it's a session-backed identity switch for the
  demo. A real app would replace it with a proper login. Because the identity
  lives in the session, switching users re-renders the root layout, which
  re-issues the `context` (user, `socket_token`, and the simulated Graph token)
  for the newly-selected person.
  """
  use ExampleWeb, :controller
  alias Example.{Directory, I18n}

  def switch(conn, %{"user_id" => user_id} = params) do
    conn =
      case Directory.get(user_id) do
        nil -> conn
        user -> put_session(conn, "user_id", user.id)
      end

    redirect(conn, to: return_to(conn, params))
  end

  @doc """
  Stores the chosen UI language in the session and reloads. Reloading re-renders
  the root layout, which re-issues the `context` with the new `locale` so every
  island picks it up.
  """
  def locale(conn, %{"locale" => locale} = params) do
    conn
    |> put_session("locale", I18n.locale(locale))
    |> redirect(to: return_to(conn, params))
  end

  # Prefer an explicit, same-origin return path; fall back to the referer path,
  # then the workspace root. Never redirect to an absolute/off-site URL.
  defp return_to(conn, params) do
    with nil <- safe_path(params["return_to"]),
         nil <- referer_path(conn) do
      "/"
    end
  end

  defp referer_path(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] -> safe_path(URI.parse(referer).path)
      _ -> nil
    end
  end

  defp safe_path("/" <> _ = path), do: path
  defp safe_path(_), do: nil
end
