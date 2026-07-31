<script>
  import { untrack } from "svelte";
  // The "different component in the same app": it never edits, it asks the
  // server to auto-translate the block and lets the admin accept the result.
  let { block, languages = [], live, onsave, onclose } = $props();

  // `languages` is fixed for the lifetime of the mount, so seeding the target
  // from it once is exactly right (the warning about capturing the initial
  // value is what we want here).
  let status = $state("idle"); // idle | loading | ready | saving
  let translated = $state(null);
  let to = $state(untrack(() => languages[0]?.code) ?? "es");

  function translate() {
    if (!live) return;
    status = "loading";
    live.pushEvent("translate_text", { html: block.html, to }, (reply) => {
      translated = reply?.html ?? "";
      status = "ready";
    });
  }

  async function accept() {
    if (translated == null) return;
    status = "saving";
    try {
      await onsave(translated);
      onclose();
    } catch (_e) {
      // Persistence failed — return to the ready state so the user can retry.
      status = "ready";
    }
  }
</script>

<div class="row">
  <label class="lbl" for="target-lang">Translate to</label>
  <select id="target-lang" bind:value={to} disabled={status === "loading" || status === "saving"}>
    {#each languages as lang}
      <option value={lang.code}>{lang.label}</option>
    {/each}
  </select>
  <button type="button" class="primary" onclick={translate} disabled={status === "loading" || status === "saving"}>
    {status === "loading" ? "Translating…" : "Auto-translate"}
  </button>
</div>

<div class="panes">
  <div class="pane">
    <p class="cap">Source</p>
    <div class="content">{@html block.html}</div>
  </div>
  <div class="pane">
    <p class="cap">Translation</p>
    {#if status === "ready" || status === "saving"}
      <div class="content">{@html translated}</div>
    {:else}
      <div class="empty">Pick a language and press <em>Auto-translate</em>.</div>
    {/if}
  </div>
</div>

<div class="actions">
  <button type="button" class="ghost" onclick={onclose}>Cancel</button>
  <button
    type="button"
    class="primary"
    onclick={accept}
    disabled={status !== "ready"}
  >
    {status === "saving" ? "Saving…" : "Accept translation"}
  </button>
</div>

<style>
  .row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.6rem;
  }
  .lbl {
    font-size: 0.8rem;
    opacity: 0.7;
  }
  select {
    padding: 0.3rem 0.5rem;
    border-radius: 0.45rem;
    border: 1px solid rgba(120, 120, 140, 0.3);
    background: transparent;
    color: inherit;
    font-size: 0.82rem;
  }
  .panes {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.6rem;
  }
  .pane {
    border: 1px solid rgba(120, 120, 140, 0.22);
    border-radius: 0.5rem;
    padding: 0.55rem 0.7rem;
    min-height: 4.5rem;
  }
  .cap {
    font-size: 0.62rem;
    font-weight: 700;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    opacity: 0.45;
    margin: 0 0 0.35rem;
  }
  .content {
    font-size: 0.9rem;
    line-height: 1.45;
  }
  .content :global(h2) {
    font-size: 1.05rem;
    font-weight: 700;
    margin: 0 0 0.3rem;
  }
  .content :global(p) {
    margin: 0.25rem 0;
  }
  .empty {
    font-size: 0.8rem;
    opacity: 0.5;
  }
  .actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    margin-top: 0.7rem;
  }
  .actions button,
  .row .primary {
    padding: 0.4rem 0.9rem;
    border-radius: 0.5rem;
    font-size: 0.82rem;
    font-weight: 600;
    cursor: pointer;
    border: 1px solid transparent;
  }
  .ghost {
    background: transparent;
    border-color: rgba(120, 120, 140, 0.3);
    color: inherit;
  }
  .ghost:hover {
    background: rgba(120, 120, 140, 0.12);
  }
  .primary {
    background: #6366f1;
    color: #fff;
  }
  .primary:hover {
    background: #4f46e5;
  }
  button:disabled {
    opacity: 0.6;
    cursor: default;
  }
</style>
