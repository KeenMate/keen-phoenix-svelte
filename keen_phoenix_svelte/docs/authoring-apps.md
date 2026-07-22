# Authoring apps

An "app" is a self-contained **island** — a bundle that mounts into a DOM element
and honors one small contract. This guide covers writing one from scratch.

The happy path is a **Svelte** island living in your Phoenix repo (discovered
automatically, no registration). But nothing about the contract is Svelte-specific:
the same island works in **React, Lit, Vue, or plain JavaScript**, and works
whether it's local or [hosted on a CDN](external-apps.md). The back half of this
guide is the Vite config that turns any of those into one self-contained `.mjs`.

> Authoring one from scratch (below) naturally produces an island. If you're trying
> to reuse an **existing** bundle — a third-party app, or something built by another
> team — first check it can even be an island: see
> [Island-able vs page-owning apps](packaging-apps.md).

## The mount contract

Everything an app must do is captured by one default export. `main.js`
default-exports a **mount function**:

```js
(target, { props, context, live, api, channel, bus, el }) => handle
```

- `target` — the element to mount into.
- the options object is the [app boundary](server-communication.md#the-app-boundary)
  (`props`, `context`, `live`, `api`, `channel`, `bus`, `el`).
- `handle` — `{ setProps, destroy }`. The hook calls `setProps` when the server
  changes props, and `destroy` on teardown. This keeps the library agnostic to the
  framework (and Svelte version).

That's the whole interface. The library `import()`s your module, calls the default
export with a `target` and the boundary, and later calls `setProps`/`destroy` on
the handle you return. Per framework, your only job is to **adapt** its lifecycle
onto `{ setProps, destroy }`.

## Folder structure (Svelte, in your repo)

A local Svelte app lives in a folder under `assets/apps/<name>/` and is discovered
automatically — no central registration:

```
assets/apps/like/
  js/
    App.svelte        # the component
    main.js           # entry (default-exports the mount fn)
    mount.svelte.js   # Svelte 5 only: mount logic that uses $state
```

## Svelte 5 (recommended)

Svelte 5 uses `mount`/`unmount` + `$state`. Because `$state` must be compiled by
Svelte, the mount logic goes in a `.svelte.js` module, re-exported from `main.js`:

```js
// main.js — stable entry
export { default } from "./mount.svelte.js";
```

```js
// mount.svelte.js
import { mount, unmount } from "svelte";
import App from "./App.svelte";

export default (target, { props, context, live, api, channel, bus }) => {
  const state = $state({ ...props, context, live, api, channel, bus });
  const instance = mount(App, { target, props: state });
  return {
    setProps: (next) => Object.assign(state, next),
    destroy: () => unmount(instance),
  };
};
```

```svelte
<!-- App.svelte -->
<script>
  let { id, liked: likedProp = false, live, api } = $props();

  // Local state mirrored from server-pushed props (avoids reassigning a prop).
  let liked = $state(likedProp);
  $effect(() => { liked = likedProp; });

  async function toggle() {
    if (live) {
      live.pushEvent("toggle_like", { id });            // LiveView page
    } else {
      const res = await api.post("/api/like", { id });  // plain page
      liked = res.liked;
    }
  }
</script>

<button class:liked onclick={toggle}>{liked ? "♥" : "♡"} #{id}</button>
```

## Svelte 4

Returning the raw `new App()` instance also works — the hook falls back to
`$set` / `$destroy`:

```js
// main.js
import App from "./App.svelte";
export default (target, { props, context, live, api }) =>
  new App({ target, props: { ...props, live, api } });
```

Use `svelte@^4` and `@sveltejs/vite-plugin-svelte@^3` in that case.

## Other frameworks (React, Lit, Vue, plain JS)

The contract is framework-free, so an island can be built with anything that
renders into an element. The job is always the same: **produce one self-contained
ES module that default-exports the contract**, adapting the framework's lifecycle
onto `{ setProps, destroy }`. All the recipes below are real, working apps in
`example/assets/apps/`.

### The build: Vite library mode

The "one self-contained `.mjs`" requirement is met by Vite's **library mode**
(`build.lib`) — one entry in, one `main.mjs` out, framework runtime bundled in,
nothing externalized. One config serves every app (the app to build is passed via
`SVELTE_APP`):

```js
// assets/apps.vite.config.mjs
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

const appName = process.env.SVELTE_APP;

export default defineConfig(({ mode }) => {
  const production = mode === "prod";

  return {
    build: {
      emptyOutDir: true,
      minify: production ? "esbuild" : false,
      sourcemap: !production,
      lib: {
        entry: `apps/${appName}/js/main.js`,   // your default-export module
        formats: ["es"],                        // ES module → `.mjs`
        fileName: () => "main.mjs",             // stable name the loader imports
      },
      outDir: `../priv/static/apps/${appName}/`,
    },
    // React: automatic JSX runtime — no `import React` needed in .jsx.
    esbuild: { jsx: "automatic", jsxImportSource: "react" },
    // React/Preact/others branch on process.env.NODE_ENV; replace it statically so
    // the browser never hits a bare `process`, and the smaller prod build is picked.
    define: {
      "process.env.NODE_ENV": JSON.stringify(production ? "production" : "development"),
    },
    resolve: { dedupe: ["svelte", "react", "react-dom"] },
    plugins: [
      // Only touches .svelte files; Lit / vanilla / React pass straight through.
      svelte({ emitCss: false, compilerOptions: { dev: !production } }),
    ],
  };
});
```

The four load-bearing lines:

| Line | Why it matters |
|---|---|
| `formats: ["es"]` | Emits an ES module, so `import()` works and tree-shaking applies. |
| `fileName: () => "main.mjs"` | A **stable** entry name — the loader imports `main.mjs`, not a hashed file. |
| *(no `rollupOptions.external`)* | Every dependency is bundled **in**. Self-contained — this is what lets it load cross-origin from a CDN with zero import-map wiring. |
| `emptyOutDir` + fixed `outDir` | Each app owns `priv/static/apps/<name>/`. |

> **Everything really does end up in one file.** In library mode with no externals,
> Vite inlines the framework runtime, your components, and (see below) your CSS. The
> trade-off: each app carries its own copy of its runtime. For a few islands that's
> fine; for many sharing one framework, see [Sharing a runtime](#sharing-a-runtime-optional).

You don't write a config per app — a small builder discovers `apps/*` and runs the
one config per app with `SVELTE_APP` set (`node builder.js -m prod`), so vanilla,
Svelte, React, and Lit apps all build through the same pipeline. See
`example/assets/builder.js`.

### Plain JavaScript — no framework, no plugin

Build the DOM yourself, return the handle. Nothing beyond library mode is needed:

```js
// apps/hello-js/js/main.js
export default (target, { props = {}, bus } = {}) => {
  const root = document.createElement("div");
  const render = () => { root.textContent = `Hello ${props.name ?? "there"}`; };
  render();
  target.appendChild(root);

  return {
    setProps: (next) => { Object.assign(props, next); render(); },
    destroy: () => root.remove(),
  };
};
```

### React — automatic JSX + the `NODE_ENV` define

No React plugin required — **esbuild** compiles JSX. Two config lines do it (already
above): `esbuild: { jsx: "automatic", jsxImportSource: "react" }` (so `.jsx` needs
no `import React`) and the `process.env.NODE_ENV` `define`. The adapter maps a React
root onto the handle:

```js
// apps/reactions-react/js/main.js
import { createElement } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.jsx";

export default (target, opts = {}) => {
  const root = createRoot(target);
  let props = { ...(opts.props || {}), bus: opts.bus, context: opts.context, live: opts.live };
  const render = () => root.render(createElement(App, props));
  render();
  return {
    setProps: (next) => { props = { ...props, ...next }; render(); },
    destroy: () => root.unmount(),
  };
};
```

For CSS, use inline `style` objects or `import "./app.css"` — in library mode Vite
inlines the imported CSS into the JS, so it stays one file.

### Lit / Web Components — nothing special

Lit is plain JS + a custom element; no plugin, no config changes. Styles live in
the component's **shadow DOM** (`static styles = css\`…\``), so there's no sibling
stylesheet. The adapter creates the element, maps props onto it, and forwards a
custom event to the `bus`:

```js
// apps/kudos-lit/js/main.js
import "./KudosButton.js";               // defines <kudos-button>

export default (target, { props = {}, bus } = {}) => {
  const el = document.createElement("kudos-button");
  Object.assign(el, props);              // props → Lit reactive properties
  const onKudos = (e) => bus?.emit("activity", { title: "Kudos!", text: `Count ${e.detail.count}` });
  el.addEventListener("kudos", onKudos);
  target.appendChild(el);
  return {
    setProps: (next) => Object.assign(el, next),
    destroy: () => { el.removeEventListener("kudos", onKudos); el.remove(); },
  };
};
```

### Vue, Solid, Preact — same shape, add the plugin

Add the framework's Vite plugin (`@vitejs/plugin-vue`, `vite-plugin-solid`,
`@preact/preset-vite`), keep library mode, and write the same adapter — mount in the
body, re-render/patch in `setProps`, tear down in `destroy`:

```js
// Vue sketch
import { createApp } from "vue";
import App from "./App.vue";

export default (target, { props = {}, bus } = {}) => {
  const state = { ...props, bus };
  const app = createApp(App, state);
  app.mount(target);
  return {
    setProps: (next) => Object.assign(state, next), // reactive if state is reactive()
    destroy: () => app.unmount(),
  };
};
```

### CSS in a single file

The self-contained rule includes styles — an island should not depend on a
stylesheet the host page happens to load. Three ways to keep CSS in the one bundle:

- **Injected by JS** — Svelte's `emitCss: false`, or `import "./app.css"` in any
  framework (Vite inlines it in library mode). Styles land in a `<style>` at runtime.
- **Shadow DOM** — Lit / web components scope styles to the element; nothing leaks.
- **Inline styles** — React `style={{…}}` / vanilla `el.style` — best for small islands.

Whichever you choose, **scope your selectors** (a prefix class, or shadow DOM) so
the island can't restyle the host page.

> If a bundle genuinely ships a *separate* stylesheet or data file it can't inline
> (a vendor player, say), that's the multi-file case: host the directory and register
> it with `base:`, resolving siblings via `new URL("./x.css", import.meta.url)`. See
> [External apps → multi-file bundles](external-apps.md#multi-file-bundles-a-base-path-app).

### Sharing a runtime (optional)

Every app bundling its own runtime is the simplest model and the right default. If
you have *many* islands on the same framework and the duplicated runtime bytes
matter, externalize it: mark `svelte` (or `react`/`react-dom`) as `external` in
`build.rollupOptions`, emit it as one shared chunk, and add an import map to the
page so each island resolves the same copy. This trades single-file simplicity for
smaller totals — only worth it past a handful of same-framework apps.

## Rendering the app

Drop a mount point into any template (LiveView or controller-rendered):

```heex
<.app name="like" id={"like-#{@id}"} props={%{id: @id, liked: @liked}} />
```

- `name` — the folder under `assets/apps/` (or a [registered](external-apps.md) app).
- `id` — **required**, unique and stable (LiveView hooks need it).
- `props` — small per-component **config, not payload**. For large datasets, pass
  an identifier and have the app fetch/subscribe (see
  [Server communication](server-communication.md)).

## Build output

Each app builds to `priv/static/apps/<name>/main.mjs` — a self-contained ES module
with CSS injected by the JS. The hook `import()`s it on demand, so only apps present
on a page are ever fetched.

## Checklist

Before wiring the app in (`<.app name="…">` locally, or registering a
[CDN URL](external-apps.md)), confirm the built `main.mjs`:

- [ ] **default-exports** `(target, opts) => { setProps, destroy }`.
- [ ] is **one file** — no bare framework `import` the browser must resolve, and no
      sibling `.css` unless you deliberately went multi-file.
- [ ] **cleans up in `destroy`** — unmount the framework instance, `clearInterval`,
      remove listeners. Live navigation remounts islands; a leaky `destroy` piles up.
- [ ] **scopes its styles** — prefix class, shadow DOM, or inline. No global bleed.
- [ ] **mirrors, not mutates, pushed props** — `setProps` updates local state
      (`Object.assign(state, next)` / re-render), not framework-owned props.
- [ ] uses the boundary correctly — `if (live) live.pushEvent(...) else api.post(...)`;
      see [Server communication](server-communication.md).
