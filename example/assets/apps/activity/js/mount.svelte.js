import { mount, unmount } from "svelte";
import App from "./App.svelte";

// Standard keen_phoenix_svelte mount boilerplate. This island only needs `bus`,
// but takes the whole boundary so it stays copy-pasteable like the others.
export default (target, { props, context, live, api, channel, bus }) => {
  const state = $state({ ...props, context, live, api, channel, bus });
  const instance = mount(App, { target, props: state });

  return {
    setProps: (next) => Object.assign(state, next),
    destroy: () => unmount(instance),
  };
};
