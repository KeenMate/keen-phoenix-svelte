// Multi-component island: one bundle (one shared Svelte runtime) exposing
// several views. `<.app component="chart|table">` picks which one mounts — see
// mount.svelte.js. The mount logic lives in a `.svelte.js` module because it
// mirrors server-pushed props into `$state`.
export { default } from "./mount.svelte.js";
