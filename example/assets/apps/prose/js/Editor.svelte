<script>
  import { onMount, onDestroy } from "svelte";
  import { Editor } from "@tiptap/core";
  import StarterKit from "@tiptap/starter-kit";

  let { block, onsave, onclose } = $props();

  let element; // the contenteditable host TipTap manages
  let editor = null;
  let saving = $state(false);

  // A version counter so the toolbar's active states re-evaluate on every
  // selection/content change (TipTap mutates its own state outside Svelte).
  let version = $state(0);

  onMount(() => {
    editor = new Editor({
      element,
      extensions: [StarterKit],
      content: block.html,
      onTransaction: () => (version += 1),
    });
  });

  onDestroy(() => editor?.destroy());

  // `version` is read so these recompute reactively; the value itself is unused.
  const active = $derived.by(() => {
    version;
    return (name, attrs) => editor?.isActive(name, attrs) ?? false;
  });

  function run(fn) {
    return () => fn(editor.chain().focus()).run();
  }

  let error = $state(null);

  async function save() {
    saving = true;
    error = null;
    try {
      await onsave(editor.getHTML());
      onclose();
    } catch (_e) {
      // Persistence failed (e.g. too large) — keep the overlay open, don't crash.
      error = "Couldn't save — the content may be too large.";
    } finally {
      saving = false;
    }
  }
</script>

<div class="toolbar" role="toolbar" aria-label="Formatting">
  <button type="button" class:on={active("bold")} onclick={run((c) => c.toggleBold())} title="Bold"><b>B</b></button>
  <button type="button" class:on={active("italic")} onclick={run((c) => c.toggleItalic())} title="Italic"><i>I</i></button>
  <span class="sep"></span>
  <button type="button" class:on={active("heading", { level: 2 })} onclick={run((c) => c.toggleHeading({ level: 2 }))} title="Heading">H2</button>
  <button type="button" class:on={active("bulletList")} onclick={run((c) => c.toggleBulletList())} title="Bullet list">•</button>
  <button type="button" class:on={active("orderedList")} onclick={run((c) => c.toggleOrderedList())} title="Numbered list">1.</button>
  <span class="sep"></span>
  <button type="button" onclick={run((c) => c.undo())} title="Undo">↺</button>
  <button type="button" onclick={run((c) => c.redo())} title="Redo">↻</button>
</div>

<div class="editor" bind:this={element}></div>

<p class="err" hidden={!error}>{error}</p>

<div class="actions">
  <button type="button" class="ghost" onclick={onclose} disabled={saving}>Cancel</button>
  <button type="button" class="primary" onclick={save} disabled={saving}>
    {saving ? "Saving…" : "Save"}
  </button>
</div>

<style>
  .toolbar {
    display: flex;
    align-items: center;
    gap: 0.15rem;
    margin-bottom: 0.5rem;
  }
  .toolbar button {
    min-width: 1.9rem;
    height: 1.9rem;
    padding: 0 0.4rem;
    border: 1px solid rgba(120, 120, 140, 0.25);
    background: transparent;
    border-radius: 0.4rem;
    cursor: pointer;
    font-size: 0.8rem;
    color: inherit;
  }
  .toolbar button:hover {
    background: rgba(120, 120, 140, 0.12);
  }
  .toolbar button.on {
    background: rgba(99, 102, 241, 0.16);
    border-color: rgba(99, 102, 241, 0.4);
    color: #6366f1;
  }
  .sep {
    width: 1px;
    height: 1.2rem;
    background: rgba(120, 120, 140, 0.25);
    margin: 0 0.25rem;
  }
  .editor {
    border: 1px solid rgba(120, 120, 140, 0.25);
    border-radius: 0.5rem;
    padding: 0.6rem 0.75rem;
    min-height: 5rem;
    font-size: 0.95rem;
    line-height: 1.5;
  }
  /* TipTap renders a ProseMirror node inside .editor */
  .editor :global(.ProseMirror) {
    outline: none;
  }
  .editor :global(.ProseMirror:focus) {
    outline: none;
  }
  .editor :global(h2) {
    font-size: 1.15rem;
    font-weight: 700;
    margin: 0 0 0.4rem;
  }
  .editor :global(ul),
  .editor :global(ol) {
    padding-left: 1.25rem;
    margin: 0.35rem 0;
  }
  .editor :global(p) {
    margin: 0.35rem 0;
  }
  .err {
    margin: 0.5rem 0 0;
    font-size: 0.78rem;
    color: #dc2626;
  }
  .actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    margin-top: 0.6rem;
  }
  .actions button {
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
