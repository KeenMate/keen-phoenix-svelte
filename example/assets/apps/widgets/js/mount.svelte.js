import { mount, unmount } from "svelte";
import Chart from "./Chart.svelte";
import Table from "./Table.svelte";

// The whole point of a multi-component app: both views ship in ONE bundle, so
// the Svelte runtime is downloaded once and shared. `props.component` (set by the
// `<.app component="…">` sugar) selects which view to mount. It's read once here
// at mount — each `<.app>` is a fixed view — so it isn't reactively swappable;
// everything *inside* the chosen view stays fully reactive to prop updates.
const VIEWS = { chart: Chart, table: Table };

export default (target, { props, context, live, api, channel, bus }) => {
  const View = VIEWS[props.component] ?? Chart;
  const state = $state({ ...props, context, live, api, channel, bus });
  const instance = mount(View, { target, props: state });

  return {
    setProps: (next) => Object.assign(state, next),
    destroy: () => unmount(instance),
  };
};
