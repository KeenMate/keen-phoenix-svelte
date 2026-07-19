defmodule ExampleWeb.DemoLive do
  @moduledoc """
  Demo of mounting compiled Svelte components inside LiveView with
  `keen_phoenix_svelte`.

  The like state lives on the server (socket assigns). Clicking a Svelte button
  pushes `toggle_like` over the LiveView socket; the reply updates the assign,
  which re-renders `data-props` and flows the authoritative state back into the
  Svelte component via the hook's `updated()` -> `$set`.
  """
  use ExampleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    items = for i <- 1..6, into: %{}, do: {i, false}
    {:ok, assign(socket, items: items)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-3xl p-8">
        <h1 class="text-2xl font-bold mb-2">Svelte components in LiveView</h1>
        <p class="text-sm text-gray-500 mb-6">
          Each button is a compiled Svelte app auto-mounted by keen_phoenix_svelte.
          State is owned by the server.
        </p>

        <div class="grid grid-cols-3 gap-4">
          <div :for={{id, liked} <- Enum.sort(@items)} class="rounded-lg border p-4 text-center">
            <div class="text-sm text-gray-500 mb-3">Item #{id}</div>
            <.svelte name="like" id={"like-#{id}"} props={%{id: id, liked: liked}} />
          </div>
        </div>

        <p class="text-sm text-gray-500 mt-6">
          Liked: {@items |> Map.values() |> Enum.count(& &1)} / {map_size(@items)}
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("toggle_like", %{"id" => id}, socket) do
    id = normalize_id(id)
    liked = not Map.fetch!(socket.assigns.items, id)
    {:reply, %{liked: liked}, assign(socket, items: Map.put(socket.assigns.items, id, liked))}
  end

  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)
end
