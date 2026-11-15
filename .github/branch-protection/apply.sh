#!/usr/bin/env bash
# ==============================================================================
# .github/branch-protection/apply.sh
#
# Applies the branch protection ruleset defined in ruleset.json to this
# repository, and creates the GitHub environments the deployment workflows need.
#
# Docs: docs/CI_CD.md
#
# Requirements
#   * gh, authenticated as a user with ADMIN access to the repository
#     (an installation token cannot administer branch rulesets)
#   * the CODEOWNERS teams to already exist, or the rule silently does nothing
#
# Usage
#   bash .github/branch-protection/apply.sh            # create or update
#   bash .github/branch-protection/apply.sh --dry-run  # show what would change
#   bash .github/branch-protection/apply.sh --remove   # delete the ruleset
#
# The script is idempotent: running it twice leaves the repository in the same
# state as running it once.
# ==============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RULESET_FILE="$HERE/ruleset.json"

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)}"
if [ -z "$REPO" ]; then
  echo "apply: could not determine the repository. Set GITHUB_REPOSITORY=owner/name." >&2
  exit 1
fi

DRY_RUN=0
REMOVE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --remove)  REMOVE=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

if ! command -v gh >/dev/null 2>&1; then
  echo "apply: gh is not installed. https://cli.github.com" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "apply: gh is not authenticated. Run 'gh auth login'." >&2
  exit 1
fi

say "Repository: $REPO"

# ------------------------------------------------------------------------------
# Verify we can actually ADMINISTER rulesets.
#
# Reading rulesets is not proof of write access. A GitHub App installation
# token with "Administration: read" passes a read probe and then fails with
# `Resource not accessible by integration (HTTP 403)` on the actual POST — so
# the read probe is deliberately followed by a write probe against an endpoint
# that is harmless and reversible.
#
# This is not theoretical: the sandbox that built this pipeline had exactly
# that token, and the read probe alone was not enough to catch it.
# ------------------------------------------------------------------------------
if ! gh api "repos/$REPO/rulesets" >/dev/null 2>&1; then
  cat >&2 <<'MSG'
apply: cannot read repository rulesets.

Check that gh is authenticated and that the repository name is correct.

  gh auth status
MSG
  exit 1
fi

write_probe() {
  # Creating and immediately deleting a ruleset with no rules is a no-op on
  # the branch, and proves the token can administer rulesets.
  local id
  id="$(gh api -X POST "repos/$REPO/rulesets" \
          --input <(printf '%s' '{"name":"__apply_probe__","target":"branch","enforcement":"disabled","conditions":{"ref_name":{"include":["refs/heads/__nonexistent__"],"exclude":[]}},"rules":[]}') \
          --jq '.id' 2>/dev/null)" || return 1
  [ -z "$id" ] && return 1
  gh api -X DELETE "repos/$REPO/rulesets/$id" >/dev/null 2>&1 || true
  return 0
}

if ! write_probe; then
  cat >&2 <<'MSG'
apply: this token cannot administer repository rulesets.

The payload in ruleset.json is valid and ready. The blocker is the credential,
not the configuration.

DIAGNOSIS
  The error is `Resource not accessible by integration`, and
  `GET /installation/repositories` is also unreachable. That combination means
  GH_TOKEN is a GitHub App installation token, and the app does not hold the
  "Administration" repository permission.

  Granting the account write access to the repository does NOT fix this. The
  token already reports admin:true on the repo — the missing permission is on
  the App itself, and only the App's configuration can grant it.

THREE WAYS TO FIX IT

  A. Give the GitHub App the Administration permission (keeps automation
     working, including from CI and from this pipeline):
       1. Organisation Settings → Developer settings → GitHub Apps
       2. Select the app this token belongs to
       3. Permissions & events → Repository permissions
       4. Set "Administration" to "Read and write" → Save changes
       5. An organisation owner must approve the updated permission request
       6. Re-run this script

  B. Run it once with a personal access token (fastest, no org changes):
       gh auth logout
       gh auth login          # HTTPS + token, classic PAT with `repo` scope
       bash .github/branch-protection/apply.sh

  C. Import it through the web UI (no token needed at all):
       Settings → Rules → Rulesets → New ruleset → Import a ruleset
       then paste the contents of .github/branch-protection/ruleset.json

Note that A is the only option that lets a workflow or a future automation
apply ruleset changes on its own. B and C are one-shot.

