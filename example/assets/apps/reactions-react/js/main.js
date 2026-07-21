import { createElement } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.jsx";

// React adapter: render into the mount target with a root, re-render on prop
// pushes, unmount on destroy — mapping React's model onto { setProps, destroy }.
export default (target, opts = {}) => {
  const root = createRoot(target);
  let props = { ...(opts.props || {}), bus: opts.bus, context: opts.context, live: opts.live };

  const render = () => root.render(createElement(App, props));
  render();

  return {
    setProps: (next) => {
      props = { ...props, ...next };
      render();
    },
    destroy: () => root.unmount(),
  };
};
