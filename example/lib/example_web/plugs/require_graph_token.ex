defmodule ExampleWeb.Plugs.RequireGraphToken do
  @moduledoc """
  Simulates the token validation a real external service (Microsoft Graph) does.

  Expects `Authorization: Bearer <token>`, where `<token>` is the value the root
  layout placed in `context.tokens.graph` (a `Phoenix.Token` we signed to stand
  in for an Entra access token). On success it assigns `:graph_user_id`;
  otherwise it halts with a Graph-shaped `401`.

  Deliberately **no** session or CSRF here — this is a different service reached
  with a bearer token, which is exactly why the `calendar` island uses its own
  `fetch` instead of the `api` helper.
  """
  import Plug.Conn

  @salt "graph token"
  @max_age 3600

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user_id} <-
           Phoenix.Token.verify(ExampleWeb.Endpoint, @salt, token, max_age: @max_age) do
      assign(conn, :graph_user_id, user_id)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{
          error: %{
            code: "InvalidAuthenticationToken",
            message: "Access token is empty or invalid."
          }
        })
        |> halt()
    end
  end

  @doc "The salt the root layout signs the simulated Graph token with."
  def salt, do: @salt
end
