<script>
  import VideoCard from "./VideoCard.svelte";
  import Player from "./Player.svelte";
  import { translator } from "./i18n.js";

  // context: page-wide user/tokens/locale; api: REST helper; live: LiveView
  // bridge or null on a plain page. The catalogue loads over `api`; "save"
  // prefers `live`. The island localizes itself from context.locale.
  let { context, api, live, bus } = $props();

  const t = $derived(translator(context.locale || "en"));

  let videos = $state([]);
  let categories = $state(["All"]);
  let activeCategory = $state("All");
  let selected = $state(null);
  let saved = $state(new Set());
  let status = $state("loading"); // loading | ready | error
  let error = $state(null);

  // Load the catalogue once, over the same-origin REST helper.
  $effect(() => {
    let cancelled = false;

    api
      .get("/videos")
      .then((data) => {
        if (cancelled) return;
        videos = data.videos;
        categories = ["All", ...data.categories];
        status = "ready";
      })
      .catch(() => {
        if (cancelled) return;
        status = "error";
        error = t("error");
      });

    return () => (cancelled = true);
  });

  const filtered = $derived(
    activeCategory === "All"
      ? videos
      : videos.filter((v) => v.category === activeCategory),
  );

  function applySaved({ id, saved: isSaved }) {
    const next = new Set(saved);
    if (isSaved) next.add(id);
    else next.delete(id);
    saved = next;

    // Announce a save to the rest of the page via the bus (the activity toast
    // island picks it up). We only toast on save, not un-save.
    const video = videos.find((v) => v.id === id);
    if (isSaved && video) {
      bus?.emit("activity", {
        title: t("savedActivity"),
        text: video.title,
        icon: "★",
        color: "#f59e0b",
      });
    }
  }

  // The canonical dual-transport action: on a LiveView page push over the
  // socket; on a plain page fall back to REST. Both reply with { id, saved }.
  function toggleSave(video) {
    const next = !saved.has(video.id);
    if (live) {
      live.pushEvent("save_video", { id: video.id, saved: next }, applySaved);
    } else {
      api.post(`/videos/${video.id}/save`, { saved: next }).then(applySaved);
    }
  }

  function onKeydown(event) {
    if (event.key === "Escape") selected = null;
  }
</script>

<svelte:window onkeydown={onKeydown} />

<div class="catalogue">
  <header class="head">
    <div>
      <h1>{t("title")}</h1>
      <p>{t("subtitle")} — {t("videosCount", videos.length)}</p>
    </div>
    {#if status === "ready"}
      <div class="filters" role="tablist" aria-label="Filter by category">
        {#each categories as cat (cat)}
          <button
            type="button"
            class="chip"
            class:active={cat === activeCategory}
            onclick={() => (activeCategory = cat)}
          >
            {cat === "All" ? t("all") : cat}
          </button>
        {/each}
      </div>
    {/if}
  </header>

  {#if status === "loading"}
    <p class="state">{t("loading")}</p>
  {:else if status === "error"}
    <p class="state error">{error}</p>
  {:else}
    <div class="grid">
      {#each filtered as video (video.id)}
        <VideoCard
          {video}
          {t}
          saved={saved.has(video.id)}
          onOpen={(v) => (selected = v)}
          onToggleSave={toggleSave}
        />
      {/each}
    </div>
  {/if}
</div>

{#if selected}
  <div class="overlay">
    <!-- Backdrop is a real button so click-to-close is keyboard-accessible;
         Escape also closes via the window handler above. -->
    <button class="backdrop" aria-label={t("close")} onclick={() => (selected = null)}></button>
    <div
      class="modal"
      role="dialog"
      aria-modal="true"
      aria-label={selected.title}
      tabindex="-1"
    >
      <header class="modal-head">
        <div>
          <h2>{selected.title}</h2>
          <p>{selected.presenter} · {selected.category}</p>
        </div>
        <button class="x" onclick={() => (selected = null)} aria-label={t("close")}>✕</button>
      </header>
      {#key selected.id}
        <Player video={selected} />
      {/key}
    </div>
  </div>
{/if}

<style>
  .catalogue {
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    color: #0f172a;
  }
  .head {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 20px;
  }
  h1 {
    margin: 0;
    font-size: 1.4rem;
  }
  .head p {
    margin: 2px 0 0;
    color: #64748b;
    font-size: 0.88rem;
  }
  .filters {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .chip {
    padding: 5px 12px;
    border: 1px solid #cbd5e1;
    border-radius: 999px;
    background: #fff;
    color: #475569;
    font: inherit;
    font-size: 0.82rem;
    cursor: pointer;
  }
  .chip:hover {
    border-color: #94a3b8;
  }
  .chip.active {
    background: #6366f1;
    border-color: #6366f1;
    color: #fff;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 18px;
  }
  .state {
    color: #64748b;
    padding: 40px 0;
    text-align: center;
  }
  .state.error {
    color: #b91c1c;
  }
  .overlay {
    position: fixed;
    inset: 0;
    z-index: 50;
    display: grid;
    place-items: center;
    padding: 24px;
  }
  .backdrop {
    position: absolute;
    inset: 0;
    border: 0;
    padding: 0;
    background: rgba(15, 23, 42, 0.72);
    cursor: pointer;
  }
  .modal {
    position: relative;
    z-index: 1;
    width: min(880px, 100%);
    background: #0f172a;
    border-radius: 14px;
    overflow: hidden;
    box-shadow: 0 24px 64px rgba(0, 0, 0, 0.5);
  }
  .modal-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    padding: 14px 18px;
    color: #fff;
  }
  .modal-head h2 {
    margin: 0;
    font-size: 1.05rem;
  }
  .modal-head p {
    margin: 2px 0 0;
    color: #94a3b8;
    font-size: 0.82rem;
  }
  .x {
    border: 0;
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
    width: 32px;
    height: 32px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.9rem;
    flex: none;
  }
  .x:hover {
    background: rgba(255, 255, 255, 0.2);
  }
</style>
