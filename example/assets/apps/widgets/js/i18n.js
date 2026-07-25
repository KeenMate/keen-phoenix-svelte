// Self-contained island i18n (see the chat/calendar islands for the pattern).
// The `title` and the data labels are server *content* and stay as-is; only the
// island's own chrome (the table's column headers) is translated. The server
// sends just `context.locale`. Both views share this one dictionary.

const dict = {
  en: {
    label: "Label",
    value: "Value",
    share: "Share",
  },
  es: {
    label: "Etiqueta",
    value: "Valor",
    share: "Cuota",
  },
};

export function translator(locale) {
  const table = dict[locale] || dict.en;
  return (key, ...args) => {
    const value = table[key] ?? dict.en[key] ?? key;
    return typeof value === "function" ? value(...args) : value;
  };
}
