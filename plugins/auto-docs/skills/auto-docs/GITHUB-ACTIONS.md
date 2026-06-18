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

# Serialize docs runs per branch, but DON'T cancel an in-flight run — a routine
# merge landing during a long bootstrap must not kill it. Branches are run-id
# suffixed, so a queued run never clashes with the one ahead of it.
concurrency:
  group: auto-docs-${{ github.ref }}
  cancel-in-progress: false

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

      # A bare runner has no git identity, so `git commit` would abort with
      # "Author identity unknown". Seed the github-actions bot identity.
      - name: Configure git identity
        run: |
          git config --global user.name  "github-actions[bot]"
          git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"

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
            3. Commit all changes to a new branch named docs/auto-${{ github.run_id }},
               then push it: git push -u origin docs/auto-${{ github.run_id }}
            4. Open a pull request to ${{ github.ref_name }}. Title it
               "docs: bootstrap documentation" when MODE=bootstrap, otherwise
               "docs: update from auto-docs". Summarise what you did in the body.
            5. If MODE=update and the changed-file list is empty, make NO edits,
               open NO PR, and say so — an empty result is valid. But if the list
               shows an "<unknown: ...>" marker, do NOT treat it as "no changes":
               the base ref could not be resolved, so review the docs against the
               current code and update whatever is stale.

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
- **Avoiding wasted runs.** A docs-only merge still fires the `push` trigger and starts a billable Claude run that then finds nothing to do — safe, but not free. `detect-context.sh` only keeps the *changed-file list* clean (it excludes `docs/**` and the root `README.md`); it does **not** stop the run. To actually skip docs-only merges, add the `paths-ignore` filter below — that's the real fix, not just an optimization.
- **Scoping the trigger.** Add `paths-ignore: ['docs/**', 'README.md']` to the `push` trigger so the docs this skill writes don't start a run. Deliberately narrow — it does **not** ignore `**/*.md`, so genuine Markdown *source* changes elsewhere still trigger a docs update. Widen the pattern only if your repo treats other `.md` files as generated docs.
- **Tightening permissions.** `Bash(bash:*)` is there to run the detect script and `git push`. You can narrow it to explicit prefixes (`Bash(bash .claude/skills/auto-docs/scripts/detect-context.sh:*)`) once you've confirmed your runner's working directory.
- **Codex / other agents.** This template is the Claude Code integration. The skill instructions themselves are agent-agnostic — to run elsewhere, point that agent at `SKILL.md` and have it follow the same workflow.
