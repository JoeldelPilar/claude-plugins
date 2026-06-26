# auto-docs evaluations

Three scenarios that test the gaps this skill exists to close. They follow the
[Anthropic eval format](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#evaluation-and-iteration):
each is a JSON file with `skills`, `query`, `files`, and `expected_behavior`
(a checkable rubric). There is no built-in runner — score a run by checking the
agent's behaviour against each `expected_behavior` line.

## Scenarios

| File | Mode it exercises |
| ---- | ----------------- |
| [bootstrap.json](bootstrap.json) | First run on an undocumented repo |
| [update-module.json](update-module.json) | A merged PR adds a module |
| [no-op.json](no-op.json) | A change that touches no documented behaviour |

## Fixtures

Each eval names a fixture repo under `fixtures/`. A fixture is just a small repo
snapshot (e.g. a TS/Node service with two or three modules and an HTTP API). Point
the eval at any small repo of the right shape; the assertions are written to be
fixture-agnostic. The `update-module.json` and `no-op.json` cases assume the
fixture is a git repo with at least two commits so `detect-context.sh` can diff.

## Model coverage

Run each scenario on every model you deploy the skill with — Anthropic's checklist
calls for Haiku, Sonnet, and Opus. Haiku exposes under-specified instructions;
Opus exposes over-explaining. Record pass/fail per model here as you test:

| Scenario | Haiku | Sonnet | Opus |
| -------- | :---: | :----: | :--: |
| bootstrap | — | — | — |
| update-module | — | — | — |
| no-op | — | — | — |
