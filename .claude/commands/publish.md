---
description: Prepare BOTH keen_phoenix_svelte (Hex) and @keenmate/phoenix_svelte (npm) for publish in one lockstep pass — bump versions, finalize CHANGELOG/README, test, verify both tarballs, commit
argument-hint: rc|release|patch|minor|major
---

# /publish — prepare a lockstep release of the dual package

You are preparing **both halves** of this dual package for publish in a single
pass:

- the **Hex** library `keen_phoenix_svelte` (`mix hex.publish`), and
- the **npm** package `@keenmate/phoenix_svelte` (`npm publish`).

**Do not run `mix hex.publish` or `npm publish`** — the user authenticates and
publishes both manually. This command prepares, verifies, and commits; it reports
the two exact publish commands at the end.

Both manifests live in `./keen_phoenix_svelte/`, share **one version**, one
`CHANGELOG.md`, and one `README.md`. Because they must always ship together, this
one command owns the whole release. (The sibling commands `/publish-hex` and
`/publish-npm` still exist for the rare case where one registry's publish failed
and you need to redo *only* that half — they take a "fast path" when the release
is already finalized. For the normal flow, prefer **this** command.)

This command follows the canonical `/publish` structure (from the BlissFramework
component guidelines). Sections marked **[canonical]** are the shared release
ritual; **[per-repo]** sections are customized for this dual-package layout;
**[hex]** / **[npm]** mark the ecosystem-specific gates that this command runs
**both** of.

## Working directory [per-repo]

Both manifests live in `./keen_phoenix_svelte/`, **not** the repo root. Run all
`mix` and `npm` commands from there (`cd keen_phoenix_svelte`). The **test gate is
`make test` from the repo root** (it does `cd example && mix test`).

## No npm build step [npm]

`@keenmate/phoenix_svelte` **ships raw source** — `package.json` has `"files":
["assets"]`, `main`/`module`/`exports` point straight at `assets/js/...` and
`assets/vite/config.js`, and there is **no `scripts` block, no `dist/`, no bundler
step.** `npm pack --dry-run` inspects the exact files on disk. Do not look for a
`npm run build`. (The Hex side *does* have a doc build — see step 8.)

## Lockstep coupling [per-repo] — read this first

The two packages **always share one version**. This command bumps **both**
manifests together and finalizes the **shared** CHANGELOG + README, in a single
commit:

- `keen_phoenix_svelte/mix.exs` — `@version "X.Y.Z"` (Hex source of truth)
- `keen_phoenix_svelte/package.json` — `"version": "X.Y.Z"` (npm source of truth)

**rc format — per-ecosystem styles [important].** The two packages carry the
*same semantic version* but render the rc suffix in each ecosystem's own idiom:

| Surface | Style | Example |
|---|---|---|
| **Hex** — `mix.exs`, and the **canonical** form used in CHANGELOG / git tag / commit subject / What's New heading | dotted | `1.0.0-rc.1` |
| **npm** — `package.json` **only** | zero-padded, no dot | `1.0.0-rc01` |

The **canonical (dotted) form is authoritative.** Derive the npm form by replacing
`-rc.N` with `-rc` + `N` zero-padded to two digits (`rc.1`→`rc01`, `rc.12`→`rc12`).
Two version strings that normalize to the same `(major, minor, patch, rc-number)`
are **the same release** — that is what "lockstep" means, *not* byte-identical
strings. A final (non-rc) release like `1.0.0` is identical in both manifests.

## Argument [canonical]

The release type: **$1** (one of `rc`, `release`, `patch`, `minor`, `major`).

- `rc` — ship the WIP rc as-is. The topmost CHANGELOG heading gets ` [PUBLISHED]`
  appended; npm publishes under the `rc` dist-tag (see step 11).
- `release` — promote a WIP rc to a final release. `X.Y.Z-rc.N` → `X.Y.Z`.
- `patch` / `minor` / `major` — SemVer bump; drops any `-rc.N` suffix.

