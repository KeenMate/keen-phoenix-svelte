defmodule ExampleWeb.MeetingChannelTest do
  # async: false — the channel mutates the shared in-memory Chat store.
  use ExampleWeb.ChannelCase, async: false

  alias ExampleWeb.{MeetingChannel, UserSocket}

  setup do
    {:ok, _reply, socket} =
      UserSocket
      |> socket("user_socket:1", %{user_id: 1})
      |> subscribe_and_join(MeetingChannel, "meeting:daily-standup")

    %{socket: socket}
  end

  test "any meeting id joins (ad-hoc rooms), history starts empty", %{socket: socket} do
    ref = push(socket, "history", %{"cid" => "h1"})
    assert_reply ref, :ok, %{data: %{messages: messages}, requestId: "h1"}
    assert is_list(messages)
  end

  test "send_message replies and broadcasts new_message to the meeting", %{socket: socket} do
    ref = push(socket, "send_message", %{"text" => "starting now", "cid" => "s1"})
    assert_reply ref, :ok, %{data: %{text: "starting now", user_id: 1}, requestId: "s1"}
    assert_broadcast "new_message", %{data: %{text: "starting now", user_id: 1}}
  end

  test "a sent message is then visible in history", %{socket: socket} do
    push(socket, "send_message", %{"text" => "persisted", "cid" => "s2"})
    assert_broadcast "new_message", %{data: %{text: "persisted"}}

    ref = push(socket, "history", %{"cid" => "h2"})
    assert_reply ref, :ok, %{data: %{messages: messages}}
    assert Enum.any?(messages, &(&1.text == "persisted"))
  end

  test "blank messages are rejected", %{socket: socket} do
    ref = push(socket, "send_message", %{"text" => "  ", "cid" => "s3"})
    assert_reply ref, :error, %{data: %{error: :empty}}
  end
end
