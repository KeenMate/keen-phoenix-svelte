defmodule ExampleWeb.DemoChannel do
  @moduledoc """
  Demo channel reachable from Svelte apps via the keen `channel` helper.

  The reply envelope here (`%{data: ..., requestId: cid}`) mirrors the
  Simplificator3000 channel-macro style so the client sees a consistent shape —
  but this is plain app code; keen_phoenix_svelte does not depend on that macro.
  In a real app you'd `use Simplificator3000Phoenix.Channel` and write `msg`
  handlers instead.
  """
  use Phoenix.Channel

  @impl true
  def join("demo:" <> _sub, _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    reply = %{data: %{pong: true, user_id: socket.assigns.user_id}, requestId: payload["cid"]}
    {:reply, {:ok, reply}, socket}
  end

  def handle_in("toggle_like", %{"id" => id} = payload, socket) do
    reply = %{data: %{id: id, liked: true}, requestId: payload["cid"]}
    {:reply, {:ok, reply}, socket}
  end
end
