<script>
  // Props/context/capabilities come from keen_phoenix_svelte.
  let { id, liked: likedProp = false, context, live, api } = $props();

  // Local state, kept in sync with server-pushed prop changes (LiveView mode).
  let liked = $state(likedProp);
  $effect(() => {
    liked = likedProp;
  });

  async function toggle() {
    if (live) {
      // LiveView page: push over the socket; server updates the assign and the
      // authoritative state flows back in as a prop (updated() -> setProps).
      live.pushEvent("toggle_like", { id });
    } else {
      // Plain page: no socket — go over REST (CSRF + session handled by `api`).
      const res = await api.post("/api/like", { id, liked: !liked });
      liked = res.liked;
    }
  }
</script>

<button type="button" class:liked onclick={toggle} aria-pressed={liked}>
  <span class="heart">{liked ? "♥" : "♡"}</span>
  <span>{liked ? "Liked" : "Like"}</span>
</button>

<style>
  button {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.4rem 0.9rem;
    border: 1px solid #d1d5db;
    border-radius: 9999px;
    background: white;
    cursor: pointer;
    font: inherit;
    transition: all 0.15s ease;
  }
  button:hover {
    border-color: #fda4af;
  }
  button.liked {
    background: #fff1f2;
    border-color: #fb7185;
    color: #e11d48;
  }
  .heart {
    font-size: 1.1rem;
    line-height: 1;
  }
</style>
