defmodule ExampleWeb.CalendarLive do
  @moduledoc """
  Hosts the `calendar` island. The island depends on nothing LiveView-specific —
  it reads `context.tokens.graph` and calls the mock Graph service with its own
  `fetch` — so the very same mount also works on the plain `/calendar-plain` page.
  """
  use ExampleWeb, :live_view

  # The three moving parts, verbatim from the running app, so the prose below the
  # demo points at real code rather than a paraphrase.
  @context_snippet """
  # root.html.heex — minted once, per user, into the page-wide runtime context
  <KeenPhoenixSvelte.runtime context={%{
    user: %{id: @current_user.id, name: @current_user.name, email: @current_user.email},
    # A short-lived, per-user bearer for a *different* service. In a real app this
    # is an on-behalf-of token for graph.microsoft.com; here it's a Phoenix.Token.
    tokens: %{graph: Phoenix.Token.sign(ExampleWeb.Endpoint, "graph token", @current_user.id)}
  }} />
  """

  @island_snippet """
  // calendar/js/App.svelte — the island calls the third party with its OWN fetch,
  // using the token from context. No `api`, no `live` — nothing Phoenix-specific.
  let { context } = $props();

  $effect(() => {
    fetch("/mock-graph/v1.0/me/calendarView", {
      headers: { Authorization: `Bearer ${context.tokens.graph}` },
    })
      .then((r) => (r.status === 401 ? reauth() : r.json()))
      .then((data) => (events = data.value));
  });
  """

  @verify_snippet """
  # RequireGraphToken — what the "third-party" service does with the bearer.
  # No session, no CSRF: it's a different service reached with a token, which is
  # exactly why the island uses its own fetch instead of the `api` helper.
  with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
       {:ok, user_id} <- Phoenix.Token.verify(Endpoint, "graph token", token, max_age: 3600) do
    assign(conn, :graph_user_id, user_id)
  else
    _ -> conn |> put_status(:unauthorized) |> json(%{error: %{code: "InvalidAuthenticationToken"}}) |> halt()
  end
  """

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Calendar",
       context_snippet: @context_snippet,
       island_snippet: @island_snippet,
       verify_snippet: @verify_snippet
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:calendar}
      title="Calendar"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-4xl mx-auto space-y-10 pb-6">
        <%!-- The demo itself --%>
        <section>
          <.app name="calendar" id="calendar-app" props={%{}} />
        </section>

        <%!-- How it works, below the demo --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-key" class="size-7 text-primary" />
            <h1 class="text-2xl font-bold tracking-tight">Talking to a different service</h1>
          </div>
          <p class="mt-3 text-base-content/70">
            Most islands talk to <em>your</em>
            Phoenix backend over <code>live</code>
            or <code>api</code>. This one doesn't: the agenda comes from a
            <strong>separate service</strong>
            (a stand-in for Microsoft Graph). The pattern works whenever your app and
            that service <strong>trust the same identity provider</strong>
            (here, imagine Entra) — so a token minted for the signed-in user is
            accepted by both. Phoenix mints it; the island spends it directly.
          </p>
        </section>

        <%!-- The token's journey --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-arrow-path-rounded-square" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">The token's journey</h2>
          </div>
          <ol class="mt-3 space-y-3 text-sm text-base-content/70 list-decimal pl-5 marker:text-base-content/40">
            <li>
              <strong>Mint (server).</strong>
              On each page render the root layout signs a short-lived, per-user token
              and drops it into the page-wide runtime <code>context</code>
              under <code>tokens.graph</code> — <em>context, not payload</em>: a
              page-wide credential, minted once, the same for every island on the page.
            </li>
            <li>
              <strong>Embed.</strong>
              <code>&lt;.runtime&gt;</code>
              serializes the context into one JSON <code>&lt;script&gt;</code>
              in the page. It rides in the HTML the user already received — so keep it
              <strong>short-lived and narrowly scoped</strong>, never a long-lived secret.
            </li>
            <li>
              <strong>Read (client).</strong>
              The island receives that context at its boundary and reads
              <code>context.tokens.graph</code> — no round-trip, it's already there.
            </li>
            <li>
              <strong>Spend.</strong>
              The island calls the third party with its <strong>own <code>fetch</code></strong>
              and an <code>Authorization: Bearer</code>
              header. Phoenix is never in that request's path — no proxy, no
              <code>api</code> helper, no channel.
            </li>
            <li>
              <strong>Verify (the other service).</strong>
              The service checks the bearer and answers. No session or CSRF is
              involved — that's the whole reason this can't go through <code>api</code>.
            </li>
            <li>
              <strong>Expire → re-auth.</strong>
              The embedded token is a render-time snapshot, so it eventually expires.
              A <code>401</code>
              is the island's signal to get a fresh one (re-mint via a small
              session-protected endpoint, or a LiveView push) — flip the
              <strong>"simulate expired token"</strong>
              checkbox in the demo to see the <code>401</code> → re-auth path.
            </li>
          </ol>
        </section>

        <%!-- The code, all three sides --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-code-bracket" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">The three sides, in code</h2>
          </div>

          <p class="mt-3 text-sm font-medium">1 · Phoenix mints the token into context</p>
          <pre class="mt-1 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@context_snippet}</code></pre>

          <p class="mt-4 text-sm font-medium">2 · The island spends it with its own fetch</p>
          <pre class="mt-1 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@island_snippet}</code></pre>

          <p class="mt-4 text-sm font-medium">3 · The other service verifies the bearer</p>
          <pre class="mt-1 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@verify_snippet}</code></pre>
        </section>

        <%!-- Why this shape --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-light-bulb" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">Why deliver it this way</h2>
          </div>
          <div class="grid gap-4 md:grid-cols-2 mt-4">
            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <.icon name="hero-bolt" class="size-4 text-primary" />
                <span class="text-sm font-semibold">Direct, not proxied</span>
              </div>
              <p class="text-sm text-base-content/70 mt-2">
                The island hits the service straight from the browser — your backend
                isn't a relay in the hot path, and the same mount works on the plain
                <.link navigate={~p"/calendar-plain"} class="link link-primary">/calendar-plain</.link>
                page with no <code>live</code> at all.
              </p>
            </div>
            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <.icon name="hero-shield-check" class="size-4 text-primary" />
                <span class="text-sm font-semibold">Small blast radius</span>
              </div>
              <p class="text-sm text-base-content/70 mt-2">
                Because it lives in the DOM, the token is <strong>short-lived</strong>,
                <strong>per-user</strong>, and scoped to just this service. A downstream
                <em>secret</em>
                would never go here — that stays server-side, behind <code>api</code>.
              </p>
            </div>
          </div>
          <p class="mt-4 text-sm text-base-content/60">
            Full write-up: the <.link
              navigate={~p"/docs"}
              class="link link-primary"
            >Runtime context</.link> guide covers relaying user identity and shared tokens, including token freshness.
          </p>
        </section>
      </div>

      <:aside>
        <Layouts.info_panel title="Calendar — a different service">
          <p>
            This island talks to a <strong>different service</strong>, not our backend.
            It imagines our app and a calendar provider (Microsoft Graph) both trust the
            same identity provider (Entra), so we hold a shared token.
          </p>
          <p>
            The agenda uses neither <code>api</code>
            nor <code>live</code>
            — just <code>context.tokens.graph</code>
            and its own <code>fetch</code>, so the exact same mount works on the plain
            <.link navigate={~p"/calendar-plain"} class="link link-primary">/calendar-plain</.link>
            page.
          </p>
          <p>
            <strong>Click "Join online"</strong>
            on a meeting to open its chat — that part rides a Phoenix <code>channel</code>, so one island uses two transports at once.
          </p>
          <:wire label="context">
            Reads the signed Graph token the root layout put in the runtime context.
          </:wire>
          <:wire label="fetch">
            <code>GET /mock-graph/v1.0/me/calendarView</code>
            with <code>Authorization: Bearer …</code>
            (a stand-in for <code>graph.microsoft.com</code>).
          </:wire>
          <:wire label="channel">
            Joining a meeting opens <code>meeting:&lt;id&gt;</code>
            (history + <code>Presence</code>) — our backend, not Graph.
          </:wire>
          <:wire label="401">
            Drop/expire the token and the island shows a re-auth path, just like a real API.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
