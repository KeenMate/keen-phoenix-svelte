defmodule ExampleWeb.DemoChannelTest do
  use ExampleWeb.ChannelCase, async: true

  setup do
    {:ok, _reply, socket} =
      ExampleWeb.UserSocket
      |> socket("user_socket:1", %{user_id: 1})
      |> subscribe_and_join(ExampleWeb.DemoChannel, "demo:lobby")

    %{socket: socket}
  end

  test "ping replies with a data envelope echoing the cid", %{socket: socket} do
    ref = push(socket, "ping", %{"cid" => "abc-123"})
    assert_reply ref, :ok, %{data: %{pong: true, user_id: 1}, requestId: "abc-123"}
  end

  test "toggle_like replies with the item state", %{socket: socket} do
    ref = push(socket, "toggle_like", %{"id" => 7, "cid" => "c1"})
    assert_reply ref, :ok, %{data: %{id: 7, liked: true}, requestId: "c1"}
  end

  describe "socket auth" do
    test "connects with a valid signed token" do
      token = Phoenix.Token.sign(ExampleWeb.Endpoint, "user socket", 42)
      assert {:ok, socket} = connect(ExampleWeb.UserSocket, %{"token" => token})
      assert socket.assigns.user_id == 42
    end

    test "rejects a bad token" do
      assert :error = connect(ExampleWeb.UserSocket, %{"token" => "nope"})
    end

    test "rejects a missing token" do
      assert :error = connect(ExampleWeb.UserSocket, %{})
    end
  end
end
