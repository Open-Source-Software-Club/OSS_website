# Branch protection rulesets

The server-side half of the repository gate. Everything in `scripts/checks/`
runs in a hook or in CI and can be bypassed with `--no-verify` or a
force-merge; these files are what make the rules non-optional.

The authoritative description is [docs/CI_CD.md §5](../../docs/CI_CD.md).

## The set

| File | Ruleset | Target | What it prevents |
|---|---|---|---|
| `rulesets/protect-main.json` | Protect main | default branch | direct pushes, unreviewed merges, force-pushes, deleting `main`, squash-only, 5 required checks |
| `rulesets/protect-release-branches.json` | Protect release branches | `release/**`, `hotfix/**`, `support/**` | force-pushes, deletion, unreviewed changes on a release train |
| `rulesets/protect-tags.json` | Protect release tags | `refs/tags/v*` | deleting, moving or re-pointing a release tag; non-semver tag names |
| `rulesets/branch-naming.json` | Branch naming | all branches except bots/main/release | `<type>/<description>` naming |
| `optional/require-signed-commits.json` | Require signed commits | default branch | unsigned commits — **opt-in**, see §5.5 |

## Usage

```bash
bash .github/branch-protection/apply.sh --list      # applied vs. defined
bash .github/branch-protection/apply.sh --dry-run   # the exact payloads
bash .github/branch-protection/apply.sh             # create or update all four

bash .github/branch-protection/apply.sh --file optional/require-signed-commits.json
bash .github/branch-protection/apply.sh --remove
bash .github/branch-protection/apply.sh --remove --file rulesets/branch-naming.json
```

`apply.sh` needs `gh` authenticated as someone with **Administration: write** on
the repository. A GitHub App installation token will fail with
`Resource not accessible by integration (HTTP 403)`; the script detects this
before changing anything and prints the three ways to fix it.

## Editing a ruleset

1. Edit the JSON. Every file carries a `_comment` array explaining the *why* —
   keep that up to date, it is the only place the reasoning is recorded.
   Keys starting with `_` are stripped before the payload is sent.
2. Run `bash scripts/checks/check-rulesets.sh`. It validates the payload against
   the rule types GitHub accepts, and checks that every required status check
   context is the `name:` of a job a workflow actually emits. A required check
   that never reports makes a branch permanently unmergeable.
3. `bash .github/branch-protection/apply.sh --dry-run`, then apply.

Rulesets are matched by their `name` field, not the file name. Renaming a *file*
is free; renaming a *ruleset* leaves the old one in place — remove it first.

## Deliberate omissions

- **`bypass_actors` is empty everywhere.** Administrators are bound too. A
  genuine emergency bypass should be a temporary, visible change, and
  `.github/workflows/protect-main.yml` opens an incident issue when `main`
  moves without a merged pull request.
- **No `required_signatures` by default.** It is a real barrier to a student's
  first contribution. It ships as an opt-in file instead.
- **No push rulesets.** They need the GitHub Team plan; the payload to use when
  the club upgrades is in [docs/CI_CD.md §5.6](../../docs/CI_CD.md).
- **No required status checks on release branches.** Every workflow triggers on
  pull requests targeting `main`, so those contexts never report on a release
  branch, and requiring them would make the branch unmergeable.
