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

printf 'orchestrator tests passed\n'
