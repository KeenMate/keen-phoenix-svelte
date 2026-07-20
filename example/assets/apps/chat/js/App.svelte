<script>
  import RoomList from "./RoomList.svelte";
  import MessageList from "./MessageList.svelte";
  import Composer from "./Composer.svelte";
  import Avatar from "./Avatar.svelte";
  import { untrack } from "svelte";
  import { applyDiff, onlineUsers } from "./presence.js";
  import { translator } from "./i18n.js";

  // props: rooms + initialRoom come from the server (<.svelte props=…>);
  // context carries the signed-in user; channel is the Phoenix channel factory;
  // live is the LiveView bridge (null on a plain page).
  let { rooms = [], initialRoom, context, channel, live } = $props();

  const me = $derived(context.user);
  const locale = $derived(context.locale || "en");
  const t = $derived(translator(locale));

  // Clicking an avatar asks the *host LiveView* to open that person's profile in
  // the page's right column. The island owns realtime over its channel, but this
  // one action is delegated to LiveView to show the two coexisting: Svelte fires
  // an event, server-rendered chrome next to the island reacts.
  const openProfile = live ? (userId) => live.pushEvent("show_profile", { user_id: userId }) : null;

  // Initial room only — the user drives it after mount, so we read the prop once
  // via untrack() rather than tracking it (which Svelte would warn about).
  let activeRoom = $state(untrack(() => initialRoom || rooms[0]?.id));
  let messages = $state([]);
  let presences = $state({});
  let status = $state("connecting"); // connecting | ready | error
  let error = $state(null);

  // The channel for the room we're currently in. Held outside $state because
  // send() only needs to read the latest value, not react to it.
  let activeChannel = null;

  const online = $derived(onlineUsers(presences));
  const room = $derived(rooms.find((r) => r.id === activeRoom));

  // (Re)join whenever the active room changes. The $effect cleanup leaves the
  // previous channel, so switching rooms tears down the old subscription and
  // its presence tracking automatically.
  $effect(() => {
    const roomId = activeRoom;
    if (!roomId || !channel) return;

    status = "connecting";
    error = null;
    messages = [];
    presences = {};

    const ch = channel(`chat:${roomId}`);
    activeChannel = ch;

    ch.on("new_message", ({ data }) => {
      messages = [...messages, data];
    });
    ch.on("presence_state", (state) => {
      presences = state;
    });
    ch.on("presence_diff", (diff) => {
      presences = applyDiff(presences, diff);
    });

    ch.joined
      .then(() => ch.push("history"))
      .then(({ data }) => {
        messages = data.messages;
        status = "ready";
      })
      .catch(() => {
        status = "error";
        error = t("couldntJoin");
      });

    return () => {
      ch.leave();
      if (activeChannel === ch) activeChannel = null;
    };
  });

  function send(text) {
    if (!activeChannel || status !== "ready") return;
    // Server-authoritative: the message renders when the "new_message" broadcast
    // arrives (for everyone, including us), so we don't append optimistically.
    activeChannel.push("send_message", { text }).catch(() => {
      error = t("sendFailed");
    });
  }
</script>

<div class="chat">
  <aside class="sidebar">
    <div class="brand">
      <span class="logo">◆</span> KeenSpace
    </div>
    <RoomList {rooms} {activeRoom} onSelect={(id) => (activeRoom = id)} />
  </aside>

  <section class="pane">
    <header class="pane-top">
      <div class="room-title">
        <strong>#{room?.name}</strong>
        <span class="topic">{room?.topic}</span>
      </div>
      <div class="online" aria-label={t("onlineAria", online.length)}>
        <div class="stack">
          {#each online.slice(0, 5) as u (u.id)}
            <Avatar
              name={u.name}
              color={u.color}
              size={28}
              onSelect={openProfile && (() => openProfile(u.id))}
            />
          {/each}
        </div>
        {#if online.length}
          <span class="count">{t("online", online.length)}</span>
        {/if}
      </div>
    </header>

    {#if status === "error"}
      <div class="banner">{error}</div>
    {/if}

    <MessageList {messages} {locale} {t} currentUserId={me.id} onSelectUser={openProfile} />

    <Composer disabled={status !== "ready"} onSend={send} {t} />
  </section>
</div>

<style>
  .chat {
    display: grid;
    grid-template-columns: 220px 1fr;
    height: 100%;
    min-height: 520px;
    border-radius: 14px;
    overflow: hidden;
    background: #fff;
    box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12), 0 8px 24px rgba(15, 23, 42, 0.08);
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  .sidebar {
    background: #1e1b4b;
    color: #e2e8f0;
    display: flex;
    flex-direction: column;
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 16px;
    font-weight: 700;
    letter-spacing: 0.01em;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }
  .logo {
    color: #818cf8;
  }
  .pane {
    display: flex;
    flex-direction: column;
    min-width: 0;
    background: #f8fafc;
  }
  .pane-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 12px 20px;
    background: #fff;
    border-bottom: 1px solid #e2e8f0;
  }
  .room-title {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .room-title strong {
    font-size: 1rem;
    color: #0f172a;
  }
  .topic {
    font-size: 0.78rem;
    color: #94a3b8;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .online {
    display: flex;
    align-items: center;
    gap: 10px;
    flex: none;
  }
  .stack {
    display: flex;
  }
  .stack :global(.avatar:not(:first-child)) {
    margin-left: -8px;
  }
  .count {
    font-size: 0.78rem;
    color: #64748b;
    white-space: nowrap;
  }
  .banner {
    padding: 8px 20px;
    background: #fef2f2;
    color: #b91c1c;
    font-size: 0.85rem;
    border-bottom: 1px solid #fecaca;
  }
</style>
