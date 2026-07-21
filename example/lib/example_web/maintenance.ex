defmodule ExampleWeb.Maintenance do
  @moduledoc """
  Demo housekeeping: reset the in-memory chat state and notify open clients.

  Keeps the split the rest of the app uses — `Example.Chat` owns the *data* (it
  re-seeds itself), and the realtime fan-out lives here in the web layer. Both the
  periodic `ExampleWeb.MaintenanceScheduler` and the `/api/maintenance/reset` hook
  call `reset_chat/0`, so the "reset and notify" behaviour is defined once.
  """

  alias Example.Chat
  alias ExampleWeb.Endpoint

  @doc """
  Re-seeds the chat store and broadcasts `room_reset` (with the fresh history) to
  every room, so open chat islands replace their messages live. Meeting rooms are
  wiped too, but aren't broadcast to — they're ad-hoc and transient.
  """
  @spec reset_chat() :: :ok
  def reset_chat do
    :ok = Chat.reset()

    for room <- Chat.list_rooms() do
      Endpoint.broadcast("chat:#{room.id}", "room_reset", %{
        data: %{messages: Chat.list_messages(room.id)}
      })
    end

    :ok
  end
end
