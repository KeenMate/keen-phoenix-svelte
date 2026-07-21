import { useState } from "react";

const EMOJIS = ["👍", "❤️", "🎉", "🚀"];

// A small React island. JSX is compiled by esbuild's automatic runtime (see the
// Vite config) — no `import React` needed. It gets the same boundary the other
// islands do, here `bus` to broadcast a reaction.
export default function Reactions({ bus }) {
  const [counts, setCounts] = useState({});

  const bump = (emoji) => {
    setCounts((c) => ({ ...c, [emoji]: (c[emoji] || 0) + 1 }));
    bus?.emit("activity", {
      title: "Reaction",
      text: `${emoji} reacted`,
      icon: emoji,
      color: "#0ea5e9",
    });
  };

  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 8, fontFamily: "system-ui, sans-serif" }}>
      {EMOJIS.map((emoji) => (
        <button key={emoji} onClick={() => bump(emoji)} style={btn}>
          <span style={{ fontSize: "1.1rem" }}>{emoji}</span>
          <span style={badge}>{counts[emoji] || 0}</span>
        </button>
      ))}
    </div>
  );
}

const btn = {
  display: "inline-flex",
  alignItems: "center",
  gap: 6,
  border: "1px solid #bae6fd",
  background: "#f0f9ff",
  borderRadius: 10,
  padding: "6px 10px",
  cursor: "pointer",
  font: "inherit",
};

const badge = {
  background: "#0ea5e9",
  color: "#fff",
  borderRadius: 999,
  padding: "0 6px",
  fontSize: "0.75rem",
};
