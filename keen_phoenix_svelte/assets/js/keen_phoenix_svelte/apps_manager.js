/**
 * Resolves and caches Svelte app bundles, then mounts them.
 *
 * Each app is a folder under `assets/apps/<name>/` whose `main.js` has a default
 * export `(target, { props, context, live, api, channel, bus, el }) => handle`.
 * Bundles are built to `priv/static/apps/<name>/main.mjs` and imported on demand
 * — only the apps actually present on a page are ever fetched.
 */
export default class AppsManager {
  constructor(opts = {}) {
    this.basePath = opts.basePath || "/apps";
    // Optional `name -> url` map (or a function returning one) for apps whose
    // bundle lives elsewhere — a CDN, another deploy, or a same-origin proxy path
    // (see the Elixir `KeenPhoenixSvelte.Apps` registry). Emitted into the page as
    // `#keen-apps` and read here; unlisted apps fall back to `basePath`.
    this.manifest = opts.manifest || null;
    // name -> Promise<module>
    this.modules = {};
  }

  /** The URL the bundle for `name` is imported from. */
  resolve(name) {
    const map = typeof this.manifest === "function" ? this.manifest() : this.manifest;
    return (map && map[name]) || `${this.basePath}/${name}/main.mjs`;
  }

  /**
   * Register an already-loaded mount function, bypassing dynamic import.
   * Use for apps you bundle into the main app.js instead of lazy-loading.
   */
  register(name, mountFn) {
    this.modules[name] = Promise.resolve({ default: mountFn });
  }

  load(name) {
    if (!this.modules[name]) {
      this.modules[name] = import(/* @vite-ignore */ this.resolve(name));
    }
    return this.modules[name];
  }

  async create(name, target, opts) {
    const mod = await this.load(name);
    const mount = mod.default || mod.mount;

    if (typeof mount !== "function") {
      throw new Error(
        `[keen_phoenix_svelte] app "${name}" must have a default export ` +
          `(target, { props, context, live, api, channel, bus, el }) => handle`
      );
    }

    // Remove any server-rendered placeholder/loader now that the bundle has
    // loaded and we're about to mount. The app owns the target subtree from
    // here on. We clear *after* the (potentially slow) import above, so the
    // placeholder stays visible for the whole fetch — no flash of empty
    // container.
    target.replaceChildren();

    return mount(target, opts);
  }
}
