import { svelte, vitePreprocess } from "@sveltejs/vite-plugin-svelte";

/**
 * Shared Vite config factory for building one Svelte app as a self-contained
 * ES module bundle. CSS is injected by the JS at runtime (`emitCss: false`), so
 * there is no separate stylesheet to wire up per app.
 *
 * Usage (assets/apps.vite.config.js):
 *
 *   import { defineConfig } from "vite"
 *   import { appConfig } from "@keenmate/phoenix_svelte/vite"
 *   export default defineConfig(({ mode }) =>
 *     appConfig({ appName: process.env.SVELTE_APP, mode }))
 */
export function appConfig({ appName, mode, outDir } = {}) {
  const production = mode === "prod";

  return {
    build: {
      emptyOutDir: true,
      minify: production ? "esbuild" : false,
      sourcemap: !production,
      lib: {
        entry: `apps/${appName}/js/main.js`,
        formats: ["es"],
        fileName: () => "main.mjs",
      },
      outDir: outDir || `../priv/static/apps/${appName}/`,
    },
    resolve: {
      dedupe: ["svelte"],
    },
    plugins: [
      svelte({
        // Inject component styles via JS instead of emitting a .css file.
        emitCss: false,
        preprocess: vitePreprocess({ sourceMap: !production }),
        compilerOptions: { dev: !production },
      }),
    ],
  };
}
