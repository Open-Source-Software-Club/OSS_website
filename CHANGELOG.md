# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Nothing has been released yet: there are no tags and no published releases.
Release Drafter (`.github/workflows/release-drafter.yml`) keeps a draft of the
next release's notes up to date from merged pull-request titles; when the first
version is tagged, its section is cut from **Unreleased** below.

The website itself has not landed yet. Everything listed here is the
repository's contribution pipeline, which is built first so that the first
application pull request is already reviewed, tested and scanned.

---

## [Unreleased]

### Added
- **Branch protection rulesets**, split into four files under
  `.github/branch-protection/rulesets/` and applied by one script:
  `Protect main` (the merge gate), `Protect release branches`
  (`release/**`, `hotfix/**`, `support/**` — no force-push, no deletion,
  reviewed PRs), `Protect release tags` (immutable `v*` tags with semver-only
  names) and `Branch naming` (`<type>/<description>`). The former single
  `ruleset.json` is now `rulesets/protect-main.json`; `apply.sh` gained `--list`
  and `--file`.
- `optional/require-signed-commits.json`: the commit-signing rule, kept out of
  the default set because it would block a first-time contributor.
- `scripts/checks/check-rulesets.sh`: validates every ruleset payload against
  the rules GitHub accepts and fails the build when a required status check
  names a job no workflow emits.
- `Workflow Security` (`workflow-security.yml`): a pinned `zizmor` audit of the
  pipeline itself — template injection, `pull_request_target` misuse, leaked
  checkout credentials and unpinned actions.
- `Scorecard` (`scorecard.yml`): OpenSSF supply-chain posture published as SARIF
  to the Security tab.
- `Release Drafter` (`release-drafter.yml`): release notes assembled from the
  Conventional Commit titles that `PR Conventions` enforces.
- `Deployment Smoke Test` (`smoke.yml`): verifies that the URL Vercel published
  actually renders, and reports the deployment's security headers.
- `scripts/checks/check-docs.sh`: documentation integrity — required documents
  exist, every relative link resolves, exactly one H1 per document.
- Shell linting of the pipeline itself (`bash -n` + `shellcheck`) in
  `Repository Hygiene`.
- `PR Conventions` (`pr-conventions.yml`): its own workflow, re-run when a
  pull request's title, description or labels change, so fixing a title no
  longer needs a new commit (#59).

### Changed
- Every action is pinned to a full commit SHA with its release in a trailing
  comment, and `Workflow Security` enforces it; pnpm is installed by
  `pnpm/action-setup`, versioned by `package.json`'s `packageManager` (#59).
- The repository gate (`scripts/checks/`) runs a fixed handful of processes for
  the whole tree instead of a dozen per file: 63 s → 4 s per `git push` on Git
  for Windows (#59).
- GitHub's **Revert** button (`revert-<n>-<branch>`, `Revert "<title>"`) is
  accepted by the branch, commit and title checks (#59).

### Fixed
- `Secret Scan` read 12 of 75 tracked files on the CI runners: binary detection
  compared a character count with a byte count, so under `C.UTF-8` every file
  containing a non-ASCII character was skipped (#59).
- Dependabot never ran: `commit-message.prefix-separator` is not a Dependabot
  option, and an unknown key rejects the whole configuration (#59). The
  `/supabase` Docker block, which failed on every run, was removed (#61).
- CRLF line endings were never detected on Windows, where GNU grep strips `\r`
  unless given `-U` (#59).
- `stale.yml` would have closed every issue after 67 days, and could delete a
  branch that had commits after its pull request was merged (#59).
- `protect-main.yml` ran `git` commands without ever cloning the repository,
  interpolated the commit subject into a `github-script` body, and now neither
  raises a false incident for a new repository's first commit nor ignores an
  orphan history pushed over `main` (#61).
- `pr-automation.yml` checked out the pull-request *head* inside a
  `pull_request_target` workflow, giving fork code a write token; it now checks
  out nothing at all (#59).
- `labels-sync.yml` invoked a `label-sync` CLI that does not exist, and synced
  labels from any pushed branch rather than only from `main` (#59).
- `Verify` treated a *failing* `type-check` the same as a missing one and went
  green; the script that exists is now resolved before it runs.
- Six documents linked to `./ARCHITECTURE.md` (the file is
  `docs/architecture.md`), and the pull-request template linked to a
  `CONTRIBUTING.md` that resolves relative to `.github/`.

[Unreleased]: https://github.com/Open-Source-Software-Club/OSS_website/commits/main
