// Builds every Svelte app under assets/apps/* into
// priv/static/apps/<name>/main.mjs using Vite (one bundle per app).
//
//   node builder.js -m dev  -w      # unminified, watch
//   node builder.js -m prod         # minified, one-shot
//   node builder.js -m dev like     # only the named app(s)
const { readdir } = require("fs/promises");
const { exec } = require("child_process");
const fs = require("fs");
const path = require("path");

function parseArgs() {
  return require("yargs/yargs")(process.argv.slice(2))
    .alias("w", "watch")
    .describe("w", "Recompile when files change")
    .boolean("w")
    .default("w", false)
    .alias("m", "mode")
    .describe("m", "Build mode")
    .choices("m", ["dev", "prod"])
    .demandOption("m")
    .nargs("m", 1)
    .help("h")
    .alias("h", "help").argv;
}

async function discoverApps() {
  const full = path.resolve(__dirname, "apps");
  if (!fs.existsSync(full)) return [];

  const entries = await readdir(full, { withFileTypes: true });
  return entries.filter((e) => e.isDirectory()).map((e) => e.name);
}

function buildCommand(name, { mode, watch }) {
  let cmd = `cross-env SVELTE_APP=${name} vite build --mode ${mode} --config apps.vite.config.mjs`;
  if (watch) cmd += " --watch";
  return { name, cmd };
}

function stream(name, data) {
  const text = String(data)
    .replace(/\n+$/, "")
    .replace(/^/gm, `[38;5;39m[${name}][0m `);
  process.stdout.write(text + "\n");
}

function runAll(scripts) {
  scripts.forEach((script) => {
    console.log("building " + script.name);
    const child = exec(script.cmd, { cwd: __dirname });
    child.stdout.on("data", (d) => stream(script.name, d));
    child.stderr.on("data", (d) => stream(script.name, d));
  });
}

(async () => {
  const args = parseArgs();
  const apps = args._.length > 0 ? args._ : await discoverApps();

  if (apps.length === 0) {
    console.log("no apps found in assets/apps");
    return;
  }

  console.log("building apps: " + apps.join(", "));
  runAll(apps.map((name) => buildCommand(name, { mode: args.m, watch: args.w })));
})();
