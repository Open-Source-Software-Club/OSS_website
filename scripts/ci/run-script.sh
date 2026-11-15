#!/usr/bin/env bash
# ==============================================================================
# scripts/ci/run-script.sh
#
# Runs one package.json script out of a list of accepted names, and reports a
# GitHub Actions warning (not a failure) if none of them exists.
#
# Why this exists
#   The pipeline must be able to require the "Verify" status check from the very
#   first commit, before package.json exists and before every convention the
#   README documents has been settled. A missing script is therefore a warning
#   so a greenfield repository is not blocked, while a *failing* script is still
#   a hard failure the moment it exists.
#
#   The alias list is what makes that possible without masking failures. The
#   obvious way to support two names —
#
#       run-script.sh type-check || run-script.sh typecheck
#
#   — is a bug: `||` cannot tell "the script does not exist" (skip, exit 0)
#   from "the script exists and failed" (must fail the build), so a failing
#   type-check would be silently followed by the missing alias and the job would
#   go green. Here the script that exists is resolved *before* anything runs,
#   and only that one is executed, so a failure can never be swallowed.
#
# Usage
#   run-script.sh <candidates> [-- <extra args>]
#
#   <candidates>  one or more script names separated by `|`, tried in order.
#                 A candidate may carry its own arguments after `::`.
#
# Examples
#   run-script.sh lint
#   run-script.sh 'typecheck|type-check'
#   run-script.sh 'format:check|format::--check'
#   run-script.sh test -- --coverage
#
# Exit codes
#   0  the script ran and succeeded, or no candidate exists (warning only)
#   1  the resolved script ran and failed
#   2  usage error
# ==============================================================================
set -uo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <name[|alias...]> [-- <extra args...>]" >&2
  exit 2
fi

CANDIDATES="$1"
shift

EXTRA_ARGS=()
if [ "${1:-}" = "--" ]; then
  shift
  EXTRA_ARGS=("$@")
elif [ "$#" -gt 0 ]; then
  # Tolerate the older call style: extra arguments without a leading `--`.
  EXTRA_ARGS=("$@")
fi

if [ ! -f package.json ]; then
  echo "::warning::package.json not found — nothing to run for '$CANDIDATES'."
  exit 0
fi

# Split the candidate list on `|` without touching the inner `::` argument
# separator. `read -ra` is enough because script names never contain spaces.
IFS='|' read -ra NAMES <<< "$CANDIDATES"

RESOLVED=""
RESOLVED_ARGS=()
EXISTING=()

for candidate in "${NAMES[@]}"; do
  name="${candidate%%::*}"
  inline=""
  if [ "$candidate" != "$name" ]; then
    inline="${candidate#*::}"
  fi

  [ -z "$name" ] && continue

  if node -e "const s=require('./package.json').scripts||{}; process.exit(Object.prototype.hasOwnProperty.call(s, process.argv[1])?0:1)" "$name"; then
    EXISTING+=("$name")
    if [ -z "$RESOLVED" ]; then
      RESOLVED="$name"
      # shellcheck disable=SC2206  # word splitting of the inline arg string is intended
      [ -n "$inline" ] && RESOLVED_ARGS=($inline)
    fi
  fi
done

if [ -z "$RESOLVED" ]; then
  echo "::warning::package.json defines none of '$CANDIDATES' — skipping this verification step. Add the script when the application lands."
  exit 0
fi

if [ "${#EXISTING[@]}" -gt 1 ]; then
  # Not fatal, but two names for the same job is how CI and the README drift
  # apart. Say which one won so the duplicate can be deleted deliberately.
  echo "::notice::Both '${EXISTING[*]}' exist; running '$RESOLVED' (first match). Remove the duplicate script from package.json."
fi

# `--` is what tells pnpm that the following words belong to the script rather
# than to pnpm. Omitting it works for some arguments and silently swallows
# others (`--coverage`, `--check`), which would turn a coverage threshold or a
# formatting check into a no-op.
ARGS=(${RESOLVED_ARGS[@]+"${RESOLVED_ARGS[@]}"} ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"})

echo "::group::pnpm run $RESOLVED ${ARGS[*]:-}"
if [ "${#ARGS[@]}" -gt 0 ]; then
  pnpm run "$RESOLVED" -- "${ARGS[@]}"
else
  pnpm run "$RESOLVED"
fi
rc=$?
echo "::endgroup::"
exit "$rc"
