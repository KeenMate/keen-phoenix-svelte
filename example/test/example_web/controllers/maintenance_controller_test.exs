defmodule ExampleWeb.MaintenanceControllerTest do
  # Mutates the global Chat GenServer, so run serially.
  use ExampleWeb.ConnCase, async: false

  alias Example.{Chat, Directory}

  test "POST /api/maintenance/reset re-seeds chat and returns ok", %{conn: conn} do
    # Dirty the store so we can prove the reset wiped it.
    {:ok, _} = Chat.add_message("general", Directory.default(), "temporary message")
    assert length(Chat.list_messages("general")) > 2

    conn = post(conn, "/api/maintenance/reset")
    assert json_response(conn, 200) == %{"ok" => true, "reset" => "chat"}

    # Back to the seeded baseline (general is seeded with two messages).
    assert length(Chat.list_messages("general")) == 2
  end
end
