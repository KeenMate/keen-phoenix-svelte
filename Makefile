# Root Makefile for keen_phoenix_svelte (library) + example (Phoenix app)
SHELL := bash
EXAMPLE := example
ASSETS := example/assets

# The dual package lives in this subdir: Hex library + npm @keenmate/phoenix_svelte.
LIB := keen_phoenix_svelte
PKG := keen_phoenix_svelte
NPM_PKG := @keenmate/phoenix_svelte

# Versions differ by ecosystem style (lockstep, same release):
#   Hex (canonical, dotted) e.g. 1.0.0-rc.1   — from mix.exs @version
#   npm (zero-padded)       e.g. 1.0.0-rc01   — from package.json version
HEX_VERSION := $(shell grep -E '^\s*@version\s+"' $(LIB)/mix.exs | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
NPM_VERSION := $(shell grep -E '"version"\s*:' $(LIB)/package.json | head -1 | sed -E 's/.*"version"\s*:\s*"([^"]+)".*/\1/')

.DEFAULT_GOAL := help
.PHONY: help setup dev server sync-lib build-assets test clean docs \
        hex-deps hex-compile hex-build-docs hex-docs hex-build hex-build-inspect \
        hex-publish-dry hex-publish-rc hex-publish \
        npm-pack npm-publish-rc npm-publish \
        current-version last-published \
        container-build container-run container-shell container-push

help:
	@echo "keen_phoenix_svelte — Hex $(HEX_VERSION) / npm $(NPM_VERSION)"
	@echo ""
	@echo "Example app (Phoenix demo):"
	@echo "  setup             Fetch deps, npm install, build assets"
	@echo "  dev / server      Start the Phoenix server (http://localhost:4000)"
	@echo "  sync-lib          Re-copy the library JS into node_modules (after editing library JS)"
	@echo "  build-assets      Build Svelte apps + JS + CSS (re-syncs the library first)"
	@echo "  test              Run the example test suite (the shared publish gate)"
	@echo "  clean             Remove build artifacts, deps and node_modules"
	@echo ""
	@echo "Library — docs & inspection ($(LIB)/):"
	@echo "  docs              Build the hexdocs and serve them at http://localhost:$(DOCS_PORT)"
	@echo "  hex-docs          Generate hexdocs into $(LIB)/doc via ex_doc"
	@echo "  hex-build-docs    mix compile --warnings-as-errors + mix docs (publish-time build)"
	@echo "  hex-build-inspect Build the Hex tarball and print its file list"
	@echo "  npm-pack          npm pack --dry-run (inspect the npm tarball contents)"
	@echo "  current-version   Print both versions (Hex + npm)"
	@echo "  last-published    Query Hex + npm for the latest published versions"
	@echo ""
	@echo "Library — publish (guarded by version shape; the user runs these):"
	@echo "  hex-publish-dry   mix hex.publish --dry-run"
	@echo "  hex-publish-rc    Publish the rc to Hex (refuses unless @version is X.Y.Z-rc.N)"
	@echo "  hex-publish       Publish a stable to Hex (refuses if @version is an rc)"
	@echo "  npm-publish-rc    npm publish --tag rc (refuses unless version is a pre-release)"
	@echo "  npm-publish       npm publish (refuses if version is a pre-release)"
	@echo ""
	@echo "Demo container (example app → keen-phoenix-svelte.keenmate.dev):"
	@echo "  container-build   Build the example app image (context = repo root)"
	@echo "  container-run     Build + run on http://localhost:$(HOST_PORT)"
	@echo "  container-shell   Open a shell in the built image"
	@echo "  container-push    Tag + push to IMAGE_REMOTE"

# ---------------------------------------------------------------------------
# Example app (Phoenix demo)
# ---------------------------------------------------------------------------

setup:
	cd $(EXAMPLE) && mix setup

dev: server

server:
	cd $(EXAMPLE) && mix phx.server

# The npm `@keenmate/phoenix_svelte` dep is a `file:` package installed with
# --install-links, i.e. a real COPY in node_modules — NOT a symlink (that avoids
# the Vite/Svelte-plugin realpath resolution issue on Windows). The trade-off:
# edits to the library's JS don't propagate until the copy is refreshed. `npm
# install` alone won't re-copy (same version → skipped), so we remove it first.
# Elixir/HEEx changes never need this — only bundled JS under $(LIB)/assets/js.
sync-lib:
	cd $(ASSETS) && rm -rf node_modules/$(NPM_PKG) && npm install --install-links

# Always re-sync the copied library before building, so library-JS edits can't
# silently ship a stale bundle (run `mix assets.build` directly to skip the sync).
build-assets: sync-lib
	cd $(EXAMPLE) && mix assets.build

test:
	cd $(EXAMPLE) && mix test

clean:
	rm -rf \
	  $(EXAMPLE)/_build $(EXAMPLE)/deps $(ASSETS)/node_modules \
	  $(EXAMPLE)/priv/static/assets $(EXAMPLE)/priv/static/apps \
	  $(LIB)/_build $(LIB)/deps $(LIB)/doc $(LIB)/$(PKG)-*.tar

# ---------------------------------------------------------------------------
# Library — docs (Hex/ex_doc), run inside $(LIB)/
# ---------------------------------------------------------------------------

hex-deps: ## Fetch the library's Hex deps
	cd $(LIB) && mix deps.get

hex-compile: ## Compile the library with --warnings-as-errors
	cd $(LIB) && mix compile --warnings-as-errors

# Port the local docs server binds to (override: `make docs DOCS_PORT=9000`).
DOCS_PORT ?= 8888

docs: hex-docs ## Build the hexdocs and serve them locally at http://localhost:$(DOCS_PORT)
	@echo "Serving $(LIB)/doc at http://localhost:$(DOCS_PORT)/ (Ctrl+C to stop) ..."
	@# Open the browser once (non-blocking); harmless if it can't.
	@python3 -m webbrowser "http://localhost:$(DOCS_PORT)/" >/dev/null 2>&1 || true
	@# Serve over HTTP (not file://) so the docs' search index loads correctly.
	@cd $(LIB)/doc && python3 -m http.server $(DOCS_PORT)

hex-docs: ## Generate hexdocs into $(LIB)/doc via ex_doc
	cd $(LIB) && mix docs

# The publish-time build gate: warnings-as-errors compile + docs.
hex-build-docs: hex-compile hex-docs ## Compile (warnings-as-errors) + generate docs

# ---------------------------------------------------------------------------
# Library — tarball inspection (Hex hex.build + npm pack)
# ---------------------------------------------------------------------------

hex-build: ## Build the Hex tarball without publishing
	cd $(LIB) && mix hex.build

hex-build-inspect: hex-build ## Build the Hex tarball and print its file list
	@echo ""
	@echo "Contents of $(LIB)/$(PKG)-$(HEX_VERSION).tar:"
	@echo "---"
	@# A Hex .tar wraps the files in an inner contents.tar.gz — unwrap it to list them.
	@tar -xOf $(LIB)/$(PKG)-$(HEX_VERSION).tar contents.tar.gz | tar -tzf - | sort

npm-pack: ## Inspect the npm tarball contents (no publish)
	cd $(LIB) && npm pack --dry-run

# ---------------------------------------------------------------------------
# State inspection — "what version are we at vs the registries?"
# ---------------------------------------------------------------------------

current-version: ## Print both versions (Hex canonical + npm rendered)
	@echo "Hex (mix.exs):      $(HEX_VERSION)"
	@echo "npm (package.json): $(NPM_VERSION)"

last-published: ## Print the latest published versions on Hex and npm
	@echo "Querying Hex for $(PKG) ..."
	@cd $(LIB) && mix hex.info $(PKG) 2>/dev/null \
		| grep -iE '^(Releases|Config):' \
		|| echo "  Not found on Hex (first publish?)."
	@echo "Querying npm for $(NPM_PKG) ..."
	@npm view $(NPM_PKG) version 2>/dev/null \
		| sed 's/^/  latest: /' \
		|| echo "  Not found on npm (first publish?)."

# ---------------------------------------------------------------------------
# Publish — Hex. rc/release split enforced by @version shape.
#
# Hex has no dist-tags: the rc/release distinction lives in the version string
# (`1.0.0-rc.1` vs `1.0.0`). Consumers' `{:dep, "~> 1.0"}` constraints skip
# pre-releases by default, so SemVer semantics do what npm's `--tag rc` does.
# ---------------------------------------------------------------------------

hex-publish-dry: hex-build-docs hex-build ## Dry-run: build + hex.publish --dry-run
	@echo "Running mix hex.publish --dry-run ..."
	cd $(LIB) && mix hex.publish --dry-run
	@echo "Dry-run complete — review the output above."

hex-publish-rc: ## Publish an rc to Hex (requires @version to match X.Y.Z-rc.N)
	@case "$(HEX_VERSION)" in \
		*-rc.*) echo "@version is $(HEX_VERSION) — proceeding with rc publish." ;; \
		*) echo "ERROR: @version is $(HEX_VERSION), which is not an rc."; \
		   echo "       Use 'make hex-publish' for a stable release."; exit 1 ;; \
	esac
	@echo "WARNING: This will publish $(PKG) $(HEX_VERSION) to Hex."
	@echo "         RC versions publish as regular releases — consumers opt in"
	@echo "         explicitly because '~> X.Y' constraints skip pre-releases."
	@echo "         Press Ctrl+C to cancel, or Enter to continue ..."
	@read _
	$(MAKE) hex-build-docs
	cd $(LIB) && mix hex.publish
	@echo "Published $(PKG) $(HEX_VERSION) (rc)."

