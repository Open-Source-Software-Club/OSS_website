#!/usr/bin/env bash
# ==============================================================================
# check-text-hygiene.sh
#
# Whitespace and encoding hygiene. These are the defects that produce 400-line
# "formatting only" diffs and make `git blame` useless, so they are blocked at
# commit time rather than argued about in review.
#
# Rules (text files only; binaries are skipped):
#   * no trailing whitespace  (two trailing spaces in Markdown = hard break, allowed)
#   * no tab characters
#   * no CRLF line endings    (.gitattributes forces LF)
#   * file ends with exactly one newline
#   * no UTF-8 BOM            (warning only)
#   * no lines longer than 400 bytes (warning only)
#
# Performance
#   The whole file list goes through one `awk` pass and one `tail`, instead of
#   about a dozen processes per file. On Git for Windows that took this check
#   from ~34 s to ~1 s on a 75-file tree, and it is part of every `git push`.
#
# Usage:
#   scripts/checks/check-text-hygiene.sh [--staged]
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

log_header "Text hygiene"

MAX_LINE=400

if [ "$STAGED" -eq 1 ]; then
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null | tr '\0' '\n')
else
  mapfile -t FILES < <(list_tracked_files)
fi

mapfile -t TEXT_FILES < <(select_text_files "${FILES[@]:-}")
checked=${#TEXT_FILES[@]}

if [ "$checked" -gt 0 ]; then
  # ---- CRLF: git's own line-ending report -------------------------------------
  # `git ls-files --eol` reads the bytes itself, so it is exact on every
  # platform. grep is not: GNU grep on Windows strips '\r' before matching
  # unless given -U (so the previous `grep $'\r'` test could never fire on the
  # machines CRLF actually comes from), and gawk there strips it too.
  #
  # The index column (i/) is what gets committed. The working-tree column is
  # legitimately CRLF on a Windows clone with core.autocrlf, which is not a
  # defect; on the CI runner the two columns are identical.
  declare -A IS_TEXT=()
  for file in "${TEXT_FILES[@]}"; do
    IS_TEXT["$file"]=1
  done
  while IFS= read -r -d '' record; do
    info="${record%%$'\t'*}"
    file="${record#*$'\t'}"
    [ -n "${IS_TEXT[$file]:-}" ] || continue
    case "$info" in
      i/crlf*|i/mixed*)
        record_error "$file has CRLF line endings" \
          "'$file' contains CRLF line endings. .gitattributes enforces LF — run 'dos2unix $file' or enable 'files.eol = lf' in your git config." ;;
    esac
  done < <(git ls-files --eol -z 2>/dev/null)

  # ---- line-level rules: one awk pass over every file -------------------------
  # Each finding is printed as "<rule> TAB <line> TAB <path>". The path is the
  # last field, so it survives `read` intact whatever characters it contains.
  #
  # LC_ALL=C keeps the pass byte-oriented on every awk (mawk on Ubuntu, BWK awk
  # on macOS, gawk on Git for Windows), so `length` and the BOM comparison mean
  # the same thing everywhere.
  while IFS=$'\t' read -r rule lineno file; do
    case "$rule" in
      trailing)
        if [[ "$file" == *.md ]]; then
          record_error "$file:$lineno has trailing whitespace" \
            "'$file' line $lineno has trailing whitespace. Markdown only allows a two-space hard break."
        else
          record_error "$file:$lineno has trailing whitespace" \
            "'$file' line $lineno has trailing whitespace. Configure your editor to trim it on save."
        fi ;;
      tab)
        record_error "$file:$lineno contains a tab character" \
          "'$file' line $lineno contains a tab. Use spaces for indentation." ;;
      blank)
        record_warning "$file ends with multiple blank lines" \
          "'$file' ends with more than one blank line. Trim to a single newline." ;;
      bom)
        record_warning "$file starts with a UTF-8 BOM" \
          "'$file' begins with a UTF-8 BOM. Remove it — it breaks shebangs, diffs and concatenation." ;;
      long)
        record_warning "$file:$lineno is longer than $MAX_LINE characters" \
          "'$file' line $lineno exceeds $MAX_LINE characters." ;;
    esac
  done < <(printf '%s\0' "${TEXT_FILES[@]}" | LC_ALL=C xargs -0 awk \
      -v max="$MAX_LINE" -v bom=$'\xef\xbb\xbf' '
    # Two or more empty lines at the very end of the previous file.
    function finish_file() {
      if (name != "" && lines >= 2 && last == "" && before_last == "")
        print "blank\t" lines "\t" name
    }
    FNR == 1 {
      finish_file()
      name = FILENAME; lines = 0; last = "x"; before_last = "x"
      markdown = (FILENAME ~ /\.md$/)
      if (substr($0, 1, 3) == bom) print "bom\t1\t" FILENAME
    }
    {
      # A CRLF ending is reported once per file by the grep above; drop the
      # "\r" here so it is not also reported as trailing whitespace on every
      # line (and so every awk sees the same line, stripped or not).
      line = $0
      sub(/\r$/, "", line)
      lines = FNR; before_last = last; last = line
      # Markdown allows exactly two trailing spaces after real text as an
      # explicit hard break; anything else at the end of a line is an error.
      if (line ~ /[[:space:]]$/ && !(markdown && line ~ /[^[:space:]]  $/))
        print "trailing\t" FNR "\t" FILENAME
      if (line ~ /\t/) print "tab\t" FNR "\t" FILENAME
      if (length(line) > max) print "long\t" FNR "\t" FILENAME
    }
    END { finish_file() }
  ' 2>/dev/null)

  # ---- final newline: the last byte of every file in one `tail` ---------------
  # Every path in TEXT_FILES is non-empty, so `tail -q -c 1` prints exactly one
  # byte per file, in order; `od` turns them into hex ("0a" is a newline).
  last_bytes=()
  IFS=$' \t\n' read -r -d '' -a last_bytes < <(
    printf '%s\0' "${TEXT_FILES[@]}" | xargs -0 tail -q -c 1 -- 2>/dev/null | od -An -v -tx1
  ) || true

  if [ "${#last_bytes[@]}" -ne "$checked" ]; then
    # A `tail` without -q, or a file that changed underneath us: fall back to
    # one file at a time rather than misattribute a byte to the wrong file.
    last_bytes=()
    for file in "${TEXT_FILES[@]}"; do
      last_bytes+=("$(tail -c 1 -- "$file" 2>/dev/null | od -An -tx1 | tr -d ' \n')")
    done
  fi

  for i in "${!TEXT_FILES[@]}"; do
    if [ "${last_bytes[$i]}" != '0a' ]; then
      record_error "${TEXT_FILES[$i]} is missing a trailing newline" \
        "'${TEXT_FILES[$i]}' does not end with a newline. POSIX text files end with one."
    fi
  done
fi

log_ok "Checked $checked text file(s)"

finish "Text hygiene check"
