#!/usr/bin/env bash
# ==============================================================================
# scripts/install-hooks.sh
#
# Points git at the repository's own hooks in .githooks/.
#
# Run once after cloning (and again after `git clone` of a fork, since
# core.hooksPath is a local setting that is not inherited):
#
#   ./scripts/install-hooks.sh
#
# Once package.json exists, add a `prepare` script so `pnpm install` does this
# for every contributor automatically:
#
#   "prepare": "git config core.hooksPath .githooks || true"
#
# (`|| true` keeps installs working where there is no .git directory, such as
# a Vercel build.)
#
# To remove the hooks:  git config --unset core.hooksPath
# To bypass a single run: git commit --no-verify / git push --no-verify
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [ ! -d .githooks ]; then
  echo "install-hooks: .githooks/ directory not found in $REPO_ROOT" >&2
  exit 1
fi

chmod +x .githooks/* 2>/dev/null || true
chmod +x scripts/checks/*.sh 2>/dev/null || true

git config core.hooksPath .githooks

echo "install-hooks: core.hooksPath -> $(git config --get core.hooksPath)"
echo "install-hooks: installed hooks:"
for h in .githooks/*; do
  [ -f "$h" ] || continue
  case "$h" in *.md) continue ;; esac
  printf '  %s %s\n' "-" "${h#.githooks/}"
done
echo
echo "Pre-commit, commit-msg and pre-push are now active for this clone."
