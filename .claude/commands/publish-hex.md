---
description: Prepare keen_phoenix_svelte for Hex publish — bump BOTH versions (lockstep), finalize CHANGELOG/README, compile, test, commit
argument-hint: rc|release|patch|minor|major
---

# /publish-hex — prepare a Hex release of keen_phoenix_svelte

You are preparing the **Hex** side of this dual package for `mix hex.publish`.
**Do not run `mix hex.publish`** — the user authenticates and publishes manually.

This is a **dual package**: one Hex library (`keen_phoenix_svelte`) and one npm
package (`@keenmate/phoenix_svelte`), both living in `./keen_phoenix_svelte/` and
kept in **lockstep** — the same version string, the same `CHANGELOG.md`, the same
`README.md`. This command owns the shared version/changelog work **and** the Hex
publish. Its sibling `/publish-npm` owns the npm publish. Whichever you run first
does the version bump + changelog finalize; the other detects the already-finalized
state and jumps straight to its publish step (see "Fast path" below).

This command adapts the canonical `/publish` structure (from the BlissFramework
component guidelines) to an Elixir / Hex package. Sections marked **[canonical]**
are the shared release ritual; **[per-repo]** sections are customized for this
dual-package layout.

## npm → Hex substitution map

| npm concept (canonical text) | Hex equivalent (this repo) |
|---|---|
| `package.json` `version` | `@version` attribute in `keen_phoenix_svelte/mix.exs` |
| `npm view <pkg>@<v> version` | `mix hex.info keen_phoenix_svelte <v>` (prints "Released at …" if it exists) |
| `npm view <pkg> version` | `mix hex.info keen_phoenix_svelte` (prints `Releases: <latest>, …`) |
| `npm run build` | `mix compile --warnings-as-errors && mix docs` |
| `npm run test:e2e` | `make test` (root — runs `mix test` in `example/`) |
| `npm pack --dry-run` | `mix hex.build` (writes `keen_phoenix_svelte-<v>.tar`; inspect with `tar -tzf <file> \| sort`) |
| `npm publish` | `mix hex.publish` (Hex has **no** dist-tags — see Section 11) |
| `files` field in `package.json` | `:files` list in `package/0` inside `mix.exs` |

## Working directory [per-repo]

Both manifests live in `./keen_phoenix_svelte/`, **not** the repo root. Run all
`mix` commands from there (`cd keen_phoenix_svelte`). The **test gate is `make
test` from the repo root** (it does `cd example && mix test`).

## Lockstep coupling [per-repo] — read this first

The Hex library and the npm package **always share one version**. This command
therefore bumps **both** manifests together:

- `keen_phoenix_svelte/mix.exs` — `@version "X.Y.Z"` (Hex source of truth)
- `keen_phoenix_svelte/package.json` — `"version": "X.Y.Z"` (npm source of truth)

and finalizes the **shared** `keen_phoenix_svelte/CHANGELOG.md` and
`keen_phoenix_svelte/README.md`. The commit stages all four files. This keeps the
two ecosystems from drifting no matter which publish command runs first.

**rc format — per-ecosystem styles [important].** The two packages carry the
*same semantic version* but render the rc suffix in each ecosystem's own idiom:

| Surface | Style | Example |
|---|---|---|
| **Hex** — `mix.exs`, and the **canonical** form used in CHANGELOG / git tag / commit subject / What's New heading | dotted | `1.0.0-rc.1` |
| **npm** — `package.json` **only** | zero-padded, no dot | `1.0.0-rc01` |

The **canonical (dotted) form is authoritative.** Derive the npm form by replacing
`-rc.N` with `-rc` + `N` zero-padded to two digits (`rc.1`→`rc01`, `rc.12`→`rc12`).
Two version strings that normalize to the same `(major, minor, patch, rc-number)`
are **the same release** — that is what "lockstep" means here, *not* byte-identical
strings. A final (non-rc) release like `1.0.0` is identical in both manifests.

## Argument [canonical]

The release type: **$ARGUMENTS**

Must be one of:

- `rc` — ship the WIP rc as-is. The topmost CHANGELOG heading (e.g. `## [0.2.0-rc.0] - 2026-07-19`) gets ` [PUBLISHED]` appended.
- `release` — promote a WIP rc to a final release. `X.Y.Z-rc.N` → `X.Y.Z`. CHANGELOG heading is renamed to match.
- `patch` — SemVer patch bump. Drops any `-rc.N` suffix.
- `minor` — SemVer minor bump. Drops `-rc.N`. Resets patch.
- `major` — SemVer major bump. Drops `-rc.N`. Resets minor and patch.

