import { mount, unmount } from "svelte";
import App from "./App.svelte";

// Standard keen_phoenix_svelte mount boilerplate. This island is purely
// prop-driven: the server owns the amount (a LiveView-owned <input> round-trips
// each change), recomputes the total, and pushes new props — `setProps` mirrors
// them into reactive `$state`, so the QR re-encodes with no client-side state.
export default (target, { props, context, live, api, channel, bus }) => {
  const state = $state({ ...props, context, live, api, channel, bus });
  const instance = mount(App, { target, props: state });

  return {
    setProps: (next) => Object.assign(state, next),
    destroy: () => unmount(instance),
  };
};
