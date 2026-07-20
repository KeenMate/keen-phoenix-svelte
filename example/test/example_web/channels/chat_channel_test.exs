defmodule ExampleWeb.ChatChannelTest do
  # async: false — the channel mutates the shared in-memory Chat store.
  use ExampleWeb.ChannelCase, async: false

  alias ExampleWeb.{ChatChannel, UserSocket}

  setup do
    {:ok, _reply, socket} =
      UserSocket
      |> socket("user_socket:1", %{user_id: 1})
      |> subscribe_and_join(ChatChannel, "chat:general")

    %{socket: socket}
  end

  test "history returns seeded messages under a data envelope", %{socket: socket} do
    ref = push(socket, "history", %{"cid" => "h1"})
    assert_reply ref, :ok, %{data: %{messages: messages}, requestId: "h1"}
    assert is_list(messages)
    assert Enum.all?(messages, &(&1.room == "general"))
  end

  test "send_message replies and broadcasts new_message to the room", %{socket: socket} do
    ref = push(socket, "send_message", %{"text" => "hello team", "cid" => "s1"})
    assert_reply ref, :ok, %{data: %{text: "hello team", user_id: 1}, requestId: "s1"}
    assert_broadcast "new_message", %{data: %{text: "hello team", user_id: 1}}
  end

  test "blank messages are rejected", %{socket: socket} do
    ref = push(socket, "send_message", %{"text" => "   ", "cid" => "s2"})
    assert_reply ref, :error, %{data: %{error: :empty}}
  end

  test "joining an unknown room fails" do
    assert {:error, %{reason: "unknown room"}} =
             UserSocket
             |> socket("user_socket:1", %{user_id: 1})
             |> subscribe_and_join(ChatChannel, "chat:does-not-exist")
  end

  describe "socket auth" do
    test "connects with a valid signed token" do
      token = Phoenix.Token.sign(ExampleWeb.Endpoint, "user socket", 42)
      assert {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert socket.assigns.user_id == 42
    end

    test "rejects a bad token" do
      assert :error = connect(UserSocket, %{"token" => "nope"})
    end

    test "rejects a missing token" do
      assert :error = connect(UserSocket, %{})
    end
  end
end
