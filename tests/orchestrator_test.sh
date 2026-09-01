#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CLI="${PROJECT_ROOT}/bin/orchestrator"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/orchestrator-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

assert_contains() {
  local actual="$1"
  local expected="$2"

  if [[ "$actual" != *"$expected"* ]]; then
    printf 'Expected output to contain: %s\nActual output: %s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

assert_failure_contains() {
  local expected="$1"
  shift
  local output

  if output="$("$@" 2>&1)"; then
    printf 'Expected command to fail: %s\n' "$*" >&2
    exit 1
  fi

  assert_contains "$output" "$expected"
}

assert_status() {
  local phase="$1"
  local task_id="$2"
  local expected_next="$3"
  local status_output

  printf 'phase=%s\ntask_id=%s\n' "$phase" "$task_id" >"${target_dir}/.agent/STATUS.md"
  status_output="$("$CLI" status "$target_dir")"
  assert_contains "$status_output" "Phase: ${phase}"
  assert_contains "$status_output" "$expected_next"
}

target_dir="${test_root}/target"
init_output="$("$CLI" init "$target_dir")"
assert_contains "$init_output" 'Installed AGENTS.md'

for expected_file in AGENTS.md CLAUDE.md .agent/REQUEST.md .agent/PLAN.md .agent/TASKS.json .agent/REVIEW.md .agent/STATUS.md; do
  [[ -f "${target_dir}/${expected_file}" ]]
done

printf 'custom instructions\n' >"${target_dir}/AGENTS.md"
printf 'custom request\n' >"${target_dir}/.agent/REQUEST.md"
init_output="$("$CLI" init "$target_dir")"
assert_contains "$init_output" 'Preserved existing AGENTS.md'
assert_contains "$init_output" 'Preserved existing .agent/REQUEST.md'
[[ "$(<"${target_dir}/AGENTS.md")" == "custom instructions" ]]
[[ "$(<"${target_dir}/.agent/REQUEST.md")" == "custom request" ]]
"$CLI" init "$target_dir" --force >/dev/null
assert_contains "$(<"${target_dir}/AGENTS.md")" 'You are the implementation agent.'
assert_contains "$(<"${target_dir}/.agent/REQUEST.md")" 'Describe the outcome needed by the project.'

assert_failure_contains 'No workflow state found.' "$CLI" status "${test_root}/missing"

assert_status planning '' 'Next: Claude Code creates PLAN.md and TASKS.json.'
assert_status implementing 'task-001' 'Next: Codex implements task task-001 and runs validation.'
assert_status reviewing 'task-001' 'Next: Claude Code reviews the implementation in REVIEW.md.'
assert_status fixing 'task-001' 'Next: Codex applies review findings and reruns validation.'
assert_status approved 'task-001' 'Next: Claude Code selects the next pending task or completes the request.'
assert_status invalid 'task-001' 'Next: Set a supported phase in .agent/STATUS.md.'

printf ' phase = implementing \r\n task_id = task=002 \r\n' >"${target_dir}/.agent/STATUS.md"
status_output="$("$CLI" status "$target_dir")"
assert_contains "$status_output" 'Phase: implementing'
assert_contains "$status_output" 'Task: task=002'
assert_contains "$status_output" 'Next: Codex implements task task=002 and runs validation.'

fake_claude="${test_root}/fake-claude"
fake_codex="${test_root}/fake-codex"

cat >"$fake_claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

prompt=""
for argument in "$@"; do
  prompt="$argument"
done

case "$prompt" in
  *'Create .agent/PLAN.md'*)
    printf 'phase=implementing\ntask_id=task-001\n' >.agent/STATUS.md
    printf 'fake claude planning\n'
    ;;
  *'Review only task'*)
    if [[ -f .agent/.reviewed-once ]]; then
      printf 'phase=approved\ntask_id=task-001\n' >.agent/STATUS.md
      printf 'fake claude approval\n'
    else
      touch .agent/.reviewed-once
      printf 'phase=fixing\ntask_id=task-001\n' >.agent/STATUS.md
      printf 'fake claude changes requested\n'
    fi
    ;;
  *)
    printf 'Unexpected Claude prompt: %s\n' "$prompt" >&2
    exit 1
    ;;
esac
EOF

cat >"$fake_codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

