# GitHub Actions integration (optional)

The skill runs fine locally — just invoke it in Claude Code or Codex. This file
covers the unattended CI path: regenerate/update docs on **merge to the default
branch** and on **manual dispatch**, then open a PR for review.

Verified against `anthropics/claude-code-action@v1`.

## Setup (once per repo)

1. **Add the skill to the repo** so Claude Code discovers it in CI:
   ```
   .claude/skills/auto-docs/   ← copy this whole folder here
   ```
   (Claude Code auto-loads skills from `.claude/skills/`.)
2. **Add the API key** as a repo secret: `ANTHROPIC_API_KEY`.
   - Vendor-independent alternative: authenticate against **AWS Bedrock** or **Google Vertex** instead — the action supports both via env/config. See the action's auth docs and drop the `anthropic_api_key` input.
3. **Make the helper executable** when you commit it: `chmod +x .claude/skills/auto-docs/scripts/detect-context.sh`.
4. **Branch protection**: the workflow opens a PR rather than pushing to the default branch, so the only requirement is that Actions is allowed to create PRs (Settings → Actions → "Allow GitHub Actions to create and approve pull requests").

## Workflow

Save as `.github/workflows/auto-docs.yml`:

```yaml
name: auto-docs

on:
  push:
    branches: [main]        # runs after a PR merges
  workflow_dispatch:        # manual run (use this for the first bootstrap)
    inputs:
      model:
        description: "Model alias or id (sonnet | opus | claude-opus-4-8 …)"
        default: "sonnet"

# One docs run at a time; cancel an in-flight run if a newer commit lands.
concurrency:
  group: auto-docs-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: write          # create the docs branch
  pull-requests: write      # open the PR

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0    # full history so the diff base is reachable

      - name: Generate / update documentation
        uses: anthropics/claude-code-action@v1
        env:
          # Wires the push event's "before" SHA into detect-context.sh,
          # and gives the gh CLI a token to open the PR.
          GITHUB_EVENT_BEFORE: ${{ github.event.before }}
          GH_TOKEN: ${{ github.token }}
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Use the auto-docs skill to document this repository.

            1. Run: bash .claude/skills/auto-docs/scripts/detect-context.sh
            2. Follow the skill's bootstrap or update workflow based on the reported MODE.
            3. Write all changes to a new branch named: docs/auto-${{ github.run_id }}
            4. Open a pull request to ${{ github.ref_name }} titled "docs: update from auto-docs".
               In the PR body, summarise what you documented or changed.
            5. If MODE=update and no change affects the docs, make NO edits, open NO PR,
               and say so. An empty result is valid.

            Constraints: edit only README.md and docs/**. Do not add any AI
            attribution (no "Co-Authored-By") to commits or the PR. Never put
            secret values in docs — reference variable names only.
          claude_args: |
            --model ${{ github.event.inputs.model || 'sonnet' }}
            --max-turns 40
            --allowedTools Edit,Write,Read,Glob,Grep,Bash(git:*),Bash(gh:*),Bash(bash:*)
```

## Notes & tuning

- **First run = bootstrap.** Trigger it manually via *Run workflow* on a repo with no `docs/`. It will scan everything and open the initial docs PR. For a large/mature codebase, bump the dispatch `model` input to `opus` (or pin `claude-opus-4-8`) and raise `--max-turns`.
- **Why a PR, not a push?** Keeps a human in the loop and matches the PR-review-before-merge standard. The merge that opened the PR is already on the default branch; the docs follow in their own reviewable PR.
- **Avoiding loops.** `detect-context.sh` excludes `docs/**` and `*.md` from the changed-file list, so a docs-only merge won't re-trigger generation work. The `push` trigger still fires, but update mode will find no relevant changes and exit cleanly.
- **Scoping triggers.** To run only when code (not docs) changes, add a `paths-ignore: ['docs/**', '**/*.md']` filter to the `push` trigger.
- **Tightening permissions.** `Bash(bash:*)` is there to run the detect script. You can narrow it to the explicit script path once you've confirmed your runner's working directory.
- **Codex / other agents.** This template is the Claude Code integration. The skill instructions themselves are agent-agnostic — to run elsewhere, point that agent at `SKILL.md` and have it follow the same workflow.
