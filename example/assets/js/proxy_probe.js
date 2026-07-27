// Demo-only LiveView hook for the /guarding page. Fetches a set of proxy
// sub-paths and shows which the app SERVES (200) vs BLOCKS (404) — the `manifest:`
// allowlist in action — with per-request latency, so a re-run shows negatively
// cached misses answering fast (no repeat upstream fetch). Needs no cooperation
// from the library: it just `fetch`es `/apps/<name>/<sub>` like the browser would.
//
// Attached to `#proxy-probe` (`phx-update="ignore"`). Config from `data-probe`:
// [{group, name, sub, note}]. `cache: "no-store"` so every run reaches the server.
export const ProxyProbe = {
  mounted() {
    try {
      this.targets = JSON.parse(this.el.dataset.probe || "[]");
    } catch {
      this.targets = [];
    }
    this.rows = this.targets.map((t) => ({ ...t, status: null, ms: null, pending: false }));
    this.run = 0;
    this.render();
    this.el.addEventListener("click", (e) => {
      if (e.target.closest("[data-run]")) this.probe();
    });
  },

  async probe() {
    this.run += 1;
    await Promise.all(
      this.rows.map(async (r) => {
        r.pending = true;
        r.status = null;
        r.ms = null;
        this.render();
        const t0 = performance.now();
        try {
          const res = await fetch(`/apps/${r.name}/${r.sub}`, { cache: "no-store" });
          r.status = res.status;
        } catch {
          r.status = 0;
        }
        r.ms = performance.now() - t0;
        r.pending = false;
        this.render();
      }),
    );
  },

  render() {
    const verdict = (r) => {
      if (r.pending) return `<span class="loading loading-spinner loading-xs"></span>`;
      if (r.status == null) return `<span class="opacity-40">—</span>`;
      if (r.status >= 200 && r.status < 300)
        return `<span class="badge badge-sm badge-success gap-1">200 · served</span>`;
      if (r.status === 404)
        return `<span class="badge badge-sm badge-error gap-1">404 · blocked</span>`;
      return `<span class="badge badge-sm badge-warning">${r.status || "err"}</span>`;
    };
    const ms = (r) =>
      r.ms == null
        ? `<span class="opacity-40">—</span>`
        : `${Math.round(r.ms)}<span class="opacity-50 text-[0.65rem]"> ms</span>`;

    const rowHtml = (r) => `
      <tr class="border-t border-base-200">
        <td class="py-2 pr-3">
          <code class="text-xs">${r.name}</code>
          <span class="text-base-content/40">/</span><code class="text-xs font-semibold">${r.sub}</code>
          <div class="text-[0.7rem] text-base-content/50">${r.note}</div>
        </td>
        <td class="py-2 pr-3 whitespace-nowrap">${verdict(r)}</td>
        <td class="py-2 font-mono tabular-nums text-right whitespace-nowrap">${ms(r)}</td>
      </tr>`;

    this.el.innerHTML = `
      <div class="flex items-center justify-between mb-3">
        <button data-run class="btn btn-sm btn-primary gap-2">
          Run probe${this.run ? ` · run #${this.run}` : ""}
        </button>
        <span class="text-xs text-base-content/50">${this.run ? "re-run to see cached misses answer faster" : "fetches each path through the proxy"}</span>
      </div>
      <table class="w-full text-sm">
        <thead class="text-[0.7rem] uppercase tracking-wide text-base-content/40 text-left">
          <tr><th class="pb-1 font-medium">request</th><th class="pb-1 font-medium">result</th><th class="pb-1 font-medium text-right">latency</th></tr>
        </thead>
        <tbody>${this.rows.map(rowHtml).join("")}</tbody>
      </table>`;
  },
};
