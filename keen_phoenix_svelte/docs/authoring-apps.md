# Authoring apps

An "app" is a self-contained Svelte island. It lives in a folder under
`assets/apps/<name>/` and is discovered automatically — no central registration.

> Authoring one from scratch (below) naturally produces an island. If you're trying
> to reuse an **existing** bundle — a third-party app, or something built by another
> team — first check it can even be an island: see
> [Island-able vs page-owning apps](packaging-apps.md).

## Folder structure

```
assets/apps/like/
  js/
    App.svelte        # the component
    main.js           # entry (default-exports the mount fn)
    mount.svelte.js   # Svelte 5 only: mount logic that uses $state
```

## The mount contract

`main.js` default-exports a mount function:

```js
(target, { props, context, live, api, channel, el }) => handle
```

- `target` — the element to mount into.
- the options object is the [app boundary](server-communication.md#the-app-boundary).
- `handle` — `{ setProps, destroy }`. The hook calls `setProps` when the server
  changes props, and `destroy` on teardown. This keeps the library agnostic to
  the Svelte version.

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

export default (target, { props, context, live, api, channel }) => {
  const state = $state({ ...props, context, live, api, channel });
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

## Rendering the app

Drop a mount point into any template (LiveView or controller-rendered):

```heex
<.svelte name="like" id={"like-#{@id}"} props={%{id: @id, liked: @liked}} />
```

- `name` — the folder under `assets/apps/`.
- `id` — **required**, unique and stable (LiveView hooks need it).
- `props` — small per-component **config, not payload**. For large datasets, pass
  an identifier and have the app fetch/subscribe (see
  [Server communication](server-communication.md)).

## Build output

Each app builds to `priv/static/apps/<name>/main.mjs` — a self-contained ES
module with CSS injected by the JS. The hook `import()`s it on demand, so only
apps present on a page are ever fetched.
