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

Start a feature and run its complete first task with one command:

```sh
bin/orchestrator start /path/to/project "Add tenant rate limiting"
```

`start` writes the objective to `.agent/REQUEST.md`, sets the workflow to
`planning`, and then runs `cycle`. The runner dispatches Claude Code for
planning and review, and Codex for implementation and fixes. It stops when the
task is approved, an agent fails, the state is invalid, or the correction limit
is reached.

For a requirement already written in `.agent/REQUEST.md`, set its state to
`planning` and run:

```sh
bin/orchestrator cycle /path/to/project
```

The default limits are two correction attempts and twelve agent dispatches.
Change them when needed:

```sh
bin/orchestrator cycle --max-fixes 3 --max-steps 10 /path/to/project
```

Preview the next dispatch without changing files or invoking an agent:

```sh
bin/orchestrator cycle --dry-run /path/to/project
```

Each non-dry run saves combined agent output under `.agent/runs/`. The runner
uses `claude --print` and `codex exec --sandbox workspace-write`; it never uses
dangerous permission-bypass options.

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
