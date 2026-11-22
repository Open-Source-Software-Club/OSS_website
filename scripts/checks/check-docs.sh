#!/usr/bin/env bash
# ==============================================================================
# check-docs.sh
#
# Documentation integrity. The documents in docs/ are the specification the
# whole project is built from — the PRD, the schema, the integration contract —
# so a link that points at a file which no longer exists is not a cosmetic
# defect, it is a specification that nobody can follow.
#
# What is checked
#   1. Every document the project promises to maintain exists.
#   2. Every relative link and image path in every tracked Markdown file
#      resolves to a real file or directory.
#   3. No Markdown document has more than one H1, and none (except the
#      generated changelog) is missing one.
#   4. Anchors that name a document but not a section are allowed; a link to a
#      missing *file* is an error.
#
# What is deliberately not checked
#   * External URLs. A link check that depends on the network fails when GitHub
#     rate-limits the runner, which trains people to ignore it. External links
#     are covered by the scheduled advisory job instead.
#   * Heading anchors (docs/CI_CD.md#section). GitHub's slugification rules are
#     subtle enough that a wrong reimplementation would produce false failures.
#
# Usage
#   bash scripts/checks/check-docs.sh
#   bash scripts/checks/check-docs.sh --staged   # only staged Markdown files
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

STAGED=0
for arg in "$@"; do
  case "$arg" in
    --staged) STAGED=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

log_header "Documentation integrity"

# ------------------------------------------------------------------------------
# 1. The documents the pipeline depends on.
#
# docs/CI_CD.md is read by the hygiene job, SECURITY.md is where a vulnerability
# report is supposed to go, and the rest are the specification. A pull request
# that deletes one of them is either a mistake or a decision that deserves its
# own discussion.
# ------------------------------------------------------------------------------
REQUIRED_DOCS=(
  README.md
  CONTRIBUTING.md
  CODE_OF_CONDUCT.md
  SECURITY.md
  CHANGELOG.md
  docs/PRD.md
  docs/architecture.md
  docs/DATABASE_SCHEMA.md
  docs/GITHUB_INTEGRATION.md
  docs/GITHUB_WORKFLOW.md
  docs/GITHUB_ISSUES.md
  docs/UI_UX_SPECIFICATION.md
  docs/DEVELOPMENT_ROADMAP.md
  docs/CI_CD.md
)

for doc in "${REQUIRED_DOCS[@]}"; do
  if [ ! -f "$doc" ]; then
    record_error "Required document '$doc' is missing."
  fi
done

# ------------------------------------------------------------------------------
# 2. Relative links.
#
# Markdown files are enumerated from git, so generated or ignored files are
# never checked and the result is identical on every machine.
# ------------------------------------------------------------------------------
if [ "$STAGED" -eq 1 ]; then
  mapfile -t DOC_FILES < <(git diff --cached --name-only --diff-filter=ACMR -- '*.md')
else
  mapfile -t DOC_FILES < <(git ls-files -- '*.md')
fi

LINK_COUNT=0

for file in "${DOC_FILES[@]}"; do
  [ -f "$file" ] || continue
  # Parameter expansion rather than "$(dirname ...)": no fork per document.
  case "$file" in
    */*) dir="${file%/*}" ;;
    *)   dir='.' ;;
  esac

  # Strip fenced code blocks first: a shell snippet or an example link inside a
  # fence is sample text, not a link that has to resolve.
  targets="$(
    awk '
      /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
      fence { next }
      { print }
    ' "$file" \
    | sed -E 's/`[^`]*`//g' \
    | grep -oE '\]\([^)]*\)|^[[:space:]]*\[[^]]+\]:[[:space:]]*[^[:space:]]+' \
    | sed -E 's/^\]\(//; s/\)$//; s/^[[:space:]]*\[[^]]+\]:[[:space:]]*//' \
    || true
  )"

  while IFS= read -r raw; do
    [ -z "$raw" ] && continue

    target="$raw"

    # Drop a title: ](path "Title") and <path>
    target="${target%%[[:space:]]*}"
    target="${target#<}"
    target="${target%>}"

    # Fragments, query strings and fully-qualified URLs are out of scope.
    target="${target%%#*}"
    target="${target%%\?*}"

    [ -z "$target" ] && continue

    case "$target" in
      http://*|https://*|mailto:*|tel:*|ftp:*|//*) continue ;;
      /*) continue ;;                        # site-absolute, not a repo path
      '{'*|'<'*|'$'*) continue ;;            # template placeholders
      '#'*|'?') continue ;;
    esac

    # Markdown and URLs escape spaces; the filesystem does not.
    target="${target//%20/ }"

    LINK_COUNT=$((LINK_COUNT + 1))

    if [ ! -e "$dir/$target" ]; then
      record_error "'$file' links to '$target', which does not exist."
    fi
  done <<< "$targets"
done

# ------------------------------------------------------------------------------
# 3. One H1 per document.
#
# GitHub renders the first H1 as the page title. A second H1 in the body is
# almost always a section that used the wrong level, and it breaks the document
# outline that screen readers navigate by.
# ------------------------------------------------------------------------------
for file in "${DOC_FILES[@]}"; do
  [ -f "$file" ] || continue

  h1_count="$(
    awk '
      /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
      !fence && /^# [^#]/ { n++ }
      END { print n + 0 }
    ' "$file"
  )"

  if [ "$h1_count" -eq 0 ]; then
    record_warning "'$file' has no level-1 heading."
  elif [ "$h1_count" -gt 1 ]; then
    record_error "'$file' has $h1_count level-1 headings; a document has exactly one."
  fi
done

if [ "${#DOC_FILES[@]}" -eq 0 ]; then
  log_warn "No Markdown files found to check."
else
  log_ok "Checked ${#DOC_FILES[@]} Markdown file(s) and $LINK_COUNT relative link(s)."
fi

finish "Documentation integrity"
