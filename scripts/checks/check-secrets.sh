#!/usr/bin/env bash
# ==============================================================================
# check-secrets.sh
#
# Content-based secret scanning over every text file tracked by git.
#
# This is the hard gate that keeps credentials, private keys and API tokens out
# of the repository. It is deliberately dependency-free (POSIX ERE + git) so it
# runs identically on a contributor's laptop (pre-commit hook) and on the CI
# runner, with no tool to install and no licence key to manage.
#
# Severity model
#   ERROR   — a specific, high-confidence vendor pattern (a real leak).
#   WARNING — a generic "looks like a secret" assignment. Humans review these;
#             set STRICT=1 to promote them to errors.
#
# Usage:
#   scripts/checks/check-secrets.sh [--strict] [--staged]
#
#   --strict  promote warnings to errors (used for release branches)
#   --staged  scan only the git index (used by the pre-commit hook)
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

STRICT=0
STAGED=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --staged) STAGED=1 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

log_header "Secret scanning"

# ------------------------------------------------------------------------------
# High-confidence patterns (POSIX ERE). A match here is almost never legitimate.
# ------------------------------------------------------------------------------
PRIVATE_KEY_RE='-----BEGIN[[:space:]]?[A-Z0-9 ]*PRIVATE KEY-----'
GITHUB_TOKEN_RE='(ghp|gho|ghu|ghs|ghr|github_pat)_[A-Za-z0-9_]{16,}'
AWS_KEY_ID_RE='(AKIA|ASIA|ABIA|ACCA)[0-9A-Z]{16}'
AWS_SECRET_RE='aws.{0,20}(secret|access).{0,4}key.{0,4}["'"'"']?[=:][[:space:]]*["'"'"']?[A-Za-z0-9/+=]{40}'
GOOGLE_API_RE='AIza[0-9A-Za-z_-]{35}'
SLACK_TOKEN_RE='xox[baprs]-[0-9A-Za-z-]{10,}'
SLACK_WEBHOOK_RE='https://hooks\.slack\.com/services/[A-Za-z0-9/]{20,}'
STRIPE_RE='(sk|rk|pk)_(live|test)_[0-9a-zA-Z]{16,}'
SUPABASE_JWT_RE='eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'
NPM_TOKEN_RE='npm_[A-Za-z0-9]{36}'
SENDGRID_RE='SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
TWILIO_RE='SK[0-9a-fA-F]{32}'

# A JWT that is a Supabase *service-role* key is the single most damaging thing
# that could ever be committed to this repo (it bypasses Row Level Security).
SUPABASE_SERVICE_RE='(SUPABASE_SERVICE_ROLE_KEY|SERVICE_ROLE_KEY|service_role)'

# ------------------------------------------------------------------------------
# Generic assignment patterns — noisy by nature, so they are warnings.
# ------------------------------------------------------------------------------
GENERIC_SECRET_RE='(password|passwd|pwd|secret|token|api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|client[_-]?secret|auth[_-]?token|bearer)[[:space:]]*(=>|[:=])[[:space:]]*["'"'"']?[A-Za-z0-9/+=_.-]{16,}'

# Lines matching any of these are examples, placeholders or indirections, not
# real secrets. Keep this list tight and explicit.
PLACEHOLDER_RE='PLACEHOLDER|CHANGEME|CHANGE_ME|REDACTED|<[A-Za-z0-9_ -]+>|xxxx+|XXXX+|YOUR[_-]|your[_-]|example\.(com|org|net)|dummy|sample|fake|not[_-]?real|process\.env|import\.meta\.env|os\.environ|Deno\.env|\$\{\{|\$\(|\.\.\.|\*\*\*'

# ------------------------------------------------------------------------------
# Enumerate the files to scan
# ------------------------------------------------------------------------------
if [ "$STAGED" -eq 1 ]; then
  # Pre-commit: only what is about to be committed, deleted files excluded.
  # Renames (R) are included: `git mv` plus an edit is still new content.
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null | tr '\0' '\n')
else
  mapfile -t FILES < <(list_tracked_files)
fi

existing=0
for file in "${FILES[@]:-}"; do
  [ -n "$file" ] && [ -f "$file" ] && existing=$((existing + 1))
done

mapfile -t TEXT_FILES < <(select_text_files "${FILES[@]:-}")
scanned=${#TEXT_FILES[@]}
skipped=$((existing - scanned))

HIGH_CONFIDENCE_RE="$PRIVATE_KEY_RE|$GITHUB_TOKEN_RE|$AWS_KEY_ID_RE|$AWS_SECRET_RE|$GOOGLE_API_RE|$SLACK_TOKEN_RE|$SLACK_WEBHOOK_RE|$STRIPE_RE|$NPM_TOKEN_RE|$SENDGRID_RE|$TWILIO_RE|$SUPABASE_JWT_RE"

# --- high-confidence patterns ---------------------------------------------
# One grep over every text file per pattern set. Hits are rare, so the
# per-hit classification below costs nothing on a clean tree.
while IFS= read -r -d '' file && IFS= read -r rest; do
  lineno="${rest%%:*}"
  text="${rest#*:}"

  if printf '%s' "$text" | grep -Eq -- "$PLACEHOLDER_RE"; then
    record_warning "$file:$lineno looks like a credential but is clearly a placeholder" \
      "Possible placeholder secret at $file:$lineno — verify it is not a real value."
    continue
  fi

  # Supabase service-role JWT is the highest-impact leak: always an error.
  if printf '%s' "$text" | grep -Eq "$SUPABASE_JWT_RE" \
     && printf '%s' "$text" | grep -Eqi -- "$SUPABASE_SERVICE_RE"; then
    record_error "$file:$lineno contains a Supabase service-role key" \
      "SECURITY: a Supabase service-role JWT was found at $file:$lineno. This key bypasses Row Level Security. Remove it from history (git filter-repo), rotate it in the Supabase dashboard, and force-push."
    continue
  fi

  record_error "$file:$lineno contains a credential-like string" \
    "SECURITY: possible hardcoded credential at $file:$lineno. Remove it, move it to an environment variable, and rotate the exposed value."
done < <(grep_text_files -E -e "$HIGH_CONFIDENCE_RE")

# --- generic assignments ---------------------------------------------------
while IFS= read -r -d '' file && IFS= read -r rest; do
  lineno="${rest%%:*}"
  text="${rest#*:}"

  if printf '%s' "$text" | grep -Eq -- "$PLACEHOLDER_RE"; then
    continue
  fi

  if [ "$STRICT" -eq 1 ]; then
    record_error "$file:$lineno contains a possible hardcoded secret" \
      "Possible hardcoded secret at $file:$lineno (strict mode)."
  else
    record_warning "$file:$lineno contains a possible hardcoded secret" \
      "Possible hardcoded secret at $file:$lineno — if it is real, remove it and rotate the value."
  fi
done < <(grep_text_files -E -e "$GENERIC_SECRET_RE")

log_ok "Scanned $scanned text file(s), skipped $skipped binary or empty file(s)"

finish "Secret scan"
