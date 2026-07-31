<script>
  import Editor from "./Editor.svelte";
  import Translator from "./Translator.svelte";

  // The host LiveView hands in the block, the mode ("edit" | "translate") and
  // the list of target languages. `live` is the bridge back to it; `api` is the
  // same-origin REST helper (session cookie + CSRF).
  let { block, mode = "edit", languages = [], live, api } = $props();

  // Persist an edit two ways: `live` for the instant, in-session update, and
  // `api` for the durable write into the session (a LiveView can't write the
  // session itself), so the edit survives a reload. Resolves once persisted.
  async function persist(html) {
    live?.pushEvent("save_block", { id: block.id, html });
    await api?.post("/inline-edit/blocks", { id: block.id, html });
  }

  // Closing is LiveView's call: it set editing, it clears editing. We just ask.
  function close() {
    live?.pushEvent("close_editor", {});
  }
</script>

<div class="island">
  <header class="head">
    <span class="badge">
      {mode === "translate" ? "Translate" : "Edit"}
    </span>
    <span class="title">{block.title}</span>
    <button type="button" class="x" onclick={close} aria-label="Close">✕</button>
  </header>

  <div class="body">
    {#if mode === "translate"}
      <Translator {block} {languages} {live} onsave={persist} onclose={close} />
    {:else}
      <Editor {block} onsave={persist} onclose={close} />
    {/if}
  </div>
</div>

<style>
  .island {
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    background: var(--fallback-b1, #fff);
    color: inherit;
    border: 1px solid rgba(120, 120, 140, 0.28);
    border-radius: 0.75rem;
    box-shadow: 0 12px 30px -10px rgba(0, 0, 0, 0.35);
    overflow: hidden;
  }
  .head {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 0.5rem 0.5rem 0.75rem;
    border-bottom: 1px solid rgba(120, 120, 140, 0.2);
    background: rgba(120, 120, 140, 0.06);
  }
  .badge {
    font-size: 0.62rem;
    font-weight: 700;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: #6366f1;
    background: rgba(99, 102, 241, 0.12);
    padding: 0.15rem 0.45rem;
    border-radius: 0.35rem;
  }
  .title {
    font-size: 0.8rem;
    font-weight: 600;
    opacity: 0.7;
  }
  .x {
    margin-left: auto;
    border: 0;
    background: transparent;
    cursor: pointer;
    font-size: 0.9rem;
    line-height: 1;
    opacity: 0.55;
    padding: 0.25rem;
    border-radius: 0.35rem;
    color: inherit;
  }
  .x:hover {
    opacity: 1;
    background: rgba(120, 120, 140, 0.15);
  }
  .body {
    padding: 0.75rem;
  }
</style>
