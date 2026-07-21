# syntax=docker/dockerfile:1
#
# Builds the keen_phoenix_svelte example ("KeenSpace") as a self-contained
# Elixir release for https://keen-phoenix-svelte.keenmate.dev.
#
# IMPORTANT: the build context must be the repo ROOT, not example/. The example
# app pulls the library via `path: "../keen_phoenix_svelte"`, and its npm assets
# pull it via `file:../../keen_phoenix_svelte`, so both directories have to be
# visible to the build.
#
#   podman build -t keen-phoenix-svelte-example .
#   podman run --rm -p 4070:4070 \
#     -e SECRET_KEY_BASE="$(openssl rand -base64 48)" \
#     keen-phoenix-svelte-example
#
# SECRET_KEY_BASE is required at runtime (never baked into the image); PHX_HOST
# and PORT default below and can be overridden with -e. Elixir 1.18 / OTP 27.

########################################
# Build stage — compile assets + assemble the release
########################################
FROM elixir:1.18.4-otp-27 AS build

# Node is needed for the Svelte/Vite asset build. (keen-web-multiselect ships
# prebuilt assets and skips this; this example compiles its islands at build.)
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends curl ca-certificates git \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

WORKDIR /src

# The library — both the Elixir `path:` dep and the npm `file:` dep resolve here.
COPY keen_phoenix_svelte ./keen_phoenix_svelte
# The example app itself.
COPY example ./example

WORKDIR /src/example

# 1. Fetch + compile prod deps (also compiles the path-dep library).
RUN mix deps.get --only prod
RUN mix deps.compile

# 2. Install the JS toolchain (tailwind + esbuild binaries, and `npm install
#    --install-links`, which installs the local `file:` library as a real copy —
#    matching dev, and sidestepping the Vite/Svelte-plugin realpath issue).
RUN mix assets.setup

# 3. Compile the app BEFORE building assets: the phoenix_live_view compiler emits
#    the generated `phoenix-colocated/example` module that app.js imports, so
#    esbuild can only resolve it once the app is compiled. (The dev `assets.build`
#    alias compiles first; `assets.deploy` does not, so we do it here.)
RUN mix compile

# 4. Build minified assets (tailwind, esbuild, and the Svelte islands via Vite),
#    then digest them.
RUN mix assets.deploy

# 5. Assemble the release (bundles ERTS + deps + priv/static).
RUN mix release --overwrite

########################################
# Runtime stage — minimal image, just the release + its ERTS
########################################
FROM debian:bookworm-slim AS runtime

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
       libstdc++6 openssl libncurses6 locales ca-certificates \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

WORKDIR /app

# Run unprivileged — it's a public demo with no need for root.
RUN useradd --create-home --uid 1000 app
USER app

# The release bundles the ERTS, the app, every dep, and priv/static (served by
# Plug.Static), so no Elixir/Node/mix is needed at runtime.
COPY --from=build --chown=app:app /src/example/_build/prod/rel/example ./

# Defaults; override at run time as needed. TLS terminates upstream.
ENV PHX_HOST=keen-phoenix-svelte.keenmate.dev \
    PORT=4070

EXPOSE 4070

CMD ["bin/example", "start"]
