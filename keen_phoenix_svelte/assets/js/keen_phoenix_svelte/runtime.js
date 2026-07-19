// Page-wide runtime: the once-per-page context (user, csrf, tokens, api_base)
// and the standardized REST + channel helpers built from it. Works on both
// LiveView and plain controller-rendered pages.

import { getChannelFactory } from "./channel";

let _context;
let _api;
let _channel;

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

function parseProps(el) {
  try {
    return JSON.parse(el.dataset.props || "{}");
  } catch (_e) {
    return {};
  }
}

/**
 * Fallback mount for plain (non-LiveView) pages, where `phx-hook` never fires.
 * Mounts every `[data-app]` element that is NOT managed by a LiveView (those get
 * the KeenSvelte hook instead) and hasn't been mounted already. `live` is null
 * here — apps fall back to `api` / their own transport.
 */
export function mountStatic(appsManager, root = document) {
  root.querySelectorAll("[data-app]").forEach((el) => {
    if (el.__keenMounted) return;
    if (el.closest("[data-phx-session]")) return; // LiveView-managed
    el.__keenMounted = true;

    appsManager
      .create(el.dataset.app, el, {
        props: parseProps(el),
        context: getContext(),
        live: null,
        api: getApi(),
        channel: getChannel(),
        el,
      })
      .catch((err) => console.error(err));
  });
}
