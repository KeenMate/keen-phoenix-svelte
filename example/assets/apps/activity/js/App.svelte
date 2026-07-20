<script>
  // A page-wide toast feed driven entirely by the event bus. It knows nothing
  // about the other islands — it just listens for "activity" events. The video
  // catalogue and calendar islands (separate bundles, mounted independently)
  // emit those events; this is pure island-to-island messaging, no server.
  let { bus } = $props();

  let toasts = $state([]);
  let seq = 0;

  $effect(() => {
    if (!bus) return;
    // bus.on returns an unsubscribe fn — perfect as the $effect cleanup.
    return bus.on("activity", (detail) => {
      const id = ++seq;
      toasts = [...toasts, { id, ...detail }];
      // Auto-dismiss. setTimeout is fine here; no scheduling correctness needed.
      setTimeout(() => (toasts = toasts.filter((t) => t.id !== id)), 4000);
    });
  });

  function dismiss(id) {
    toasts = toasts.filter((t) => t.id !== id);
  }
</script>

<div class="toasts" role="status" aria-live="polite">
  {#each toasts as t (t.id)}
    <div class="toast" style="--c:{t.color || '#4f46e5'}">
      <span class="ic">{t.icon || "◆"}</span>
      <div class="tx">
        {#if t.title}<strong>{t.title}</strong>{/if}
        <span>{t.text}</span>
      </div>
      <button type="button" onclick={() => dismiss(t.id)} aria-label="Dismiss">✕</button>
    </div>
  {/each}
</div>

<style>
  .toasts {
    position: fixed;
    right: 20px;
    bottom: 20px;
    z-index: 50;
    display: flex;
    flex-direction: column;
    gap: 10px;
    pointer-events: none;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  .toast {
    pointer-events: auto;
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 240px;
    max-width: 340px;
    padding: 10px 12px;
    background: #fff;
    border: 1px solid #e2e8f0;
    border-left: 4px solid var(--c);
    border-radius: 10px;
    box-shadow: 0 8px 24px rgba(15, 23, 42, 0.14);
    animation: slide-in 0.18s ease-out;
  }
  .ic {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: 8px;
    background: color-mix(in srgb, var(--c) 15%, white);
    color: var(--c);
    font-size: 0.9rem;
    flex: none;
  }
  .tx {
    display: flex;
    flex-direction: column;
    min-width: 0;
    line-height: 1.25;
  }
  .tx strong {
    font-size: 0.82rem;
    color: #0f172a;
  }
  .tx span {
    font-size: 0.8rem;
    color: #475569;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .toast button {
    margin-left: auto;
    border: 0;
    background: transparent;
    color: #94a3b8;
    cursor: pointer;
    font-size: 0.8rem;
    padding: 2px 4px;
    line-height: 1;
  }
  .toast button:hover {
    color: #475569;
  }
  @keyframes slide-in {
    from {
      opacity: 0;
      transform: translateY(8px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
</style>
