// A deliberately FRAMEWORK-FREE island, hand-written with no build step and
// served from OUTSIDE the normal /apps pipeline (here, /external/...). It exists
// to demonstrate loading an app whose bundle lives *elsewhere* — a CDN, another
// team's deploy, or a database-driven catalogue — through the app registry +
// manifest (KeenPhoenixSvelte.Apps), and optionally through the same-origin
// island proxy. It still honors the standard mount contract:
//
//   default export (target, { props, context, live, api, channel, bus, el }) => { setProps, destroy }
//
export default function mount(target, { props = {}, context = {}, bus } = {}) {
  const via = props.via || "the app registry";
  const locale = (context && context.locale) || "en";
  const hi = locale === "es" ? "¡Hola" : "Hello";

  const root = document.createElement("div");
  root.style.cssText =
    "font-family:system-ui,-apple-system,'Segoe UI',sans-serif;border:1px dashed #6366f1;" +
    "border-radius:12px;padding:16px 18px;background:#eef2ff;color:#3730a3;cursor:pointer;";

  const render = (p) => {
    root.innerHTML =
      `<strong>🌍 ${hi} from an externally-loaded island</strong>` +
      `<div style="font-size:.85rem;margin-top:4px;color:#4338ca">` +
      `Framework-free, not under <code>/apps</code> — loaded via ${p.via || via}. Click me.` +
      `</div>`;
  };
  render(props);
  target.appendChild(root);

  // Proves the bus works across bundles too: an external island can join in.
  const onClick = () =>
    bus &&
    bus.emit("activity", {
      title: "External island",
      text: "Loaded and clicked 🎉",
      icon: "🌍",
      color: "#6366f1",
    });
  root.addEventListener("click", onClick);

  return {
    setProps: (next) => render({ ...props, ...next }),
    destroy: () => {
      root.removeEventListener("click", onClick);
      root.remove();
    },
  };
}
