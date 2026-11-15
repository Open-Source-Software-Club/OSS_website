#!/usr/bin/env bash
# ==============================================================================
# check-pr-agent-workflow.sh
#
# Asserts that the privileged PR-Agent workflow (.github/workflows/pr-agent.yml)
# complies with strict security invariant constraints:
#
#   1. Zero code checkout: `actions/checkout` must never be present.
#   2. Zero shell execution: no `run:` steps may exist.
#   3. Trigger constraints: `pull_request_target` (for PR lifecycle events) and
#      `issue_comment` (for slash commands) must remain present.
#   4. Token permissions: `contents` must be `read` (never `write`), `issues`
#      and `pull-requests` must be `write`.
#   5. Exact authorization logic: slash commands must match the canonical
#      approved expression rejecting bots, non-PR comments, non-slash comments,
#      and external PR authors, while authorizing only OWNER, MEMBER, and
#      COLLABORATOR roles.
#
# Usage:
#   scripts/checks/check-pr-agent-workflow.sh          # validate live workflow
#   scripts/checks/check-pr-agent-workflow.sh --test   # run negative test suite
# ==============================================================================
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

RUN_SELF_TEST=0
for arg in "$@"; do
  case "$arg" in
    --test) RUN_SELF_TEST=1 ;;
    *) WORKFLOW="$arg" ;;
  esac
done

WORKFLOW="${WORKFLOW:-.github/workflows/pr-agent.yml}"

# ------------------------------------------------------------------------------
# Self-test mode: execute comprehensive negative test suite
# ------------------------------------------------------------------------------
if [ "$RUN_SELF_TEST" -eq 1 ]; then
  log_header "PR-Agent workflow security — negative test suite"

  if ! command -v python3 >/dev/null 2>&1; then
    record_error "python3 is unavailable; cannot run self-tests"
    finish "PR-Agent workflow security self-tests"
  fi

  python3 - <<'EOF'
import os
import subprocess
import sys
import tempfile
import yaml

WORKFLOW_FILE = '.github/workflows/pr-agent.yml'

with open(WORKFLOW_FILE, 'r', encoding='utf-8') as f:
    base_content = f.read()

def run_check_on_content(content, env_extra=None):
    with tempfile.NamedTemporaryFile('w', suffix='.yml') as tmp:
        tmp.write(content)
        tmp.flush()
        cmd = ['bash', 'scripts/checks/check-pr-agent-workflow.sh', tmp.name]
        env = os.environ.copy()
        if env_extra:
            env.update(env_extra)
        res = subprocess.run(cmd, capture_output=True, text=True, env=env)
        return res.returncode, res.stdout + res.stderr

tests = [
    (
        "Permissive OR branch (PR author bypass)",
        lambda c: c.replace(
            "contains(fromJSON('[\"OWNER\", \"MEMBER\", \"COLLABORATOR\"]'), github.event.comment.author_association)",
            "contains(fromJSON('[\"OWNER\", \"MEMBER\", \"COLLABORATOR\"]'), github.event.comment.author_association) || github.event.comment.user.login == github.event.issue.user.login"
        ),
        None,
        "insecure authorization bypass"
    ),
    (
        "Permissive OR branch (CONTRIBUTOR role added)",
        lambda c: c.replace(
            "contains(fromJSON('[\"OWNER\", \"MEMBER\", \"COLLABORATOR\"]'), github.event.comment.author_association)",
            "contains(fromJSON('[\"OWNER\", \"MEMBER\", \"COLLABORATOR\"]'), github.event.comment.author_association) || contains(fromJSON('[\"CONTRIBUTOR\"]'), github.event.comment.author_association)"
        ),
        None,
        "does not match the canonical approved authorization expression"
    ),
    (
        "Permissive OR branch (actor bypass)",
        lambda c: c.replace(
            "contains(fromJSON('[\"OWNER\", \"MEMBER\", \"COLLABORATOR\"]'), github.event.comment.author_association)",
            "contains(fromJSON('[\"OWNER\", \"MEMBER\", \"COLLABORATOR\"]'), github.event.comment.author_association) || github.actor == 'somebody'"
        ),
        None,
        "does not match the canonical approved authorization expression"
    ),
    (
        "Permissive OR branch (wildcard true)",
        lambda c: c.replace(
            "contains(fromJSON('[\"OWNER\", \"MEMBER\", \"COLLABORATOR\"]'), github.event.comment.author_association)",
            "contains(fromJSON('[\"OWNER\", \"MEMBER\", \"COLLABORATOR\"]'), github.event.comment.author_association) || true"
        ),
        None,
        "does not match the canonical approved authorization expression"
    ),
    (
        "Missing bot check (github.event.sender.type != 'Bot')",
        lambda c: c.replace("github.event.sender.type != 'Bot' &&", ""),
        None,
        "does not match the canonical approved authorization expression"
    ),
    (
        "Missing slash prefix check (startsWith)",
        lambda c: c.replace("startsWith(github.event.comment.body, '/') &&", ""),
        None,
        "does not match the canonical approved authorization expression"
    ),
    (
        "Missing PR check (github.event.issue.pull_request)",
        lambda c: c.replace("github.event.issue.pull_request &&", ""),
        None,
        "does not match the canonical approved authorization expression"
    ),
    (
        "Injected actions/checkout step",
        lambda c: c.replace("uses: The-PR-Agent/pr-agent", "uses: actions/checkout@v4\n      - uses: The-PR-Agent/pr-agent"),
        None,
        "actions/checkout is strictly forbidden"
    ),
    (
        "Injected shell run step",
        lambda c: c.replace("uses: The-PR-Agent/pr-agent", "run: echo pwned\n      - uses: The-PR-Agent/pr-agent"),
        None,
        "shell execution is strictly forbidden"
    ),
    (
        "Elevated permissions (contents: write)",
        lambda c: c.replace("contents: read", "contents: write"),
        None,
        "permissions.contents must be 'read'"
    ),
    (
        "Missing pull_request_target trigger",
        lambda c: c.replace("pull_request_target:", "pull_request:"),
        None,
        "missing 'pull_request_target' trigger"
    ),
    (
        "Unexpected Python validator crash",
        lambda c: c,
        {"_SIMULATE_PYTHON_FAILURE": "1"},
        "python validator failed"
    ),
]

