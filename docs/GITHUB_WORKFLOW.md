# Development Workflow

> §11 of the OSS Club Website PRD
> Related docs: [PRD](./PRD.md) · [ARCHITECTURE](./architecture.md) · [GITHUB_ISSUES](./GITHUB_ISSUES.md)

---

## Branching strategy

Trunk-based development.

- `main` is protected
- Feature branches: `feat/<area>-<short>`, `fix/…`, `docs/…`, `chore/…`
- Issue number referenced in PR body

---

## Commit conventions

[Conventional Commits](https://www.conventionalcommits.org/), enforced by `scripts/checks/check-commit-msg.sh` (the `commit-msg` hook and every commit in a PR) and by `check-pr-meta.sh` on the PR title, since we squash-merge. Both run in the `PR Conventions` check; there is no commitlint.

Examples:
- `feat(contribute): add difficulty filter`
- `fix(auth): handle expired GitHub token gracefully`
- `docs: update ARCHITECTURE.md with webhook flow`

---

## Pull request rules

- **1 approval** required, from a **code owner** for `lib/github`, `supabase/migrations`, `lib/rbac` and every other path in `.github/CODEOWNERS`
- All required CI checks green: `Repository Hygiene`, `PR Conventions`, `Verify`, `Secret Scan`, `Dependency Review`
- Up-to-date with `main`
- Linear history (squash merge only; merge commits are rejected)
- All conversations resolved
- No force-push to `main`, no branch deletion
- PR title is a Conventional Commit, because squash-merge uses it as the commit on `main`

Applied by `.github/branch-protection/apply.sh`, which pushes every file in
`.github/branch-protection/rulesets/`:

| Ruleset | Covers |
|---|---|
| Protect main | the merge gate above |
| Protect release branches | `release/**`, `hotfix/**`, `support/**` — no force-push, no deletion, reviewed PRs |
| Protect release tags | `v*` tags — immutable, semver names only |
| Branch naming | `<type>/<description>` for every new branch |

`optional/require-signed-commits.json` is available but not applied by default.
See [CI_CD](./CI_CD.md) §5.

### PR template checklist

- Linked issue
- Screenshots/video for UI changes
- Test notes
- Accessibility checklist
- Migration note (if applicable)

---

## Projects board

| Column | Description |
|---|---|
| Backlog | Triaged but not started |
| Ready | Dependencies met, can be picked up |
| In progress | Actively being worked on |
| In review | PR open, awaiting review |
| Done | Merged to main |

**Fields:** Epic, Phase, Difficulty, Area, Size

**Milestones** = Phases 0–7

**Epics** = Parent issues with sub-issues

---

## Issue templates (YAML forms)

Every dev issue includes:

1. **Title**
2. **Problem** — what's wrong or missing
3. **Objective** — what success looks like
4. **Scope** (in/out)
5. **Implementation guidance** — actual file paths, component names, specific instructions
6. **Acceptance criteria** (Given/When/Then)
7. **Dependencies** — other issue numbers
8. **Difficulty** — Beginner / Intermediate / Advanced
9. **Required skills**
10. **Labels** — from taxonomy in [GITHUB_INTEGRATION.md](./GITHUB_INTEGRATION.md)
11. **Testing requirements**
12. **Docs requirements**

### Template types

| Template | Extra fields |
|---|---|
| Feature | — |
| Bug | Repro steps, expected/actual, environment |
| UI/UX | Design reference, viewport |
| Documentation | Target audience |
| Tech debt | Impact, effort |
| Integration | API/permission/rate-limit fields |

---

## Task distribution by difficulty

| Difficulty | Suitable tasks |
|---|---|
| **Beginner** | Static pages, content components, docs, copy, seed data, a11y fixes |
| **Intermediate** | Filters, forms, admin CRUD screens, tests |
| **Advanced** | GitHub App, sync/webhooks, RLS, authz, CI/CD, performance |

**Rule:** each issue touches one `features/*` module.

---

## CI pipeline

Implemented, not sketched. The authoritative description — including why each
rule exists and how to extend it — is **[CI_CD.md](./CI_CD.md)**.

```yaml
# .github/workflows/ci.yml  (abridged)
name: CI
on:
  pull_request: { branches: [main] }
  push:         { branches: [main] }
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
permissions: { contents: read }

jobs:
  hygiene:                       # required check — always runs
    name: Repository Hygiene
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/checks/check-forbidden-files.sh
      - run: bash scripts/checks/check-large-files.sh
      - run: bash scripts/checks/check-lockfiles.sh
      - run: bash scripts/checks/check-text-hygiene.sh
      # + YAML syntax, actionlint, CODEOWNERS validation

  verify:                        # required check — activates with package.json
    name: Verify (Lint · Types · Tests · Build)
    needs: hygiene
    steps:
      - run: pnpm install --frozen-lockfile
      - run: bash scripts/ci/run-script.sh lint
      - run: bash scripts/ci/run-script.sh type-check
      - run: bash scripts/ci/run-script.sh format:check
      - run: bash scripts/ci/run-script.sh test -- --coverage
      - run: bash scripts/ci/run-script.sh build
      # + client-bundle secret scan

  accessibility:                 # advisory until the app exists
    name: Accessibility (Lighthouse)
    needs: verify
```

```yaml
# .github/workflows/pr-conventions.yml — its own workflow so that editing the
# title or labels re-runs it (a Re-run replays the original payload).
on:
  pull_request:
    types: [opened, edited, synchronize, reopened, labeled, unlabeled]
jobs:
  pr-conventions:                # required check — PRs only, no `needs:`
    name: PR Conventions
    steps:
      - run: bash scripts/checks/check-branch-name.sh "$HEAD_REF"
      - run: bash scripts/checks/check-commit-msg.sh --range "origin/$BASE_REF...HEAD"
      - run: bash scripts/checks/check-pr-meta.sh
```

Sibling workflows: `security.yml` (Secret Scan · Dependency Review),
`codeql.yml`, `db-check.yml` (migrations + pgTAP on a fresh local Postgres),
`e2e.yml` (Playwright), `labels-sync.yml`, `reconcile.yml`, `db-migrate.yml`
(manual approval), `stale.yml`, `protect-main.yml`, `pr-automation.yml`,
`workflow-security.yml` (zizmor audit of the workflows themselves),
`scorecard.yml` (OpenSSF Scorecard), `release-drafter.yml` (draft release
notes), `smoke.yml` (post-deployment HTTP check).

**Design rule:** every required check runs unconditionally and always reports a
conclusion. A skipped job cannot be a required status check without deadlocking
merges, so jobs with nothing to do yet succeed with a `::notice::` instead.
The authoritative description of all of this is `docs/CI_CD.md`.

### Deployment integration

- **Vercel** native Git integration for Preview (every PR) and Production (`main`) deploys
- GitHub Actions is the **quality gate** (branch protection requires `Repository Hygiene`, `PR Conventions`, `Verify (Lint · Types · Tests · Build)`, `Secret Scan` and `Dependency Review`; database, E2E and Lighthouse checks are advisory — see `docs/CI_CD.md` §3)
- Don't duplicate deploys from Actions
- **Database migrations:** applied to prod by a manual-approval workflow (`supabase db push`) — never auto from PR
