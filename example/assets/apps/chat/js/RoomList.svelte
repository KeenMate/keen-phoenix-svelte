<script>
  let { rooms = [], activeRoom, onSelect } = $props();
</script>

<nav class="rooms" aria-label="Chat rooms">
  {#each rooms as room (room.id)}
    <button
      type="button"
      class="room"
      class:active={room.id === activeRoom}
      aria-current={room.id === activeRoom ? "page" : undefined}
      onclick={() => onSelect(room.id)}
    >
      <span class="hash" aria-hidden="true">#</span>
      <span class="name">{room.name}</span>
    </button>
  {/each}
</nav>

<style>
  .rooms {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 8px;
  }
  .room {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 8px 10px;
    border: 0;
    border-radius: 8px;
    background: transparent;
    color: #cbd5e1;
    font: inherit;
    font-size: 0.9rem;
    text-align: left;
    cursor: pointer;
  }
  .room:hover {
    background: rgba(255, 255, 255, 0.06);
    color: #fff;
  }
  .room.active {
    background: rgba(99, 102, 241, 0.9);
    color: #fff;
  }
  .hash {
    opacity: 0.6;
    font-weight: 700;
  }
  .name {
    font-weight: 500;
  }
</style>