all_passed = True
for item in tests:
    name, modifier, env_extra, expected_err = item
    modified_content = modifier(base_content)
    code, output = run_check_on_content(modified_content, env_extra=env_extra)
    if code == 0:
        print(f"  ✗ FAILED: {name} was expected to fail but passed!", file=sys.stderr)
        all_passed = False
    elif expected_err.lower() not in output.lower():
        print(f"  ✗ FAILED: {name} failed, but did not contain expected message {expected_err!r}. Output:\n{output}", file=sys.stderr)
        all_passed = False
    else:
        print(f"  ✓ PASSED: {name} caught and rejected as expected.")

# Verify baseline passes cleanly
code, output = run_check_on_content(base_content)
if code != 0:
    print(f"  ✗ FAILED: Baseline workflow failed check:\n{output}", file=sys.stderr)
    all_passed = False
else:
    print(f"  ✓ PASSED: Baseline workflow passed all security checks.")

sys.exit(0 if all_passed else 1)
EOF
  if [ $? -eq 0 ]; then
    log_ok "All negative and positive security tests passed successfully."
    finish "PR-Agent workflow security self-tests"
  else
    record_error "One or more security self-tests failed."
    finish "PR-Agent workflow security self-tests"
  fi
fi

# ------------------------------------------------------------------------------
# Production check mode: validate specified or default workflow file
# ------------------------------------------------------------------------------
log_header "PR-Agent workflow security"

if [ ! -f "$WORKFLOW" ]; then
  record_error "$WORKFLOW is missing" \
    "$WORKFLOW is required for automated PR code review. See docs/CI_CD.md."
  finish "PR-Agent workflow security"
fi

if ! command -v python3 >/dev/null 2>&1; then
  record_error "python3 is unavailable; cannot validate PR-Agent workflow" \
    "python3 is required to parse and validate .github/workflows/pr-agent.yml."
  finish "PR-Agent workflow security"
fi

findings=""
py_rc=0
findings="$(python3 - "$WORKFLOW" <<'PY' 2>&1
import os
import sys

if os.environ.get('_SIMULATE_PYTHON_FAILURE') == '1':
    sys.stderr.write("Simulated unexpected Python validator crash\n")
    sys.exit(1)

workflow_path = sys.argv[1]
problems = []


def problem(path, message):
    problems.append((os.path.relpath(path), message))


try:
    import yaml
except ImportError:
    sys.stderr.write("PyYAML is not installed; cannot perform structural validation.\n")
    sys.exit(1)

try:
    with open(workflow_path, 'r', encoding='utf-8') as fh:
        data = yaml.safe_load(fh)
except Exception as exc:
    problem(workflow_path, f'failed to parse YAML: {exc}')
    print('\n'.join(f'{p}\t{m}' for p, m in problems))
    sys.exit(0)

if not isinstance(data, dict):
    problem(workflow_path, 'workflow YAML must define an object.')
    print('\n'.join(f'{p}\t{m}' for p, m in problems))
    sys.exit(0)

# ---------------------------------------------------------------------------
# 1. Triggers
# ---------------------------------------------------------------------------
triggers = data.get('on') or data.get(True)
if not isinstance(triggers, dict):
    problem(workflow_path, "missing 'on' trigger configuration.")
