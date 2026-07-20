// Self-contained island i18n. The island ships its own strings and only needs
// the locale — which arrives via `context.locale` (the server sends the locale,
// never translated text). `translator(locale)` returns a `t(key, ...args)`
// function; values may be strings or functions (for counts/plurals).

const dict = {
  en: {
    title: "Calendar",
    loading: "Loading your agenda…",
    empty: "Nothing on the calendar today 🎉",
    error: "Couldn't reach the calendar service",
    simulateExpired: "Simulate expired token",
    sessionExpired: "Session expired",
    tokenMissing: "Your Microsoft Graph token is missing or expired.",
    reauth: "Re-authenticate",
    join: "Join online",
    inMeeting: "In meeting",
    joinedActivity: "Joined meeting",
    inCall: (n) => `${n} ${n === 1 ? "person" : "people"} in call`,
    connecting: "Connecting to the meeting…",
    noMessages: "No messages yet — say hello 👋",
    messagePlaceholder: "Message the meeting…",
    send: "Send",
    leave: "Leave meeting",
  },
  es: {
    title: "Calendario",
    loading: "Cargando tu agenda…",
    empty: "Hoy no tienes nada en el calendario 🎉",
    error: "No se pudo conectar con el calendario",
    simulateExpired: "Simular token caducado",
    sessionExpired: "Sesión caducada",
    tokenMissing: "Tu token de Microsoft Graph falta o ha caducado.",
    reauth: "Volver a autenticar",
    join: "Unirse en línea",
    inMeeting: "En la reunión",
    joinedActivity: "Te has unido a la reunión",
    inCall: (n) => `${n} ${n === 1 ? "persona" : "personas"} en la llamada`,
    connecting: "Conectando a la reunión…",
    noMessages: "Aún no hay mensajes — saluda 👋",
    messagePlaceholder: "Escribe a la reunión…",
    send: "Enviar",
    leave: "Salir de la reunión",
  },
};

export function translator(locale) {
  const table = dict[locale] || dict.en;
  return (key, ...args) => {
    const value = table[key] ?? dict.en[key] ?? key;
    return typeof value === "function" ? value(...args) : value;
  };
}
