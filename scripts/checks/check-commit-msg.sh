#!/usr/bin/env bash
# ==============================================================================
# check-commit-msg.sh
#
# Enforces Conventional Commits, as required by CONTRIBUTING.md:
#
#   <type>(<scope>): <subject>
#
#   feat(projects): add search filter by programming language
#
# Rules enforced:
#   1. Header matches `type(optional-scope)!: subject`
#   2. `type` is one of the documented set
#   3. Subject is 1..72 characters, lowercase-start, no trailing period
#   4. A blank line separates the header from the body
#   5. No body line exceeds 100 characters
#   6. Footers use `Closes #123` / `BREAKING CHANGE: ...`
#
# Usage:
#   check-commit-msg.sh <message-file>      # git hook style
#   check-commit-msg.sh --range <rev-range> # CI style (all PR commits)
#   check-commit-msg.sh --stdin            # read one message from stdin
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|release|wip'
HEADER_RE="^($TYPES)(\\([a-z0-9][a-z0-9._/-]*\\))?(!)?: [^ ]"
# `git revert` and GitHub's Revert button both write 'Revert "<original>"'.
# commitlint accepts that form by default; rejecting it blocks an emergency
# revert behind a reword nobody needs.
REVERT_RE='^Revert ".+"$'
MAX_SUBJECT=72
MAX_BODY=100

log_header "Commit message (Conventional Commits)"

check_message() {
  local label="$1" msg="$2"
  local header line n=0 ok=1

  header="$(printf '%s' "$msg" | head -1)"

  # A generated revert header is valid as-is and has no "type: subject" to
  # measure, so the subject rules below do not apply to it.
  if printf '%s' "$header" | grep -Eq -- "$REVERT_RE"; then
    log_ok "$label is a revert of an earlier commit"
    return 0
  fi

  # Rule 1 + 2: header shape and type.
  if ! printf '%s' "$header" | grep -Eq -- "$HEADER_RE"; then
    record_error "$label has a non-conventional header: '$header'" \
      "Commit '$label' header '$header' is not a Conventional Commit. Expected '<type>(<scope>): <subject>' with type in {feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert}. Example: 'feat(events): add RSVP button'."
    ok=0
  fi

  # Rule 3: subject length.
  subject="${header#*: }"
  if [ "${#subject}" -gt "$MAX_SUBJECT" ]; then
    record_warning "$label subject is ${#subject} characters (max $MAX_SUBJECT)" \
      "Commit '$label' subject is ${#subject} characters; keep it under $MAX_SUBJECT so it reads well in 'git log --oneline'."
  fi
  if printf '%s' "$subject" | grep -q '\.$'; then
    record_warning "$label subject ends with a period" \
      "Commit '$label' subject ends with a full stop. Conventional Commits subjects have no trailing period."
  fi

  # Rule 4: blank line after the header when a body follows.
  if [ "$(printf '%s' "$msg" | wc -l)" -ge 2 ]; then
    second="$(printf '%s' "$msg" | sed -n '2p')"
    if [ -n "$second" ]; then
      record_warning "$label has no blank line after the header" \
        "Commit '$label' is missing the blank line between the subject and the body."
    fi
  fi

  # Rule 5: body line length.
  while IFS= read -r line; do
    n=$((n + 1))
    [ "$n" -le 2 ] && continue
    if [ "${#line}" -gt "$MAX_BODY" ]; then
      record_warning "$label body line $n is ${#line} characters (max $MAX_BODY)" \
        "Commit '$label' body line $n exceeds $MAX_BODY characters. Wrap the body for readability."
      break
    fi
  done < <(printf '%s\n' "$msg")

  # Rule 6: footers are recognised, anything else in the footer block is fine.
  printf '%s' "$msg" | grep -Eq '(Closes|Fixes|Resolves|Refs|Related to) +#?[0-9]+|BREAKING CHANGE:' \
    && log_ok "$label references an issue or declares a breaking change"

  [ "$ok" -eq 1 ] && log_ok "$label is a valid Conventional Commit"
  return 0
}

case "${1:-}" in
  --range)
    RANGE="$2"
    mapfile -t SUBJECTS < <(git log --format='%H%x09%s' --no-merges "$RANGE" 2>/dev/null)
    if [ "${#SUBJECTS[@]}" -eq 0 ]; then
      log_ok "No commits in range $RANGE"
    else
      for entry in "${SUBJECTS[@]}"; do
        sha="${entry%%$'\t'*}"
        subj="${entry#*$'\t'}"
        check_message "${sha:0:8} ($subj)" "$subj"
      done
    fi
    ;;
  --stdin)
    MSG="$(cat)"
    check_message "commit" "$MSG"
    ;;
  '')
    printf 'Usage: %s <message-file> | --range <rev-range> | --stdin\n' "$0" >&2
    exit 2
    ;;
  *)
    # git hook style: the argument is a file containing the message.
    if [ ! -f "$1" ]; then
      printf 'No such message file: %s\n' "$1" >&2
      exit 2
    fi
    MSG="$(cat "$1")"
    check_message "commit" "$MSG"
    ;;
esac

finish "Commit message check"
