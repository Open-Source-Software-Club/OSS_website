#!/usr/bin/env bash
# ==============================================================================
# check-pr-meta.sh
#
# Pull-request discipline. CI calls this with the metadata GitHub already knows;
# the script itself is pure logic so it can be unit-tested and reused.
#
# Environment variables consumed:
#   PR_NUMBER        PR number
#   PR_TITLE         PR title            (must be a Conventional Commit header)
#   PR_BODY          PR description
#   PR_HEAD_REF      head branch name    (must follow the branch convention)
#   PR_BASE_REF      base branch name
#   PR_COMMITS       number of commits
#   PR_ADDITIONS     added lines
#   PR_DELETIONS     deleted lines
#   PR_CHANGED_FILES number of changed files
#   PR_LABELS       comma-separated label names (enables the size exemption)
#
# Thresholds:
#   WARN  > 400 changed lines or > 20 changed files  (CONTRIBUTING.md asks for
#          atomic PRs — "a PR that fixes three bugs and redesigns two pages is
#          difficult to review and will likely be rejected")
#   FAIL  > 10000 changed lines or > 300 changed files
#
# Exemption: a PR carrying the 'size: exempt' label skips the size check. The
# label is CODEOWNERS-protected and audited, because occasionally the right
# change IS large — a new pipeline, a one-off codemod, a vendored file — and a
# mechanical limit should not be the reason it never lands.
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

WARN_LINES=400
WARN_FILES=20
FAIL_LINES=10000
FAIL_FILES=300

TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|release'
TITLE_RE="^($TYPES)(\\([a-z0-9][a-z0-9._/-]*\\))?(!)?: .+"
# GitHub's "Revert" button titles its pull request 'Revert "<original title>"'.
# Accepting that form keeps the one-click revert usable in an emergency; it is
# the same exception commitlint makes by default.
REVERT_TITLE_RE='^Revert ".+"$'
ISSUE_RE='(Closes|Close|Fixes|Fix|Resolves|Resolve|Refs|Related to|Implements) +#[0-9]+'

log_header "Pull request discipline"

missing=0
for var in PR_NUMBER PR_TITLE PR_HEAD_REF PR_BASE_REF; do
  if [ -z "${!var:-}" ]; then
    record_error "PR metadata '$var' was not supplied" \
      "check-pr-meta.sh requires $var to be set. This is a pipeline wiring problem, not a contributor problem."
    missing=1
  fi
done
[ "$missing" -eq 1 ] && finish "PR discipline check"

log_ok "PR #$PR_NUMBER: '$PR_TITLE' ($PR_HEAD_REF -> $PR_BASE_REF)"

# ------------------------------------------------------------------------------
# 1. PR title must be a Conventional Commit header.
#    We squash-merge, so the PR title becomes the commit on main.
# ------------------------------------------------------------------------------
if printf '%s' "$PR_TITLE" | grep -Eq -- "$TITLE_RE"; then
  log_ok "PR title follows Conventional Commits"
elif printf '%s' "$PR_TITLE" | grep -Eq -- "$REVERT_TITLE_RE"; then
  log_ok "PR title is a GitHub revert of an earlier pull request"
else
  record_error "PR title '$PR_TITLE' is not a Conventional Commit" \
    "PR titles become squash-merge commit messages on main, so they must follow Conventional Commits: '<type>(<scope>): <subject>'. Got: '$PR_TITLE'. Example: 'feat(events): add RSVP button'."
fi

# ------------------------------------------------------------------------------
# 2. Branch name convention.
# ------------------------------------------------------------------------------
BASE_REF="$PR_BASE_REF" bash "$REPO_ROOT/scripts/checks/check-branch-name.sh" "$PR_HEAD_REF" || true

# ------------------------------------------------------------------------------
# 3. Issue linkage. CONTRIBUTING.md: "please open an issue first before
#    opening a PR". Enforced as a warning so quick doc fixes are not blocked.
# ------------------------------------------------------------------------------
if printf '%s' "${PR_BODY:-}" | grep -Eqi -- "$ISSUE_RE"; then
  log_ok "PR links a related issue"
else
  record_warning "PR does not link an issue" \
    "PR #$PR_NUMBER does not reference an issue. CONTRIBUTING.md asks that every PR links the issue it resolves — add 'Closes #<number>' to the description."
fi

