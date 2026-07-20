<script>
  // onSelect (optional): when given, the avatar becomes a button. Clicking it is
  // how the island asks the *LiveView* to open a profile — see App.svelte.
  let { name = "", color = "#6b7280", size = 32, onSelect = null } = $props();

  const initials = $derived(
    name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((w) => w[0])
      .join("")
      .toUpperCase(),
  );
</script>

{#if onSelect}
  <button
    type="button"
    class="avatar clickable"
    style="--c:{color}; --s:{size}px"
    title="View {name}’s profile"
    aria-label="View {name}’s profile"
    onclick={onSelect}
  >
    {initials}
  </button>
{:else}
  <span class="avatar" style="--c:{color}; --s:{size}px" title={name} aria-label={name}>
    {initials}
  </span>
{/if}

<style>
  .avatar {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: var(--s);
    height: var(--s);
    border-radius: 50%;
    background: var(--c);
    color: #fff;
    font-size: calc(var(--s) * 0.4);
    font-weight: 600;
    line-height: 1;
    flex: none;
    user-select: none;
    box-shadow: 0 0 0 2px var(--surface, #fff);
  }
  button.avatar {
    border: none;
    padding: 0;
    font-family: inherit;
    cursor: pointer;
    transition:
      transform 0.08s ease,
      box-shadow 0.08s ease;
  }
  button.avatar:hover {
    transform: translateY(-1px);
    box-shadow:
      0 0 0 2px var(--surface, #fff),
      0 0 0 4px var(--c);
  }
  button.avatar:focus-visible {
    outline: 2px solid var(--c);
    outline-offset: 2px;
  }
</style>
