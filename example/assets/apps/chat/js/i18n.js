// Self-contained island i18n (see the calendar island for the pattern). Room
// names and topics are server *content* and stay as-is; only the island's own UI
// chrome is translated. The server sends just `context.locale`.

const dict = {
  en: {
    online: (n) => `${n} online`,
    onlineAria: (n) => `${n} people online`,
    noMessages: "No messages yet — say hello 👋",
    connecting: "Connecting…",
    messagePlaceholder: "Message…",
    send: "Send",
    messageAria: "Message",
    couldntJoin: "Couldn't join this room",
    sendFailed: "Message failed to send",
  },
  es: {
    online: (n) => `${n} en línea`,
    onlineAria: (n) => `${n} personas en línea`,
    noMessages: "Aún no hay mensajes — saluda 👋",
    connecting: "Conectando…",
    messagePlaceholder: "Mensaje…",
    send: "Enviar",
    messageAria: "Mensaje",
    couldntJoin: "No se pudo unir a esta sala",
    sendFailed: "No se pudo enviar el mensaje",
  },
};

export function translator(locale) {
  const table = dict[locale] || dict.en;
  return (key, ...args) => {
    const value = table[key] ?? dict.en[key] ?? key;
    return typeof value === "function" ? value(...args) : value;
  };
}
