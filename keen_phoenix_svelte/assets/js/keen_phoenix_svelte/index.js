import AppsManager from "./apps_manager";
import {
  getContext,
  getApi,
  getChannel,
  getBus,
  getAppsManifest,
  mountStatic as mountStaticWith,
} from "./runtime";

export { AppsManager };
export { getContext, getApi, getChannel, getBus, getAppsManifest } from "./runtime";

// A single shared manager instance is enough for most apps. It's given the app
// manifest lazily (read from the page on first mount), so registered/external
// apps resolve to their configured URL and everything else uses the base path.
export const appsManager = new AppsManager({ manifest: getAppsManifest });

/**
 * Mount every `[data-app]` on a plain (non-LiveView) page. Call once after the
 * DOM is ready. Elements inside a LiveView are skipped — the hook handles those.
 */
export function mountStatic(root) {
  return mountStaticWith(appsManager, root);
}

/**
 * LiveView hook that mounts a compiled Svelte component into its element and
 * keeps it in sync with server-driven prop changes.
 *
 * Rendered by the `<.app>` function component; you only need to register it:
 *
 *   import { getHooks } from "@keenmate/phoenix_svelte"
 *   new LiveSocket("/live", Socket, { hooks: getHooks(), ... })
 */
export const KeenSvelte = {
  mounted() {
    const name = this.el.dataset.app;

    // Tracks server->client subscriptions so we can remove them on destroy.
    this.eventRefs = [];
    // Last raw props JSON, to skip redundant re-renders.
    this.lastRaw = this.el.dataset.props || "{}";
    // Bridge handed to the component so it can talk to the server over the
    // LiveView socket. Only exists here, in the hook — hence eager islands mount
    // with live:null and get it later (see below).
    this.live = buildLive(this);

    // Eager path: mountStatic() already mounted this island (with live:null)
    // before the socket connected, so it has painted. Don't re-mount — adopt the
    // existing instance and hand it the live bridge, then announce it.
    if (this.el.__keenEager) {
      this.el.__keenMounted = true;
      Promise.resolve(this.el.__keenReady).then((instance) => {
        if (!instance) return; // eager mount failed; nothing to upgrade
        this.instance = instance;
        if (typeof instance.setLive === "function") instance.setLive(this.live);
        // Announce that the live bridge is now available (liveStatus pending ->
        // ready). Apps can listen instead of (or as well as) implementing setLive
        // — e.g. to hide a "connecting" loader.
        this.el.dispatchEvent(
          new CustomEvent("keen:live-ready", { detail: { live: this.live } })
        );
        // Flush any prop change that arrived before the instance resolved.
        if (this.pendingProps) {
          applyProps(instance, this.pendingProps);
          this.pendingProps = null;
        }
      });
      return;
    }

    // Default path: mount now that the hook (and thus live) is available.
    this.el.__keenMounted = true;
    appsManager
      .create(name, this.el, {
        props: parse(this.lastRaw),
        context: getContext(),
        live: this.live,
        liveStatus: "ready",
        api: getApi(),
        channel: getChannel(),
        bus: getBus(),
        el: this.el,
      })
      .then((instance) => {
        this.instance = instance;
        // Flush any prop change that arrived before mount resolved.
        if (this.pendingProps) {
          applyProps(instance, this.pendingProps);
          this.pendingProps = null;
        }
      })
      .catch((err) => console.error(err));
  },

  updated() {
    const raw = this.el.dataset.props || "{}";
    if (raw === this.lastRaw) return; // props unchanged — nothing to do
    this.lastRaw = raw;

    const props = parse(raw);
    if (this.instance) {
      applyProps(this.instance, props);
    } else {
      // Mount not resolved yet — remember the latest props.
      this.pendingProps = props;
    }
  },

  destroyed() {
    (this.eventRefs || []).forEach((ref) => this.removeHandleEvent(ref));
    this.eventRefs = [];
    if (this.instance) teardown(this.instance);
  },
};

function parse(raw) {
  try {
    return JSON.parse(raw || "{}");
  } catch (_e) {
    return {};
  }
}

// Builds the `live` bridge from a hook instance. Extracted so both the default
// and eager mount paths share one definition. All calls delegate to the hook's
// own LiveView methods, which only exist once the hook has mounted.
function buildLive(hook) {
  return {
    // Push to the parent LiveView.
    pushEvent: (event, payload, onReply) => hook.pushEvent(event, payload, onReply),

    // Push to a specific LiveComponent/element. Defaults to this component's own
    // root element, so islands inside a LiveComponent reach *its* handle_event/3
    // rather than the parent LiveView.
    pushEventTo: (target, event, payload, onReply) =>
      hook.pushEventTo(target || hook.el, event, payload, onReply),

    // Subscribe to a server-pushed event. The ref is tracked and removed
    // automatically on destroy (prevents leaks / double-fires on remount).
    handleEvent: (event, callback) => {
      const ref = hook.handleEvent(event, callback);
      hook.eventRefs.push(ref);
      return ref;
    },
    removeHandleEvent: (ref) => {
      hook.removeHandleEvent(ref);
      hook.eventRefs = hook.eventRefs.filter((r) => r !== ref);
    },

    // Drive LiveView uploads from the component.
    upload: (name, files) => hook.upload(name, files),
    uploadTo: (target, name, files) => hook.uploadTo(target || hook.el, name, files),

    el: hook.el,
  };
}

// The app entry returns a "handle" describing how to update/tear down the
// mounted component. This keeps the hook agnostic to the Svelte version:
//   * Svelte 5: return { setProps, destroy } wrapping mount()/unmount().
//   * Svelte 4: returning the raw `new App()` instance also works via the
//     `$set` / `$destroy` fallbacks below.
function applyProps(instance, props) {
  if (typeof instance.setProps === "function") instance.setProps(props);
  else if (typeof instance.$set === "function") instance.$set(props);
}

function teardown(instance) {
  if (typeof instance.destroy === "function") instance.destroy();
  else if (typeof instance.$destroy === "function") instance.$destroy();
}

/** Convenience for `new LiveSocket(..., { hooks: getHooks() })`. */
export function getHooks(extra = {}) {
  return { KeenSvelte, ...extra };
}

export default getHooks;
