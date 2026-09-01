# Claude Code + Codex Orchestrator

A dependency-free workflow kit that coordinates Claude Code as planner and
reviewer with Codex as implementer. Run one command with a feature description;
the orchestrator plans, implements, validates, reviews, and applies bounded
corrections in the target project.

## Prerequisites

- `claude` and `codex` must be installed and authenticated.
- The target project must be a Git repository.
- Start from a clean working tree so the review covers only the automated work.

```sh
git -C /path/to/project status --short
```

## Quick start

Initialize the target project once:

```sh
bin/orchestrator init /path/to/project
```

Then start a feature. Replace the final quoted text with the desired outcome:

```sh
bin/orchestrator start /path/to/project "Add tenant rate limiting"
```

The command writes the feature request and runs this sequence automatically:

```text
Claude Code plans → Codex implements and validates → Claude Code reviews
→ Codex fixes, if needed → Claude Code approves
```

It stops when the current task is approved, an agent fails, an invalid state is
found, or a configured limit is reached. You do not need to copy prompts
between the two CLIs.

## Example

From a different directory, call the executable by its absolute path:

```sh
/path/to/AI-orchestrator/bin/orchestrator start \
  /path/to/PHP-META-API \
  "Add a GET /health endpoint that returns JSON with status ok"
```

## Check the result

Check the current state at any time:

```sh
bin/orchestrator status /path/to/project
```

- `phase=approved`: read `.agent/REVIEW.md`, inspect the Git diff, and run any
  project-specific checks before committing.
- `phase=fixing`: inspect the latest `.agent/runs/*.log` file, then run `cycle`
  again to continue from the recorded state.
- A nonzero command exit: inspect the terminal output and the latest log before
  retrying.

Each non-dry run records combined agent output under `.agent/runs/`.

## Advanced use

Preview the next agent without changing files or invoking a model:

```sh
bin/orchestrator cycle --dry-run /path/to/project
```

For a requirement already prepared in `.agent/REQUEST.md`, set the phase to
`planning` and run the cycle directly:

```sh
bin/orchestrator cycle /path/to/project
```

The default limits are two corrections and twelve agent dispatches. Override
them for a run when needed:

```sh
bin/orchestrator cycle --max-fixes 3 --max-steps 10 /path/to/project
```

The runner uses `claude --print` and `codex exec --sandbox workspace-write`; it
does not use dangerous permission-bypass options.

## Existing instruction files

`init` adds only missing files and preserves an existing `AGENTS.md` or
`CLAUDE.md`. Merge the template guidance into existing instructions if the
target project already uses those files. Use `--force` only when you explicitly
want to replace the kit-managed files:

```sh
bin/orchestrator init --force /path/to/project
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
