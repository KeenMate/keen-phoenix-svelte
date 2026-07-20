import { mount, unmount } from "svelte";
import App from "./App.svelte";

// Standard keen_phoenix_svelte mount boilerplate: hand the boundary
// (per-component props + context/live/api/channel/bus) to the component as one
// reactive props object, and mirror server-pushed prop changes via setProps.
export default (target, { props, context, live, api, channel, bus }) => {
  const state = $state({ ...props, context, live, api, channel, bus });
  const instance = mount(App, { target, props: state });

  return {
    setProps: (next) => Object.assign(state, next),
    destroy: () => unmount(instance),
  };
};
