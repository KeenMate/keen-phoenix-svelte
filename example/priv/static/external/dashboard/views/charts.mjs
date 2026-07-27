// A tiny inline-SVG bar chart — lazily imported on the Charts tab.
export default function render(container, data) {
  const series = data.series || [];
  const max = Math.max(1, ...series);
  const bars = series
    .map((v, i) => {
      const h = (v / max) * 90;
      const x = i * 26 + 6;
      return `<rect x="${x}" y="${100 - h}" width="18" height="${h}" rx="3" class="keen-dash__bar"/>`;
    })
    .join("");
  container.innerHTML = `<svg viewBox="0 0 ${series.length * 26 + 12} 100" class="keen-dash__chart">${bars}</svg>`;
}
