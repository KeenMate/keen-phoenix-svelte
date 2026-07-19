import { defineConfig } from "vite";
import { svelte, vitePreprocess } from "@sveltejs/vite-plugin-svelte";

// Builds one Svelte app (assets/apps/<SVELTE_APP>) into
// priv/static/apps/<SVELTE_APP>/main.mjs as a self-contained ES module.
// CSS is injected by the JS at runtime (emitCss: false) — no separate stylesheet.
//
// Inlined (rather than using @keenmate/phoenix_svelte/vite) because a local
// `file:` dependency is symlinked and Node would resolve the Svelte plugin from
// the library's realpath instead of this app's node_modules.
const appName = process.env.SVELTE_APP;

export default defineConfig(({ mode }) => {
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
      outDir: `../priv/static/apps/${appName}/`,
    },
    resolve: { dedupe: ["svelte"] },
    plugins: [
      svelte({
        emitCss: false,
        preprocess: vitePreprocess(),
        compilerOptions: { dev: !production },
      }),
    ],
  };
});
