defmodule ExampleWeb.InlineEditController do
  @moduledoc """
  Durable half of the `/inline-edit` demo. The editor island updates the page
  instantly over `live` (a LiveView can't write the Plug session itself), then
  POSTs the same HTML here over the `api` helper so it's persisted into the
  **session** — which is why an edit survives a reload. Per-user, expires with
  the session, nothing to reset.

  Security: the HTML is **untrusted**. The TipTap editor is not a security
  control — a client can POST any HTML straight to `save/2` — so it's sanitized
  server-side before it's stored and later rendered with `raw`/`@html`, and its
  size is capped so it can't overflow the ~4 KB cookie session. In a real app
  this endpoint would also **authorize** the caller (the admin toggle in the UI
  is cosmetic; the endpoint is the real boundary).
  """
  use ExampleWeb, :controller

  alias Example.Content

  @session_key "inline_edit"

  # The cookie session is ~4 KB total; keep one block and the whole persisted set
  # comfortably under that so a large paste returns a clean 413, not a 500 at
  # cookie-encoding time.
  @max_html_bytes 2_000
  @max_total_bytes 2_800

  def save(conn, %{"id" => id, "html" => html}) when is_binary(id) and is_binary(html) do
    cond do
      is_nil(Content.get(Content.default_blocks(), id)) ->
        conn |> put_status(:not_found) |> json(%{error: "unknown block"})

      byte_size(html) > @max_html_bytes ->
        conn |> put_status(:request_entity_too_large) |> json(%{error: "block too large"})

      true ->
        clean = HtmlSanitizeEx.basic_html(html)

        overrides =
          conn
          |> get_session(@session_key)
          |> Kernel.||(%{})
          |> Map.put(id, clean)

        if total_bytes(overrides) > @max_total_bytes do
          conn
          |> put_status(:request_entity_too_large)
          |> json(%{error: "too much saved content"})
        else
          conn
          |> put_session(@session_key, overrides)
          # Return the sanitized HTML so the caller can reconcile if it differs.
          |> json(%{ok: true, html: clean})
        end
    end
  end

  @doc """
  Clears all persisted edits from the session and returns to the page, which
  re-mounts with the default blocks. A plain form POST (not `api`) because it
  navigates — the same shape as the user/language switchers.
  """
  def reset(conn, _params) do
    conn
    |> delete_session(@session_key)
    |> redirect(to: ~p"/inline-edit")
  end

  defp total_bytes(overrides) do
    overrides |> Map.values() |> Enum.map(&byte_size/1) |> Enum.sum()
  end
end