hex-publish: ## Publish a stable release to Hex (refuses if @version is an rc)
	@case "$(HEX_VERSION)" in \
		*-rc.*) echo "ERROR: @version is $(HEX_VERSION), which is an rc."; \
		   echo "       Use 'make hex-publish-rc', or drop the -rc.N suffix first."; exit 1 ;; \
	esac
	@echo "WARNING: This will publish $(PKG) $(HEX_VERSION) to Hex as a STABLE release."
	@echo "         '~> X.Y' constraints pick this up on next deps.get."
	@echo "         Press Ctrl+C to cancel, or Enter to continue ..."
	@read _
	$(MAKE) hex-build-docs
	cd $(LIB) && mix hex.publish
	@echo "Published $(PKG) $(HEX_VERSION) (stable)."

# ---------------------------------------------------------------------------
# Publish — npm. rc/release split enforced by version shape.
#
# `--tag rc` keeps the pre-release off the `latest` dist-tag so it isn't the
# default install. `--access public` is required on a scoped package's first
# publish (a no-op afterward). Run `npm login` first.
# ---------------------------------------------------------------------------

npm-publish-rc: ## npm publish --tag rc (requires version to be a pre-release, e.g. 1.0.0-rc01)
	@case "$(NPM_VERSION)" in \
		*-rc*) echo "version is $(NPM_VERSION) — proceeding with rc publish." ;; \
		*) echo "ERROR: version is $(NPM_VERSION), which is not a pre-release."; \
		   echo "       Use 'make npm-publish' for a stable release."; exit 1 ;; \
	esac
	@echo "WARNING: This will publish $(NPM_PKG)@$(NPM_VERSION) to npm under the 'rc' tag."
	@echo "         Run 'npm login' first. Press Ctrl+C to cancel, or Enter to continue ..."
	@read _
	cd $(LIB) && npm publish --tag rc --access public
	@echo "Published $(NPM_PKG)@$(NPM_VERSION) (rc)."

