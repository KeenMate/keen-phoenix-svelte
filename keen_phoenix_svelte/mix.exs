defmodule KeenPhoenixSvelte.MixProject do
  use Mix.Project

  @version "1.0.0-rc.4"
  @source_url "https://github.com/KeenMate/keen-phoenix-svelte"
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
        "Auto-mount compiled Svelte (React, Lit, …) apps into Phoenix — LiveView + plain pages — via a hook + function component.",
      package: package(),
      name: "KeenPhoenixSvelte",
      source_url: @source_url,
      homepage_url: @homepage_url,
      docs: docs()
    ]
  end

  def application do
    # :inets/:ssl back the built-in :httpc client used by the (optional) app
    # proxy; they're OTP apps, so no external dependency is added. The supervised
    # `mod` starts the proxy's single-flight cache (idle unless the proxy is used).
    [
      extra_applications: [:logger, :inets, :ssl, :crypto],
      mod: {KeenPhoenixSvelte.Application, []}
    ]
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
      before_closing_body_tag: &mermaid_script/1,
      extras: [
        "README.md",
        "docs/philosophy.md": [title: "Philosophy & comparison"],
        "docs/packaging-apps.md": [title: "Island-able vs page-owning apps"],
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

  # Render ```mermaid code fences in the guides as diagrams (ex_doc emits them as
  # <pre><code class="mermaid">; this swaps each for an inline SVG). HTML output only.
  defp mermaid_script(:html) do
    """
    <style>
      /* Always render diagrams on a light card so they stay legible regardless of
         the docs' light/dark theme, with the SVG scaled to fit the content column. */
      .mermaid-graph {
        margin: 1.5rem 0;
        padding: 1rem;
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        text-align: center;
        overflow-x: auto;
      }
      .mermaid-graph svg { max-width: 100%; height: auto; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        // "default" is a light, high-contrast theme; the white .mermaid-graph card
        // keeps it readable even when the surrounding docs are in dark mode.
        mermaid.initialize({ startOnLoad: false, theme: "default" });
        let id = 0;
        const blocks = document.querySelectorAll("pre code.mermaid, pre code.language-mermaid");
        for (const codeEl of blocks) {
          const preEl = codeEl.parentElement;
          const graphEl = document.createElement("div");
          graphEl.className = "mermaid-graph";
          mermaid.render("mermaid-graph-" + id++, codeEl.textContent).then(({ svg, bindFunctions }) => {
            graphEl.innerHTML = svg;
            if (bindFunctions) bindFunctions(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp mermaid_script(_other), do: ""
end
