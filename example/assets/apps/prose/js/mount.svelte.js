import { mount, unmount } from "svelte";
import App from "./App.svelte";

// Standard keen_phoenix_svelte mount boilerplate. This island is only ever
// mounted inside a LiveView (the /inline-edit host renders it on demand), so it
// leans on `live` for its save/translate round-trips.
export default (target, { props, context, live, api, channel, bus }) => {
  const state = $state({ ...props, context, live, api, channel, bus });
  const instance = mount(App, { target, props: state });

  return {
    setProps: (next) => Object.assign(state, next),
    destroy: () => unmount(instance),
  };
};
