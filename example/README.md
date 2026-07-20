# KeenSpace — the keen_phoenix_svelte demo

A small but real-looking **corporate workspace** app that shows how
[`keen_phoenix_svelte`](../keen_phoenix_svelte) mounts autonomous **Svelte 5
islands** into a **Phoenix** app. It's both the runnable demo (deployed at
**keen-phoenix-svelte.keenmate.dev**) and a set of copy-able reference apps.

Everything is **in-memory** — no database. A user switcher (top-right) lets you
"become" different people so the multi-user features are believable from one
machine: open two browser profiles, switch users, and watch chat + presence update.

## The three islands

Each area is a self-contained Svelte app under `assets/apps/`, and each one
demonstrates a different piece of the [app boundary](../keen_phoenix_svelte/docs/server-communication.md):

| Route | Island | Talks to the server via |
| --- | --- | --- |
| `/chat` | `chat` | **`channel` + Presence** — a Phoenix channel per room (`chat:<room>`), live messages, online avatars. |
| `/videos` | `video-catalogue` | **`api`** (REST catalogue) **+ the `live` bridge** — "save" pushes over the LiveView socket, with an `api.post` fallback. Plays with [Plyr](https://plyr.io). |
| `/calendar` | `calendar` | **`context.tokens` + its own `fetch`** — calls a *simulated* Microsoft Graph (`/mock-graph/...`) with a bearer token, exactly as it would call `graph.microsoft.com`. |

`/calendar-plain` is the same calendar island on a **plain, non-LiveView page**
(mounted by `mountStatic()` with `live: null`) — proof that an island runs
anywhere and only its transport changes.

This mapping mirrors the library's
[Worked example: multiple apps](../keen_phoenix_svelte/docs/multiple-apps.md) guide.

## Run it

```bash
make setup     # from the repo root — deps + npm install + build assets
make dev       # http://localhost:4000
```

During development the Phoenix watcher rebuilds the Svelte apps on change
(`assets/builder.js`). Run the tests with `make test`.

> On Windows, if `@keenmate/phoenix_svelte` fails to resolve, re-run
> `cd example/assets && npm install --install-links` (npm can't create the `file:`
> symlink without Developer Mode).

## How it's wired

- **Runtime context** — `lib/example_web/components/layouts/root.html.heex` renders
  `<KeenPhoenixSvelte.runtime context={…}>` once per page: the current user, CSRF,
  the channel `socket_token`, and the simulated `tokens.graph`.
- **Shell** — `Layouts.workspace/1` is the sidebar + top-bar chrome shared by every
  LiveView and the plain page.
- **Islands** — `<.svelte name="…" props={…}>` in each thin LiveView
  (`lib/example_web/live/`). The Svelte source lives in `assets/apps/<name>/js/`.
- **Backend** — in-memory contexts (`Example.Directory`, `Example.Chat`,
  `Example.VideoCatalogue`, `Example.Calendar`), the `ChatChannel`, the REST
  `VideoController`, and the mock-Graph controller + `RequireGraphToken` plug.

## Deploy

A repo-root `Dockerfile` builds this app (assets included) into a self-contained
Elixir release. From the repo root:

```bash
make container-build                      # build the image
make container-run                        # run locally on http://localhost:4070
make container-push IMAGE_REMOTE=registry.keenmate.dev/keen-phoenix-svelte-example:prod
```

`SECRET_KEY_BASE` is required at runtime (generated fresh by `container-run`);
`PHX_HOST` and `PORT` default in the image. TLS terminates at the reverse proxy.
