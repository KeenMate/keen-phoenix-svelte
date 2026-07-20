defmodule ExampleWeb.VideoController do
  @moduledoc """
  Same-origin JSON API for the `video-catalogue` island (session + CSRF, no
  bearer token — it's *our* backend). The island fetches the catalogue with the
  `api` helper.

  `save/2` is the plain-page fallback for the "save" action: on a LiveView page
  the island uses `live.pushEvent("save_video", …)`; on a plain page (no `live`)
  it POSTs here instead — the canonical `if (live) … else api.post(…)` pattern.
  """
  use ExampleWeb, :controller

  alias Example.VideoCatalogue

  def index(conn, _params) do
    json(conn, %{videos: VideoCatalogue.list(), categories: VideoCatalogue.categories()})
  end

  def show(conn, %{"id" => id}) do
    case VideoCatalogue.get(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
      video -> json(conn, %{video: video})
    end
  end

  # Stateless demo: echo the requested saved-state (a real app persists it per
  # user). Mirrors the LiveView `save_video` reply shape so the island treats
  # both transports identically.
  def save(conn, %{"id" => id} = params) do
    json(conn, %{id: id, saved: !!params["saved"]})
  end
end
