#!/usr/bin/env bash
# ==============================================================================
# check-large-files.sh
#
# Git is a source-code repository, not a binary CDN. Large blobs are cloned by
# every contributor on every clone and are the single biggest cause of a
# sluggish fork/clone experience for a student club on metered connections.
#
# Hard limit : 1 MiB per file  (override per file in .github/large-files.allowlist)
# Soft limit : 512 KiB         (reported as a warning)
#
# Usage:
#   scripts/checks/check-large-files.sh [--staged]
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

STAGED=0
for arg in "$@"; do
  case "$arg" in
    --staged) STAGED=1 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

log_header "Large files"

HARD_LIMIT=$((1024 * 1024))   # 1 MiB
SOFT_LIMIT=$((512 * 1024))    # 512 KiB

load_allowlist "$LARGE_FILES_LIST"

if [ "$STAGED" -eq 1 ]; then
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null | tr '\0' '\n')
else
  mapfile -t FILES < <(list_tracked_files)
fi

oversized=0

# Byte sizes for the whole list in one `stat` (GNU or BSD), not one per file.
while IFS=$'\t' read -r size file; do
  [ -z "$file" ] && continue
  case "$size" in ''|*[!0-9]*) continue ;; esac

  if [ "$size" -gt "$HARD_LIMIT" ]; then
    if is_allowlisted "$file"; then
      log_warn "$file is $(human_size "$size") — allowlisted in $LARGE_FILES_LIST"
      continue
    fi
    record_error "$file is $(human_size "$size") (limit 1 MiB)" \
      "Large file '$file' ($(human_size "$size")) exceeds the 1 MiB limit. Compress it, move it to an external asset store, or add a justified exception to $LARGE_FILES_LIST."
    oversized=$((oversized + 1))
  elif [ "$size" -gt "$SOFT_LIMIT" ]; then
    log_warn "$file is $(human_size "$size") — approaching the 1 MiB limit"
  fi
done < <(file_sizes "${FILES[@]:-}")

if [ "$oversized" -eq 0 ]; then
  log_ok "All files are under the 1 MiB limit"
fi

finish "Large file check"
