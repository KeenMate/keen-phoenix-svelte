defmodule ExampleWeb.CalendarLive do
  @moduledoc """
  Hosts the `calendar` island. The island depends on nothing LiveView-specific —
  it reads `context.tokens.graph` and calls the mock Graph service with its own
  `fetch` — so the very same mount also works on the plain `/calendar-plain` page.
  """
  use ExampleWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Calendar")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:calendar}
      title="Calendar"
      locale={@locale}
      flash={@flash}
    >
      <.app name="calendar" id="calendar-app" props={%{}} />

      <:aside>
        <Layouts.info_panel title="Calendar — a different service">
          <p>
            This island talks to a <strong>different service</strong>, not our backend.
            It imagines our app and a calendar provider (Microsoft Graph) both trust the
            same identity provider (Entra), so we hold a shared token.
          </p>
          <p>
            The agenda uses neither <code>api</code>
            nor <code>live</code>
            — just <code>context.tokens.graph</code>
            and its own <code>fetch</code>, so the exact same mount works on the plain
            <.link navigate={~p"/calendar-plain"} class="link link-primary">/calendar-plain</.link>
            page.
          </p>
          <p>
            <strong>Click "Join online"</strong>
            on a meeting to open its chat — that part rides a Phoenix <code>channel</code>, so one island uses two transports at once.
          </p>
          <:wire label="context">
            Reads the signed Graph token the root layout put in the runtime context.
          </:wire>
          <:wire label="fetch">
            <code>GET /mock-graph/v1.0/me/calendarView</code>
            with <code>Authorization: Bearer …</code>
            (a stand-in for <code>graph.microsoft.com</code>).
          </:wire>
          <:wire label="channel">
            Joining a meeting opens <code>meeting:&lt;id&gt;</code>
            (history + <code>Presence</code>) — our backend, not Graph.
          </:wire>
          <:wire label="401">
            Drop/expire the token and the island shows a re-auth path, just like a real API.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
