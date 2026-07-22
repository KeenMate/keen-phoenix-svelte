# Island-able vs page-owning apps

Before you register or mount anything, there's one question that decides whether a
given bundle can be an island at all:

> **Was it built to mount into a container someone hands it — or to be the whole page?**

Everything else follows from that. Note what the question is **not** about: it says
nothing about size, richness, statefulness, internal routing, or whether you call
it a "SPA". A full file-management applet — drag-and-drop, virtual scrolling, its
own toolbars and internal views, tons of state — sitting in the middle of a page is
a **perfect island**. That is exactly what this library is for (see
[Philosophy](philosophy.md): islands are autonomous dashboards, org-browsers,
applets). An island can be a whole application. It just isn't *the* page.

So the axis is **embeddable component** vs **page owner** — a *packaging* decision,
made by how the app is built, not by how complex it is.

## Island-able: the requirements

An app can be mounted inline (and get the [boundary](server-communication.md):
`context` / `live` / `api` / `channel` / `bus`) when its bundle:

1. **Mounts into the `target` it's handed** — never grabs `#app`, `document.body`,
   or any fixed element it expects to find on the page.
2. **Exports a mount function** — `export default (target, opts) => { setProps,
   destroy }` (the [mount contract](authoring-apps.md#the-mount-contract)). It does
   **not** run and mount itself as a side effect of being imported.
3. **Carries its own dependencies** — bundles its framework/vendor code. It does
   **not** assume page globals like `window.$`, jQuery, or a global Bootstrap are
   already loaded.
4. **Resolves assets relative to itself** — sibling files via
   `new URL("./thing.css", import.meta.url)`, or CSS injected by JS. **No absolute
   root paths** (`/css/…`, `/js/…`, `/assets/…`), which break the moment the bundle
   is served under a different origin or base path.
5. **Has a stable entry filename** (`main.mjs`) — not a per-build hash like
   `index-a1b2c3.js`, so it can be registered and re-served.
6. **Scopes its styles** — shadow DOM or scoped/prefixed classes, so it doesn't
   restyle the host page.
7. **Routes internally** — in-memory or hash state it owns. It does **not** try to
   drive the browser URL/history, which belongs to the host page.

Meet those and the *same* app works in **both** delivery modes (`:direct` /
`:proxy`), single- or multi-file, on a LiveView **and** a plain page — no variants.
[Authoring apps](authoring-apps.md) shows how to produce this from Svelte, React,
Lit or vanilla JS; the mechanics are a **library build** (e.g. Vite `build.lib`),
not an app build.

## Page-owning: the anti-pattern

A default framework *app* build (what `vite build` gives you without `build.lib`)
produces the opposite. Tell-tale signs a bundle is a page owner, not an island:

- ships an `index.html` and **auto-mounts** to a fixed `#app` on import;
- **absolute root** asset URLs (`/css/…`, `/js/…`, `/vite.svg`), and font/image
  `url(/…)` inside its CSS;
- relies on **page-global** vendor scripts loaded by its own `<script>` tags
  (jQuery, Bootstrap);
- a **hashed** entry filename;
- wants to own the browser URL/history.

None of these are about the app being "too big" — they're build-output choices.
Re-target the *same* application as a library build (mount into `target`, export
the fn, bundle its deps, relative assets) and it becomes a first-class island.

## Can't repackage it? Use an iframe

When you don't control the build — or it genuinely *is* a whole standalone app you
can't re-target — don't force it into an island. **Embed it in an `<iframe>`.** A
page-owning build already ships an `index.html` with absolute paths, which is
exactly what an iframe wants; host it at its own path/subdomain and the "island"
becomes a thin adapter that renders an `<iframe src="…">` sized to the container.

The trade-off: an iframe is a separate document, so it does **not** get the
in-process boundary. Configuration and messaging cross the frame via the URL and
`postMessage`, not `context` / `bus` directly. Full isolation is the upside — its
globals, CSS, and absolute paths can't collide with the host.

## Rule of thumb

- **You control the app's build** → make it island-able (a library build meeting
  the list above), and it plugs straight into the boundary.
- **You don't — or it's a whole app, not a component** → iframe it.

The [proxy](external-apps.md) is orthogonal to this choice: it only decides *where
the bytes come from* (same-origin vs cross-origin), never whether the thing is
mountable in the first place.
