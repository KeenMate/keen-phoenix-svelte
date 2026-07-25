// Page-wide runtime: the once-per-page context (user, csrf, tokens, api_base)
// and the standardized REST + channel helpers built from it. Works on both
// LiveView and plain controller-rendered pages.

import { getChannelFactory } from "./channel";
import { createBus } from "./bus";

let _context;
let _api;
let _channel;
let _bus;
let _appsManifest;

/** Reads the JSON emitted by `<KeenPhoenixSvelte.runtime context={...} />`. */
export function getContext() {
  if (_context === undefined) {
    const el = document.getElementById("keen-context");
    try {
      _context = el ? JSON.parse(el.textContent) : {};
    } catch (_e) {
      _context = {};
    }
  }
  return _context;
}

/**
 * A `fetch` wrapper for same-origin REST to your Phoenix backend. Attaches the
 * CSRF token and sends the session cookie automatically — the CSRF+session
 * pattern, no bearer token needed. JSON in, JSON out.
 */
export function getApi() {
  if (!_api) _api = buildApi(getContext());
  return _api;
}

function buildApi(context) {
  const base = (context.api_base || "").replace(/\/$/, "");
  const csrf = context.csrf_token;

  async function request(method, path, body, options = {}) {
    const res = await fetch(base + path, {
      method,
      credentials: "same-origin",
      headers: {
        accept: "application/json",
        ...(csrf ? { "x-csrf-token": csrf } : {}),
        ...(body !== undefined ? { "content-type": "application/json" } : {}),
        ...(options.headers || {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) throw new Error(`${method} ${path} -> ${res.status}`);
    const text = await res.text();
    return text ? JSON.parse(text) : null;
  }

  return {
    base,
    csrfToken: csrf,
    request,
    get: (path, options) => request("GET", path, undefined, options),
    post: (path, body, options) => request("POST", path, body, options),
    put: (path, body, options) => request("PUT", path, body, options),
    patch: (path, body, options) => request("PATCH", path, body, options),
    delete: (path, body, options) => request("DELETE", path, body, options),
  };
}

/** A `channel(topic, params)` factory bound to the page socket (lazy connect). */
export function getChannel() {
  if (!_channel) _channel = getChannelFactory(getContext());
  return _channel;
}

/** The shared, page-wide event bus for island-to-island messaging. */
export function getBus() {
  if (!_bus) _bus = createBus();
  return _bus;
}

/**
 * The `name -> url` app manifest emitted by `<KeenPhoenixSvelte.runtime>` (read
 * from `#keen-apps`). Tells `AppsManager` where each registered/external app's
 * bundle lives; apps not listed fall back to the default `basePath`.
 */
export function getAppsManifest() {
  if (_appsManifest === undefined) {
    const el = document.getElementById("keen-apps");
    try {
      _appsManifest = el ? JSON.parse(el.textContent) : {};
    } catch (_e) {
      _appsManifest = {};
    }
  }
  return _appsManifest;
}

function parseProps(el) {
  try {
    return JSON.parse(el.dataset.props || "{}");
  } catch (_e) {
    return {};
  }
}

/**
 * Early mount for `[data-app]` elements, called once after the DOM is ready.
 *
 * Two cases mount here:
 *   * **Plain (non-LiveView) pages** — `phx-hook` never fires, so every island
 *     mounts here with `live: null` (`liveStatus: "none"`); apps fall back to
 *     `api` / their own transport.
 *   * **Eager islands on a LiveView page** (`<.app eager>`, i.e. `data-eager`) —
 *     mounted here too, *before* the socket connects, so they paint without
 *     waiting for the hook. They start with `live: null` and `liveStatus:
 *     "pending"`; the `KeenApp` hook later upgrades them with the live bridge
 *     (see index.js) and fires a `keen:live-ready` event.
 *
 * Non-eager LiveView islands are skipped — the hook mounts those once connected.
 * The resolved handle and a readiness promise are stashed on the element
 * (`__keenInstance` / `__keenReady`) so the hook can adopt an eager instance.
 */
export function mountStatic(appsManager, root = document) {
  root.querySelectorAll("[data-app]").forEach((el) => {
    if (el.__keenMounted) return;
    const inLiveView = !!el.closest("[data-phx-session]");
    const eager = el.hasAttribute("data-eager");
    if (inLiveView && !eager) return; // LiveView-managed — the hook mounts it

    el.__keenMounted = true;
    if (inLiveView && eager) el.__keenEager = true;

    el.__keenReady = appsManager
      .create(el.dataset.app, el, {
        props: parseProps(el),
        context: getContext(),
        live: null,
        // "pending" = eager, live bridge is coming on connect; "none" = plain
        // page, there is no live here at all. Apps can show a loader for the
        // former and go straight to REST for the latter.
        liveStatus: el.__keenEager ? "pending" : "none",
        api: getApi(),
        channel: getChannel(),
        bus: getBus(),
        el,
      })
      .then((instance) => (el.__keenInstance = instance))
      .catch((err) => {
        console.error(err);
        return null;
      });
  });
}
