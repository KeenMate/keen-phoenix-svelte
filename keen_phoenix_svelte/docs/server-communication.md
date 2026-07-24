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
| `live` | LiveView bridge, or **`null`** on plain pages (and initially on an eager mount) |
| `liveStatus` | `"ready"` \| `"pending"` \| `"none"` — whether `live` is here, coming, or never (see below) |
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

### `liveStatus` and eager mounting

Normally the island mounts from the `KeenSvelte` hook, which only runs after the
LiveView socket connects — so `live` is present from the first frame
(`liveStatus: "ready"`). With [`<.app eager>`](KeenPhoenixSvelte.html#app/1-eager-mounting)
the island instead mounts *before* connect, to paint sooner. It then starts with
`live: null` and `liveStatus: "pending"`, and the bridge arrives later.

`liveStatus` tells the app which situation it's in at mount:

| value | meaning | what an app does |
| --- | --- | --- |
| `"ready"` | `live` is available now | use `live` immediately |
| `"pending"` | eager mount; `live` is coming on connect | render now (optionally a loader), wait for it |
| `"none"` | plain page; there is no `live` at all | use `api` / `channel` / another server |

When an eager island's bridge becomes available, the library fires a
**`keen:live-ready`** `CustomEvent` on the island's element (`el`), with
`detail.live`. Listen for it to swap a loader for live UI:

```js
export default (target, { live, liveStatus, el }) => {
  let bridge = live;                       // null while "pending"
  if (liveStatus === "pending") {
    el.addEventListener("keen:live-ready", (e) => {
      bridge = e.detail.live;              // now safe to pushEvent/handleEvent
      // hide the loader, wire up server-pushed events, etc.
    });
  }
  // ...
};
```

As an alternative to the event, if the handle you return exposes a `setLive(live)`
method the hook calls it with the same bridge when it upgrades the island.

Server-pushed **prop** changes (`updated()` → `setProps`) work regardless of
`liveStatus`, so an eager island still re-renders on assign changes even before —
and after — the bridge arrives. Only the imperative `live.*` calls need it.

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
