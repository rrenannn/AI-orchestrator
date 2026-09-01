# Claude Code + Codex Orchestrator

A dependency-free workflow kit for coordinating Claude Code as planner and
reviewer with Codex as implementer. It works through files committed in the
target project, so it does not require a particular language, framework, or AI
API integration.

## Install in a project

From this repository, run:

```sh
bin/orchestrator init /path/to/project
```

The command installs missing coordination files. It preserves files that already
exist, including a project's `AGENTS.md` and `CLAUDE.md`. Review and merge the
template guidance into existing instruction files when needed. To intentionally
replace the kit's files, use `--force`.

```sh
bin/orchestrator init --force /path/to/project
```

## Workflow

1. Write the feature requirement in `.agent/REQUEST.md`.
2. Ask Claude Code to create `.agent/PLAN.md` and populate `.agent/TASKS.json`.
3. Set `phase=implementing` and the active `task_id` in `.agent/STATUS.md`.
4. Ask Codex to implement only that task and run its validation commands.
5. Codex sets `phase=reviewing`; Claude Code records its decision in
   `.agent/REVIEW.md`.
6. Claude Code sets `phase=fixing` for findings or `phase=approved` after an
   approval. Codex handles fixes, then the cycle repeats.

Check the current handoff at any time:

```sh
bin/orchestrator status /path/to/project
```

## Task format

Each item in `.agent/TASKS.json` should include an ID, status, objective,
affected files, implementation notes, acceptance criteria, and validation
commands. Keep one task active at a time.

## Development checks

```sh
bash -n bin/orchestrator tests/orchestrator_test.sh
bash tests/orchestrator_test.sh
```
