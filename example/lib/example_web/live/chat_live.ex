defmodule ExampleWeb.ChatLive do
  @moduledoc """
  Hosts the `chat` island. The LiveView is intentionally thin — it just passes
  the room list as config. All realtime (join, messages, presence, room
  switching) happens inside the island over its Phoenix channel; LiveView never
  touches the Svelte-owned subtree (`phx-update="ignore"`).
  """
  use ExampleWeb, :live_view

  alias Example.{Chat, Directory}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, rooms: Chat.list_rooms(), profile: nil, page_title: "Chat")}
  end

  # The island pushes this when an avatar is clicked. LiveView looks the user up
  # in the directory and renders their profile in the right column — server-side,
  # right next to the (untouched) Svelte subtree.
  def handle_event("show_profile", %{"user_id" => user_id}, socket) do
    {:noreply, assign(socket, :profile, Directory.get(user_id))}
  end

  def handle_event("clear_profile", _params, socket) do
    {:noreply, assign(socket, :profile, nil)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:chat}
      title="Chat"
      locale={@locale}
      flash={@flash}
    >
      <div class="h-[calc(100vh-8rem)]">
        <.svelte name="chat" id="chat-app" props={%{rooms: @rooms, initialRoom: "general"}} />
      </div>

      <:aside>
        <Layouts.profile_card :if={@profile} user={@profile} />

        <Layouts.info_panel :if={!@profile} title="Chat — over a channel">
          <p>
            A self-contained <strong>Svelte 5</strong>
            island mounted inside this LiveView. LiveView never touches its DOM
            (<code>phx-update="ignore"</code>) — all realtime flows over a Phoenix channel the island opens itself.
          </p>
          <p>
            Open a second browser (or switch users, top-right) to see messages and presence update live.
            <strong>Click any avatar</strong>
            to load that person's profile here.
          </p>
          <:wire label="props">
            The room list is passed as static config from <code>ChatLive</code>.
          </:wire>
          <:wire label="context">
            The island reads the page socket + current user from the once-per-page runtime context.
          </:wire>
          <:wire label="channel">
            Joins <code>chat:&lt;room&gt;</code>; history, <code>new_message</code>
            broadcasts and <code>Presence</code>
            avatars all ride this topic.
          </:wire>
          <:wire label="live">
            Clicking an avatar pushes <code>show_profile</code>
            to LiveView, which renders the profile card in this column.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
