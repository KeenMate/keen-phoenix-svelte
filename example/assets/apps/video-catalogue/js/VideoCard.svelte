<script>
  // t: the translator from the parent (App), so this card localizes too.
  let { video, saved = false, onOpen, onToggleSave, t = (k) => k } = $props();
</script>

<article class="card">
  <button class="thumb" onclick={() => onOpen(video)} aria-label={t("play", video.title)}>
    <img src={video.poster} alt="" loading="lazy" />
    <span class="play" aria-hidden="true">▶</span>
    <span class="dur">{video.duration}</span>
  </button>

  <div class="meta">
    <span class="cat">{video.category}</span>
    <h3>{video.title}</h3>
    <p class="presenter">{video.presenter}</p>
    <p class="desc">{video.description}</p>
    <button
      type="button"
      class="save"
      class:on={saved}
      onclick={() => onToggleSave(video)}
      aria-pressed={saved}
    >
      {saved ? t("saved") : t("save")}
    </button>
  </div>
</article>

<style>
  .card {
    display: flex;
    flex-direction: column;
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    overflow: hidden;
    transition: box-shadow 0.15s, transform 0.15s;
  }
  .card:hover {
    box-shadow: 0 8px 24px rgba(15, 23, 42, 0.12);
    transform: translateY(-2px);
  }
  .thumb {
    position: relative;
    aspect-ratio: 16 / 9;
    border: 0;
    padding: 0;
    cursor: pointer;
    background: #0f172a;
    overflow: hidden;
  }
  .thumb img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
    opacity: 0.92;
    transition: opacity 0.15s, transform 0.3s;
  }
  .thumb:hover img {
    opacity: 1;
    transform: scale(1.04);
  }
  .play {
    position: absolute;
    inset: 0;
    margin: auto;
    width: 52px;
    height: 52px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: rgba(15, 23, 42, 0.6);
    color: #fff;
    font-size: 1.1rem;
    padding-left: 4px;
  }
  .dur {
    position: absolute;
    right: 8px;
    bottom: 8px;
    padding: 2px 6px;
    border-radius: 6px;
    background: rgba(15, 23, 42, 0.85);
    color: #fff;
    font-size: 0.72rem;
    font-variant-numeric: tabular-nums;
  }
  .meta {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 12px 14px 14px;
  }
  .cat {
    align-self: flex-start;
    font-size: 0.68rem;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: #6366f1;
  }
  h3 {
    margin: 0;
    font-size: 0.98rem;
    line-height: 1.3;
    color: #0f172a;
  }
  .presenter {
    margin: 0;
    font-size: 0.8rem;
    color: #64748b;
  }
  .desc {
    margin: 4px 0 8px;
    font-size: 0.82rem;
    line-height: 1.4;
    color: #475569;
  }
  .save {
    align-self: flex-start;
    margin-top: auto;
    padding: 5px 12px;
    border: 1px solid #cbd5e1;
    border-radius: 999px;
    background: #fff;
    color: #475569;
    font: inherit;
    font-size: 0.8rem;
    font-weight: 600;
    cursor: pointer;
  }
  .save:hover {
    border-color: #6366f1;
    color: #6366f1;
  }
  .save.on {
    background: #eef2ff;
    border-color: #6366f1;
    color: #4f46e5;
  }
</style>
