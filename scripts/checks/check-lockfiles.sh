#!/usr/bin/env bash
# ==============================================================================
# check-lockfiles.sh
#
# Enforces the single-package-manager rule documented in CONTRIBUTING.md:
#
#   "Do NOT run npm install or yarn install. Doing so generates conflicting
#    lockfiles (package-lock.json or yarn.lock) and will cause automated CI
#    workflows to fail."
#
# Rules:
#   1. At most one lockfile may exist, and it must be `pnpm-lock.yaml`.
#   2. If `package.json` exists, `pnpm-lock.yaml` must exist too.
#   3. A repo with neither (current greenfield state) is valid and reported.
#
# Usage:
#   scripts/checks/check-lockfiles.sh
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

log_header "Package manager lockfiles"

FOREIGN_LOCKFILES=(
  'package-lock.json'
  'npm-shrinkwrap.json'
  '.package-lock.json'
  'yarn.lock'
  'bun.lockb'
  'bun.lock'
)

found_foreign=0
for lf in "${FOREIGN_LOCKFILES[@]}"; do
  if [ -e "$lf" ]; then
    record_error "$lf exists" \
      "Conflicting lockfile '$lf' found. This repository uses pnpm exclusively — delete it and run 'pnpm install' to regenerate 'pnpm-lock.yaml'."
    found_foreign=1
  fi
done

if [ -f 'package.json' ] && [ ! -f 'pnpm-lock.yaml' ]; then
  record_error "package.json without pnpm-lock.yaml" \
    "'package.json' exists but 'pnpm-lock.yaml' is missing. Run 'pnpm install' and commit the lockfile so CI can use --frozen-lockfile."
elif [ -f 'package.json' ] && [ -f 'pnpm-lock.yaml' ]; then
  log_ok "pnpm-lock.yaml present and is the only lockfile"
elif [ "$found_foreign" -eq 0 ] && [ ! -f 'package.json' ] && [ ! -f 'pnpm-lock.yaml' ]; then
  log_ok "No JavaScript manifest yet (greenfield) — nothing to verify"
  gha_notice "No package.json/pnpm-lock.yaml yet. Lockfile policy check is a no-op until Phase 0 scaffolding lands."
fi

# Warn (do not fail) about an out-of-date pnpm version pin in CI, so the
# packageManager field and the workflow never silently diverge.
#
# Required, not advisory: CI installs pnpm with pnpm/action-setup, which reads
# the version from this field. Without it, every job that needs pnpm fails with
# "No pnpm version is specified" — so say so here, in plain words, instead.
if [ -f 'package.json' ]; then
  pm="$(grep -o '"packageManager"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null | head -1 \
        | sed 's/^"packageManager"[[:space:]]*:[[:space:]]*"\([^"]*\)"$/\1/')"
  case "${pm:-}" in
    pnpm@?*)
      log_ok "package.json pins packageManager $pm" ;;
    '')
      record_error "package.json has no \"packageManager\" field" \
        "package.json must declare \"packageManager\": \"pnpm@<version>\" (for example \"pnpm@9.15.9\"). CI takes the pnpm version from it, so every contributor and every runner uses the same one." ;;
    *)
      record_error "package.json declares packageManager '$pm', not pnpm" \
        "package.json declares \"packageManager\": \"$pm\". This repository uses pnpm exclusively — set it to \"pnpm@<version>\"." ;;
  esac
fi

finish "Lockfile policy check"
