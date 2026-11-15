#!/usr/bin/env bash
# ==============================================================================
# .github/branch-protection/apply.sh
#
# Applies the rulesets in .github/branch-protection/rulesets/*.json to this
# repository, and creates the GitHub environments the deployment workflows need.
#
# Docs: docs/CI_CD.md §5
#
# Requirements
#   * gh, authenticated as a user with ADMIN access to the repository
#     (a GitHub App installation token cannot administer repository rulesets)
#   * python3 (payload validation only — no third-party modules)
#
# Usage
#   bash .github/branch-protection/apply.sh                    # create or update all
#   bash .github/branch-protection/apply.sh --dry-run          # show what would change
#   bash .github/branch-protection/apply.sh --remove           # delete the managed rulesets
#   bash .github/branch-protection/apply.sh --list             # what exists vs. what is defined
#   bash .github/branch-protection/apply.sh --file rulesets/protect-tags.json
#                                                              # just one file (repeatable)
#
#   The opt-in ruleset lives outside the default set:
#   bash .github/branch-protection/apply.sh --file optional/require-signed-commits.json
#
# The script is idempotent: running it twice leaves the repository in the same
# state as running it once. Rulesets are matched by their `name` field, not by
# the file name, so renaming a file is safe. Renaming a ruleset creates a second
# ruleset with the new name — remove the old one with --remove first.
# ==============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SETS_DIR="$HERE/rulesets"

# Remove every generated payload on exit, including on a validation failure:
# the validator may write three files before rejecting the fourth, and a stale
# *.payload.json is a hand-editable copy of a ruleset that nothing applies.
cleanup() {
  find "$HERE" -name '*.payload.json' -type f -delete 2>/dev/null || true
}
trap cleanup EXIT

