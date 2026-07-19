defmodule ExampleWeb.ApiController do
  @moduledoc """
  Same-origin JSON API for Svelte apps running on plain (non-LiveView) pages.

  Behind the `:browser_api` pipeline: `fetch_session` + `protect_from_forgery`,
  so requests authenticate with the session cookie + CSRF token — exactly what
  the client `api` helper attaches (`credentials: same-origin` + `x-csrf-token`).
  No bearer token required.
  """
  use ExampleWeb, :controller

  # Demo endpoint: echoes the desired state back (no persistence). A real app
  # would read the session/user and persist here.
  def like(conn, %{"id" => id, "liked" => liked}) do
    json(conn, %{id: id, liked: !!liked})
  end
end
