import { mount, unmount } from "svelte";
import App from "./App.svelte";

// keen_phoenix_svelte hands the mount fn a single options object:
//   { props, context, live, api, el }
// `$state` makes them reactive so the hook can push server-driven prop updates
// in via setProps() (Svelte 5 has no `$set`).
export default (target, { props, context, live, api }) => {
  const state = $state({ ...props, context, live, api });
  const instance = mount(App, { target, props: state });

  return {
    setProps: (next) => Object.assign(state, next),
    destroy: () => unmount(instance),
  };
};