DRY_RUN=0
REMOVE=0
LIST_ONLY=0
FILES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --remove)  REMOVE=1 ;;
    --list)    LIST_ONLY=1 ;;
    --file)
      if [ "$#" -lt 2 ]; then
        echo "apply: --file needs a path (relative to $HERE)." >&2
        exit 2
      fi
      case "$2" in
        /*) FILES+=("$2") ;;
        *)  FILES+=("$HERE/$2") ;;
      esac
      shift
      ;;
    -h|--help) sed -n '2,34p' "$0"; exit 0 ;;
    *) echo "apply: unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\n\033[1;31m==>\033[0m %s\n' "$1" >&2; }

# ------------------------------------------------------------------------------
# Preconditions.
# ------------------------------------------------------------------------------
command -v gh >/dev/null 2>&1 || { echo "apply: gh is not installed. https://cli.github.com" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "apply: python3 is required to validate the payloads." >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "apply: gh is not authenticated. Run 'gh auth login'." >&2; exit 1; }

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)}"
if [ -z "$REPO" ]; then
  echo "apply: could not determine the repository. Set GITHUB_REPOSITORY=owner/name." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# The default set.
#
# Order is for readability only: rulesets layer, they do not overwrite each
# other. 'Protect main' is listed first because it is the one that makes CI
# mandatory; the rest harden surfaces that main does not cover.
# ------------------------------------------------------------------------------
if [ "${#FILES[@]}" -eq 0 ]; then
  for f in \
    "$SETS_DIR/protect-main.json" \
    "$SETS_DIR/protect-release-branches.json" \
    "$SETS_DIR/protect-tags.json" \
    "$SETS_DIR/branch-naming.json"
  do
    [ -f "$f" ] && FILES+=("$f")
  done
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "apply: no ruleset files found in $SETS_DIR." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Validate everything BEFORE touching the API.
#
# A payload rejected halfway through leaves the repository with some rules
# enforced and others silently missing, which is worse than having applied
# nothing. So: parse every file, shape-check every file, write every API payload
# to disk, and only then start making requests.
#
# The helper prints one line per file, tab-separated:
#     <ruleset name> <payload path> <source path>
# ------------------------------------------------------------------------------
say "Validating ${#FILES[@]} ruleset file(s)"

ENTRIES="$(python3 - "${FILES[@]}" <<'PY'
import json
import os
import sys

REQUIRED = ('name', 'target', 'enforcement', 'conditions', 'rules')
TARGETS = {'branch', 'tag', 'push'}
ENFORCEMENT = {'active', 'disabled', 'evaluate'}

failed = False
seen = {}


def die(message):
    print(f'apply: {message}', file=sys.stderr)
    sys.exit(1)


for path in sys.argv[1:]:
    # Relative paths in messages: this script is often run from the repository
    # root, and an absolute /home/... path in an error is noise.
    display = os.path.relpath(path)
    if not os.path.isfile(path):
        die(f'{display} not found.')

    try:
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        die(f'{display} is not valid JSON: {exc}')

    if not isinstance(data, dict):
        die(f'{display} must contain a JSON object.')

    missing = [key for key in REQUIRED if key not in data]
    if missing:
        die(f'{display} is missing required key(s): {", ".join(missing)}.')

    if data['target'] not in TARGETS:
        die(f"{display} has target {data['target']!r}; expected one of {sorted(TARGETS)}.")

    if data['enforcement'] not in ENFORCEMENT:
        die(f"{display} has enforcement {data['enforcement']!r}; expected one of {sorted(ENFORCEMENT)}.")

    if not isinstance(data['rules'], list):
        die(f'{display} has a non-list "rules".')

    if not data['rules']:
        die(f'{display} has no rules — a ruleset that enforces nothing.')

    for rule in data['rules']:
        if not isinstance(rule, dict) or 'type' not in rule:
            die(f'{display} has a rule without a "type".')

    # Two files defining the same ruleset name would make one silently
    # overwrite the other depending on API ordering. That is a bug in this
    # directory, not in GitHub.
    name = data['name']
    if name in seen:
        die(f'{display} and {os.path.relpath(seen[name])} both define the ruleset {name!r}.')
    seen[name] = path

    # The payload is the file minus its `_comment` documentation keys, written
    # next to the source (and gitignored) so --dry-run can print exactly what
    # would be sent over the wire.
    payload = os.path.splitext(path)[0] + '.payload.json'
    stripped = {k: v for k, v in data.items() if not k.startswith('_')}
    with open(payload, 'w', encoding='utf-8') as fh:
        json.dump(stripped, fh, indent=2, ensure_ascii=False)
        fh.write('\n')

    print('\t'.join((name, payload, path)))
PY
)"

NAMES=()
PAYLOADS=()
SOURCES=()
while IFS=$'\t' read -r name payload src; do
  [ -z "$name" ] && continue
  NAMES+=("$name")
  PAYLOADS+=("$payload")
  SOURCES+=("$src")
  printf '    \033[1;32m✓\033[0m %-34s %s\n' "$name" "$(basename "$src")"
done <<< "$ENTRIES"

# ------------------------------------------------------------------------------
# What GitHub actually has. One API call, tab-separated, so every later lookup
# is a grep rather than another request (and cannot be rate-limited mid-run).
# ------------------------------------------------------------------------------
existing_id_for() {
  printf '%s\n' "$EXISTING" | awk -F'\t' -v want="$1" '$2 == want { print $1; exit }'
}

if ! EXISTING="$(gh api "repos/$REPO/rulesets?per_page=100" \
                   --jq '.[] | "\(.id)\t\(.name)\t\(.target)\t\(.enforcement)"' 2>/dev/null)"; then
  cat >&2 <<'MSG'
apply: cannot read repository rulesets.

Check that gh is authenticated and that you can see the repository.

  gh auth status
  gh repo view
MSG
  exit 1
fi

say "Repository: $REPO"

if [ "$LIST_ONLY" -eq 1 ]; then
  say "Rulesets on $REPO"
  if [ -z "$EXISTING" ]; then
    echo "    (none)"
  else
    printf '%s\n' "$EXISTING" | awk -F'\t' '{ printf "    %-34s %-8s %-10s id=%s\n", $2, $3, $4, $1 }'
  fi
  say "Rulesets defined in $HERE"
  i=0
  while [ "$i" -lt "${#NAMES[@]}" ]; do
    if [ -n "$(existing_id_for "${NAMES[$i]}")" ]; then
      printf '    %-34s %s\n' "${NAMES[$i]}" 'applied'
    else
      printf '    %-34s %s\n' "${NAMES[$i]}" 'NOT applied'
    fi
    i=$((i + 1))
  done
  exit 0
fi

# ------------------------------------------------------------------------------
# Prove the token can ADMINISTER rulesets, not merely read them.
#
# A GitHub App installation token with "Administration: read" passes a read
# probe and then fails with `Resource not accessible by integration (HTTP 403)`
# on the actual POST — so the read probe is followed by a write probe against a
# ruleset that matches no refs at all and is deleted immediately.
#
# This is not theoretical: the sandbox that built this pipeline had exactly that
# token, and the read probe alone was not enough to catch it.
# ------------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  probe_body='{"name":"__apply_probe__","target":"branch","enforcement":"disabled","conditions":{"ref_name":{"include":["refs/heads/__nonexistent__"],"exclude":[]}},"rules":[{"type":"deletion"}]}'

  probe_id="$(printf '%s' "$probe_body" \
    | gh api -X POST "repos/$REPO/rulesets" --input - --jq '.id' 2>/dev/null || true)"

  if [ -z "$probe_id" ]; then
    cat >&2 <<'MSG'
apply: this token cannot administer repository rulesets.

The payloads in rulesets/ are valid and ready. The blocker is the credential,
not the configuration.

DIAGNOSIS
  `Resource not accessible by integration` on a POST to /rulesets, while the
  account reports admin:true on the repository, means GH_TOKEN is a GitHub App
  installation token and the App does not hold the "Administration" repository
  permission. Granting the account write access does not change this: the
  missing permission is on the App.

THREE WAYS TO FIX IT

  A. Give the GitHub App the Administration permission (keeps automation
     working, including from CI):
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

  C. Import through the web UI (no token needed at all):
       Settings → Rules → Rulesets → New ruleset → Import a ruleset
     GitHub imports ONE ruleset per file, so this is one paste per file in
     rulesets/ — four pastes, not one.

Option A is the only one that lets a workflow or future automation apply
ruleset changes on its own. B and C are one-shot.

Nothing else in the pipeline depends on this script: the workflows, hooks and
checks all work without it. The rulesets are what make them mandatory.
MSG
    exit 1
  fi

  gh api -X DELETE "repos/$REPO/rulesets/$probe_id" >/dev/null 2>&1 || true
  say "Token can administer rulesets."
fi

# ------------------------------------------------------------------------------
# Remove.
# ------------------------------------------------------------------------------
if [ "$REMOVE" -eq 1 ]; then
  i=0
  while [ "$i" -lt "${#NAMES[@]}" ]; do
    name="${NAMES[$i]}"
    id="$(existing_id_for "$name")"
    if [ -z "$id" ]; then
      say "No '$name' ruleset found — nothing to remove."
    elif [ "$DRY_RUN" -eq 1 ]; then
      say "Would delete '$name' (id $id)"
    else
      gh api -X DELETE "repos/$REPO/rulesets/$id" >/dev/null
      say "Deleted '$name' (id $id)"
    fi
    i=$((i + 1))
  done
  exit 0
fi

# ------------------------------------------------------------------------------
# Create or update, one file at a time.
#
# A failure on one ruleset does not roll back the others: every rule in this
# directory only ever *adds* restriction, so a partial application is strictly
# safer than none, and stopping would leave the operator guessing about the
# result. Each failure is reported per file and the exit code is non-zero.
# ------------------------------------------------------------------------------
failures=0
applied=0
i=0

while [ "$i" -lt "${#NAMES[@]}" ]; do
  name="${NAMES[$i]}"
  payload="${PAYLOADS[$i]}"
  src="${SOURCES[$i]}"
  id="$(existing_id_for "$name")"

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ -n "$id" ]; then
      say "Would UPDATE '$name' (id $id) from $(basename "$src")"
    else
      say "Would CREATE '$name' from $(basename "$src")"
    fi
    cat "$payload"
    i=$((i + 1))
    continue
  fi

  if [ -n "$id" ]; then
    if err="$(gh api -X PUT "repos/$REPO/rulesets/$id" --input "$payload" 2>&1 >/dev/null)"; then
      say "Updated '$name' (id $id)"
      applied=$((applied + 1))
    else
      fail "Failed to update '$name'"
      printf '%s\n' "$err" | sed 's/^/    /' >&2
      failures=$((failures + 1))
    fi
  else
    if err="$(gh api -X POST "repos/$REPO/rulesets" --input "$payload" 2>&1 >/dev/null)"; then
      say "Created '$name'"
      applied=$((applied + 1))
    else
      fail "Failed to create '$name'"
      printf '%s\n' "$err" | sed 's/^/    /' >&2
      failures=$((failures + 1))
    fi
  fi

  i=$((i + 1))
done

if [ "$DRY_RUN" -eq 1 ]; then
  say "Dry run: nothing was written."
  exit 0
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
What is enforced now, and what it means in practice:

  Protect main
    * nobody can push to main directly — everything arrives through a PR
    * a PR cannot be merged without one approving review
    * CODEOWNERS-protected paths need an approval from a code owner
    * approvals are dismissed when new commits are pushed
    * all review conversations must be resolved
    * merge commits are rejected (linear history), and merges are squash-only
    * branches must be up to date with main before merging
    * the five required status checks must pass
    * force-pushes and branch deletion are blocked

  Protect release branches
    * release/**, hotfix/** and support/** cannot be force-pushed or deleted
    * changes to them still need a reviewed pull request

  Protect release tags
    * v* tags cannot be deleted, force-pushed or re-pointed at another commit
    * a tag name must be v<major>.<minor>.<patch>[-prerelease]

  Branch naming
    * new branches must be <type>/<description>, e.g. feat/events-rsvp
    * dependabot/**, arena/** and the other automation prefixes are exempt

  Deliberately NOT in the default set:
    * commits must be signed      — optional/require-signed-commits.json, §5.5
    * push rulesets (max file size, restricted extensions and paths) need the
      GitHub Team plan; the payload to use then is in §5.6

Next steps:

  1. Create the teams referenced in .github/CODEOWNERS, or replace them with
     individual @usernames.
  2. Add required reviewers to the 'production' and 'staging' environments.
  3. Turn on GitHub secret scanning and push protection:
       Settings → Code security → Secret protection
  4. Merge a documentation-only PR to confirm the gate is green.

To see what is applied:
  bash .github/branch-protection/apply.sh --list

To remove the managed rulesets:
  bash .github/branch-protection/apply.sh --remove
------------------------------------------------------------------------------
MSG

if [ "$failures" -ne 0 ]; then
  echo "apply: $failures ruleset(s) failed to apply. See the errors above." >&2
  exit 1
fi

echo "apply: $applied ruleset(s) applied or updated."
