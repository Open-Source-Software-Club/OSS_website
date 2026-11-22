#!/usr/bin/env bash
# ==============================================================================
# check-forbidden-files.sh
#
# Fails when a file that must never be version-controlled is tracked by git.
# This is the first line of defence against "unwanted code": build output,
# editor droppings, foreign lockfiles, private keys and dependency caches.
#
# Usage:
#   scripts/checks/check-forbidden-files.sh
#
# Exceptions: add the path/glob to .github/allowed-files.txt (reviewed via
# CODEOWNERS) instead of editing the list below.
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

log_header "Forbidden files"

# Root-anchored globs. A pattern without `/` is matched against the basename
# at any depth; a pattern with `/` is matched against the full repo-relative
# path, so `dist/*` only ever refers to the top-level `dist/` directory.
FORBIDDEN_GLOBS=(
  # ---- Foreign / conflicting package managers (pnpm is the only source) ----
  'package-lock.json' 'npm-shrinkwrap.json' '.package-lock.json'
  'yarn.lock' '.yarn-integrity'
  'bun.lockb' 'bun.lock'
  '.pnp.cjs' '.pnp.loader.mjs' '.pnp.data.json'
  '.npmrc' '.yarnrc' '.yarnrc.yml' '.pnpmfile.cjs'

  # ---- Secrets & certificates -------------------------------------------------
  '.env' '.env.local' '.env.development' '.env.production' '.env.staging'
  '.env.test' '.env.*.local' '.env.production.local'
  '*.pem' '*.key' '*.p12' '*.pfx' '*.jks' '*.keystore' '*.ppk' '*.asc'
  '*.crt' '*.cer' '*.der' '*.csr'
  'id_rsa*' 'id_dsa*' 'id_ecdsa*' 'id_ed25519*' '.ssh/*' '.gnupg/*'
  '*service-role*' '*service_role*key*'
  'secrets.json' 'secrets.yaml' 'secrets.yml' 'credentials.json'
  '.netrc' '.git-credentials' '.git-credentials.txt'

  # ---- Build & bundler output --------------------------------------------------
  'node_modules/*' '.next/*' '.nuxt/*' '.svelte-kit/*' '.output/*' '.parcel-cache/*'
  'dist/*' 'build/*' 'out/*' '.turbo/*' '.cache/*' '.vercel/*' '.serverless/*'
  'target/*' '.venv/*' '__pycache__/*' '*.pyc' '*.pyo'
  '.mypy_cache/*' '.pytest_cache/*' '.ruff_cache/*' '.nox/*' '.tox/*'
  '.pnpm-store/*' 'coverage/*' '.nyc_output/*'
  'playwright-report/*' 'test-results/*' 'blob-report/*' 'lighthouse-ci-report/*'
  '*.tsbuildinfo' '*.js.map' '*.css.map'
  'supabase/.temp/*' 'supabase/.branches/*'
  '.firebase/*' '.docusaurus/*' '.astro/*'

  # ---- Operating-system droppings ---------------------------------------------
  '.DS_Store' '.AppleDouble' '.LSOverride' '._*' '.Spotlight-V100' '.Trashes'
  '.Trash-*' '.fuse_hidden*' '.directory'
  'Thumbs.db' 'Thumbs.db:encryptable' 'ehthumbs.db' 'ehthumbs_vista.db'
  'desktop.ini' '$RECYCLE.BIN/*' '*.lnk'
  '*.stackdump'

  # ---- Editor / IDE state ------------------------------------------------------
  '.idea/*' '*.iml' '*.iws' '*.ipr' '*.code-workspace'
  '*.swp' '*.swo' '*.swn' '.*.sw?' 'Session.vim' '.netrwhist'
  '*.sublime-project' '*.sublime-workspace'
  '*.esproj' '*.tmproj'
  '.history/*' '.history'
  '.vscode/*.log' '.claude/settings.local.json'

  # ---- Logs, debug and scratch -------------------------------------------------
  '*.log' 'logs/*' 'npm-debug.log*' 'yarn-debug.log*' 'yarn-error.log*'
  'pnpm-debug.log*' 'lerna-debug.log*'
  '*.bak' '*.backup' '*.old' '*.orig' '*.rej' '*.save' '*.tmp' '*.temp'
  '*.patch' '*.diff' '*.rej'
  '*~' '*.~*'

  # ---- Archives & vendor dumps -------------------------------------------------
  '*.zip' '*.tar' '*.tgz' '*.tar.gz' '*.tar.bz2' '*.tar.xz' '*.gz' '*.bz2'
  '*.xz' '*.rar' '*.7z' '*.jar' '*.war' '*.exe' '*.dmg' '*.msi' '*.iso'
  'vendor/*' 'third_party/*'

  # ---- Personal / scratch ------------------------------------------------------
  'TODO.txt' 'NOTES.md' 'scratch/*' 'tmp/*' 'sandbox/*'
  '.arena/*' '.playwright-cli/*'
)

# Match a repo-relative path against the forbidden glob list. The matching glob
# is returned in MATCHED rather than printed: capturing it with "$(...)" forked
# a subshell for every tracked file, which is most of this check's run time on
# Git for Windows.
MATCHED=''
matches_forbidden() {
  local f="$1" pat base
  base="${f##*/}"
  for pat in "${FORBIDDEN_GLOBS[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$f" == $pat || "$base" == $pat ]]; then
      MATCHED="$pat"
      return 0
    fi
  done
  return 1
}

load_allowlist "$ALLOWED_FILES_LIST"

violations=0
if [ "$STAGED" -eq 1 ]; then
  # Pre-commit path: only police what is about to be committed. Renames (R)
  # are included, so `git mv notes.txt .env` cannot slip through.
  mapfile -t TO_CHECK < <(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null | tr '\0' '\n')
else
  mapfile -t TO_CHECK < <(list_tracked_files)
fi

for file in "${TO_CHECK[@]:-}"; do
  [ -z "$file" ] && continue

  if is_allowlisted "$file"; then
    continue
  fi

  if matches_forbidden "$file"; then
    matched="$MATCHED"
    record_error "$file (matched '$matched')" \
      "Forbidden file tracked by git: $file — remove it with 'git rm --cached $file' and ensure .gitignore covers it."
    violations=$((violations + 1))
  fi
done

if [ "$violations" -eq 0 ]; then
  log_ok "No forbidden files (${#TO_CHECK[@]} file(s) scanned)"
fi

finish "Forbidden file check"
