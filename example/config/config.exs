# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :example,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :example, ExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ExampleWeb.ErrorHTML, json: ExampleWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Example.PubSub,
  live_view: [signing_salt: "KwPJBevx"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  example: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  example: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# keen_phoenix_svelte app registry — demonstrates loading an island whose bundle
# lives *outside* the normal /apps pipeline (here, a hand-written file under
# /external). Base config loads it :direct (same-origin, always works); dev.exs
# flips it to :proxy to show the server fetching + re-serving it. See
# KeenPhoenixSvelte.Apps.
config :keen_phoenix_svelte,
  apps: %{
    "greeter" => "/external/greeter/main.mjs",
    # Two islands hosted on a GENUINELY external CDN
    # (apps.keen-phoenix-svelte.keenmate.dev — see the sibling
    # keen-phoenix-svelte-apps repo), showcased side by side on the /proxying
    # page. `hello` loads :direct — the browser imports the CDN URL itself.
    # `metrics` loads :proxy — Phoenix fetches the CDN bundle *and* its sibling
    # stylesheet + data file and re-serves them same-origin under /apps/metrics/*.
    "hello" => %{
      url: "https://apps.keen-phoenix-svelte.keenmate.dev/hello/main.mjs",
      mode: :direct
    },
    "metrics" => %{
      base: "https://apps.keen-phoenix-svelte.keenmate.dev/metrics/",
      entry: "main.mjs",
      mode: :proxy,
      ttl: :timer.seconds(60)
    }
  },
  # Server-wide island loader. The placeholder is server-rendered into the page
  # (so it can use the app's own daisyUI/Tailwind) and the client clears it the
  # instant the bundle mounts — no flash of empty container. Any island can
  # override this with a <:placeholder> slot.
  placeholder: ~s|<div class="skeleton h-full min-h-[3rem] w-full rounded-lg"></div>|

# We don't use LiveView's colocated hooks / JS (islands are separate compiled
# bundles, wired via getHooks()), so silence the Windows-only "Failed to symlink
# node_modules for ColocatedJS: :eperm" compile warning — the symlink is for a
# feature we never touch.
config :phoenix_live_view, :colocated_js, disable_symlink_warning: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
