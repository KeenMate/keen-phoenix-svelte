<script>
  import EventCard from "./EventCard.svelte";
  import MeetingChat from "./MeetingChat.svelte";
  import { translator } from "./i18n.js";

  // The agenda comes from a *different* service (a mock Microsoft Graph): the
  // server minted a short-lived token into context.tokens.graph, which we send as
  // a bearer token over our own `fetch`. Joining a meeting, though, opens a chat
  // over a Phoenix `channel` — one island, two very different transports.
  let { context, channel, bus } = $props();

  // Locale arrives via context; the island localizes itself (strings + dates).
  const locale = $derived(context.locale || "en");
  const t = $derived(translator(locale));

  // The meeting whose chat is open in the right pane (null = none).
  let activeMeeting = $state(null);

  function joinMeeting(event) {
    activeMeeting = event;
    // Tell the rest of the page (the activity toast island listens for this).
    // We localize the title here, at the source — the toast island stays generic.
    bus?.emit("activity", {
      title: t("joinedActivity"),
      text: event.subject,
      icon: "📞",
      color: "#4f46e5",
    });
  }

  // In a real app: "https://graph.microsoft.com/v1.0". Here, a same-origin mock.
  const GRAPH_BASE = "/mock-graph/v1.0";

  let events = $state([]);
  let status = $state("loading"); // loading | ready | empty | unauthorized | error
  let error = $state(null);
  // Lets the demo show the 401 path on demand (sends a deliberately bad token).
  let simulateExpired = $state(false);

  const today = $derived(
    new Date().toLocaleDateString(locale, {
      weekday: "long",
      month: "long",
      day: "numeric",
    }),
  );

  $effect(() => {
    // Re-run whenever the token or the "simulate expired" toggle changes.
    load(context.tokens?.graph, simulateExpired);
  });

  async function load(token, expired) {
    status = "loading";
    error = null;

    const bearer = expired ? "expired.invalid.token" : token;
    if (!bearer) {
      status = "unauthorized";
      return;
    }

    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date();
    end.setHours(23, 59, 59, 999);

    const url =
      `${GRAPH_BASE}/me/calendarView` +
      `?startDateTime=${start.toISOString()}&endDateTime=${end.toISOString()}`;

    try {
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${bearer}` },
      });

      if (res.status === 401) {
        status = "unauthorized";
        return;
      }
      if (!res.ok) throw new Error(`Graph returned ${res.status}`);

      const data = await res.json();
      events = data.value ?? [];
      status = events.length ? "ready" : "empty";
    } catch (_e) {
      status = "error";
      error = t("error");
    }
  }
</script>

<div class="cal-wrap">
  <div class="calendar">
    <header class="head">
    <div>
      <h1>{t("title")}</h1>
      <p>{today}</p>
    </div>
    <label class="sim">
      <input type="checkbox" bind:checked={simulateExpired} />
      {t("simulateExpired")}
    </label>
  </header>

  {#if status === "loading"}
    <p class="state">{t("loading")}</p>
  {:else if status === "unauthorized"}
    <div class="reauth">
      <p><strong>{t("sessionExpired")}</strong></p>
      <p>{t("tokenMissing")}</p>
      <button
        type="button"
        onclick={() => {
          simulateExpired = false;
        }}
      >
        {t("reauth")}
      </button>
    </div>
  {:else if status === "error"}
    <p class="state error">{error}</p>
  {:else if status === "empty"}
    <p class="state">{t("empty")}</p>
  {:else}
    <div class="agenda">
      {#each events as event (event.id)}
        <EventCard
          {event}
          {locale}
          onJoin={channel ? joinMeeting : null}
          active={activeMeeting?.id === event.id}
        />
      {/each}
    </div>
  {/if}
  </div>

  {#if activeMeeting}
    <MeetingChat
      meeting={activeMeeting}
      {channel}
      {context}
      onClose={() => (activeMeeting = null)}
    />
  {/if}
</div>

<style>
  .cal-wrap {
    display: flex;
    align-items: flex-start;
    gap: 20px;
    flex-wrap: wrap;
  }
  .calendar {
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 14px;
    padding: 20px 22px;
    max-width: 560px;
  }
  .head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 18px;
  }
  h1 {
    margin: 0;
    font-size: 1.3rem;
    color: #0f172a;
  }
  .head p {
    margin: 2px 0 0;
    color: #64748b;
    font-size: 0.88rem;
  }
  .sim {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 0.78rem;
    color: #64748b;
    cursor: pointer;
    user-select: none;
  }
  .agenda {
    display: flex;
    flex-direction: column;
  }
  .state {
    color: #64748b;
    padding: 24px 0;
    text-align: center;
  }
  .state.error {
    color: #b91c1c;
  }
  .reauth {
    text-align: center;
    padding: 24px;
    background: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 12px;
  }
  .reauth p {
    margin: 0 0 6px;
    color: #9a3412;
    font-size: 0.9rem;
  }
  .reauth strong {
    color: #7c2d12;
  }
  .reauth button {
    margin-top: 8px;
    padding: 8px 18px;
    border: 0;
    border-radius: 8px;
    background: #ea580c;
    color: #fff;
    font: inherit;
    font-weight: 600;
    cursor: pointer;
  }
</style>
