# Runtime context — user identity & shared tokens

The **runtime context** is the page-wide bundle of facts every island on the page
receives as `context`. It is how the server relays *who the user is* and *what
credentials an island may use* — without each island having to ask.

This guide walks a concrete, common case: relaying the **current user** (UPN,
display name, email) and a **shared JWT** that islands then use to talk to a
**third-party server** directly. For the full boundary (`live` / `api` / `channel`
/ `bus`) see [Server communication](server-communication.md).

## What context is (and is not)

`<KeenPhoenixSvelte.runtime context={…}>` emits **one** `<script
type="application/json" id="keen-context">` in the page. The client reads it once
and injects the same object into **every** mounted island as `context`.

- **Context, not payload.** It carries page-wide *facts* — user identity, a CSRF
  token, an `api_base`, a socket token, locale, and any access tokens islands need.
  Per-island data belongs in each `<.app props={…} />`, not here.
- **Emitted once, at render time.** It is a snapshot taken when the page HTML is
  built. That matters for anything that expires — see
  [Token freshness](#token-freshness-when-the-jwt-expires).
- **Visible to the user.** It ships in the HTML the browser receives, so treat it
  as readable by the signed-in user (it is *their* session). Never put anything
  there the user shouldn't see — no server secrets, no other users' data, no
  long-lived or broadly-scoped credentials.

## Relaying the current user

Render the context once, in your root layout, so it covers every page (LiveView
**and** plain controller pages):

```heex
<!-- root.html.heex -->
<KeenPhoenixSvelte.runtime context={%{
  user: %{
    upn: @current_user.upn,
    display_name: @current_user.display_name,
    email: @current_user.email
  },
  csrf_token: get_csrf_token(),
  api_base: "/api",
  # A shared token for a *different* server — see below.
  tokens: %{api: MyApp.Tokens.for_downstream(@current_user)}
}} />
```

On the client, any island reads it straight off `context`:

```js
export default (target, { context }) => {
  const { upn, display_name, email } = context.user;
  // …render a greeting, an avatar, gate a feature by identity, etc.
};
```

In Svelte it arrives through `$props()` (via the standard `mount.svelte.js`), so
it stays reactive if the server later pushes a new one:

```svelte
<script>
  let { context } = $props();
  let user = $derived(context.user);
</script>

<span>Signed in as {user.display_name} ({user.email})</span>
```

> **Shape it once, server-side.** Map your user struct to exactly the fields
> islands need (`upn`, `display_name`, `email`) in one place. Don't dump the whole
> struct — every extra field is bytes on every page and one more thing exposed in
> the DOM.

## A shared JWT for a third-party server

The island model shines when an island talks to **another server directly** —
your Phoenix app isn't a proxy in the hot path. To make that possible, the server
mints a token and drops it into `context.tokens`; the island calls the downstream
service with its own `fetch`.

This works cleanly when your Phoenix app and the third-party server **trust the
same issuer** (e.g. both validate tokens from your IdP / Entra ID / Auth0). The
server performs the exchange (on-behalf-of, token-vending endpoint, or a signed
`Phoenix.Token`) and hands the island a **short-lived, narrowly-scoped** token:

```elixir
tokens: %{
  # Short-lived, minimal scope, minted for *this* user for *this* downstream.
  reports: MyApp.Tokens.mint(@current_user, aud: "reports-api", scope: "reports:read", ttl: :timer.minutes(15))
}
```

The island uses it directly — no round-trip through Phoenix:

```svelte
<!-- reports/js/App.svelte -->
<script>
  let { org_id, context } = $props();
  let rows = $state([]);

  $effect(() => {
    fetch(`https://reports.example.com/v1/orgs/${org_id}/summary`, {
      headers: { Authorization: `Bearer ${context.tokens.reports}` },
    })
      .then((r) => r.json())
      .then((data) => (rows = data.rows));
  });
</script>
```

The `example/` app does exactly this with a simulated Microsoft Graph calendar —
see [Worked example: multiple apps](multiple-apps.md) (`graph-calendar`).

### Rules for tokens in context

- **Short TTL.** Minutes, not hours. The token lives in the DOM for the life of
  the page.
- **Narrow audience & scope.** Mint it for the specific downstream (`aud`) and the
  minimum scope. A token that can only read reports is a small blast radius if
  copied.
- **Per-user, minted server-side.** Never a static, shared, or admin credential.
  Never a downstream **API secret** — that's a server-to-server credential and must
  stay on the server (put such calls behind `api` instead).
- **One token per downstream.** `tokens: %{reports: …, billing: …}` — so each has
  its own audience and scope and you can revoke or narrow one without the others.

## Token freshness — when the JWT expires

Because context is a **render-time snapshot**, its JWT will eventually expire on a
page the user keeps open. The token's job is the *first* calls; islands that
outlive its TTL need a way to get a fresh one. Pick per page type:

**On a plain page (or any page) — a same-origin mint endpoint via `api`.** The
`api` helper is authenticated by session cookie + CSRF, so the island can ask your
Phoenix app for a fresh downstream token whenever the current one is near expiry:

```js
// island keeps its own copy; refreshes before it expires
let token = context.tokens.reports;
async function authHeader() {
  if (expiringSoon(token)) token = (await api.post("/tokens/reports")).token;
  return { Authorization: `Bearer ${token}` };
}
```

```elixir
# a small, session-protected endpoint that re-mints exactly what context seeded
post "/api/tokens/reports", TokenController, :reports
```

**On a LiveView page — push a fresh token.** The host LiveView can re-mint on a
timer and hand it down; the island receives it as a normal prop update
(`updated()` → `setProps`) or via `live.handleEvent`:

```elixir
# in the LiveView
def handle_info(:refresh_downstream_token, socket) do
  Process.send_after(self(), :refresh_downstream_token, :timer.minutes(10))
  {:noreply, push_event(socket, "token:reports", %{token: MyApp.Tokens.mint(socket.assigns.current_user, aud: "reports-api")})}
end
```

```js
// island
live?.handleEvent("token:reports", ({ token }) => setToken(token));
```

Either way the principle holds: **context seeds the island; the island refreshes
through the boundary.** Don't try to make one embedded token last the whole
session by giving it a long TTL — that just trades a small refresh for a large
exposure.

## Where each fact belongs

| Fact | Put it in | Why |
| --- | --- | --- |
| User UPN / display name / email | `context.user` | Page-wide identity, same for every island |
| CSRF token | `context.csrf_token` | Consumed by the `api` helper |
| `api_base`, `socket_path`, `socket_token` | `context` | Page-wide transport wiring |
| Short-lived downstream JWT | `context.tokens.<name>` | Page-wide credential an island uses directly |
| A downstream **API secret** | *nowhere client-side* | Keep it server-side; call through `api` |
| Per-island config (an id, a flag, a mode) | `<.app props={…} />` | It's payload/config for one island, not the page |

## See also

- [Server communication](server-communication.md) — the full boundary (`live` /
  `api` / `channel` / `bus`) and how an island picks its transport.
- [Worked example: multiple apps](multiple-apps.md) — `graph-calendar` calling a
  third-party service with a shared token from `context.tokens`.
- [Philosophy & comparison](philosophy.md) — why islands talk to servers directly
  rather than through server-rendered slots.
