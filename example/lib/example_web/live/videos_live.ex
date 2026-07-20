defmodule ExampleWeb.VideosLive do
  @moduledoc """
  Hosts the `video-catalogue` island.

  The island loads the catalogue over REST (`api`), but "save" is pushed over the
  LiveView socket: `save_video` toggles a per-session saved set and replies with
  the new state. On a plain page (see `/calendar-plain`) the island would fall
  back to `api.post`, which is why `VideoController.save/2` mirrors this reply.
  """
  use ExampleWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, saved: MapSet.new(), page_title: "Videos")}
  end

  def handle_event("save_video", %{"id" => id, "saved" => saved?}, socket) do
    saved =
      if saved?,
        do: MapSet.put(socket.assigns.saved, id),
        else: MapSet.delete(socket.assigns.saved, id)

    {:reply, %{id: id, saved: MapSet.member?(saved, id)}, assign(socket, :saved, saved)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:videos}
      title="Videos"
      locale={@locale}
      flash={@flash}
    >
      <.svelte name="video-catalogue" id="videos-app" props={%{}} />

      <:aside>
        <Layouts.info_panel title="Videos — REST + the live bridge">
          <p>
            The catalogue loads over our own JSON API using the <code>api</code>
            helper (session cookie + CSRF, no bearer token). Clips play in an in-page
            <strong>Plyr</strong>
            player bundled into the island.
          </p>
          <p>
            "Save" shows the canonical dual-transport pattern: <code>if (live) live.pushEvent(…) else api.post(…)</code>.
          </p>
          <:wire label="api">
            <code>api.get("/videos")</code>
            — the helper prepends <code>api_base</code>
            (<code>/api</code>), hitting <code>VideoController</code>.
          </:wire>
          <:wire label="live">
            Saving a video pushes <code>save_video</code>
            over the LiveView socket; <code>VideosLive</code>
            replies with the new state.
          </:wire>
          <:wire label="fallback">
            On the plain <code>/calendar-plain</code>-style page (no <code>live</code>) it would
            <code>api.post</code>
            instead.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
