// A tiny vanilla-JS island that makes the *mount lifecycle* visible — built to
// demonstrate `eager` mounting. It reads `liveStatus` from the boundary and, when
// it mounted before the socket was up (`"pending"`), listens for the library's
// `keen:live-ready` event to know when the `live` bridge arrives.
//
//   liveStatus "ready"   → mounted by the hook, live already here (default mode).
//   liveStatus "pending" → mounted eagerly with live:null; show a loader, then
//                          flip to "ready" when keen:live-ready fires.
//   liveStatus "none"    → plain page, there is no live at all; use REST.
//
// It also stamps performance.now() at paint and at live-ready so you can see how
// much sooner the eager island appears, and how long after that live connects.
export default (target, { liveStatus = "none", live = null, el } = {}) => {
  const paintedAt = performance.now();

  const palette = {
    ready: { color: "#22c55e", label: "live connected" },
    pending: { color: "#f59e0b", label: "mounted eagerly — waiting for live…" },
    none: { color: "#64748b", label: "no live (plain page) — REST only" },
  };

  // Start in whatever state the boundary handed us; `live` present means ready.
  let status = live ? "ready" : liveStatus;
  let liveReadyAt = status === "ready" ? paintedAt : null;

  const root = document.createElement("div");
  root.style.cssText =
    "font-family:system-ui,-apple-system,'Segoe UI',sans-serif;" +
    "border:1px solid currentColor;border-radius:12px;padding:14px 16px;" +
    "opacity:.95;display:flex;align-items:center;gap:12px;min-height:56px";

  const render = () => {
    const p = palette[status];
    const spin = status === "pending" ? "animation:keen-eager-pulse 1s ease-in-out infinite" : "";
    const gap =
      status === "ready" && liveReadyAt !== null && liveReadyAt > paintedAt
        ? ` · live +${Math.round(liveReadyAt - paintedAt)} ms later`
        : "";
    root.innerHTML =
      `<span style="width:12px;height:12px;border-radius:50%;flex:0 0 auto;` +
      `background:${p.color};box-shadow:0 0 0 4px ${p.color}33;${spin}"></span>` +
      `<div style="line-height:1.35">` +
      `<div style="font-weight:600">${p.label}</div>` +
      `<div style="font-size:12px;opacity:.7">painted at ${Math.round(paintedAt)} ms${gap}</div>` +
      `</div>`;
  };
  render();

  // Pulse keyframes injected once (islands carry no external CSS).
  if (!document.getElementById("keen-eager-demo-style")) {
    const style = document.createElement("style");
    style.id = "keen-eager-demo-style";
    style.textContent = "@keyframes keen-eager-pulse{0%,100%{opacity:.35}50%{opacity:1}}";
    document.head.appendChild(style);
  }

  target.appendChild(root);

  // The event the library fires when an eagerly-mounted island's live bridge
  // becomes available. Listening is optional — an app could implement the
  // handle's setLive() below instead, or ignore live entirely.
  const onLiveReady = () => {
    status = "ready";
    liveReadyAt = performance.now();
    render();
  };
  el.addEventListener("keen:live-ready", onLiveReady);

  return {
    setProps: () => render(),
    // Alternative to the event: the hook calls this with the live bridge when it
    // upgrades an eager island. We already handle the event, so this is a no-op
    // kept to show the contract.
    setLive: (_live) => {},
    destroy: () => {
      el.removeEventListener("keen:live-ready", onLiveReady);
      root.remove();
    },
  };
};
