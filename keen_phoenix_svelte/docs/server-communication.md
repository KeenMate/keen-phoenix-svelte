# Server communication

An app is a self-contained island: initialized with context, then it talks to the
server on its own terms. `keen_phoenix_svelte` gives it four things at its
boundary and stays out of the way.

## Runtime context

Deliver page-wide context once (root layout), on both LiveView and plain pages:

```heex
<KeenPhoenixSvelte.runtime context={%{
  user: %{id: @user.id, name: @user.name, roles: @roles},
  csrf_token: get_csrf_token(),
  api_base: "/api",
  socket_path: "/socket",
  socket_token: Phoenix.Token.sign(MyAppWeb.Endpoint, "user socket", @user.id)
}} />
```

It is read once by the client and injected into every app as `context`. Keep it
to *context, not payload* — user identity, a CSRF token for `api`, an `api_base`,
a `socket_token` for channels, locale, and any tokens the app needs. Per-app data
belongs in each `<.app props={...} />`.

## The app boundary

The mount fn receives one options object:

| Key | What it is |
| --- | --- |
| `props` | per-component config from `<.app props={...} />` |
| `context` | the page-wide runtime context above |
| `live` | LiveView bridge, or **`null`** on plain (non-LiveView) pages |
| `api` | REST helper to your Phoenix backend (CSRF + session) |
| `channel` | `channel(topic, params)` factory over a Phoenix socket (lazy connect) |
| `el` | the root element |

The same component runs on a LiveView page or a plain page — it just picks a
transport:

```js
if (live) {
  live.pushEvent("toggle_like", { id });                  // websocket, LiveView
} else {
  const { liked } = await api.post("/api/like", { id });  // REST, CSRF+session
}
```

## `live` — the LiveView bridge

Available only when the app is hosted inside a LiveView. Talks over the existing
socket — no separate API needed.

```js
live.pushEvent(event, payload, onReply)
live.pushEventTo(target?, event, payload, onReply)   // defaults to own root
live.handleEvent(event, callback)                    // auto-removed on destroy
live.removeHandleEvent(ref)
live.upload(name, files)
live.uploadTo(target?, name, files)
live.el
```

Server side — the reply is authoritative and the updated assign flows back into
the component as a prop change (`updated()` → `setProps`):

```elixir
def handle_event("toggle_like", %{"id" => id}, socket) do
  liked = toggle(id)
  {:reply, %{liked: liked}, assign(socket, ...)}
end
```

## `api` — REST to your backend

A `fetch` wrapper that attaches `x-csrf-token` and sends the session cookie.
Works on any page (LiveView or plain).

```js
await api.get("/api/org/42")
await api.post("/api/node", { parent_id: 1 })
await api.put("/api/node/5", { name: "…" })
await api.delete("/api/node/5")
```

Put the endpoints behind a pipeline that does `fetch_session` +
`protect_from_forgery`:

```elixir
pipeline :browser_api do
  plug :accepts, ["json"]
  plug :fetch_session
  plug :protect_from_forgery
end
```

For a **different service** (not your Phoenix backend), deliver a server-minted
token via `context.tokens.*` and let the app call that service itself with its
own `fetch`.

## `channel` — Phoenix channels

A promise-based wrapper over a Phoenix channel. The socket connects lazily on the
first `channel(...)` call, using `context.socket_path` / `context.socket_token`.

```js
const ch = channel("org:42")
await ch.joined

const reply = await ch.push("load", { id: 42 })  // resolves with the raw reply
const { data } = reply

ch.on("update", (msg) => { /* server push */ })
ch.leave()
```

`push()` is **envelope-agnostic** — it resolves with whatever the server replies,
so you read `reply.data` / `reply.error` yourself. It also auto-attaches a `cid`
correlation id to each push (`{ cid: false }` to omit, `{ cid }` to set your own).
That `cid` is harmless if the server ignores it, and is consumed as `requestId` by
channels written with the Simplificator3000 channel macro.

The **app owns the socket and channels** server-side (a `UserSocket` +
`Phoenix.Channel`s, authenticated with the `socket_token`). `keen_phoenix_svelte`
provides only the client and does not depend on any particular channel framework.
See `example/lib/example_web/channels/` for a minimal socket + channel.
