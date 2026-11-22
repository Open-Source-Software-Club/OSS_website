#!/usr/bin/env bash
# ==============================================================================
# Shared helpers for the OSS Club repository quality checks.
#
# Every script in this directory is intentionally dependency-free (bash + git +
# grep) so that the exact same checks can run:
#   * locally, inside .githooks/pre-commit|pre-push  (developer machine)
#   * in CI, inside .github/workflows/ci.yml         (GitHub Actions runner)
#
# Sourced by all check scripts. Never executed directly.
# ==============================================================================

# ------------------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  # `declare a=1 b=2` keeps the block on one line while still letting a single
  # SC2034 directive cover every variable: ShellCheck cannot see the reads,
  # because they happen in the scripts that source this file.
  # shellcheck disable=SC2034
  declare C_RESET='\033[0m' C_RED='\033[1;31m' C_GREEN='\033[1;32m' C_YELLOW='\033[1;33m' C_BLUE='\033[1;34m' C_DIM='\033[2m'
else
  # shellcheck disable=SC2034
  declare C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_DIM=''
fi

log_header() { printf '\n%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$1"; }
log_ok()     { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
log_warn()   { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
log_fail()   { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$1"; }

# GitHub Actions workflow commands. No-op (but harmless) outside Actions.
gha_error()   { echo "::error::$1"; }
gha_warning() { echo "::warning::$1"; }
gha_notice()  { echo "::notice::$1"; }

# ------------------------------------------------------------------------------
# Repository root — scripts may be invoked from a hook (repo root) or from
# anywhere else, so resolve it from git rather than $PWD.
# ------------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

# Path of the allowlist files (reviewable in git, owned by CODEOWNERS).
# shellcheck disable=SC2034  # consumed by the scripts that source this file
ALLOWED_FILES_LIST=".github/allowed-files.txt"
# shellcheck disable=SC2034  # consumed by the scripts that source this file
LARGE_FILES_LIST=".github/large-files.allowlist"

# Human-readable byte size, portable across GNU and BSD.
human_size() {
  local bytes="$1"
  if [ "$bytes" -ge $((1024 * 1024)) ]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f MiB", b / 1048576 }'
  elif [ "$bytes" -ge 1024 ]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f KiB", b / 1024 }'
  else
    printf '%s B' "$bytes"
  fi
}

# ------------------------------------------------------------------------------
# Tracked file enumeration
# ------------------------------------------------------------------------------
# `git ls-files -z` is authoritative: it lists exactly what git would commit,
# which is precisely what we want to police.
list_tracked_files() {
  git ls-files -z 2>/dev/null | tr '\0' '\n'
}

# ------------------------------------------------------------------------------
# Binary detection — text-only checks must not run against images or fonts.
#
# A file is binary when it has a known binary extension, or when it contains a
# NUL byte near its start (the heuristic git itself uses).
#
# Everything here is byte-oriented and pinned to LC_ALL=C. The previous version
# compared `${#chunk}` of `chunk="$(head -c 8000 file)"` against `wc -c`, which
# was wrong twice over: command substitution silently drops NUL bytes, so a
# real binary was never detected, and under a UTF-8 locale `${#chunk}` counts
# characters while `wc -c` counts bytes, so every text file containing "—", "✓"
# or "©" was classified as binary and skipped. The GitHub runners use C.UTF-8:
# on main the secret scan read 12 of 75 tracked files.
# ------------------------------------------------------------------------------
has_binary_extension() {
  case "${1##*.}" in
    png|jpg|jpeg|gif|webp|avif|bmp|ico|icns|pdf|woff|woff2|ttf|otf|eot|mp3|mp4|webm|mov|zip|gz|tgz|tar|rar|7z|wasm)
      return 0 ;;
  esac
  return 1
}

is_binary_file() {
  local f="$1" nul_bytes
  has_binary_extension "$f" && return 0
  # Count the NUL bytes in the first 8 KB straight from the byte stream: they
  # never pass through a shell variable, so none of them can be dropped.
  nul_bytes="$(head -c 8000 -- "$f" 2>/dev/null | LC_ALL=C tr -dc '\000' | wc -c | tr -d ' ')"
  [ "${nul_bytes:-0}" -gt 0 ]
}

# select_text_files <path>...
#   Prints, one per line and in input order, the given paths that exist, are
#   non-empty and are text. Empty files are left out: there is nothing in them
#   for a content check to find.
#
#   One `grep` covers the whole list. Testing files one at a time cost several
#   processes per file, and on Git for Windows — where most contributors run
#   the hooks — process start-up is nearly the whole cost of these checks.
select_text_files() {
  local f
  local -a candidates=()
  for f in "$@"; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    has_binary_extension "$f" && continue
    candidates+=("$f")
  done
  [ "${#candidates[@]}" -gt 0 ] || return 0
  # -I treats a file containing a NUL byte as matching nothing; an empty
  # pattern matches every line, so -l lists every other non-empty file.
  printf '%s\0' "${candidates[@]}" | LC_ALL=C xargs -0 grep -Il -e '' -- 2>/dev/null
  return 0
}

# grep_text_files <grep arguments...>
#   Runs one `grep -nH --null` over every path in the caller's TEXT_FILES array.
#   Each hit is printed as "<path> NUL <line>:<text>", so a caller reads it with
#
#     while IFS= read -r -d '' file && IFS= read -r rest; do ...
#
#   and the path may contain any character, including ':'.
grep_text_files() {
  [ "${#TEXT_FILES[@]}" -gt 0 ] || return 0
  printf '%s\0' "${TEXT_FILES[@]}" | LC_ALL=C xargs -0 grep -nH --null "$@" -- 2>/dev/null
  return 0
}

# file_sizes <path>...
#   Prints "<bytes> TAB <path>" for each existing path, in one `stat` process
#   (GNU or BSD flavour) rather than one per file.
file_sizes() {
  local f
  local -a existing=()
  for f in "$@"; do
    [ -n "$f" ] && [ -f "$f" ] && existing+=("$f")
  done
  [ "${#existing[@]}" -gt 0 ] || return 0
  if stat -c '%s' -- "${existing[0]}" >/dev/null 2>&1; then
    printf '%s\0' "${existing[@]}" | xargs -0 stat -c $'%s\t%n' -- 2>/dev/null
  else
    printf '%s\0' "${existing[@]}" | xargs -0 stat -f $'%z\t%N' -- 2>/dev/null
  fi
  return 0
}

# ------------------------------------------------------------------------------
# Allowlists
# ------------------------------------------------------------------------------
# Reads a newline-delimited allowlist file into the global array
# ALLOWLIST_PATTERNS, ignoring blank lines and `#` comments.
load_allowlist() {
  local file="$1"
  ALLOWLIST_PATTERNS=()
  [ -f "$file" ] || return 0
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    ALLOWLIST_PATTERNS+=("$line")
  done < "$file"
}

# True when $1 matches any entry of the loaded allowlist.
is_allowlisted() {
  local candidate="$1" pat
  for pat in "${ALLOWLIST_PATTERNS[@]:-}"; do
    [ -z "$pat" ] && continue
    # shellcheck disable=SC2053
    if [[ "$candidate" == $pat ]]; then
      return 0
    fi
  done
  return 1
}

# ------------------------------------------------------------------------------
# Failure accumulator
#
# Checks never `exit 1` on the first problem: they collect everything and print
# one complete report. Reviewers fix a whole list in one pass instead of
# playing whack-a-mole across CI runs.
# ------------------------------------------------------------------------------
ERRORS=0
WARNINGS=0

# The second argument is the optional GitHub Actions annotation text; without
# it the human-readable message is used, so a caller can never accidentally
# trigger an "unbound variable" failure under `set -u`.
record_error() {
  ERRORS=$((ERRORS + 1))
  log_fail "$1"
  gha_error "${2:-$1}"
}

record_warning() {
  WARNINGS=$((WARNINGS + 1))
  log_warn "$1"
  gha_warning "${2:-$1}"
}

finish() {
  local label="$1"
  if [ "$ERRORS" -gt 0 ]; then
    printf '\n%s%s FAILED%s — %s error(s), %s warning(s).\n' \
      "$C_RED" "$label" "$C_RESET" "$ERRORS" "$WARNINGS"
    exit 1
  fi
  printf '\n%s%s PASSED%s — %s warning(s).\n' "$C_GREEN" "$label" "$C_RESET" "$WARNINGS"
  exit 0
}
