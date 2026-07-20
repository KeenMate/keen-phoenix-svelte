<script>
  import { translator } from "./i18n.js";

  // onJoin (optional): called with the event when "Join online" is clicked — the
  // parent opens a per-meeting chat over a channel. active: this meeting is open.
  let { event, onJoin = null, active = false, locale = "en" } = $props();

  const t = $derived(translator(locale));

  function time(iso) {
    return new Date(iso).toLocaleTimeString(locale, {
      hour: "2-digit",
      minute: "2-digit",
    });
  }
</script>

<article class="event" class:online={event.isOnlineMeeting}>
  <div class="time">
    <span class="start">{time(event.start.dateTime)}</span>
    <span class="end">{time(event.end.dateTime)}</span>
  </div>
  <div class="rail" aria-hidden="true"></div>
  <div class="detail">
    <h3>{event.subject}</h3>
    <p class="where">{event.location.displayName}</p>
    {#if event.isOnlineMeeting && onJoin}
      <button class="join" class:active type="button" onclick={() => onJoin(event)}>
        {#if active}
          <span class="dot" aria-hidden="true"></span> {t("inMeeting")}
        {:else}
          {t("join")}
        {/if}
      </button>
    {/if}
  </div>
</article>

<style>
  .event {
    display: grid;
    grid-template-columns: 64px 12px 1fr;
    align-items: stretch;
    gap: 4px;
  }
  .time {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    padding-top: 2px;
    font-variant-numeric: tabular-nums;
  }
  .start {
    font-size: 0.9rem;
    font-weight: 600;
    color: #0f172a;
  }
  .end {
    font-size: 0.75rem;
    color: #94a3b8;
  }
  .rail {
    justify-self: center;
    width: 3px;
    border-radius: 3px;
    background: #cbd5e1;
  }
  .online .rail {
    background: #6366f1;
  }
  .detail {
    padding: 0 0 16px 8px;
  }
  h3 {
    margin: 0 0 2px;
    font-size: 0.95rem;
    color: #0f172a;
  }
  .where {
    margin: 0;
    font-size: 0.82rem;
    color: #64748b;
  }
  .join {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-top: 8px;
    padding: 4px 10px;
    border: 1px solid #c7d2fe;
    border-radius: 999px;
    background: #eef2ff;
    font: inherit;
    font-size: 0.78rem;
    font-weight: 600;
    color: #4f46e5;
    cursor: pointer;
  }
  .join:hover {
    background: #e0e7ff;
  }
  .join.active {
    background: #4f46e5;
    border-color: #4f46e5;
    color: #fff;
  }
  .join .dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: #34d399;
    box-shadow: 0 0 0 3px rgba(52, 211, 153, 0.3);
  }
</style>
