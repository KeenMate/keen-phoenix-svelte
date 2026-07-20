defmodule ExampleWeb.ChatChannel do
  @moduledoc """
  Realtime chat for a single room (`chat:<room>`).

  ## Envelope

  Replies and broadcasts use the `{data, requestId}` shape the
  keen_phoenix_svelte `channel` client expects: the client auto-attaches a `cid`
  to every push and resolves `push()` with the raw reply, so we echo `cid` back
  as `requestId` and put the payload under `data`.

  ## Presence

  Online users come from `ExampleWeb.Presence`. On join we `track/3` the user and
  push the current `presence_state`; Phoenix broadcasts `presence_diff` on every
  join/leave automatically. The `chat` island folds both into its "who's online"
  list.

  ## Delivery

  Sends are server-authoritative: `send_message` stores the message and
  `broadcast!`s `new_message` to everyone in the room (including the sender), so
  the client renders from the broadcast and never has to de-dupe an optimistic
  echo.
  """
  use ExampleWeb, :channel

  alias Example.{Chat, Directory}
  alias ExampleWeb.Presence

  @impl true
  def join("chat:" <> room, _payload, socket) do
    if Chat.room?(room) do
      user = Directory.get(socket.assigns.user_id) || Directory.default()
      send(self(), :after_join)
      {:ok, assign(socket, room: room, user: user)}
    else
      {:error, %{reason: "unknown room"}}
    end
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
    messages = Chat.list_messages(socket.assigns.room)
    {:reply, {:ok, envelope(%{messages: messages}, payload)}, socket}
  end

  def handle_in("send_message", %{"text" => text} = payload, socket) do
    case Chat.add_message(socket.assigns.room, socket.assigns.user, text) do
      {:ok, message} ->
        broadcast!(socket, "new_message", %{data: message})
        {:reply, {:ok, envelope(message, payload)}, socket}

      {:error, reason} ->
        {:reply, {:error, envelope(%{error: reason}, payload)}, socket}
    end
  end

  defp envelope(data, payload), do: %{data: data, requestId: payload["cid"]}
end
