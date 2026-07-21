import { defineConfig } from "vite";
import { svelte, vitePreprocess } from "@sveltejs/vite-plugin-svelte";

// Builds one app (assets/apps/<SVELTE_APP>) into
// priv/static/apps/<SVELTE_APP>/main.mjs as a self-contained ES module.
// CSS is injected by the JS at runtime (emitCss: false) — no separate stylesheet.
//
// Apps can be built with different frameworks — the Svelte plugin only touches
// `.svelte` files; Lit and vanilla JS pass straight through, and esbuild's
// automatic JSX runtime handles React `.jsx`. Each app bundles its own runtime.
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
    // React apps use the automatic JSX runtime, so `.jsx` needs no `import React`.
    esbuild: { jsx: "automatic", jsxImportSource: "react" },
    // React (and others) branch on process.env.NODE_ENV; statically replace it so
    // the browser never hits a bare `process` (ReferenceError) and the prod React
    // build (much smaller, no dev warnings) is selected.
    define: {
      "process.env.NODE_ENV": JSON.stringify(production ? "production" : "development"),
    },
    resolve: { dedupe: ["svelte", "react", "react-dom"] },
    plugins: [
      svelte({
        emitCss: false,
        preprocess: vitePreprocess(),
        compilerOptions: { dev: !production },
      }),
    ],
  };
});
