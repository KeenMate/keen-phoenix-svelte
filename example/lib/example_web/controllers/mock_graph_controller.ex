defmodule ExampleWeb.MockGraphController do
  @moduledoc """
  A stand-in for Microsoft Graph.

  In a real app the `calendar` island would call
  `https://graph.microsoft.com/v1.0/me/calendarView`; here it calls this
  same-origin mock, which is guarded by `RequireGraphToken` (bearer only — no
  session/CSRF) and returns Graph-shaped data for the token's user.
  """
  use ExampleWeb, :controller

  alias Example.Calendar

  def calendar_view(conn, _params) do
    events = Calendar.events_for(conn.assigns.graph_user_id)
    json(conn, %{value: events})
  end
end
