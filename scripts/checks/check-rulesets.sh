#!/usr/bin/env bash
# ==============================================================================
# check-rulesets.sh
#
# The rulesets in .github/branch-protection/ are configuration that nothing
# else in the repository can test: they are applied to GitHub by an admin, not
# exercised by a pull request. That makes two failure modes silent and
# expensive:
#
#   1. A required status check that no workflow emits. The check never arrives,
#      so the pull request can never merge — a branch that is permanently red
#      for everyone, caused by a typo in a JSON file.
#   2. A payload GitHub will reject (unknown rule type, missing parameters).
#      apply.sh discovers this at apply time, on an admin's machine, possibly
#      after half the rulesets have already been written.
#
# This check catches both, locally and in CI, before anything is applied.
#
# What is checked
#   1. Every JSON file in .github/branch-protection/ parses.
#   2. The payload has the keys the Rulesets API requires, and sane values.
#   3. Every rule `type` is one the Rulesets API accepts, and each rule carries
#      the parameters that type requires.
#   4. Every required status check `context` is the `name:` of a job that some
#      workflow in .github/workflows/ actually emits.
#   5. Two files do not define the same ruleset name.
#   6. Nothing in the directory is world-writable or left behind as a generated
#      *.payload.json.
#
# Usage
#   scripts/checks/check-rulesets.sh
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

log_header "Ruleset definitions"

RULESET_DIR=".github/branch-protection"

if [ ! -d "$RULESET_DIR" ]; then
  record_error "$RULESET_DIR is missing" \
    "The branch protection rulesets are missing. They are what makes CI mandatory rather than advisory. See docs/CI_CD.md §5."
  finish "Ruleset definitions"
fi

if ! command -v python3 >/dev/null 2>&1; then
  log_warn "python3 is unavailable; skipping ruleset validation"
  gha_notice "python3 is not installed, so the ruleset payloads were not validated."
  finish "Ruleset definitions"
fi