If missing or invalid, stop and ask the user which one to use (don't guess).

## Repo layout [per-repo]

Dual package under `./keen_phoenix_svelte/`:

- **`mix.exs`** — `@version` attribute; Hex source of truth. `:files` in `package/0` controls the tarball.
- **`package.json`** — `version`; npm source of truth. Bumped in lockstep here.
- **`CHANGELOG.md`** — shared. Topmost `## [X.Y.Z] - YYYY-MM-DD` heading **without** `[PUBLISHED]` is the WIP section.
- **`README.md`** — shared. May carry `## What's New in vX.Y.Z` sections near the top (optional — this repo has not adopted them yet; see step 5).
- **`lib/`** — Elixir sources. Always shipped.
- **`assets/`, `docs/`** — shipped via `:files` (the JS the npm package publishes + the ex_doc guides).
- **`_build/`, `deps/`, `doc/`** — gitignored. Never staged.
- **`mix.lock`** — tracked. Don't touch during publish unless deps changed intentionally.

> **No LICENSE file** exists yet, and neither manifest lists one, though both declare
> MIT. Not a publish blocker — but mention it in the final report as a follow-up.

## Git note [per-repo]

The repo may not be git-initialized yet. If `git rev-parse --is-inside-work-tree`
fails, **skip** the git-dependent steps (1's `git status`, step 6, and the commit
in step 10) and tell the user the files are staged-in-spirit but uncommitted
because there's no git repo — they decide whether to `git init` first.

## CHANGELOG convention [canonical]

No `## [Unreleased]` section. The WIP section is the topmost `## [X.Y.Z] -
YYYY-MM-DD` heading without a `[PUBLISHED]` tag. Released sections carry
`[PUBLISHED]`:

```
## [0.2.0-rc.0] - 2026-07-19                  ← WIP, the one you're shipping
### Added
- ...

## [0.1.0] - 2026-07-19 [PUBLISHED]
### Added
- ...
```

Publishing means **appending ` [PUBLISHED]`** to the WIP heading — exact format
`## [X.Y.Z] - YYYY-MM-DD [PUBLISHED]`. The next dev cycle creates a fresh heading.

## Resolve versions [canonical + lockstep]

Read `@version` from `keen_phoenix_svelte/mix.exs` as `CURRENT_VERSION` (canonical
dotted form).
Read `version` from `keen_phoenix_svelte/package.json` as `NPM_VERSION`.

- Compare them by **normalizing** to `(major, minor, patch, rc-number)`, not by raw
  string — `1.0.0-rc.1` (mix.exs) and `1.0.0-rc01` (package.json) are the *same*
  release, not drift. Only if they normalize to **different** releases have the
  packages drifted: warn the user, show both, treat `mix.exs` (canonical) as
  authoritative unless they say otherwise, and resync both in step 2.

Read the topmost `## [X.Y.Z...]` heading from `CHANGELOG.md` as `WIP_VERSION`
(canonical dotted form). Track `NEW_VERSION` in canonical dotted form throughout;
render the npm form only when writing `package.json` in step 2.

Compute `NEW_VERSION`:

| Argument | Logic |
|---|---|
| `rc` | If `CURRENT_VERSION` matches `X.Y.Z-rc.N`, `NEW_VERSION = CURRENT_VERSION` (no bump). If not an rc, stop and ask (they probably wanted `release`/`patch`/etc.). |
| `release` | If `CURRENT_VERSION` matches `X.Y.Z-rc.N`, `NEW_VERSION = X.Y.Z`. Otherwise stop. |
| `patch` | Strip any `-rc.N`, then bump patch. |
| `minor` | Strip any `-rc.N`, then bump minor, reset patch. |
| `major` | Strip any `-rc.N`, then bump major, reset minor and patch. |

If `WIP_VERSION` ≠ `NEW_VERSION`, the step-3 heading rename also re-tags the
section to `NEW_VERSION` — call this out in the report.

## Fast path — sibling already finalized this release [per-repo]

If the topmost CHANGELOG heading is **already** `## [NEW_VERSION] - <date>
[PUBLISHED]` (canonical dotted) **and** `mix.exs` reads canonical `NEW_VERSION`
**and** `package.json` reads the npm-rendered `NEW_VERSION`, then `/publish-npm`
(or a prior run) already did the version + changelog work.
**Skip steps 2–4 and 6, and skip the commit in step 10** (there's nothing to
change). Still run the gates — tests (7), compile + docs (8), and the tarball
inspection (9) — then report the `mix hex.publish` command. Note in the report
that you took the fast path because the release was already finalized.

## Steps (in order)

### 1. Sanity checks [canonical]

- Run `git status` (if git-initialized). `.claude/`, `_build/`, `deps/`, `doc/`,
  and `example/`'s build output are intentionally untracked — fine. If there are
  **other** uncommitted changes outside `CHANGELOG.md`, `README.md`, `mix.exs`,
  and `package.json`, list them and ask before continuing.
- **Verify the version isn't already on Hex.** Run
  `cd keen_phoenix_svelte && mix hex.info keen_phoenix_svelte <NEW_VERSION> 2>/dev/null`
  — if it prints a "Released at …" line, **stop**: re-publishing fails after the
  one-hour revert window.
- **Verify the registry hasn't drifted past you.** Run
  `mix hex.info keen_phoenix_svelte` and read the `Releases:` line (latest first).
  If it's higher than `NEW_VERSION`, warn and ask before continuing.
- Confirm the WIP CHANGELOG section has ≥1 substantive bullet under `### Added`,
  `### Changed`, `### Removed`, `### Fixed`, or `### Internal`. If empty, stop.
- Confirm `keen_phoenix_svelte/README.md` has a `## What's New in vWIP_VERSION`
  section. If missing, draft one from the WIP CHANGELOG (5–8 canonical bullets,
  paraphrased — not copied verbatim), present it to the user as plain markdown,
  and only insert it (directly above the current top `## What's New` heading) once
  they approve or supply their own. Don't silently insert — the voice is theirs.

### 2. Bump BOTH versions (if needed) [canonical + lockstep]

If `NEW_VERSION` (canonical dotted) ≠ `CURRENT_VERSION`, edit
`keen_phoenix_svelte/mix.exs`: `@version "CURRENT_VERSION"` → `@version
"NEW_VERSION"` (dotted, e.g. `1.0.0-rc.1`).

**Always** ensure `keen_phoenix_svelte/package.json` `"version"` reads the
**npm-rendered** `NEW_VERSION` — dotted rc → zero-padded (`1.0.0-rc.1` →
`1.0.0-rc01`); a final release is written identically (`1.0.0`). Bump it even on
the `rc` no-op path if it had drifted. Both manifests must reflect `NEW_VERSION`
(each in its own style) before you commit.

### 3. Finalize CHANGELOG [canonical]

In `keen_phoenix_svelte/CHANGELOG.md`:

- If `WIP_VERSION` ≠ `NEW_VERSION` (promoting `X.Y.Z-rc.N` → `X.Y.Z`), rename the
  WIP heading to `## [NEW_VERSION] - <today>`.
- If equal, keep the version but refresh the date to today if it's stale.
- In either case, **append ` [PUBLISHED]`** so it reads exactly
  `## [NEW_VERSION] - YYYY-MM-DD [PUBLISHED]`.
- Leave bullet content untouched. Do **not** create an empty new WIP section.

### 4. Update README "What's New" [canonical]

The published README (`keen_phoenix_svelte/README.md`) carries `## What's New in
vX.Y.Z` sections near the top (adopted in v0.1.0). Each bullet is
`- **<area> — <headline>** — <engineer-level prose>` (bold lead phrase, a true
em-dash ` — `, then prose; no `### ` sub-headings). If the WIP section confirmed
in step 1 is tagged for `WIP_VERSION` and that differs from `NEW_VERSION`, rename
its heading to `## What's New in vNEW_VERSION`. Then keep only the **two most
recent** `## What's New` sections; delete older ones.

### 5. Validate README reflects the release [canonical]

Every user-facing **Added**/**Changed** CHANGELOG bullet should have a paraphrased
hit in the current What's New section. Add missing ones; condense if it exceeds ~8
bullets. Pure internal refactors and `Fixed`-only entries don't need coverage
(headline bug fixes worth advertising do).

### 6. Validate CHANGELOG entries match recent work [canonical, git-only]

If git-initialized: find the previous `[PUBLISHED]` version's bump commit
(subject usually starts `v<previous-version>`), run
`git log --oneline <prev-commit>..HEAD`, and confirm every substantive commit is
reflected in the WIP CHANGELOG section. If something significant is missing,
**stop and ask** — don't invent entries. Skip if no git.

### 7. Run tests [per-repo]

Run `make test` **from the repo root** (`cd example && mix test`). All tests must
pass. If anything fails, **stop and report** — do not proceed to compile/commit.

### 8. Compile and build docs [per-repo]

From `keen_phoenix_svelte/`, run `mix compile --warnings-as-errors && mix docs`.
The compile step turns any deprecation / unused-var / attribute-typo warning into
a hard stop. `mix docs` (ex_doc, configured in `mix.exs`'s `docs/0`) then
generates `./doc/` and verifies the `@moduledoc`/`@doc` + the `docs/*.md` guides
parse. Smoke check: `keen_phoenix_svelte/doc/index.html` exists. If the compile
or docs build errors, stop and report.

### 9. Verify the package contents [per-repo]

From `keen_phoenix_svelte/`, run `mix hex.build` then
`tar -tzf keen_phoenix_svelte-<NEW_VERSION>.tar | sort`.

The tarball MUST include (this mirrors `:files` in `mix.exs`):

- `lib/` (all `.ex` sources)
- `assets/` (the bundled JS — hook, AppsManager, runtime, channel, vite helper)
- `docs/` (the ex_doc guides: installation, authoring-apps, server-communication)
- `package.json`
- `mix.exs`
- `README.md`
- `CHANGELOG.md`
- `.formatter.exs`

The tarball MUST NOT include:

- `test/` if present (never ship)
- `_build/`, `deps/`, `doc/` (build artifacts — note: `doc/` the ex_doc *output* is excluded; `docs/` the guides source **is** shipped)
- `.elixir_ls/`, `.idea/`, `.vscode/` (editor metadata)
- `example/` (the demo app — it's a sibling dir, not under the library)
- `node_modules/`, `*.tar`

The `:files` key in `package/0` is the control surface — fix there if wrong.
Delete the inspection tarball afterward: `rm keen_phoenix_svelte-<NEW_VERSION>.tar`.

### 10. Commit [canonical + lockstep]

Stage (all four — this is the lockstep commit):

- `keen_phoenix_svelte/CHANGELOG.md`
- `keen_phoenix_svelte/README.md`
- `keen_phoenix_svelte/mix.exs`
- `keen_phoenix_svelte/package.json`

Do **not** stage `_build/`, `deps/`, `doc/`, or the `mix hex.build` tarball.

Commit message format:

```
vNEW_VERSION - <one-line summary of the headline change>

<grouped bullets paraphrased from the CHANGELOG section — Added, Fixed, Changed,
Internal, etc. Terse; full prose lives in the CHANGELOG.>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

### 11. Report [canonical-adapted]

Report back with:

- The new version number (confirm both `mix.exs` and `package.json` read it).
- The commit SHA (or a note that the repo isn't git-initialized).
- The exact publish command, run from `keen_phoenix_svelte/`:

  ```
  cd keen_phoenix_svelte
  mix hex.user auth     # if not already authenticated on this machine
  mix hex.publish
  ```

  `mix hex.publish` prompts twice — once to confirm package contents + version,
  once to confirm the publish. It builds and publishes both the package and the
  hex docs in one step.

- **Hex has no dist-tags** — an rc version (`0.2.0-rc.0`) is just a regular
  published version. A consumer's `{:keen_phoenix_svelte, "~> 0.1"}` constraint
  **skips** pre-releases by default; consumers opt into an rc by pinning it
  exactly. So the rc/release distinction is carried by the version string's
  pre-release suffix, not a publish flag.
- The revert window: within **one hour** of publish you can
  `mix hex.publish --revert <NEW_VERSION>`. After that the version is burned —
  bump and re-publish. Before the publish goes through, revert both manifests and
  the CHANGELOG `[PUBLISHED]` tag if you change your mind.
- **Reminder to publish npm too** — this was the Hex half. Run `/publish-npm rc`
  (or matching arg) to ship `@keenmate/phoenix_svelte` at the same version; it
  will take the fast path since the changelog + versions are already finalized.
- Note the **missing LICENSE file** as a follow-up (both packages declare MIT but
  ship no LICENSE).

## Things not to do [canonical-adapted]

- **Do not run `mix hex.publish`.** The user publishes manually after auth.
- **Do not push to git remote.** The commit stays local.
- **Do not let the two manifests drift** — always bump `mix.exs` and
  `package.json` to the same `NEW_VERSION` in the same commit.
- **Do not create an empty `[Unreleased]`/new WIP heading** after finalizing.
- **Do not retro-fix older CHANGELOG sections.**
- **Do not skip the compile gate** (`mix compile --warnings-as-errors`) or `make test`.
- **Do not invent CHANGELOG entries** — ask the user if something's missing.
- **Do not bump if there's nothing meaningful in the WIP section** — stop and explain.
- **Do not adopt the What's New convention mid-release** if the README doesn't use it.

### Repo-specific don'ts

- **Do not stage `example/`, `_build/`, `deps/`, `doc/`, or `keen_phoenix_svelte-*.tar`.**
- **Do not run mix commands from the repo root** — they live in `keen_phoenix_svelte/`.
  The test gate (`make test`) is the exception; it runs from root.
