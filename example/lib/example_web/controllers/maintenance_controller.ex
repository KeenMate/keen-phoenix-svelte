defmodule ExampleWeb.MaintenanceController do
  @moduledoc """
  On-demand demo reset. `POST /api/maintenance/reset` re-seeds the chat store and
  notifies open clients — the same thing the 15-minute scheduler does, callable by
  hand (e.g. `curl -XPOST`). Unauthenticated on purpose: it only touches throwaway
  demo data. Not a pattern to copy into a real app.
  """
  use ExampleWeb, :controller

  alias ExampleWeb.Maintenance

  def reset(conn, _params) do
    :ok = Maintenance.reset_chat()
    json(conn, %{ok: true, reset: "chat"})
  end
end
