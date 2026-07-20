defmodule ExampleWeb.MeetingChannel do
  @moduledoc """
  Realtime chat for a single meeting (`meeting:<id>`), opened from the calendar
  island when you "Join online".

  It is deliberately the same shape as `ExampleWeb.ChatChannel` — the same
  `{data, requestId}` envelope, the same `Presence`-backed participant list, and
  the same server-authoritative `new_message` broadcast — but the room is
  *ad-hoc*: any meeting id coming from the calendar is allowed, and its history
  is ephemeral (see `Example.Chat.add_meeting_message/3`).

  This shows one island reaching for a *channel* even though the calendar's own
  data comes from a foreign service (mock Graph) over `fetch` — a single island
  can use several boundary pieces.
  """
  use ExampleWeb, :channel

  alias Example.{Chat, Directory}
  alias ExampleWeb.Presence

  @impl true
  def join("meeting:" <> meeting_id, _payload, socket) do
    user = Directory.get(socket.assigns.user_id) || Directory.default()
    send(self(), :after_join)
    {:ok, assign(socket, meeting_id: meeting_id, user: user)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    %{user: user} = socket.assigns

    {:ok, _ref} =
      Presence.track(socket, to_string(user.id), %{
        name: user.name,
        color: user.color,
        online_at: System.system_time(:second)
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("history", payload, socket) do
    messages = Chat.list_meeting_messages(socket.assigns.meeting_id)
    {:reply, {:ok, envelope(%{messages: messages}, payload)}, socket}
  end

  def handle_in("send_message", %{"text" => text} = payload, socket) do
    case Chat.add_meeting_message(socket.assigns.meeting_id, socket.assigns.user, text) do
      {:ok, message} ->
        broadcast!(socket, "new_message", %{data: message})
        {:reply, {:ok, envelope(message, payload)}, socket}

      {:error, reason} ->
        {:reply, {:error, envelope(%{error: reason}, payload)}, socket}
    end
  end

  defp envelope(data, payload), do: %{data: data, requestId: payload["cid"]}
end
