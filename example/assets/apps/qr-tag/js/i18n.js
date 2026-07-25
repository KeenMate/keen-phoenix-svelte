// Self-contained island i18n (see the chat/calendar islands for the pattern).
// The product code/title and the prices are server *content* and stay as-is; only
// the island's own chrome (the caption + zoom-modal labels) is translated. The
// server sends just `context.locale`.

const dict = {
  en: {
    tapToZoom: "tap to zoom",
    zoomAria: (code) => `Zoom QR for ${code}`,
    dialogAria: (code) => `QR for ${code}`,
    close: "Close",
    unit: "Unit",
    qty: "Qty",
    total: "Total",
  },
  es: {
    tapToZoom: "toca para ampliar",
    zoomAria: (code) => `Ampliar QR de ${code}`,
    dialogAria: (code) => `QR de ${code}`,
    close: "Cerrar",
    unit: "Unidad",
    qty: "Cant.",
    total: "Total",
  },
};

export function translator(locale) {
  const table = dict[locale] || dict.en;
  return (key, ...args) => {
    const value = table[key] ?? dict.en[key] ?? key;
    return typeof value === "function" ? value(...args) : value;
  };
}
