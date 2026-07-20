defmodule Example.Chat do
  @moduledoc """
  In-memory chat store: the rooms and their message history.

  A real app would persist messages (Ecto/Postgres) and page through history;
  this keeps everything in one `GenServer` so the demo needs no database. State
  resets on restart — fine for a demo.

  This module owns the *data* only. Realtime fan-out (join, broadcast on send,
  presence) lives in `ExampleWeb.ChatChannel`.
  """
  use GenServer

  alias Example.Directory

  @type room :: %{id: String.t(), name: String.t(), topic: String.t()}
  @type message :: %{
          id: pos_integer(),
          room: String.t(),
          user_id: pos_integer(),
          user_name: String.t(),
          user_color: String.t(),
          text: String.t(),
          at: String.t()
        }

  @rooms [
    %{id: "general", name: "General", topic: "Company-wide announcements and watercooler chat"},
    %{
      id: "engineering",
      name: "Engineering",
      topic: "Architecture, reviews, and incident response"
    },
    %{id: "random", name: "Random", topic: "Off-topic, memes, and weekend plans"}
  ]

  @max_history 200

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "The fixed set of rooms."
  @spec list_rooms() :: [room()]
  def list_rooms, do: @rooms

  @doc "Whether `id` is a known room."
  @spec room?(String.t()) :: boolean()
  def room?(id), do: Enum.any?(@rooms, &(&1.id == id))

  @doc "Messages for a room, oldest first."
  @spec list_messages(String.t()) :: [message()]
  def list_messages(room), do: GenServer.call(__MODULE__, {:list, room})

  @doc """
  Appends a message to a room. Trims the text and rejects empty or unknown-room
  writes so the channel doesn't have to.
  """
  @spec add_message(String.t(), Directory.user(), String.t()) ::
          {:ok, message()} | {:error, :invalid_room | :empty}
  def add_message(room, user, text) do
    text = text |> to_string() |> String.trim()

    cond do
      not room?(room) -> {:error, :invalid_room}
      text == "" -> {:error, :empty}
      true -> GenServer.call(__MODULE__, {:add, room, user, text})
    end
  end

  @doc """
  Messages for an ad-hoc *meeting* room, oldest first. Meeting rooms are opened
  from the calendar island's "Join online" and share this same store under a
  namespaced key, so they never collide with the fixed rooms above.
  """
  @spec list_meeting_messages(String.t()) :: [message()]
  def list_meeting_messages(meeting_id),
    do: GenServer.call(__MODULE__, {:list, meeting_key(meeting_id)})

  @doc """
  Appends a message to a meeting room. Any meeting id is accepted (they come from
  the calendar), so unlike `add_message/3` there's no room check — only the
  empty-text guard.
  """
  @spec add_meeting_message(String.t(), Directory.user(), String.t()) ::
          {:ok, message()} | {:error, :empty}
  def add_meeting_message(meeting_id, user, text) do
    case text |> to_string() |> String.trim() do
      "" -> {:error, :empty}
      trimmed -> GenServer.call(__MODULE__, {:add, meeting_key(meeting_id), user, trimmed})
    end
  end

  defp meeting_key(meeting_id), do: "meeting:" <> to_string(meeting_id)

  # ---------------------------------------------------------------------------
  # Server
  # ---------------------------------------------------------------------------

  @impl true
  def init(:ok), do: {:ok, seed()}

  @impl true
  def handle_call({:list, room}, _from, state) do
    # Stored newest-first for cheap prepend; hand back oldest-first for rendering.
    {:reply, state.messages |> Map.get(room, []) |> Enum.reverse(), state}
  end

  def handle_call({:add, room, user, text}, _from, state) do
    message = build_message(state.next_id, room, user, text)

    messages =
      Map.update(state.messages, room, [message], fn list ->
        Enum.take([message | list], @max_history)
      end)

    {:reply, {:ok, message}, %{state | messages: messages, next_id: state.next_id + 1}}
  end

  # ---------------------------------------------------------------------------
  # Seeding & helpers
  # ---------------------------------------------------------------------------

  defp seed do
    seeds = [
      {"general", 3, "Morning everyone! Ship day 🎉"},
      {"general", 1, "Reminder: demo of the new workspace at 2pm in the main room."},
      {"engineering", 2, "The islands architecture PR is up for review when you get a sec."},
      {"engineering", 4, "Nice — I'll take a look right after standup."},
      {"random", 5, "Coffee machine on floor 3 is finally fixed ☕"}
    ]

    {messages, next_id} =
      Enum.reduce(seeds, {%{}, 1}, fn {room, user_id, text}, {acc, id} ->
        message = build_message(id, room, Directory.get(user_id), text)
        {Map.update(acc, room, [message], &[message | &1]), id + 1}
      end)

    %{messages: messages, next_id: next_id}
  end

  defp build_message(id, room, user, text) do
    %{
      id: id,
      room: room,
      user_id: user.id,
      user_name: user.name,
      user_color: user.color,
      text: text,
      at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
