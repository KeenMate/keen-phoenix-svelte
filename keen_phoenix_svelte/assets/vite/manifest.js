import { readdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

/**
 * Vite plugin that writes a `keen-manifest.json` — the exhaustive list of files
 * an app actually ships, used by the Phoenix app-proxy as a servable-file
 * allowlist (`manifest:` on the app registration).
 *
 * Unlike Vite's own `build.manifest` (which lists only what's in the module
 * graph), this scans the finished output directory in `closeBundle` — the last
 * build hook, by which point `public/` assets are already copied — so fonts,
 * images and other static files that Vite never sees are included too. The
 * output is a flat JSON array of paths relative to `outDir`, e.g.
 *
 *   ["main.mjs", "assets/logo-a1b2.svg", "fonts/inter-c3d4.woff2"]
 *
 * which is exactly the shape a proxy sub-path is matched against (no leading
 * slash, forward slashes). The proxy already parses a flat JSON array, so no
 * server-side wiring is needed beyond `manifest: "keen-manifest.json"`.
 *
 * Usage (assets/apps.vite.config.js):
 *
 *   import { defineConfig } from "vite"
 *   import { appConfig } from "@keenmate/phoenix_svelte/vite"
 *   import { keenManifest } from "@keenmate/phoenix_svelte/vite/manifest"
 *
 *   export default defineConfig(({ mode }) => {
 *     const config = appConfig({ appName: process.env.SVELTE_APP, mode })
 *     config.plugins.push(keenManifest())
 *     return config
 *   })
 *
 * @param {{ fileName?: string }} [opts] — output filename (default
 *   `"keen-manifest.json"`); written into `outDir` and excluded from itself.
 */
export function keenManifest({ fileName = "keen-manifest.json" } = {}) {
  let outDir;

  return {
    name: "keen-phoenix-svelte:manifest",
    apply: "build",

    configResolved(config) {
      outDir = resolve(config.root, config.build.outDir);
    },

    // closeBundle is the final hook — public/ assets have been copied by now.
    closeBundle() {
      const files = [];

      const walk = (dir, prefix) => {
        for (const entry of readdirSync(dir, { withFileTypes: true })) {
          const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
          if (entry.isDirectory()) walk(join(dir, entry.name), rel);
          else if (rel !== fileName) files.push(rel);
        }
      };

      walk(outDir, "");
      files.sort();
      writeFileSync(join(outDir, fileName), JSON.stringify(files, null, 2) + "\n");
    },
  };
}