else:
    pr_target = triggers.get('pull_request_target')
    if not isinstance(pr_target, dict):
        problem(workflow_path, "missing 'pull_request_target' trigger configuration.")
    else:
        branches = pr_target.get('branches') or []
        if 'main' not in branches:
            problem(workflow_path, "'pull_request_target' must target 'main' branch.")
        types = pr_target.get('types') or []
        for req_type in ['opened', 'reopened', 'ready_for_review', 'synchronize']:
            if req_type not in types:
                problem(workflow_path, f"'pull_request_target.types' missing required event type: {req_type!r}.")

    issue_comment = triggers.get('issue_comment')
    if not isinstance(issue_comment, dict):
        problem(workflow_path, "missing 'issue_comment' trigger configuration.")
    else:
        c_types = issue_comment.get('types') or []
        if 'created' not in c_types:
            problem(workflow_path, "'issue_comment.types' must include 'created'.")

# ---------------------------------------------------------------------------
# 2. Permissions
# ---------------------------------------------------------------------------
perms = data.get('permissions') or {}
if not isinstance(perms, dict):
    problem(workflow_path, 'missing or invalid top-level permissions block.')
else:
    contents_perm = perms.get('contents')
    if contents_perm != 'read':
        problem(workflow_path, f"permissions.contents must be 'read', found {contents_perm!r}.")
    issues_perm = perms.get('issues')
    if issues_perm != 'write':
        problem(workflow_path, f"permissions.issues must be 'write', found {issues_perm!r}.")
    pr_perm = perms.get('pull-requests')
    if pr_perm != 'write':
        problem(workflow_path, f"permissions.pull-requests must be 'write', found {pr_perm!r}.")

# ---------------------------------------------------------------------------
# 3. Canonical Authorization Expression for ai-review job
# ---------------------------------------------------------------------------
APPROVED_IF_NORMALIZED = (
    "github.event.sender.type != 'Bot' && ("
    " github.event_name != 'issue_comment' || ("
    " github.event.issue.pull_request &&"
    " startsWith(github.event.comment.body, '/') &&"
    ' contains(fromJSON(\x27["OWNER", "MEMBER", "COLLABORATOR"]\x27),'
    " github.event.comment.author_association) ) )"
)

jobs = data.get('jobs') or {}
if not isinstance(jobs, dict) or not jobs:
    problem(workflow_path, "workflow defines no 'jobs'.")
else:
    ai_review_job = jobs.get('ai-review')
    if not isinstance(ai_review_job, dict):
        problem(workflow_path, "missing required job 'ai-review'.")
    else:
        job_if = ai_review_job.get('if')
        if not isinstance(job_if, str):
            problem(workflow_path, "job 'ai-review' missing required 'if:' authorization guard.")
        else:
            normalized_if = ' '.join(job_if.split())
            if 'github.event.comment.user.login == github.event.issue.user.login' in normalized_if:
                problem(
                    workflow_path,
                    "job 'ai-review' contains insecure authorization bypass allowing PR authors to trigger slash commands."
                )
            if normalized_if != APPROVED_IF_NORMALIZED:
                problem(
                    workflow_path,
                    f"job 'ai-review' authorization condition in 'if:' does not match the canonical approved authorization expression.\n"
                    f"  Expected: {APPROVED_IF_NORMALIZED}\n"
                    f"  Found:    {normalized_if}"
                )

    for job_id, job in jobs.items():
        if not isinstance(job, dict):
            continue

        job_perms = job.get('permissions')
        if isinstance(job_perms, dict):
            if job_perms.get('contents') not in (None, 'read'):
                problem(workflow_path, f"job {job_id!r} elevates permissions.contents to {job_perms.get('contents')!r}.")

        steps = job.get('steps') or []
        if not isinstance(steps, list):
            problem(workflow_path, f"job {job_id!r} steps must be a list.")
            continue

        for idx, step in enumerate(steps):
            if not isinstance(step, dict):
                continue
            step_name = step.get('name') or f'step {idx}'

            uses = step.get('uses')
            if isinstance(uses, str) and ('actions/checkout' in uses.lower() or 'checkout' in uses.lower()):
                problem(workflow_path, f"job {job_id!r} {step_name!r} uses '{uses}': actions/checkout is strictly forbidden in pull_request_target workflows.")

            if 'run' in step:
                problem(workflow_path, f"job {job_id!r} {step_name!r} contains a shell 'run:' step: shell execution is strictly forbidden in PR-Agent workflow.")

print('\n'.join(f'{p}\t{m}' for p, m in problems))
PY
)" || py_rc=$?

if [ "$py_rc" -ne 0 ]; then
  record_error "Python validator failed (exit code $py_rc): ${findings:-unknown failure}" \
    "Python validator failed with exit code $py_rc: ${findings:-unknown failure}"
elif [ -n "$findings" ]; then
  while IFS=$'\t' read -r file message; do
    [ -z "$file" ] && continue
    record_error "$(basename "$file"): $message" \
      "$file: $message"
  done <<< "$findings"
fi

if [ "$ERRORS" -eq 0 ]; then
  log_ok "PR-Agent workflow obeys all security constraints (no checkout, no shell run, restricted permissions, canonical guard)"
fi

finish "PR-Agent workflow security"
