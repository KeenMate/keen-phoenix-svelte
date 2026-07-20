// Minimal Phoenix.Presence state/diff folding — enough to render a "who's in the
// meeting" list without pulling in the full phoenix Presence client. (Same helper
// the chat island uses; kept local so each island bundle is self-contained.)
//
// Shape Phoenix pushes:  { "<user_id>": { metas: [{ phx_ref, name, color, ... }] } }
// A user can have several metas (one per open tab); they only truly leave when
// the last meta goes.

export function applyDiff(presences, { joins = {}, leaves = {} } = {}) {
  const next = { ...presences };

  for (const [id, { metas }] of Object.entries(joins)) {
    const existing = next[id]?.metas ?? [];
    next[id] = { metas: [...existing, ...metas] };
  }

  for (const [id, { metas }] of Object.entries(leaves)) {
    const goneRefs = new Set(metas.map((m) => m.phx_ref));
    const remaining = (next[id]?.metas ?? []).filter((m) => !goneRefs.has(m.phx_ref));
    if (remaining.length) next[id] = { metas: remaining };
    else delete next[id];
  }

  return next;
}

export function onlineUsers(presences) {
  return Object.entries(presences)
    .map(([id, { metas }]) => ({
      id: Number(id),
      name: metas[0]?.name,
      color: metas[0]?.color,
    }))
    .sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""));
}
