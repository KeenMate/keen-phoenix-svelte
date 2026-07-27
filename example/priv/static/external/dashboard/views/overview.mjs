// KPI cards — lazily imported by main.mjs on the Overview tab.
export default function render(container, data) {
  const kpis = data.kpis || [];
  container.innerHTML = `
    <div class="keen-dash__kpis">
      ${kpis
        .map(
          (k) => `
        <div class="keen-dash__kpi">
          <div class="keen-dash__kpi-label">${k.label}</div>
          <div class="keen-dash__kpi-value">${k.value}</div>
          <div class="keen-dash__kpi-delta ${k.delta >= 0 ? "up" : "down"}">
            ${k.delta >= 0 ? "▲" : "▼"} ${Math.abs(k.delta)}%
          </div>
        </div>`,
        )
        .join("")}
    </div>`;
}
