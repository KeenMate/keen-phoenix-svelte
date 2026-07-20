defmodule ExampleWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", ExampleWeb.ChatChannel
  channel "meeting:*", ExampleWeb.MeetingChannel

  # Authenticated with the signed token that keen_phoenix_svelte delivers in the
  # runtime context (context.socket_token) and sends as a connect param.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(ExampleWeb.Endpoint, "user socket", token, max_age: 86_400) do
      {:ok, user_id} -> {:ok, assign(socket, :user_id, user_id)}
      {:error, _reason} -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(%{assigns: %{user_id: user_id}}), do: "user_socket:#{user_id}"
end
