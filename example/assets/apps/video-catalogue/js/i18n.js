// Self-contained island i18n (see the calendar island for the pattern). The
// server sends only `context.locale`; the strings live here, in the bundle.
// Video titles/presenters/categories are server *content*, not UI, so they're
// left as-is — a real app would localize content separately.

const dict = {
  en: {
    title: "Video library",
    subtitle: "Talks, all-hands, and onboarding",
    videosCount: (n) => `${n} ${n === 1 ? "video" : "videos"}`,
    all: "All",
    loading: "Loading the catalogue…",
    error: "Failed to load videos",
    save: "☆ Save",
    saved: "★ Saved",
    savedActivity: "Saved to your list",
    close: "Close",
    play: (t) => `Play ${t}`,
  },
  es: {
    title: "Biblioteca de vídeos",
    subtitle: "Charlas, reuniones generales y onboarding",
    videosCount: (n) => `${n} ${n === 1 ? "vídeo" : "vídeos"}`,
    all: "Todos",
    loading: "Cargando el catálogo…",
    error: "No se pudieron cargar los vídeos",
    save: "☆ Guardar",
    saved: "★ Guardado",
    savedActivity: "Guardado en tu lista",
    close: "Cerrar",
    play: (t) => `Reproducir ${t}`,
  },
};

export function translator(locale) {
  const table = dict[locale] || dict.en;
  return (key, ...args) => {
    const value = table[key] ?? dict.en[key] ?? key;
    return typeof value === "function" ? value(...args) : value;
  };
}
