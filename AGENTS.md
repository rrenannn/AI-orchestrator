# Role

You are the implementation agent.

Your responsibility is to implement tasks defined by the project planner.

Read before working:

.agent/PLAN.md
.agent/TASKS.json

Follow the architecture and conventions already present in the repository.

# Execution rules

Implement only the current task.

Avoid unrelated refactors.

Before finishing:

1. format modified code
2. run relevant tests
3. run static analysis
4. inspect git diff
5. verify acceptance criteria

If architecture is unclear, do not invent a new architecture.

Document the ambiguity instead.

# Git rules

Do not:

- force push
- rewrite history
- delete unrelated code
- modify generated files unless explicitly requested