prompt=""
for argument in "$@"; do
  prompt="$argument"
done

case "$prompt" in
  *'Implement only the current task'*|*'Correct only the review findings'*)
    printf 'phase=reviewing\ntask_id=task-001\n' >.agent/STATUS.md
    printf 'fake codex implementation\n'
    ;;
  *)
    printf 'Unexpected Codex prompt: %s\n' "$prompt" >&2
    exit 1
    ;;
esac
EOF

chmod +x "$fake_claude" "$fake_codex"

cycle_target="${test_root}/cycle-target"
"$CLI" init "$cycle_target" >/dev/null
cycle_output="$(ORCHESTRATOR_CLAUDE_CMD="$fake_claude" ORCHESTRATOR_CODEX_CMD="$fake_codex" "$CLI" cycle --max-fixes 1 "$cycle_target")"
assert_contains "$cycle_output" 'Task task-001 is approved.'
cycle_log="$(find "${cycle_target}/.agent/runs" -type f -name '*.log' -print -quit)"
[[ -n "$cycle_log" ]]
assert_contains "$(<"$cycle_log")" 'fake claude approval'

start_target="${test_root}/start-target"
"$CLI" init "$start_target" >/dev/null
start_output="$(ORCHESTRATOR_CLAUDE_CMD="$fake_claude" ORCHESTRATOR_CODEX_CMD="$fake_codex" "$CLI" start "$start_target" 'Automate a sample feature')"
assert_contains "$start_output" 'Task task-001 is approved.'
assert_contains "$(<"${start_target}/.agent/REQUEST.md")" 'Automate a sample feature'

dry_run_output="$("$CLI" cycle --dry-run "$start_target")"
assert_contains "$dry_run_output" 'Task task-001 is approved.'

printf 'phase=implementing\ntask_id=task-001\n' >"${start_target}/.agent/STATUS.md"
dry_run_output="$("$CLI" cycle --dry-run "$start_target")"
assert_contains "$dry_run_output" 'Would dispatch Codex for phase implementing.'

printf 'phase=invalid\ntask_id=task-001\n' >"${start_target}/.agent/STATUS.md"
assert_failure_contains 'Unsupported workflow phase: invalid' "$CLI" cycle "$start_target"

printf 'phase=implementing\ntask_id=\n' >"${start_target}/.agent/STATUS.md"
assert_failure_contains 'Workflow phase implementing requires task_id.' "$CLI" cycle "$start_target"

printf 'phase=fixing\ntask_id=task-001\n' >"${start_target}/.agent/STATUS.md"
assert_failure_contains 'Correction limit reached (0).' "$CLI" cycle --max-fixes 0 "$start_target"

stuck_codex="${test_root}/stuck-codex"
cat >"$stuck_codex" <<'EOF'
#!/usr/bin/env bash
printf 'fake codex made no state change\n'
EOF
chmod +x "$stuck_codex"

printf 'phase=implementing\ntask_id=task-001\n' >"${start_target}/.agent/STATUS.md"
assert_failure_contains 'Codex completed without changing the workflow phase.' env ORCHESTRATOR_CODEX_CMD="$stuck_codex" "$CLI" cycle "$start_target"

invalid_transition_claude="${test_root}/invalid-transition-claude"
cat >"$invalid_transition_claude" <<'EOF'
#!/usr/bin/env bash
printf 'phase=implementing\ntask_id=task-001\n' >.agent/STATUS.md
printf 'fake claude invalid transition\n'
EOF
chmod +x "$invalid_transition_claude"

printf 'phase=reviewing\ntask_id=task-001\n' >"${start_target}/.agent/STATUS.md"
assert_failure_contains 'Invalid workflow transition: reviewing -> implementing.' env ORCHESTRATOR_CLAUDE_CMD="$invalid_transition_claude" "$CLI" cycle "$start_target"

limit_target="${test_root}/limit-target"
"$CLI" init "$limit_target" >/dev/null
assert_failure_contains 'Iteration limit reached (2).' env ORCHESTRATOR_CLAUDE_CMD="$fake_claude" ORCHESTRATOR_CODEX_CMD="$fake_codex" "$CLI" cycle --max-fixes 5 --max-steps 2 "$limit_target"

printf 'orchestrator tests passed\n'
