import "./KudosButton.js";

// Lit adapter: create the custom element, map the boundary onto it, and return
// the standard { setProps, destroy } handle. Props become Lit reactive
// properties (assigning them re-renders); the kudos event feeds the shared bus.
export default (target, { props = {}, bus } = {}) => {
  const el = document.createElement("kudos-button");
  Object.assign(el, props);

  const onKudos = (e) =>
    bus &&
    bus.emit("activity", {
      title: "Kudos!",
      text: `Count is ${e.detail.count}`,
      icon: "👏",
      color: "#ec4899",
    });
  el.addEventListener("kudos", onKudos);

  target.appendChild(el);

  return {
    setProps: (next) => Object.assign(el, next),
    destroy: () => {
      el.removeEventListener("kudos", onKudos);
      el.remove();
    },
  };
};