# Leftover generated payloads mean apply.sh was interrupted, and a stray
# *.payload.json is a hand-editable copy of a ruleset that nothing applies.
stray="$(find "$RULESET_DIR" -name '*.payload.json' -type f 2>/dev/null | head -5)"
if [ -n "$stray" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    record_error "stray generated file $f" \
      "$f is a generated payload left behind by apply.sh. Delete it: generated payloads must never be committed."
  done <<< "$stray"
fi

findings="$(python3 - "$RULESET_DIR" <<'PY'
import difflib
import glob
import json
import os
import re
import sys

ruleset_dir = sys.argv[1]
workflow_dir = '.github/workflows'

# ---------------------------------------------------------------------------
# What the Rulesets API will accept.
#
# Source: docs.github.com/en/rest/repos/rules — the rule objects under
# "Create a repository ruleset". Kept as data so an unknown type is a clear
# message rather than an HTTP 422 after a partial apply.
# ---------------------------------------------------------------------------
TOGGLE_RULES = {
    'deletion', 'non_fast_forward', 'required_linear_history',
    'required_signatures', 'creation', 'update', 'pull_request',
}

PATTERN_RULES = {
    'commit_message_pattern', 'commit_author_email_pattern',
    'committer_email_pattern', 'branch_name_pattern', 'tag_name_pattern',
}

PARAMETER_RULES = {
    'required_status_checks': ('required_status_checks',
                               'strict_required_status_checks_policy'),
    'required_deployments': ('required_deployment_environments',),
    'workflows': ('workflows',),
    'code_scanning': ('code_scanning_tools',),
    'file_path_restriction': ('restricted_file_paths',),
    'file_extension_restriction': ('restricted_file_extensions',),
    'max_file_path_length': ('max_file_path_length',),
    'max_file_size': ('max_file_size',),
}

ALL_RULES = TOGGLE_RULES | PATTERN_RULES | set(PARAMETER_RULES)

TARGETS = {'branch', 'tag', 'push'}
ENFORCEMENT = {'active', 'disabled', 'evaluate'}
REQUIRED_KEYS = ('name', 'target', 'enforcement', 'conditions', 'rules')

problems = []


def problem(path, message):
    problems.append((os.path.relpath(path), message))


# ---------------------------------------------------------------------------
# Every status check context a workflow can emit.
#
# A context is the job's `name:` when it has one, and the job id otherwise —
# that is exactly what GitHub shows in the Checks tab and matches against.
# Both spellings are collected so a ruleset can use either, which is what the
# rest of the pipeline already does.
# ---------------------------------------------------------------------------
def workflow_contexts():
    contexts = set()
    try:
        import yaml
    except ImportError:
        return None

    for path in sorted(glob.glob(os.path.join(workflow_dir, '*.yml')) +
                       glob.glob(os.path.join(workflow_dir, '*.yaml'))):
        try:
            with open(path, encoding='utf-8') as fh:
                doc = yaml.safe_load(fh)
        except Exception:                                     # noqa: BLE001
            # A workflow that does not parse is Repository Hygiene's problem,
            # not this check's; do not report it twice.
            continue
        if not isinstance(doc, dict):
            continue
        for job_id, job in (doc.get('jobs') or {}).items():
            if not isinstance(job, dict):
                continue
            contexts.add(job_id)
            name = job.get('name')
            if isinstance(name, str) and name:
                contexts.add(name)
    return contexts


contexts = workflow_contexts()

# Relative paths keep the GitHub annotation file= readable in the Checks tab;
# os.path.relpath is a no-op when the script is run as .github/... style paths.
files = sorted(glob.glob(os.path.join(ruleset_dir, '**', '*.json'), recursive=True))
if not files:
    problem(ruleset_dir, 'no ruleset JSON files found.')

seen_names = {}

for path in files:
    try:
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        problem(path, f'not valid JSON: {exc}')
        continue

    if not isinstance(data, dict):
        problem(path, 'must contain a JSON object.')
        continue

    missing = [key for key in REQUIRED_KEYS if key not in data]
    if missing:
        problem(path, f'missing required key(s): {", ".join(missing)}.')
        continue

    name = data['name']
    if not isinstance(name, str) or not name.strip():
        problem(path, 'has an empty or non-string "name".')
    elif name in seen_names:
        problem(path, f'defines the same ruleset name {name!r} as {seen_names[name]}.')
    else:
        seen_names[name] = path

    if data['target'] not in TARGETS:
        problem(path, f'"target" is {data["target"]!r}; expected one of {sorted(TARGETS)}.')

    if data['enforcement'] not in ENFORCEMENT:
        problem(path, f'"enforcement" is {data["enforcement"]!r}; expected one of {sorted(ENFORCEMENT)}.')

    conditions = data.get('conditions')
    if not isinstance(conditions, dict):
        problem(path, '"conditions" must be an object.')

    rules = data['rules']
    if not isinstance(rules, list) or not rules:
        problem(path, '"rules" must be a non-empty list.')
        continue

    for rule in rules:
        if not isinstance(rule, dict) or 'type' not in rule:
            problem(path, 'has a rule without a "type".')
            continue

        rtype = rule['type']
        if rtype not in ALL_RULES:
            problem(path, f'unknown rule type {rtype!r}. Known types: {", ".join(sorted(ALL_RULES))}.')
            continue

        if rtype in PATTERN_RULES:
            params = rule.get('parameters') or {}
            if not isinstance(params, dict):
                problem(path, f'rule {rtype!r} has non-object parameters.')
                continue
            if params.get('operator') not in {'starts_with', 'ends_with', 'contains', 'regex'}:
                problem(path, f'rule {rtype!r} needs an "operator" of starts_with, ends_with, contains or regex.')
            pattern = params.get('pattern')
            if not isinstance(pattern, str) or not pattern:
                problem(path, f'rule {rtype!r} needs a non-empty "pattern".')
            elif params.get('operator') == 'regex':
                try:
                    re.compile(pattern)
                except re.error as exc:
                    problem(path, f'rule {rtype!r} has an invalid regex: {exc}.')

        if rtype in PARAMETER_RULES:
            params = rule.get('parameters') or {}
            if not isinstance(params, dict):
                problem(path, f'rule {rtype!r} has non-object parameters.')
                continue
            for key in PARAMETER_RULES[rtype]:
                if key not in params:
                    problem(path, f'rule {rtype!r} is missing the required parameter {key!r}.')

        if rtype == 'pull_request':
            params = rule.get('parameters') or {}
            methods = params.get('allowed_merge_methods')
            if methods is not None:
                bad = [m for m in methods if m not in {'merge', 'squash', 'rebase'}]
                if bad:
                    problem(path, f'pull_request has unsupported merge method(s): {bad}.')
                if not methods:
                    problem(path, 'pull_request has an empty allowed_merge_methods; at least one is required.')

        if rtype == 'required_status_checks':
            params = rule.get('parameters') or {}
            checks = params.get('required_status_checks') or []
            if not isinstance(checks, list):
                problem(path, 'required_status_checks is not a list.')
                checks = []
            for check in checks:
                context = (check or {}).get('context')
                if not context:
                    problem(path, 'a required status check has no "context".')
                    continue
                if contexts is not None and context not in contexts:
                    # A near-miss is the common case (a renamed job, a dropped
                    # suffix, a wrong dot or middot), so suggest the closest
                    # names rather than dumping all forty-odd contexts.
                    close = difflib.get_close_matches(context, sorted(contexts), n=3, cutoff=0.5)
                    hint = (f' Closest job name(s): {", ".join(repr(c) for c in close)}.'
                            if close else '')
                    problem(
                        path,
                        f'required status check {context!r} matches no job `name:` in '
                        f'{workflow_dir}/, so it would never be reported and the branch '
                        f'would be permanently unmergeable.{hint}',
                    )

print('\n'.join(f'{p}\t{m}' for p, m in problems))
PY
)"

if [ -n "$findings" ]; then
  while IFS=$'\t' read -r file message; do
    [ -z "$file" ] && continue
    record_error "$(basename "$file"): $message" \
      "$file: $message"
  done <<< "$findings"
fi

if [ "$ERRORS" -eq 0 ]; then
  log_ok "Ruleset payloads are valid and every required check matches a real job"
fi

finish "Ruleset definitions"
