---
description: Prepare @keenmate/phoenix_svelte for npm publish — bump BOTH versions (lockstep), finalize CHANGELOG/README, test, commit
argument-hint: rc|release|patch|minor|major
---

# /publish-npm — prepare an npm release of @keenmate/phoenix_svelte

You are preparing the **npm** side of this dual package for `npm publish`.
**Do not run `npm publish`** — the user logs in and publishes manually.

This is a **dual package**: one npm package (`@keenmate/phoenix_svelte`) and one
Hex library (`keen_phoenix_svelte`), both living in `./keen_phoenix_svelte/` and
kept in **lockstep** — the same version string, the same `CHANGELOG.md`, the same
`README.md`. This command owns the shared version/changelog work **and** the npm
publish. Its sibling `/publish-hex` owns the Hex publish. Whichever you run first
does the version bump + changelog finalize; the other detects the already-finalized
state and jumps straight to its publish step (see "Fast path" below).

This command follows the canonical `/publish` structure (from the BlissFramework
component guidelines). Sections marked **[canonical]** are the shared release
ritual; **[per-repo]** sections are customized for this dual-package layout.

## Working directory [per-repo]

The npm package is `./keen_phoenix_svelte/` (that's where `package.json` lives),
**not** the repo root. Run all `npm` commands from there (`cd keen_phoenix_svelte`).
The **test gate is `make test` from the repo root** (it does `cd example && mix
test`) — the JS package itself has no test suite of its own.

## No build step [per-repo]

`@keenmate/phoenix_svelte` **ships raw source** — `package.json` has `"files":
["assets"]`, `main`/`module`/`exports` point straight at `assets/js/...` and
`assets/vite/config.js`, and there is **no `scripts` block, no `dist/`, no bundler
step.** So there is nothing to build: `npm pack --dry-run` inspects the exact files
as they are on disk. Do not look for a `npm run build`.

## Lockstep coupling [per-repo] — read this first

The npm package and the Hex library **always share one version**. This command
therefore bumps **both** manifests together:

- `keen_phoenix_svelte/package.json` — `"version": "X.Y.Z"` (npm source of truth)
- `keen_phoenix_svelte/mix.exs` — `@version "X.Y.Z"` (Hex source of truth)

and finalizes the **shared** `keen_phoenix_svelte/CHANGELOG.md` and
`keen_phoenix_svelte/README.md`. The commit stages all four files. This keeps the
two ecosystems from drifting no matter which publish command runs first.

**rc format — per-ecosystem styles [important].** The two packages carry the
*same semantic version* but render the rc suffix in each ecosystem's own idiom:

| Surface | Style | Example |
|---|---|---|
| **npm** — `package.json` **only** | zero-padded, no dot | `1.0.0-rc01` |
| **Hex** — `mix.exs`, and the **canonical** form used in CHANGELOG / git tag / commit subject / What's New heading | dotted | `1.0.0-rc.1` |

The **canonical (dotted) form is authoritative.** Derive the npm form by replacing
`-rc.N` with `-rc` + `N` zero-padded to two digits (`rc.1`→`rc01`, `rc.12`→`rc12`).
Two version strings that normalize to the same `(major, minor, patch, rc-number)`
are **the same release** — that is what "lockstep" means here, *not* byte-identical
strings. A final (non-rc) release like `1.0.0` is identical in both manifests.

**Watch out:** the npm registry only knows the npm-rendered string — query it with
`1.0.0-rc01`, never the dotted `1.0.0-rc.1`.

## Argument [canonical]

The release type: **$ARGUMENTS**

Must be one of:

- `rc` — ship the WIP rc as-is. The topmost CHANGELOG heading gets ` [PUBLISHED]` appended, and npm is published under the `rc` dist-tag (see step 11).
- `release` — promote a WIP rc to a final release. `X.Y.Z-rc.N` → `X.Y.Z`. CHANGELOG heading renamed to match.
- `patch` — SemVer patch bump. Drops any `-rc.N` suffix.
- `minor` — SemVer minor bump. Drops `-rc.N`. Resets patch.
- `major` — SemVer major bump. Drops `-rc.N`. Resets minor and patch.

If missing or invalid, stop and ask the user which one to use (don't guess).

## Repo layout [per-repo]

Dual package under `./keen_phoenix_svelte/`:

- **`package.json`** — `version`; npm source of truth. `"files": ["assets"]` controls the published tarball (plus npm always adds `package.json` + `README.md` + a `LICENSE` if present).
- **`mix.exs`** — `@version`; Hex source of truth. Bumped in lockstep here.
- **`CHANGELOG.md`** — shared. Topmost `## [X.Y.Z] - YYYY-MM-DD` heading **without** `[PUBLISHED]` is the WIP section.
- **`README.md`** — shared. May carry `## What's New in vX.Y.Z` sections near the top (optional — this repo has not adopted them yet; see step 5).
- **`assets/`** — the published payload (hook, AppsManager, runtime, channel, vite helper). Raw source, no build.
- **`node_modules/`** — gitignored, never staged, never published (`files` allowlist excludes it).

> **No LICENSE file** exists yet, and neither manifest lists one, though both
> declare MIT. Not a publish blocker, but npm will warn "no license field / file"
> — mention it in the final report as a follow-up.

## Git note [per-repo]

The repo may not be git-initialized yet. If `git rev-parse --is-inside-work-tree`
fails, **skip** the git-dependent steps (1's `git status`, step 6, and the commit
in step 10) and tell the user the files are updated but uncommitted because
there's no git repo — they decide whether to `git init` first.

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

Read `version` from `keen_phoenix_svelte/package.json` as `CURRENT_VERSION`
(npm-rendered form). Read `@version` from `keen_phoenix_svelte/mix.exs` as
`HEX_VERSION` (canonical dotted form).

- Compare them by **normalizing** to `(major, minor, patch, rc-number)`, not by raw
  string — `1.0.0-rc01` (package.json) and `1.0.0-rc.1` (mix.exs) are the *same*
  release, not drift. Only if they normalize to **different** releases have the
  packages drifted: warn the user, show both, treat `mix.exs` (canonical) as
  authoritative unless they say otherwise, and resync both in step 2.

Read the topmost `## [X.Y.Z...]` heading from `CHANGELOG.md` as `WIP_VERSION`
(canonical dotted form). Track `NEW_VERSION` in canonical dotted form throughout;
render the npm form only when writing `package.json` (step 2) and when querying the
npm registry (step 1).

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
[PUBLISHED]` (canonical dotted) **and** `package.json` reads the npm-rendered
`NEW_VERSION` **and** `mix.exs` reads canonical `NEW_VERSION`, then `/publish-hex`
(or a prior run) already did the version + changelog work.
**Skip steps 2–4 and 6, and skip the commit in step 10.** Still run the gate —
tests (7) — and the pack inspection (9), then report the `npm publish` command.
Note in the report that you took the fast path because the release was already
finalized.

## Steps (in order)

### 1. Sanity checks [canonical]

- Run `git status` (if git-initialized). If there are uncommitted changes outside
  `CHANGELOG.md`, `README.md`, `mix.exs`, and `package.json`, list them and ask
  before continuing.
- **Verify the version isn't already on npm.** Run
  `npm view @keenmate/phoenix_svelte@<NPM_NEW_VERSION> version 2>/dev/null` using
  the **npm-rendered** form (e.g. `1.0.0-rc01`, not `1.0.0-rc.1`) — if it echoes
  the version, that version is already published: **stop** (re-publishing the same
  version fails and pollutes the commit).
- **Verify the registry hasn't drifted past you.** Run
  `npm view @keenmate/phoenix_svelte version` (latest on the `latest` tag). If
  it's higher than `NEW_VERSION`, warn and ask before continuing. (First-ever
  publish: `npm view` errors with E404 — that's expected, proceed.)
- Confirm the WIP CHANGELOG section has ≥1 substantive bullet under `### Added`,
  `### Changed`, `### Removed`, `### Fixed`, or `### Internal`. If empty, stop.
- Confirm `keen_phoenix_svelte/README.md` has a `## What's New in vWIP_VERSION`
  section. If missing, draft one from the WIP CHANGELOG (5–8 canonical bullets,
  paraphrased — not copied verbatim), present it to the user as plain markdown,
  and only insert it (directly above the current top `## What's New` heading) once
  they approve or supply their own. Don't silently insert — the voice is theirs.

### 2. Bump BOTH versions (if needed) [canonical + lockstep]

If `NEW_VERSION` (canonical dotted) ≠ `CURRENT_VERSION`, edit
`keen_phoenix_svelte/package.json`: `"version"` → the **npm-rendered**
`NEW_VERSION` (dotted rc → zero-padded, `1.0.0-rc.1` → `1.0.0-rc01`; a final
release like `1.0.0` is written identically).

**Always** ensure `keen_phoenix_svelte/mix.exs` `@version` reads the **canonical
dotted** `NEW_VERSION` too (bump it even on the `rc` no-op path if it had drifted).
Both manifests must reflect `NEW_VERSION` (each in its own style) before you commit.

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

If git-initialized: find the previous `[PUBLISHED]` version's bump commit, run
`git log --oneline <prev-commit>..HEAD`, and confirm every substantive commit is
reflected in the WIP CHANGELOG section. If something significant is missing,
**stop and ask** — don't invent entries. Skip if no git.

### 7. Run tests [per-repo]

Run `make test` **from the repo root** (`cd example && mix test`). This is the
only automated gate — the npm package has no test suite of its own; its assets are
exercised through the example Phoenix app. All tests must pass. If anything fails,
**stop and report** — do not proceed to pack/commit.

### 8. Build the package [per-repo] — N/A

There is **no build**. `@keenmate/phoenix_svelte` ships raw `assets/` source (no
`dist/`, no bundler, no `scripts`). Skip straight to step 9.

### 9. Verify the package contents [per-repo]

From `keen_phoenix_svelte/`, run `npm pack --dry-run` and confirm the file list:

MUST include:

- `assets/` — the entire published payload: `assets/js/keen_phoenix_svelte/*` (hook, AppsManager, runtime, channel, `index.js`) and `assets/vite/config.js` (the `./vite` export target).
- `package.json` (npm always includes it).
- `README.md` (npm always includes it).

MUST NOT include:

- `lib/`, `mix.exs`, `mix.lock`, `.formatter.exs` (Elixir side — not part of the npm package).
- `CHANGELOG.md`, `docs/`, `_build/`, `deps/`, `doc/`, `node_modules/`, `test/`, `example/`.

The `"files": ["assets"]` allowlist in `package.json` is the control surface — if
anything Elixir-side or private leaked in, or an `assets/` file is missing, fix
`files` (or the paths in `main`/`module`/`exports`) before publishing. Also
sanity-check that the `main`/`module`/`exports` targets actually appear in the
file list — a published package whose entry points 404 is worse than a failed pack.

### 10. Commit [canonical + lockstep]

Stage (all four — this is the lockstep commit):

- `keen_phoenix_svelte/CHANGELOG.md`
- `keen_phoenix_svelte/README.md`
- `keen_phoenix_svelte/mix.exs`
- `keen_phoenix_svelte/package.json`

Commit message format:

```
vNEW_VERSION - <one-line summary of the headline change>

<grouped bullets paraphrased from the CHANGELOG section — Added, Fixed, Changed,
Internal, etc. Terse; full prose lives in the CHANGELOG.>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

### 11. Report [canonical]

Report back with:

- The new version number (confirm both `package.json` and `mix.exs` read it).
- The commit SHA (or a note that the repo isn't git-initialized).
- The exact publish command, run from `keen_phoenix_svelte/`. **Pick the right one
  for the arg type:**

  - For `rc` (publishing a pre-release):
    ```
    cd keen_phoenix_svelte
    npm login          # if not already logged in
    npm publish --tag rc
    ```
    The `--tag rc` is critical — without it npm assigns the `latest` dist-tag,
    making the pre-release the default install for everyone running
    `npm install @keenmate/phoenix_svelte`. With `--tag rc`, `latest` stays put
    and consumers opt in via `@rc` or an exact pin. (Scoped package: if this is
    the **first** publish, add `--access public` so the scoped package isn't
    created private.)

  - For `release` / `patch` / `minor` / `major` (publishing a stable release):
    ```
    cd keen_phoenix_svelte
    npm login          # if not already logged in
    npm publish        # add --access public on the very first publish
    ```
    No `--tag` — it lands as `latest`.

- A reminder that the CHANGELOG `[PUBLISHED]` tag is now in place — if `npm
  publish` fails, revert both manifests (`package.json` + `mix.exs`) and the
  CHANGELOG heading tag before retrying, since npm refuses to re-publish the same
  version.
- **Reminder to publish Hex too** — this was the npm half. Run `/publish-hex rc`
  (or matching arg) to ship `keen_phoenix_svelte` at the same version; it will
  take the fast path since the changelog + versions are already finalized.
- Note the **missing LICENSE file** as a follow-up (npm warns on it; both packages
  declare MIT but ship no LICENSE).

## Things not to do [canonical]

- **Do not run `npm publish`.** The user publishes manually after `npm login`.
- **Do not push to git remote.** The commit stays local.
- **Do not let the two manifests drift** — always bump `package.json` and
  `mix.exs` to the same `NEW_VERSION` in the same commit.
- **Do not create an empty `[Unreleased]`/new WIP heading** after finalizing.
- **Do not retro-fix older CHANGELOG sections.**
- **Do not skip the test gate** (`make test`) — it's the only automated gate here.
- **Do not go looking for a build step** — there isn't one; the package ships source.
- **Do not invent CHANGELOG entries** — ask the user if something's missing.
- **Do not bump if there's nothing meaningful in the WIP section** — stop and explain.
- **Do not adopt the What's New convention mid-release** if the README doesn't use it.

### Repo-specific don'ts

- **Do not run npm commands from the repo root** — `package.json` is in
  `keen_phoenix_svelte/`. The test gate (`make test`) is the exception; it runs
  from root.
- **Do not let Elixir-side files (`lib/`, `mix.exs`, `docs/`) leak into the npm
  tarball** — the `"files": ["assets"]` allowlist prevents this; verify it in step 9.
