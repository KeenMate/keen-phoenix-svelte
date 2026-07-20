defmodule ExampleWeb.Presence do
  @moduledoc """
  Tracks who is online in each chat room.

  Backed by `Phoenix.Presence` (a CRDT synced over PubSub), so it needs no
  database and works across nodes. The `chat` Svelte island renders the online
  avatars from the presence state the `ChatChannel` pushes down.
  """
  use Phoenix.Presence,
    otp_app: :example,
    pubsub_server: Example.PubSub
end
