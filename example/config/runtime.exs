import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/example start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :example, ExampleWeb.Endpoint, server: true
end

config :example, ExampleWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  # Public demo app for https://keen-phoenix-svelte.keenmate.dev. TLS is
  # terminated by the reverse proxy in front of the container; the app speaks
  # plain HTTP internally but advertises https URLs to the browser.

  # Required — never bake a secret into the image or VCS. Generate one per deploy
  # with `mix phx.gen.secret`.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST", "keen-phoenix-svelte.keenmate.dev")
  port = String.to_integer(System.get_env("PORT", "4070"))

  # Defaults to the deployed https origin. Override for a local container
  # dry-run: `CHECK_ORIGIN=false` (or a comma-separated allow-list) so the
  # LiveView socket connects over plain http://localhost.
  check_origin =
    case System.get_env("CHECK_ORIGIN") do
      nil -> ["https://#{host}"]
      "false" -> false
      origins -> String.split(origins, ",", trim: true)
    end

  config :example, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :example, ExampleWeb.Endpoint,
    server: true,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    check_origin: check_origin,
    secret_key_base: secret_key_base
end
