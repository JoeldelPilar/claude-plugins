# GitHub Actions integration (optional)

The skill runs fine locally — just invoke it in Claude Code or Codex. This file
covers the unattended CI path: regenerate/update docs on **merge to the default
branch** and on **manual dispatch**, then open a PR for review.

Verified against `anthropics/claude-code-action@v1`.

## Contents

- Setup (once per repo)
- Workflow — the `auto-docs.yml` file
- Notes & tuning

## Setup (once per repo)

1. **Add the skill to the repo** so Claude Code discovers it in CI:
   ```
   .claude/skills/auto-docs/   ← copy this whole folder here
   ```
   (Claude Code auto-loads skills from `.claude/skills/`.)
2. **Add the API key** as a repo secret: `ANTHROPIC_API_KEY`.
   - Vendor-independent alternative: authenticate against **AWS Bedrock** or **Google Vertex** instead — the action supports both via env/config. See the action's auth docs and drop the `anthropic_api_key` input.
3. **Branch protection**: the workflow opens a PR rather than pushing to the default branch, so the only requirement is that Actions is allowed to create PRs (Settings → Actions → "Allow GitHub Actions to create and approve pull requests"). (The script is run as `bash <path>`, so no execute bit is needed.)

## Workflow

Save as `.github/workflows/auto-docs.yml`:

```yaml
name: auto-docs

on:
  push:
    branches: [main]        # runs after a PR merges
    # Skip merges that only touch the docs this skill writes (avoids a wasted
    # billable run). Narrow on purpose — does NOT ignore **/*.md source.
    paths-ignore: ['docs/**', 'README.md']
  workflow_dispatch:        # manual run (use this for the first bootstrap)
    inputs:
      model:
        description: "Model alias or id (sonnet | opus | claude-opus-4-8 …)"
        default: "sonnet"

# Serialize docs runs for this ref (the group key is github.ref, so every push
# to main shares one lane). cancel-in-progress:false keeps a long bootstrap
# alive when a routine merge lands. Caveat: GitHub keeps only ONE pending run
# per group — if several merges land while a run is busy, only the latest is
# queued and the intermediate ones are superseded. The next run documents the
# cumulative state; re-dispatch manually if you need a specific point.
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
            3. Run the skill's review loop ("Verify before finishing"): review the
               docs against the code with a fresh review sub-agent, fix every
               INCORRECT finding, and repeat (max 3 passes). Do NOT commit until the
               reviewer reports zero INCORRECT findings — or, if the cap is hit, until
               the remaining findings are left as <!-- TODO --> markers, not silent errors.
            4. Commit all changes to a new branch named docs/auto-${{ github.run_id }},
               then push it: git push -u origin docs/auto-${{ github.run_id }}
            5. Open a pull request to ${{ github.ref_name }}. Use the MODE you
               read in step 1 (note it before you start): title the PR
               "docs: bootstrap documentation" if MODE=bootstrap, else
               "docs: update from auto-docs". Summarise what you did in the body, and
               include the reviewer's final verdict (the INCORRECT count) so a human
               sees it before merging.
            6. If MODE=update and the changed-file list is empty, make NO edits,
               open NO PR, and say so — an empty result is valid. But if the list
               shows an "<unknown: ...>" marker, do NOT treat it as "no changes":
               the base ref could not be resolved, so review the docs against the
               current code and update whatever is stale.

            Constraints: edit only README.md and docs/**. Do not add any AI
            attribution (no "Co-Authored-By") to commits or the PR. Never put
            secret values in docs — reference variable names only.
          claude_args: |
            --model ${{ github.event.inputs.model || 'sonnet' }}
            --max-turns 60
            --allowedTools Edit,Write,Read,Glob,Grep,Task,Bash(git:*),Bash(gh:*),Bash(bash:*)
```

## Notes & tuning

- **Self-verifying docs (the review gate).** Before it opens the PR, the skill runs a review loop — generate → an independent review sub-agent → fix, up to 3 passes, stopping at zero INCORRECT findings — and writes the reviewer's verdict into the PR body so a human sees it before merging. The reviewer is spawned with the `Task` tool, so `Task` is in `--allowedTools` above; keep it there if you narrow the list, or the loop silently degrades to self-review. The bump to `--max-turns 60` leaves room for the extra review passes. For a *hard* gate that blocks merge, make the docs PR a required check under branch protection, or add a follow-up step that fails the job when the PR body still reports open INCORRECT findings.
- **Deterministic doc-quality gate (complements the LLM review).** The review loop catches *accuracy*; pair it with cheap deterministic linters as a required check on the docs PR. Add a separate `pull_request`-triggered workflow that runs `markdownlint` and a link-checker over `README.md` and `docs/**`:
  ```yaml
  on: { pull_request: { paths: ['docs/**', 'README.md'] } }
  jobs:
    docs-lint:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: DavidAnson/markdownlint-cli2-action@v16
          with: { globs: 'README.md docs/**/*.md' }
        - uses: lycheeverse/lychee-action@v2
          with: { args: "--no-progress README.md 'docs/**/*.md'" }
  ```
  Fail the check on broken links; keep style nits as warnings.
- **"Touch docs only" is prose-only in CI.** The `Edit,Write` tools above are not path-scoped, so the docs-only guardrail is honoured by instruction, not enforced. To make it deterministic, add a step after the action that fails the job if the branch diff touches anything outside `docs/`/`README.md`:
  ```sh
  git diff --name-only "$GITHUB_EVENT_BEFORE"...HEAD \
    | grep -vqE '^(docs/|README\.md$)' && { echo 'non-docs change'; exit 1; } || true
  ```
- **First run = bootstrap.** Trigger it manually via *Run workflow* on a repo with no `docs/`. It will scan everything and open the initial docs PR. For a large/mature codebase, bump the dispatch `model` input to `opus` (or pin `claude-opus-4-8`) and raise `--max-turns`.
- **Why a PR, not a push?** Keeps a human in the loop and matches the PR-review-before-merge standard. The merge that opened the PR is already on the default branch; the docs follow in their own reviewable PR.
- **Avoiding wasted runs.** The `push` trigger above already carries `paths-ignore: ['docs/**', 'README.md']`, so a merge touching only the docs this skill writes won't start a billable run. It's deliberately narrow — it does **not** ignore `**/*.md`, so genuine Markdown *source* changes elsewhere still trigger a docs update. Widen it only if your repo treats other `.md` files as generated docs. (`detect-context.sh`'s own filter just cleans the changed-file *list*; the `paths-ignore` is what actually skips the run.)
- **Tightening permissions.** `Bash(bash:*)` is there to run the detect script and `git push`. You can narrow it to explicit prefixes (`Bash(bash .claude/skills/auto-docs/scripts/detect-context.sh:*)`) once you've confirmed your runner's working directory.
- **Codex / other agents.** This template is the Claude Code integration. The skill instructions themselves are agent-agnostic — to run elsewhere, point that agent at `SKILL.md` and have it follow the same workflow.
