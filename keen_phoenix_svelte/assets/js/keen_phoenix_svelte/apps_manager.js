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
    // name -> Promise<module>
    this.modules = {};
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
      const url = `${this.basePath}/${name}/main.mjs`;
      this.modules[name] = import(/* @vite-ignore */ url);
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

    return mount(target, opts);
  }
}