# ------------------------------------------------------------------------------
# 4. Description substance — the PR template must actually be filled in.
# ------------------------------------------------------------------------------
body_len="$(printf '%s' "${PR_BODY:-}" | tr -d '[:space:]' | wc -c | tr -d ' ')"
if [ "$body_len" -lt 40 ]; then
  record_warning "PR description is only $body_len non-whitespace characters" \
    "PR #$PR_NUMBER description looks empty. Fill in the PR template (Description, Changes Made, How Has This Been Tested?) so reviewers have context."
fi

# ------------------------------------------------------------------------------
# 5. Size limits.
#
# A label-based exemption exists because a purely mechanical limit eventually
# blocks the right change: adding this very pipeline produced a 4,900-line pull
# request that could not have been split into anything reviewable. The exemption
# is a label rather than a title flag so it is visible, auditable and easy to
# revoke.
# ------------------------------------------------------------------------------
add="${PR_ADDITIONS:-0}"
del="${PR_DELETIONS:-0}"
files="${PR_CHANGED_FILES:-0}"
lines=$((add + del))

if printf '%s' "${PR_LABELS:-}" | tr ',' '\n' | grep -qx 'size: exempt'; then
  log_ok "PR is exempt from the size limits (label: size: exempt) — $lines lines across $files files"
  record_warning "PR #$PR_NUMBER carries the 'size: exempt' label" \
    "PR #$PR_NUMBER changes $lines lines across $files files and is exempt from the size limits via the 'size: exempt' label. Confirm the exemption is justified and record why."
else
  if [ "$lines" -gt "$FAIL_LINES" ] || [ "$files" -gt "$FAIL_FILES" ]; then
    record_error "PR is too large to review ($lines lines across $files files)" \
      "PR #$PR_NUMBER changes $lines lines across $files files (limits: $FAIL_LINES lines / $FAIL_FILES files). Split it into stacked, independently reviewable PRs, or ask a maintainer to apply the 'size: exempt' label with a written justification."
  elif [ "$lines" -gt "$WARN_LINES" ] || [ "$files" -gt "$WARN_FILES" ]; then
    record_warning "PR is large ($lines lines across $files files)" \
      "PR #$PR_NUMBER changes $lines lines across $files files. Keep PRs atomic — reviewers need to be able to hold the whole change in their head."
  else
    log_ok "PR size is reviewable ($lines lines across $files files)"
  fi
fi

# ------------------------------------------------------------------------------
# 6. Merge commits break the linear history we require. Only checkable when the
#    base ref is available locally (the CI job fetches it).
# ------------------------------------------------------------------------------
if [ -n "${PR_BASE_REF:-}" ] && git rev-parse --verify --quiet "origin/$PR_BASE_REF" >/dev/null 2>&1; then
  merges="$(git rev-list --count --merges "origin/$PR_BASE_REF..HEAD" 2>/dev/null || echo 0)"
  if [ "$merges" -gt 0 ]; then
    record_error "PR contains $merges merge commit(s)" \
      "PR #$PR_NUMBER contains $merges merge commit(s). This repository requires a linear history — rebase onto '$PR_BASE_REF' ('git rebase origin/$PR_BASE_REF') instead of merging."
  else
    log_ok "PR history is linear (no merge commits)"
  fi
else
  log_ok "Merge-commit check skipped (base ref '$PR_BASE_REF' not available locally)"
fi

# ------------------------------------------------------------------------------
# 7. Files that must never appear in a PR, checked against the actual diff.
# ------------------------------------------------------------------------------
# --diff-filter=d leaves out deletions: a pull request that REMOVES an
# accidentally committed .env is the fix, not the offence.
changed="$(git diff --name-only --diff-filter=d "origin/$PR_BASE_REF...HEAD" 2>/dev/null || true)"
if [ -n "$changed" ]; then
  banned=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "${f##*/}" in
      package-lock.json|yarn.lock|bun.lockb|.env|.env.local|*.pem|*.key|*.p12|*.pfx)
        banned="$banned $f" ;;
    esac
    case "$f" in
      .next/*|node_modules/*|dist/*|build/*|coverage/*|.vercel/*) banned="$banned $f" ;;
    esac
  done <<< "$changed"
  if [ -n "$banned" ]; then
    record_error "PR adds forbidden files:$banned" \
      "PR #$PR_NUMBER adds files that must never be committed:$banned. Remove them from the branch and extend .gitignore."
  else
    log_ok "No forbidden files in the PR diff"
  fi
fi

finish "PR discipline check"
