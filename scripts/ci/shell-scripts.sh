#!/usr/bin/env bash
# ==============================================================================
# scripts/ci/shell-scripts.sh
#
# Prints every shell script in the repository, one per line, for the CI steps
# that parse (`bash -n`) and lint (shellcheck) them.
#
# Why a script and not an inline glob
#   `git ls-files -- '*.sh' '.githooks/*'` also returns .githooks/README.md,
#   which is Markdown. Feeding Markdown to `bash -n` produces a syntax error in
#   a file that is perfectly valid, and feeding it to shellcheck produces six
#   findings about a file that is not shell at all. The shebang is the only
#   reliable signal, and it is one place instead of two.
#
# Usage:
#   bash scripts/ci/shell-scripts.sh
# ==============================================================================
set -uo pipefail

git ls-files -- '*.sh' '.githooks/*' | while IFS= read -r file; do
  [ -f "$file" ] || continue
  case "$(head -c 2 -- "$file" 2>/dev/null || true)" in
    '#!') printf '%s\n' "$file" ;;
  esac
done
