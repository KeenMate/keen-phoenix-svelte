<script>
  // Same {title, data} as the chart view — the two <.app> tags on the page pass
  // identical props, differing only by `component`. Renders the data as rows with
  // each value's share of the total.
  let { title = "Table", data = [] } = $props();

  const total = $derived(data.reduce((sum, d) => sum + d.value, 0) || 1);
</script>

<div class="card">
  <div class="head">
    <span class="tag">table</span>
    <h3>{title}</h3>
  </div>

  <table>
    <thead>
      <tr><th>Label</th><th class="num">Value</th><th class="num">Share</th></tr>
    </thead>
    <tbody>
      {#each data as d (d.label)}
        <tr>
          <td>{d.label}</td>
          <td class="num">{d.value}</td>
          <td class="num pct">{((d.value / total) * 100).toFixed(1)}%</td>
        </tr>
      {/each}
    </tbody>
  </table>
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
    color: #0d9488;
    background: #f0fdfa;
    padding: 3px 7px;
    border-radius: 999px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }
  th,
  td {
    padding: 7px 10px;
    border-bottom: 1px solid #e2e8f0;
    text-align: left;
  }
  th {
    font-size: 0.65rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #94a3b8;
  }
  .num {
    text-align: right;
    font-variant-numeric: tabular-nums;
  }
  td.num {
    font-weight: 600;
  }
  .pct {
    color: #0d9488;
  }
</style>