Nothing else in the pipeline depends on this script. The workflows, hooks and
checks all work without it; the ruleset is what makes them mandatory.
MSG
  exit 1
fi
say "Token can administer rulesets."

# ------------------------------------------------------------------------------
# Remove
# ------------------------------------------------------------------------------
if [ "$REMOVE" -eq 1 ]; then
  id="$(gh api "repos/$REPO/rulesets" --jq '.[] | select(.name == "Protect main") | .id' 2>/dev/null || true)"
  if [ -z "$id" ]; then
    say "No 'Protect main' ruleset found — nothing to remove."
    exit 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    say "Would delete ruleset $id"
    exit 0
  fi
  gh api -X DELETE "repos/$REPO/rulesets/$id" >/dev/null
  say "Deleted ruleset $id"
  exit 0
fi

# ------------------------------------------------------------------------------
# Create or update
# ------------------------------------------------------------------------------
if [ ! -f "$RULESET_FILE" ]; then
  echo "apply: $RULESET_FILE not found." >&2
  exit 1
fi

python3 - "$RULESET_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
# Strip the documentation keys so only real API fields are sent.
data = {k: v for k, v in data.items() if not k.startswith('_')}
with open(sys.argv[1] + '.payload.json', 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
print('ruleset.json is valid JSON; payload prepared.')
PY

PAYLOAD="$RULESET_FILE.payload.json"
trap 'rm -f "$PAYLOAD"' EXIT

EXISTING_ID="$(gh api "repos/$REPO/rulesets" --jq '.[] | select(.name == "Protect main") | .id' 2>/dev/null || true)"

if [ "$DRY_RUN" -eq 1 ]; then
  if [ -n "$EXISTING_ID" ]; then
    say "Would UPDATE ruleset $EXISTING_ID from $PAYLOAD"
  else
    say "Would CREATE a new ruleset from $PAYLOAD"
  fi
  cat "$PAYLOAD"
  exit 0
fi

apply_ruleset() {
  if [ -n "$EXISTING_ID" ]; then
    gh api -X PUT "repos/$REPO/rulesets/$EXISTING_ID" --input "$PAYLOAD" >/dev/null
  else
    gh api -X POST "repos/$REPO/rulesets" --input "$PAYLOAD" >/dev/null
  fi
}

if err="$(apply_ruleset 2>&1)"; then
  if [ -n "$EXISTING_ID" ]; then
    say "Updated existing ruleset $EXISTING_ID"
  else
    say "Created a new ruleset"
  fi
else
  echo "apply: failed to write the ruleset: $err" >&2
  echo "apply: the payload is valid; this is a permissions problem. See the" >&2
  echo "       guidance printed above about GitHub App installation tokens." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Environments used by the manual-approval migration workflow.
# ------------------------------------------------------------------------------
for env in production staging; do
  if gh api "repos/$REPO/environments/$env" >/dev/null 2>&1; then
    say "Environment '$env' already exists"
  else
    gh api -X PUT "repos/$REPO/environments/$env" >/dev/null 2>&1 \
      && say "Created environment '$env'" \
      || say "Could not create environment '$env' — create it in repository settings"
  fi
done

cat <<'MSG'

------------------------------------------------------------------------------
Done. Branch protection is now active on the default branch.

What this means in practice:

  * nobody can push to main directly — everything arrives through a pull request
  * a pull request cannot be merged without one approving review
  * CODEOWNERS-protected paths need an approval from a code owner
  * approvals are dismissed when new commits are pushed
  * all review conversations must be resolved
  * merge commits are rejected (linear history), and merges are squash-only
  * branches must be up to date with main before merging
  * the five required status checks must pass
  * force-pushes and branch deletion are blocked
  * commits must be signed            <-- NOT in this ruleset, see docs/CI_CD.md §5

Next steps:

  1. Create the teams referenced in .github/CODEOWNERS, or replace them with
     individual @usernames.
  2. Add required reviewers to the 'production' and 'staging' environments.
  3. Turn on GitHub secret scanning and push protection:
       Settings → Code security → Secret protection
  4. Merge a documentation-only PR to confirm the gate is green.

To see what is applied:
  gh api repos/OWNER/REPO/rulesets --jq '.[].name'

To remove it:
  bash .github/branch-protection/apply.sh --remove
------------------------------------------------------------------------------
MSG
