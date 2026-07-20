import AppsManager from "./apps_manager";
import {
  getContext,
  getApi,
  getChannel,
  getBus,
  mountStatic as mountStaticWith,
} from "./runtime";

export { AppsManager };
export { getContext, getApi, getChannel, getBus } from "./runtime";

// A single shared manager instance is enough for most apps.
export const appsManager = new AppsManager();

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
 * Rendered by the `<.svelte>` function component; you only need to register it:
 *
 *   import { getHooks } from "@keenmate/phoenix_svelte"
 *   new LiveSocket("/live", Socket, { hooks: getHooks(), ... })
 */
export const KeenSvelte = {
  mounted() {
    const name = this.el.dataset.app;
    this.el.__keenMounted = true;

    // Tracks server->client subscriptions so we can remove them on destroy.
    this.eventRefs = [];
    // Last raw props JSON, to skip redundant re-renders.
    this.lastRaw = this.el.dataset.props || "{}";

    // Bridge handed to the Svelte component so it can talk to the server over
    // the LiveView socket.
    this.live = {
      // Push to the parent LiveView.
      pushEvent: (event, payload, onReply) =>
        this.pushEvent(event, payload, onReply),

      // Push to a specific LiveComponent/element. Defaults to this component's
      // own root element, so islands inside a LiveComponent reach *its*
      // handle_event/3 rather than the parent LiveView.
      pushEventTo: (target, event, payload, onReply) =>
        this.pushEventTo(target || this.el, event, payload, onReply),

      // Subscribe to a server-pushed event. The ref is tracked and removed
      // automatically on destroy (prevents leaks / double-fires on remount).
      handleEvent: (event, callback) => {
        const ref = this.handleEvent(event, callback);
        this.eventRefs.push(ref);
        return ref;
      },
      removeHandleEvent: (ref) => {
        this.removeHandleEvent(ref);
        this.eventRefs = this.eventRefs.filter((r) => r !== ref);
      },

      // Drive LiveView uploads from the component.
      upload: (name, files) => this.upload(name, files),
      uploadTo: (target, name, files) =>
        this.uploadTo(target || this.el, name, files),

      el: this.el,
    };

    appsManager
      .create(name, this.el, {
        props: parse(this.lastRaw),
        context: getContext(),
        live: this.live,
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
