// The QR-tag island's entry point. The mount logic lives in a `.svelte.js`
// module because it uses Svelte 5 `$state` to mirror server-pushed props (see
// mount.svelte.js); `main.js` just re-exports it as the island's default.
export { default } from "./mount.svelte.js";
