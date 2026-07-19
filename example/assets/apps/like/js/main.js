// Stable entry point for every keen_phoenix_svelte app:
//   (target, props, live) => handle ({ setProps, destroy })
// Reactivity lives in mount.svelte.js so the Svelte compiler processes its runes.
export { default } from "./mount.svelte.js";
