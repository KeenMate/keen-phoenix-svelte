<script>
  // Reads the same {title, data} the table view gets — data is a list of
  // { label, value }. Server-pushed prop updates (setProps) flow straight into
  // these, so the bars re-animate when the page randomizes the data.
  let { title = "Chart", data = [] } = $props();

  const max = $derived(Math.max(1, ...data.map((d) => d.value)));
</script>

<div class="card">
  <div class="head">
    <span class="tag">chart</span>
    <h3>{title}</h3>
  </div>

  <div class="bars">
    {#each data as d (d.label)}
      <div class="col">
        <div class="track">
          <div class="bar" style={`height:${(d.value / max) * 100}%`}>
            <span class="v">{d.value}</span>
          </div>
        </div>
        <span class="lbl">{d.label}</span>
      </div>
    {/each}
  </div>
</div>

<style>
  .card {
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    color: #0f172a;
  }
  .head {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 1rem;
  }
  .head h3 {
    margin: 0;
    font-size: 1rem;
    font-weight: 700;
  }
  .tag {
    font: 600 0.6rem/1 ui-monospace, Menlo, monospace;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #4f46e5;
    background: #eef2ff;
    padding: 3px 7px;
    border-radius: 999px;
  }
  .bars {
    display: flex;
    align-items: flex-end;
    gap: 10px;
    height: 160px;
  }
  .col {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    height: 100%;
  }
  .track {
    flex: 1;
    width: 100%;
    display: flex;
    align-items: flex-end;
  }
  .bar {
    width: 100%;
    min-height: 4px;
    border-radius: 6px 6px 0 0;
    background: linear-gradient(180deg, #6366f1, #4338ca);
    position: relative;
    transition: height 0.4s cubic-bezier(0.16, 1, 0.3, 1);
    display: flex;
    justify-content: center;
  }
  .v {
    position: absolute;
    top: -1.1rem;
    font-size: 0.7rem;
    font-weight: 700;
    color: #475569;
    font-variant-numeric: tabular-nums;
  }
  .lbl {
    font-size: 0.72rem;
    color: #94a3b8;
    font-weight: 600;
  }
</style>