If missing or invalid, stop and ask the user which one to use (don't guess).

## Repo layout [per-repo]

Dual package under `./keen_phoenix_svelte/`:

- **`mix.exs`** — `@version`; Hex source of truth. `:files` in `package/0` controls the **Hex** tarball.
- **`package.json`** — `version`; npm source of truth. `"files": ["assets"]` controls the **npm** tarball.
- **`CHANGELOG.md`** — shared. Topmost `## [X.Y.Z] - YYYY-MM-DD` heading **without** `[PUBLISHED]` is the WIP section. (If the repo uses a `## [Unreleased]` heading as WIP, treat that as the WIP section and rename it to the resolved version in step 3.)
- **`README.md`** — shared. Carries `## What's New in vX.Y.Z` sections near the top.
- **`lib/`** — Elixir sources (Hex only).
- **`assets/`** — the JS the npm package publishes (shipped by **both** ecosystems).
- **`docs/`** — ex_doc guides (Hex only).
- **`_build/`, `deps/`, `doc/`, `node_modules/`** — gitignored / build artifacts. Never staged, never shipped.
- **`mix.lock`** — tracked. Don't touch during publish unless deps changed intentionally.

## Git note [per-repo]

If `git rev-parse --is-inside-work-tree` fails, **skip** the git-dependent steps
(1's `git status`, step 6, and the commit in step 10) and tell the user the files
are staged-in-spirit but uncommitted because there's no git repo.

## CHANGELOG convention [canonical]

The WIP section is the topmost `## [X.Y.Z] - YYYY-MM-DD` heading without a
`[PUBLISHED]` tag (or an `## [Unreleased]` heading, if that's what the repo uses).
Publishing means renaming it to the resolved version (if needed) and **appending
` [PUBLISHED]`** so it reads exactly `## [X.Y.Z] - YYYY-MM-DD [PUBLISHED]`. Do not
create an empty new WIP section afterward.

## Resolve versions [canonical + lockstep]

Read `@version` from `mix.exs` as `CURRENT_VERSION` (canonical dotted). Read
`version` from `package.json` as `NPM_VERSION`. Compare by **normalizing** to
`(major, minor, patch, rc-number)` — `1.0.0-rc.1` and `1.0.0-rc01` are the *same*
release, not drift. Only if they normalize to **different** releases have they
drifted: warn, show both, treat `mix.exs` as authoritative unless told otherwise,
and resync in step 2.

Read the topmost `## [X.Y.Z...]` (or `[Unreleased]`) heading from `CHANGELOG.md` as
`WIP_VERSION`. Track `NEW_VERSION` in canonical dotted form; render the npm form
(`NPM_NEW_VERSION`) only when writing `package.json`.

Compute `NEW_VERSION`:

| Argument | Logic |
|---|---|
| `rc` | If `CURRENT_VERSION` is `X.Y.Z-rc.N` **and not already published**, `NEW_VERSION = CURRENT_VERSION`. If it's already published (see step 1), the intent is the *next* rc — stop and confirm the target (e.g. `X.Y.Z-rc.(N+1)`) with the user. If not an rc at all, stop and ask. |
| `release` | If `CURRENT_VERSION` is `X.Y.Z-rc.N`, `NEW_VERSION = X.Y.Z`. Otherwise stop. |
| `patch` | Strip any `-rc.N`, bump patch. |
| `minor` | Strip any `-rc.N`, bump minor, reset patch. |
| `major` | Strip any `-rc.N`, bump major, reset minor and patch. |

If `WIP_VERSION` ≠ `NEW_VERSION`, the step-3 heading rename also re-tags the
section — call this out in the report.

## Steps (in order)

### 1. Sanity checks [canonical + both registries]

- Run `git status` (if git-initialized). `.claude/`, `_build/`, `deps/`, `doc/`,
  `node_modules/`, and `example/`'s build output are intentionally untracked —
  fine. If there are **other** uncommitted changes outside the four manifest files
  (`CHANGELOG.md`, `README.md`, `mix.exs`, `package.json`), list them and ask
  whether they belong in this release commit before continuing. On a feature
  branch it's normal for the release's own feature code to be uncommitted — in
  that case confirm the commit **scope** (library-only vs. including `example/`)
  rather than blocking.
- **Verify the version isn't already published — on EITHER registry:**
  - Hex: `cd keen_phoenix_svelte && mix hex.info keen_phoenix_svelte <NEW_VERSION> 2>/dev/null` — a "Released at …" line means it's taken. **Stop.**
  - npm: `npm view @keenmate/phoenix_svelte@<NPM_NEW_VERSION> version 2>/dev/null` — if it echoes the version, it's taken. **Stop.**
  - If it's taken on one but not the other (a half-published prior release), point that out — the untaken half can still go, but the versions must stay in lockstep, so confirm the plan with the user.
- **Verify neither registry has drifted past you:** `mix hex.info keen_phoenix_svelte` (read `Releases:`) and `npm view @keenmate/phoenix_svelte version`. If either is higher than `NEW_VERSION`, warn and ask. (First-ever npm publish: `npm view` errors E404 — expected, proceed.)
- Confirm the WIP CHANGELOG section has ≥1 substantive bullet under `### Added`,
  `### Changed`, `### Removed`, `### Fixed`, or `### Internal`. If empty, stop.
- Confirm `README.md` has a `## What's New in vWIP_VERSION` section. If missing,
  draft one from the WIP CHANGELOG (5–8 canonical bullets, paraphrased — not
  verbatim), present it as plain markdown, and only insert it (directly above the
  current top `## What's New` heading) once the user approves or supplies their
  own. Don't silently insert — the voice is theirs.
- **Scan the shipped source for debug leftovers.** Grep `assets/js/` for
  `console.log`, `debugger`, and temporary markers — these ride along in **both**
  tarballs. If found, remove them (they are never part of a release).

### 2. Bump BOTH versions (if needed) [canonical + lockstep]

If `NEW_VERSION` (canonical dotted) ≠ `CURRENT_VERSION`, edit `mix.exs`:
`@version "…"` → `@version "NEW_VERSION"` (dotted).

**Always** ensure `package.json` `"version"` reads the **npm-rendered**
`NEW_VERSION` (dotted rc → zero-padded: `1.0.0-rc.2` → `1.0.0-rc02`; a final
release is written identically). Bump it even on the `rc` no-op path if it had
drifted. Both manifests must reflect `NEW_VERSION` (each in its own style) before
you commit.

### 3. Finalize CHANGELOG [canonical]

- If `WIP_VERSION` ≠ `NEW_VERSION` (or the WIP heading is `[Unreleased]`), rename
  the heading to `## [NEW_VERSION] - <today>`.
- If equal, keep the version but refresh the date to today if stale.
- In either case, **append ` [PUBLISHED]`** → `## [NEW_VERSION] - YYYY-MM-DD [PUBLISHED]`.
- Update the reference-style link at the bottom (e.g. `[Unreleased]: …compare…` →
  `[NEW_VERSION]: …/releases/tag/vNEW_VERSION`) if the file uses them.
- Leave bullet content untouched. Do **not** create an empty new WIP section.

### 4. Update README "What's New" [canonical]

Each bullet is `- **<area> — <headline>** — <engineer-level prose>` (bold lead
phrase, a true em-dash ` — `, then prose; no `### ` sub-headings). If the WIP
section is tagged for `WIP_VERSION` and that differs from `NEW_VERSION`, rename its
heading to `## What's New in vNEW_VERSION`. Then keep only the **two most recent**
`## What's New` sections; delete older ones.

### 5. Validate README reflects the release [canonical]

Every user-facing **Added**/**Changed** CHANGELOG bullet should have a paraphrased
hit in the current What's New section. Add missing ones; condense if it exceeds ~8
bullets. Pure internal refactors and `Fixed`-only entries don't need coverage
(headline bug fixes worth advertising do).

### 6. Validate CHANGELOG entries match recent work [canonical, git-only]

If git-initialized: find the previous `[PUBLISHED]` version's bump commit (subject
usually starts `v<previous-version>`), run `git log --oneline <prev>..HEAD`, and
confirm every substantive commit is reflected in the WIP CHANGELOG section. If
something significant is missing, **stop and ask** — don't invent entries.

### 7. Run tests [per-repo]

Run `make test` **from the repo root**. All tests must pass. If anything fails,
**stop and report** — do not proceed to build/commit.

### 8. Build + verify — HEX side [hex]

From `keen_phoenix_svelte/`, run `mix compile --warnings-as-errors && mix docs`.
The compile step turns any deprecation / unused-var / attribute-typo warning into
a hard stop. `mix docs` (ex_doc) generates `./doc/` and verifies the moduledocs +
`docs/*.md` guides parse. Smoke check: `doc/index.html` exists. If either errors,
stop and report. (The npm side has no build — see the note near the top.)

### 9. Verify BOTH tarballs [hex + npm]

**Hex** — from `keen_phoenix_svelte/`, run `mix hex.build`, then unwrap and list
(the outer `.tar` wraps `contents.tar.gz`):

```
tar -xOf keen_phoenix_svelte-<NEW_VERSION>.tar contents.tar.gz | tar -tzf - | sort
```

MUST include: `lib/` (all `.ex`), `assets/` (js + vite), `docs/` (guides),
`package.json`, `mix.exs`, `README.md`, `CHANGELOG.md`, `.formatter.exs`, and
`LICENSE` if present. MUST NOT include: `test/`, `_build/`, `deps/`, `doc/` (the
ex_doc *output* — distinct from `docs/` the *guides*, which ship), editor metadata,
`example/`, `node_modules/`, `*.tar`. The `:files` key in `mix.exs`'s `package/0`
is the control surface. Delete the tarball afterward: `rm keen_phoenix_svelte-<NEW_VERSION>.tar`.

**npm** — from `keen_phoenix_svelte/`, run `npm pack --dry-run`.

MUST include: `assets/` (the entire published payload — `assets/js/keen_phoenix_svelte/*`
and `assets/vite/config.js`), `package.json`, `README.md`, and `LICENSE` if
present (npm always includes package.json/README/LICENSE). MUST NOT include:
`lib/`, `mix.exs`, `mix.lock`, `.formatter.exs`, `CHANGELOG.md`, `docs/`, `doc/`,
`_build/`, `deps/`, `node_modules/`, `test/`, `example/`. The `"files": ["assets"]`
allowlist is the control surface. Sanity-check that the `main`/`module`/`exports`
targets actually appear in the npm file list — a package whose entry points 404 is
worse than a failed pack.

> The two tarballs ship **different file sets** (Hex ships `lib/`+`docs/`+manifests;
> npm ships only `assets/`+`package.json`+`README`). That's expected — the shared
> payload is `assets/`. Verify both.

### 10. Commit [canonical + lockstep]

Stage the four shared manifest files (always):

- `keen_phoenix_svelte/CHANGELOG.md`
- `keen_phoenix_svelte/README.md`
- `keen_phoenix_svelte/mix.exs`
- `keen_phoenix_svelte/package.json`

If step 1 established that the release's own feature code is uncommitted and the
user approved a wider scope, also stage that (e.g. `git add keen_phoenix_svelte/`
for a library-only release commit). Never stage `_build/`, `deps/`, `doc/`,
`node_modules/`, or the `mix hex.build` / `npm pack` tarballs.

Commit message format:

```
vNEW_VERSION - <one-line summary of the headline change>

<grouped bullets paraphrased from the CHANGELOG section — Added, Fixed, Changed,
Internal, etc. Terse; full prose lives in the CHANGELOG.>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

### 11. Report — BOTH publish commands [canonical-adapted]

Report back with:

- `NEW_VERSION` (confirm `mix.exs` reads the dotted form and `package.json` the
  npm form).
- The commit SHA (or a note that the repo isn't git-initialized), and the commit
  scope.
- **Both** exact publish commands, run from `keen_phoenix_svelte/`:

  ```
  cd keen_phoenix_svelte

  # Hex (prompts twice; publishes package + docs together)
  mix hex.user auth        # if not already authenticated on this machine
  mix hex.publish

  # npm
  npm login                # if not already logged in
  npm publish --tag rc     # for an rc — omit --tag for release/patch/minor/major
  ```

  - **Hex has no dist-tags** — an rc version is just a regular published version;
    consumers on `~> 1.0` skip pre-releases and opt into an rc by pinning it.
  - **npm `--tag rc` is critical for pre-releases** — without it npm assigns
    `latest`, making the rc the default install for everyone. With `--tag rc`,
    `latest` stays put and consumers opt in via `@rc` or an exact pin. For a
    stable release (`release`/`patch`/`minor`/`major`), omit `--tag` so it lands
    as `latest`. **First-ever npm publish:** add `--access public` (scoped package
    would otherwise be created private).

- **Revert windows differ:**
  - Hex: within **1 hour**, `mix hex.publish --revert <NEW_VERSION>`. After that
    the version is burned.
  - npm: `npm unpublish` is only allowed within **72 hours** and is discouraged;
    treat the version as burned once published.
  - If **either** publish fails, revert both manifests (`mix.exs` + `package.json`)
    and the CHANGELOG `[PUBLISHED]` tag before retrying — both registries refuse to
    re-publish the same version.
- If one half published but the other failed, the release is **half-shipped and
  drifted**. Do **not** bump to hide it — use `/publish-hex` or `/publish-npm`
  (fast path) to complete the *same* version on the failed registry.
- Note any **missing LICENSE** as a follow-up (npm warns on it) — skip if a
  LICENSE is present in the tarballs.

## Things not to do [canonical-adapted]

- **Do not run `mix hex.publish` or `npm publish`.** The user publishes manually.
- **Do not push to git remote.** The commit stays local.
- **Do not let the two manifests drift** — bump `mix.exs` and `package.json` to
  the same `NEW_VERSION` in the same commit, always.
- **Do not create an empty `[Unreleased]`/new WIP heading** after finalizing.
- **Do not retro-fix older CHANGELOG sections.**
- **Do not skip the compile gate** (`mix compile --warnings-as-errors`) or `make test`.
- **Do not ship debug code** — grep `assets/js/` for `console.log`/`debugger` in step 1.
- **Do not invent CHANGELOG entries** — ask if something's missing.
- **Do not bump if there's nothing meaningful in the WIP section** — stop and explain.

### Repo-specific don'ts

- **Do not stage `example/`, `_build/`, `deps/`, `doc/`, `node_modules/`, or the pack/build tarballs.**
- **Do not run mix/npm commands from the repo root** — they live in `keen_phoenix_svelte/`. The `make test` gate is the exception; it runs from root.