npm-publish: ## npm publish (refuses if version is a pre-release)
	@case "$(NPM_VERSION)" in \
		*-rc*) echo "ERROR: version is $(NPM_VERSION), which is a pre-release."; \
		   echo "       Use 'make npm-publish-rc', or drop the -rcNN suffix first."; exit 1 ;; \
	esac
	@echo "WARNING: This will publish $(NPM_PKG)@$(NPM_VERSION) to npm as 'latest'."
	@echo "         Run 'npm login' first. Press Ctrl+C to cancel, or Enter to continue ..."
	@read _
	cd $(LIB) && npm publish --access public
	@echo "Published $(NPM_PKG)@$(NPM_VERSION) (stable)."

# ---------------------------------------------------------------------------
# Demo container — the example app ("KeenSpace"), for deploying to
# keen-phoenix-svelte.keenmate.dev.
#
# Build context is the repo ROOT (not example/) because the example pulls the
# library via `path:` / npm `file:` and needs both dirs visible. CONTAINER
# defaults to podman; override for docker: `make container-run CONTAINER=docker`.
# SECRET_KEY_BASE is generated fresh per run (never baked in). PORT/PHX_HOST
# default inside the image.
# ---------------------------------------------------------------------------

CONTAINER    ?= podman
IMAGE        ?= keen-phoenix-svelte-example
HOST_PORT    ?= 4070
# Registry target for container-push, e.g. registry.keenmate.dev/keen-phoenix-svelte-example:prod
IMAGE_REMOTE ?=

container-build: ## Build the example app image (context = repo root)
	$(CONTAINER) build -t $(IMAGE) .

container-run: container-build ## Build then run on http://localhost:$(HOST_PORT)
	@echo "Serving the demo on http://localhost:$(HOST_PORT)/ (Ctrl+C to stop) ..."
	$(CONTAINER) run --rm -p $(HOST_PORT):4070 \
		-e SECRET_KEY_BASE="$$(openssl rand -base64 48)" \
		-e PHX_HOST=localhost \
		-e CHECK_ORIGIN=false \
		$(IMAGE)

container-shell: container-build ## Open a shell in the built image (debugging)
	$(CONTAINER) run --rm -it --entrypoint /bin/sh $(IMAGE)

container-push: ## Tag + push the image to IMAGE_REMOTE (set IMAGE_REMOTE=registry/host:tag)
	@test -n "$(IMAGE_REMOTE)" || { echo "ERROR: set IMAGE_REMOTE=registry.example.com/name:tag"; exit 1; }
	$(CONTAINER) tag $(IMAGE) $(IMAGE_REMOTE)
	$(CONTAINER) push $(IMAGE_REMOTE)
