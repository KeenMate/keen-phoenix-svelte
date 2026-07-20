defmodule Example.Calendar do
  @moduledoc """
  Seeded calendar events, shaped like Microsoft Graph's `/me/calendarView`
  response (a `value` array of events).

  Because the shape matches Graph, the `calendar` island can be written exactly
  as it would be against the real API. In-memory only; times are generated
  relative to *today* so the agenda always looks current.
  """

  @doc "Today's events for a user, Graph-shaped and ordered by start time."
  @spec events_for(pos_integer()) :: [map()]
  def events_for(_user_id) do
    [
      event("Daily standup", {9, 0}, {9, 15}, "Team room · Online", true),
      event("Islands architecture review", {11, 0}, {12, 0}, "Zoom", true),
      event("1:1 with Grace", {13, 30}, {14, 0}, "Room 4B", false),
      event("Design sync: Workspace UI", {15, 0}, {15, 45}, "Figma · Online", true),
      event("Incident retro", {16, 30}, {17, 15}, "War room", false)
    ]
  end

  defp event(subject, {sh, sm}, {eh, em}, location, online?) do
    %{
      id: slug(subject),
      subject: subject,
      start: %{dateTime: at(sh, sm), timeZone: "UTC"},
      end: %{dateTime: at(eh, em), timeZone: "UTC"},
      location: %{displayName: location},
      isOnlineMeeting: online?,
      onlineMeeting: if(online?, do: %{joinUrl: "https://example.com/join/#{slug(subject)}"})
    }
  end

  defp at(hour, minute) do
    Date.utc_today()
    |> DateTime.new!(Time.new!(hour, minute, 0))
    |> DateTime.to_iso8601()
  end

  defp slug(subject) do
    subject
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
