# Implementation Plan

## Architecture

The kit is a dependency-free Bash CLI plus text and JSON templates. Each target
project owns its `.agent/` state, so Claude Code and Codex coordinate through
repository files rather than an API-specific integration.

## Delivery Order

1. Provide templates and a safe `init` command.
2. Provide a `status` command based on a shared workflow state.
3. Add automated shell tests and usage documentation.

## Compatibility

- Requires Bash 3.2 or newer and standard POSIX utilities available on macOS
  and common Linux distributions.
- Does not overwrite existing orchestration files unless `--force` is explicit.
