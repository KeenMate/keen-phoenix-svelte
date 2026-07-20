// A tiny page-wide event bus for island-to-island communication.
//
// Unlike `live` / `api` / `channel` (which reach the *server*), the bus is
// purely client-side: it lets independent islands on the same page coordinate
// without knowing about each other. It works identically on LiveView and plain
// pages — there's no socket involved — which is why it's part of every mount's
// boundary, even when `live` is null.
//
// Backed by a DOM EventTarget, so it's dependency-free and framework-agnostic
// (a React or plain-JS island on the page can use the same bus).

/**
 * Create an event bus over a fresh (or supplied) EventTarget.
 *
 *   const off = bus.on("cart:add", (item) => { ... })  // subscribe
 *   bus.emit("cart:add", { id: 1 })                      // publish
 *   off()                                                // unsubscribe
 *
 * `on`/`once` return an unsubscribe function — ideal for a Svelte `$effect`
 * cleanup: `$effect(() => bus.on("x", handle))`.
 *
 * Note: this is fire-and-forget. A late-mounting island does not receive events
 * emitted before it subscribed; if you need last-value semantics, keep the value
 * in a shared store and re-emit on subscribe.
 */
export function createBus(target = new EventTarget()) {
  const on = (type, handler, options) => {
    const listener = (event) => handler(event.detail, event);
    target.addEventListener(type, listener, options);
    return () => target.removeEventListener(type, listener, options);
  };

  return {
    /** The underlying EventTarget, for advanced/interop use. */
    target,
    /** Publish `detail` to everyone listening for `type`. */
    emit: (type, detail) => target.dispatchEvent(new CustomEvent(type, { detail })),
    /** Subscribe to `type`; returns an unsubscribe function. */
    on,
    /** Subscribe to the next `type` only; returns an unsubscribe function. */
    once: (type, handler) => on(type, handler, { once: true }),
  };
}
