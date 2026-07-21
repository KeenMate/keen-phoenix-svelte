defmodule KeenPhoenixSvelte.MixProject do
  use Mix.Project

  @version "1.0.0-rc.2"
  @source_url "https://github.com/keenmate/keen_phoenix_svelte"
  @homepage_url "https://keen-phoenix-svelte.keenmate.dev"

  def project do
    [
      app: :keen_phoenix_svelte,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Auto-mount compiled Svelte components into Phoenix LiveView via a hook + function component.",
      package: package(),
      name: "KeenPhoenixSvelte",
      source_url: @source_url,
      homepage_url: @homepage_url,
      docs: docs()
    ]
  end

  def application do
    # :inets/:ssl back the built-in :httpc client used by the (optional) island
    # proxy; they're OTP apps, so no external dependency is added.
    [extra_applications: [:logger, :inets, :ssl]]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["KeenMate"],
      licenses: ["MIT"],
      files:
        ~w(lib assets docs package.json mix.exs README.md CHANGELOG.md LICENSE .formatter.exs),
      links: %{"Website" => @homepage_url, "GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "docs/philosophy.md": [title: "Philosophy & comparison"],
        "docs/installation.md": [title: "Installation & setup"],
        "docs/authoring-apps.md": [title: "Authoring apps"],
        "docs/server-communication.md": [title: "Server communication"],
        "docs/multiple-apps.md": [title: "Worked example: multiple apps"],
        "docs/external-apps.md": [title: "External apps (CDN, direct vs proxy)"],
        "CHANGELOG.md": [title: "Changelog"]
      ],
      groups_for_extras: [Guides: ~r{docs/}]
    ]
  end
end
