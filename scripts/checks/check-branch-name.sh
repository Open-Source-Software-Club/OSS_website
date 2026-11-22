#!/usr/bin/env bash
# ==============================================================================
# check-branch-name.sh
#
# Enforces the branch naming standard from CONTRIBUTING.md:
#
#   feat/homepage-hero · fix/navbar-mobile-toggle · docs/setup-guide-refactor
#
# A predictable branch name is what makes `git branch --list`, the branch
# cleanup job and the "who is working on what" review queue usable.
#
# Usage:
#   check-branch-name.sh <branch-name>
#   check-branch-name.sh                 # checks the current branch
#
# Long-lived branches and automation branches are allowlisted explicitly.
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')}"

log_header "Branch naming"

if [ -z "$BRANCH" ]; then
  record_error "could not determine the current branch" \
    "Unable to determine the current branch name. Pass it explicitly: check-branch-name.sh <branch-name>."
  finish "Branch name check"
fi

# Long-lived branches that must never be renamed or deleted.
PROTECTED='^(main|master|develop|staging|production)$'

# Automation and session branches.
AUTOMATION='^(dependabot|renovate|arena|codex|agent|copilot|github-actions|preview|gh-pages)/.+'

# Release / support trains.
RELEASE='^(release|hotfix|support)/[a-z0-9][a-z0-9._-]*$'

# The branch GitHub's "Revert" button creates: revert-<PR number>-<head branch>.
# Rejecting it made the one-click revert of #49 fail CI (#55) and forced a
# hand-made replacement; a revert is exactly when nobody should be fighting CI.
GITHUB_REVERT='^revert-[0-9]+-.+'

# The documented contribution convention.
CONVENTIONAL='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)/[a-z0-9][a-z0-9._-]*$'

if [[ "$BRANCH" =~ $PROTECTED ]]; then
  log_ok "'$BRANCH' is a protected long-lived branch"
elif [[ "$BRANCH" =~ $AUTOMATION ]]; then
  log_ok "'$BRANCH' is an automation/session branch (allowlisted)"
elif [[ "$BRANCH" =~ $RELEASE ]]; then
  log_ok "'$BRANCH' follows the release-train convention"
elif [[ "$BRANCH" =~ $GITHUB_REVERT ]]; then
  log_ok "'$BRANCH' was created by GitHub's Revert button"
elif [[ "$BRANCH" =~ $CONVENTIONAL ]]; then
  log_ok "'$BRANCH' follows the contribution convention"
else
  record_error "'$BRANCH' does not follow the naming convention" \
    "Branch name '$BRANCH' is invalid. Use '<type>/<short-description>' where type is one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert. Example: 'feat/events-rsvp-button'. Rename with: git branch -m <new-name>"
fi

# A branch left at the same commit as its base carries no work and only adds
# noise to the branch list and to Vercel's preview environments.
if [ -n "${BASE_REF:-}" ]; then
  if git rev-parse --verify --quiet "origin/$BASE_REF" >/dev/null 2>&1; then
    if [ "$(git rev-list --count "origin/$BASE_REF..HEAD" 2>/dev/null || echo 0)" -eq 0 ]; then
      record_warning "'$BRANCH' contains no commits relative to $BASE_REF" \
        "Branch '$BRANCH' has no commits beyond '$BASE_REF'. Close it instead of leaving it open."
    fi
  fi
fi

finish "Branch name check"
