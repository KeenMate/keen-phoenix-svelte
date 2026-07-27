// dashboard — a CODE-SPLIT island: a small entry that lazy-loads its view chunks.
//
// Files (all under one directory, proxied together under `base:`):
//   dashboard/main.mjs            ← this entry (the only thing loaded up front)
//   dashboard/dashboard.css       ← stylesheet (references ./icon.svg)
//   dashboard/icon.svg            ← asset used by the CSS
//   dashboard/data.json           ← seed data fetched at mount
//   dashboard/views/overview.mjs  ← lazily imported on the Overview tab
//   dashboard/views/charts.mjs    ← lazily imported on the Charts tab
//   dashboard/views/table.mjs     ← lazily imported on the Table tab
//   dashboard/keen-manifest.json  ← the servable-file allowlist
//   dashboard/secret.js           ← present but NOT in the manifest (guard demo)
//
// The views stream in as NESTED sub-paths (`views/charts.mjs`) on demand, so the
// initial payload is just this entry. Every companion resolves relative to
// import.meta.url, so the same bytes work :direct (from the CDN) or :proxy
// (same-origin via Phoenix) with no hard-coded /apps path.
//
// Standard mount contract:
//   default export (target, { props, context, live, api, channel, bus, el }) => { setProps, destroy }

const CSS_URL = new URL("./dashboard.css", import.meta.url).href;
const DATA_URL = new URL("./data.json", import.meta.url).href;
const CSS_ID = "keen-dashboard-css";

const VIEWS = {
  overview: "./views/overview.mjs",
  charts: "./views/charts.mjs",
  table: "./views/table.mjs",
};

function ensureStylesheet() {
  if (document.getElementById(CSS_ID)) return;
  const link = document.createElement("link");
  link.id = CSS_ID;
  link.rel = "stylesheet";
  link.href = CSS_URL;
  document.head.appendChild(link);
}

export default (target, { props = {} } = {}) => {
  ensureStylesheet();

  const root = document.createElement("div");
  root.className = "keen-dash";
  root.innerHTML = `
    <div class="keen-dash__head">
      <span class="keen-dash__badge">code-split dashboard</span>
      <nav class="keen-dash__tabs" data-tabs>
        <button data-tab="overview" class="is-active">Overview</button>
        <button data-tab="charts">Charts</button>
        <button data-tab="table">Table</button>
      </nav>
    </div>
    <div class="keen-dash__body" data-body><p class="keen-dash__state">Loading…</p></div>
  `;
  target.appendChild(root);

  const body = root.querySelector("[data-body]");
  const tabs = root.querySelector("[data-tabs]");
  const cache = {};
  let data = null;
  let current = null;

  async function loadData() {
    if (data) return data;
    try {
      const res = await fetch(DATA_URL);
      data = await res.json();
    } catch {
      data = { kpis: [], series: [], rows: [] };
    }
    return data;
  }

  async function show(name) {
    if (current === name) return;
    current = name;
    for (const b of tabs.querySelectorAll("button")) {
      b.classList.toggle("is-active", b.dataset.tab === name);
    }
    body.innerHTML = `<p class="keen-dash__state">Loading ${name}…</p>`;
    const [d, mod] = await Promise.all([
      loadData(),
      cache[name] || (cache[name] = import(new URL(VIEWS[name], import.meta.url).href)),
    ]);
    if (current !== name) return; // a newer tab click won the race
    body.innerHTML = "";
    mod.default(body, d, props);
  }

  tabs.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-tab]");
    if (btn) show(btn.dataset.tab);
  });

  show("overview");

  return {
    setProps: (next) => {
      Object.assign(props, next);
      if (current) {
        const n = current;
        current = null;
        show(n);
      }
    },
    destroy: () => root.remove(),
  };
};
