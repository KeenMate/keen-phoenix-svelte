// Demo-only LiveView hook for the /proxying page: shows real load statistics for
// the islands on the page. It needs NO cooperation from the library or the island
// bundles — it reads two things the browser already exposes:
//
//   * Performance Resource Timing — when each bundle was *requested* (startTime)
//     and finished *loading* (responseEnd). `buffered: true` replays entries that
//     fired before this hook attached, so a fast/cached load is still captured.
//   * A MutationObserver on each island's container — the moment the island clears
//     the server-rendered placeholder and appends its own DOM = *first render*.
//
// Attached to `#proxy-load-stats` (with `phx-update="ignore"`, so this hook owns
// the subtree). Config comes from `data-apps`: [{name, container, match, label}].
// All times are milliseconds since the page started loading (the Performance
// timeline), so the three stages share one clock.
export const ProxyLoadStats = {
  mounted() {
    let apps;
    try {
      apps = JSON.parse(this.el.dataset.apps || "[]");
    } catch {
      apps = [];
    }
    if (!apps.length) return;

    this.rows = new Map(
      apps.map((a) => [a.name, { ...a, requested: null, loaded: null, rendered: null }]),
    );

    // 1) Network timing: match each app's bundle by a URL substring.
    const readEntry = (entry) => {
      for (const a of this.rows.values()) {
        if (a.requested == null && entry.name.includes(a.match)) {
          a.requested = entry.startTime;
          a.loaded = entry.responseEnd;
          this.render();
        }
      }
    };
    try {
      this.po = new PerformanceObserver((list) => list.getEntries().forEach(readEntry));
      this.po.observe({ type: "resource", buffered: true });
    } catch {
      // Older browsers: fall back to a one-shot read of whatever's buffered.
      performance.getEntriesByType("resource").forEach(readEntry);
    }

    // 2) First render: the island replaces the placeholder with its own nodes.
    // The import is async, so this hook's synchronous mount always attaches the
    // observer before the island paints — no race.
    this.observers = [];
    for (const a of this.rows.values()) {
      const target = document.getElementById(a.container);
      if (!target) continue;
      const mo = new MutationObserver((mutations) => {
        for (const m of mutations) {
          const painted = [...m.addedNodes].some((n) => n.nodeType === Node.ELEMENT_NODE);
          if (a.rendered == null && painted) {
            a.rendered = performance.now();
            this.render();
            mo.disconnect();
            return;
          }
        }
      });
      mo.observe(target, { childList: true });
      this.observers.push(mo);
    }

    this.render();
  },

  destroyed() {
    if (this.po) this.po.disconnect();
    (this.observers || []).forEach((o) => o.disconnect());
  },

  render() {
    const ms = (t) =>
      t == null
        ? `<span class="opacity-40">…</span>`
        : `${Math.round(t)}<span class="opacity-50 text-[0.65rem]"> ms</span>`;
    const delta = (from, to) =>
      to == null || from == null
        ? ""
        : `<span class="text-success text-[0.65rem]"> +${Math.round(to - from)} ms</span>`;

    const row = (label, valueHtml) => `
      <div class="flex items-baseline justify-between gap-3">
        <dt class="text-base-content/60">${label}</dt>
        <dd class="font-mono tabular-nums">${valueHtml}</dd>
      </div>`;

    this.el.innerHTML = [...this.rows.values()]
      .map(
        (a) => `
        <div class="rounded-lg border border-base-300 bg-base-100 p-4">
          <div class="flex items-center gap-2 mb-3">
            <code class="text-sm font-mono font-semibold">${a.name}</code>
            ${a.label ? `<code class="text-[0.7rem] font-mono px-1.5 py-0.5 rounded bg-primary/10 text-primary">${a.label}</code>` : ""}
          </div>
          <dl class="space-y-1.5 text-sm">
            ${row("bundle requested", ms(a.requested))}
            ${row("bundle loaded", ms(a.loaded) + delta(a.requested, a.loaded))}
            ${row("first render", ms(a.rendered) + delta(a.loaded, a.rendered))}
          </dl>
        </div>`,
      )
      .join("");
  },
};
