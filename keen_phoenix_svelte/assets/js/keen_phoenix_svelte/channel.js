import { Socket } from "phoenix";

// One shared socket per page, lazily connected from the runtime context.
// The app owns the UserSocket + channels server-side (written however you like,
// including the Simplificator3000 channel macro); this is only the client.
let _socket;

function getSocket(context) {
  if (!_socket) {
    const path = context.socket_path || "/socket";
    _socket = new Socket(path, {
      params: context.socket_token ? { token: context.socket_token } : {},
    });
    _socket.connect();
  }
  return _socket;
}

function genCid() {
  try {
    return crypto.randomUUID();
  } catch (_e) {
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }
}

/**
 * Builds a `channel(topic, params)` factory bound to the page's socket.
 * Building the factory is cheap and does NOT open the socket — the socket
 * connects on the first `channel(...)` call, so apps that never use channels
 * never connect.
 *
 * The returned object wraps a Phoenix channel with promise-based join/push and
 * is **envelope-agnostic**: `push()` resolves with the raw reply payload, so you
 * read `.data` / `.error` yourself. A `cid` correlation id is attached to each
 * push by default — harmless if the server ignores it, and consumed as
 * `requestId` by channels using the Simplificator3000 `message`/`msg` macro.
 * Pass `{ cid: false }` to omit it, or `{ cid: "..." }` to set your own.
 */
export function getChannelFactory(context) {
  return (topic, params = {}) => {
    const socket = getSocket(context);
    const channel = socket.channel(topic, params);

    const joined = new Promise((resolve, reject) => {
      channel
        .join()
        .receive("ok", resolve)
        .receive("error", reject)
        .receive("timeout", () => reject(new Error("join timeout")));
    });

    return {
      channel, // raw Phoenix channel for full control
      joined,

      push(event, payload = {}, opts = {}) {
        const body =
          opts.cid === false
            ? payload
            : { ...payload, cid: opts.cid || genCid() };

        return new Promise((resolve, reject) => {
          channel
            .push(event, body)
            .receive("ok", resolve)
            .receive("error", reject)
            .receive("timeout", () => reject(new Error("push timeout")));
        });
      },

      on: (event, cb) => channel.on(event, cb),
      off: (event, ref) => channel.off(event, ref),
      leave: () => channel.leave(),
    };
  };
}
