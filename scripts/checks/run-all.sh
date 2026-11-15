#!/usr/bin/env bash
# ==============================================================================
# run-all.sh — the complete local gate.
#
# Runs every repository check that does not need a Node toolchain, in the same
# order CI runs them. This is what the pre-push hook calls, and what a
# contributor runs by hand before opening a pull request:
#
#   ./scripts/checks/run-all.sh            # whole working tree
#   ./scripts/checks/run-all.sh --staged   # only what is staged
#
# Options:
#   --staged   check only what is staged (fast path used by pre-commit)
#   --strict   promote secret-scan warnings to errors
#   --fast     skip the commit-history and branch-name checks
#
# Exit code 0 = safe to push. Non-zero = fix the reported problems first.
# ==============================================================================
set -uo pipefail

CHECKS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
. "$CHECKS_DIR/lib/common.sh"

STAGED=0
STRICT=0
FAST=0
for arg in "$@"; do
  case "$arg" in
    --staged) STAGED=1 ;;
    --strict) STRICT=1 ;;
    --fast)   FAST=1 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

# Argument vectors for the individual checks. Kept as real arrays (never
# "${arr[@]:-}") so an empty option list expands to zero arguments rather than
# to one empty string, which the checks would reject as an unknown option.
STAGED_ARGS=()
[ "$STAGED" -eq 1 ] && STAGED_ARGS=(--staged)

SECRET_ARGS=()
[ "$STAGED" -eq 1 ] && SECRET_ARGS+=(--staged)
[ "$STRICT" -eq 1 ] && SECRET_ARGS+=(--strict)

printf '%s\n' "=============================================================================="
printf '%s\n' " OSS Club repository gate"
printf '%s\n' " mode: $([ "$STAGED" -eq 1 ] && echo 'staged changes' || echo 'full working tree')$( [ "$STRICT" -eq 1 ] && echo ' · strict')"
printf '%s\n' "=============================================================================="

FAILED=()

run_check() {
  local name="$1"; shift
  printf '\n'
  if "$@"; then
    :
  else
    FAILED+=("$name")
  fi
}

run_check "forbidden files"  bash "$CHECKS_DIR/check-forbidden-files.sh" "${STAGED_ARGS[@]}"
run_check "lockfile policy"  bash "$CHECKS_DIR/check-lockfiles.sh"
run_check "secret scan"      bash "$CHECKS_DIR/check-secrets.sh" "${SECRET_ARGS[@]}"
run_check "large files"      bash "$CHECKS_DIR/check-large-files.sh" "${STAGED_ARGS[@]}"
run_check "text hygiene"     bash "$CHECKS_DIR/check-text-hygiene.sh" "${STAGED_ARGS[@]}"
run_check "documentation"    bash "$CHECKS_DIR/check-docs.sh" "${STAGED_ARGS[@]}"
run_check "rulesets"         bash "$CHECKS_DIR/check-rulesets.sh"

if [ "$FAST" -eq 0 ]; then
  run_check "branch name"     bash "$CHECKS_DIR/check-branch-name.sh"

  # Prefer the range of commits that are actually being pushed; fall back to the
  # last commit when there is no upstream yet (first push of a new branch).
  if git rev-parse --verify --quiet '@{upstream}' >/dev/null 2>&1; then
    RANGE="@{upstream}..HEAD"
  else
    RANGE="HEAD~1..HEAD"
  fi
  run_check "commit messages" bash "$CHECKS_DIR/check-commit-msg.sh" --range "$RANGE"
fi

printf '\n%s\n' "=============================================================================="
if [ "${#FAILED[@]}" -eq 0 ]; then
  printf '%s\n' " RESULT: all checks passed — this branch is safe to push."
  printf '%s\n' "=============================================================================="
  exit 0
else
  printf '%s\n' " RESULT: ${#FAILED[@]} check(s) failed: ${FAILED[*]}"
  printf '%s\n' " Fix the errors above, then run the gate again."
  printf '%s\n' "=============================================================================="
  exit 1
fi
