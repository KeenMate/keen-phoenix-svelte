<script>
  import { applyDiff, onlineUsers } from "./presence.js";
  import { translator } from "./i18n.js";

  // meeting: the Graph event we joined; channel: the Phoenix channel factory from
  // the boundary; context: page-wide user + locale; onClose: leave + hide panel.
  let { meeting, channel, context, onClose } = $props();

  const me = $derived(context.user);
  const locale = $derived(context.locale || "en");
  const t = $derived(translator(locale));

  let messages = $state([]);
  let presences = $state({});
  let status = $state("connecting"); // connecting | ready | error
  let error = $state(null);
  let draft = $state("");
  let scroller = $state();

  // Held outside $state: send() only needs the latest value, not reactivity.
  let activeChannel = null;

  const participants = $derived(onlineUsers(presences));

  // (Re)join whenever the joined meeting changes. Cleanup leaves the old room, so
  // switching meetings tears down the previous subscription + presence tracking.
  $effect(() => {
    const id = meeting.id;
    if (!id || !channel) return;

    status = "connecting";
    error = null;
    messages = [];
    presences = {};

    const ch = channel(`meeting:${id}`);
    activeChannel = ch;

    ch.on("new_message", ({ data }) => (messages = [...messages, data]));
    ch.on("presence_state", (state) => (presences = state));
    ch.on("presence_diff", (diff) => (presences = applyDiff(presences, diff)));

    ch.joined
      .then(() => ch.push("history"))
      .then(({ data }) => {
        messages = data.messages;
        status = "ready";
      })
      .catch((e) => {
        status = "error";
        error = e?.message ?? "Couldn't join the meeting";
      });

    return () => {
      ch.leave();
      if (activeChannel === ch) activeChannel = null;
    };
  });

  // Auto-scroll to the newest message.
  $effect(() => {
    messages.length;
    if (scroller) scroller.scrollTop = scroller.scrollHeight;
  });

  function submit(event) {
    event.preventDefault();
    const text = draft.trim();
    if (!text || !activeChannel || status !== "ready") return;
    // Server-authoritative: the message renders when the broadcast returns.
    activeChannel.push("send_message", { text }).catch(() => (error = "Message failed to send"));
    draft = "";
  }

  function initials(name = "") {
    return name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((w) => w[0])
      .join("")
      .toUpperCase();
  }

  function time(iso) {
    return new Date(iso).toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit" });
  }
</script>

<section class="meeting">
  <header class="top">
    <div class="title">
      <span class="dot" aria-hidden="true"></span>
      <div class="titles">
        <strong>{meeting.subject}</strong>
        <span class="sub">{t("inCall", participants.length)}</span>
      </div>
    </div>
    <button class="close" type="button" onclick={onClose} aria-label={t("leave")}>✕</button>
  </header>

  {#if participants.length}
    <div class="people">
      {#each participants as p (p.id)}
        <span class="pa" style="--c:{p.color}" title={p.name}>{initials(p.name)}</span>
      {/each}
    </div>
  {/if}

  {#if status === "error"}
    <div class="banner">{error}</div>
  {/if}

  <div class="msgs" bind:this={scroller}>
    {#if status === "connecting"}
      <p class="muted">{t("connecting")}</p>
    {:else}
      {#each messages as m (m.id)}
        <div class="m" class:mine={m.user_id === me.id}>
          <span class="pa sm" style="--c:{m.user_color}">{initials(m.user_name)}</span>
          <div class="body">
            <div class="mh">
              <span class="who">{m.user_name}</span>
              <span class="t">{time(m.at)}</span>
            </div>
            <p>{m.text}</p>
          </div>
        </div>
      {:else}
        <p class="muted">{t("noMessages")}</p>
      {/each}
    {/if}
  </div>

  <form class="composer" onsubmit={submit}>
    <input placeholder={t("messagePlaceholder")} bind:value={draft} disabled={status !== "ready"} />
    <button type="submit" disabled={status !== "ready" || !draft.trim()}>{t("send")}</button>
  </form>
</section>

<style>
  .meeting {
    display: flex;
    flex-direction: column;
    width: 340px;
    max-width: 100%;
    height: 520px;
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 14px;
    overflow: hidden;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08);
  }
  .top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 8px;
    padding: 12px 14px;
    background: #1e1b4b;
    color: #e2e8f0;
  }
  .title {
    display: flex;
    gap: 8px;
    min-width: 0;
  }
  .dot {
    margin-top: 6px;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #34d399;
    box-shadow: 0 0 0 3px rgba(52, 211, 153, 0.25);
    flex: none;
  }
  .titles {
    min-width: 0;
  }
  .titles strong {
    display: block;
    font-size: 0.92rem;
    line-height: 1.2;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .sub {
    font-size: 0.72rem;
    color: #a5b4fc;
  }
  .close {
    border: 0;
    background: transparent;
    color: #c7d2fe;
    font-size: 0.9rem;
    cursor: pointer;
    padding: 2px 4px;
    line-height: 1;
  }
  .close:hover {
    color: #fff;
  }
  .people {
    display: flex;
    gap: 4px;
    padding: 8px 14px;
    border-bottom: 1px solid #eef2f7;
    flex-wrap: wrap;
  }
  .pa {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border-radius: 50%;
    background: var(--c, #6b7280);
    color: #fff;
    font-size: 0.62rem;
    font-weight: 600;
    flex: none;
  }
  .pa.sm {
    width: 30px;
    height: 30px;
    font-size: 0.66rem;
  }
  .banner {
    padding: 8px 14px;
    background: #fef2f2;
    color: #b91c1c;
    font-size: 0.82rem;
  }
  .msgs {
    flex: 1;
    overflow-y: auto;
    padding: 12px 14px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    background: #f8fafc;
    scroll-behavior: smooth;
  }
  .m {
    display: flex;
    gap: 8px;
    align-items: flex-start;
  }
  .body {
    min-width: 0;
  }
  .mh {
    display: flex;
    align-items: baseline;
    gap: 6px;
  }
  .who {
    font-weight: 600;
    font-size: 0.8rem;
    color: #0f172a;
  }
  .mine .who {
    color: #4f46e5;
  }
  .t {
    font-size: 0.68rem;
    color: #94a3b8;
  }
  .m p {
    margin: 1px 0 0;
    font-size: 0.88rem;
    line-height: 1.4;
    color: #1e293b;
    overflow-wrap: anywhere;
  }
  .muted {
    margin: auto;
    color: #94a3b8;
    font-size: 0.86rem;
  }
  .composer {
    display: flex;
    gap: 8px;
    padding: 10px 12px;
    border-top: 1px solid #e2e8f0;
    background: #fff;
  }
  .composer input {
    flex: 1;
    min-width: 0;
    padding: 8px 10px;
    border: 1px solid #cbd5e1;
    border-radius: 8px;
    font: inherit;
  }
  .composer input:focus {
    outline: 2px solid #a5b4fc;
    border-color: #818cf8;
  }
  .composer button {
    border: 0;
    border-radius: 8px;
    padding: 8px 14px;
    background: #4f46e5;
    color: #fff;
    font: inherit;
    font-weight: 600;
    cursor: pointer;
  }
  .composer button:disabled {
    background: #c7d2fe;
    cursor: not-allowed;
  }
</style>
