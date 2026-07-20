defmodule ExampleWeb.PageController do
  use ExampleWeb, :controller

  @doc """
  A plain, non-LiveView page that hosts the calendar island.

  Demonstrates the `mountStatic()` path: the island mounts with `live: null` and
  still works, because it reaches the mock Graph service over its own `fetch`
  using the token from `context`.
  """
  def calendar_plain(conn, _params) do
    render(conn, :calendar_plain)
  end
end
