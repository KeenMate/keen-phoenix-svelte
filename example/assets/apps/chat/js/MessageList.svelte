<script>
  import Avatar from "./Avatar.svelte";

  // onSelectUser (optional): called with a user id when their avatar is clicked;
  // App delegates this to the host LiveView to open a profile. t/locale localize
  // the empty state and message timestamps.
  let {
    messages = [],
    currentUserId,
    onSelectUser = null,
    t = (k) => k,
    locale = "en",
  } = $props();

  let scroller = $state();

  // Auto-scroll to the newest message whenever the list grows.
  $effect(() => {
    messages.length;
    if (scroller) scroller.scrollTop = scroller.scrollHeight;
  });

  function time(iso) {
    return new Date(iso).toLocaleTimeString(locale, {
      hour: "2-digit",
      minute: "2-digit",
    });
  }
</script>

<div class="messages" bind:this={scroller}>
  {#each messages as m (m.id)}
    <article class="msg" class:mine={m.user_id === currentUserId}>
      <Avatar
        name={m.user_name}
        color={m.user_color}
        size={34}
        onSelect={onSelectUser && (() => onSelectUser(m.user_id))}
      />
      <div class="body">
        <header>
          <span class="who">{m.user_name}</span>
          <time datetime={m.at}>{time(m.at)}</time>
        </header>
        <p>{m.text}</p>
      </div>
    </article>
  {:else}
    <p class="empty">{t("noMessages")}</p>
  {/each}
</div>

<style>
  .messages {
    flex: 1;
    overflow-y: auto;
    padding: 16px 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    scroll-behavior: smooth;
  }
  .msg {
    display: flex;
    gap: 10px;
    align-items: flex-start;
  }
  .body {
    min-width: 0;
  }
  header {
    display: flex;
    align-items: baseline;
    gap: 8px;
    margin-bottom: 2px;
  }
  .who {
    font-weight: 600;
    font-size: 0.85rem;
    color: #0f172a;
  }
  time {
    font-size: 0.72rem;
    color: #94a3b8;
  }
  p {
    margin: 0;
    font-size: 0.92rem;
    line-height: 1.45;
    color: #1e293b;
    overflow-wrap: anywhere;
  }
  .mine .who {
    color: #4f46e5;
  }
  .empty {
    margin: auto;
    color: #94a3b8;
    font-size: 0.9rem;
  }
</style>
