---
name: auto-docs
description: Generates and maintains Markdown documentation from a codebase — bootstraps docs where none exist, backfills a mature undocumented project, and updates docs incrementally when a PR is merged. Produces a root README plus a structured /docs tree (overview, architecture, per-module docs, API reference). Use when the user wants to document a repo, set up automated docs in CI/CD, generate or refresh a README or /docs, or keep documentation in sync with code changes. Runs locally via Claude Code or Codex, or unattended in a GitHub Actions workflow (PR-merge or manual dispatch).
---

# auto-docs

Generate and maintain documentation **from the code that actually exists** — never from assumption. Two modes, auto-detected:

- **bootstrap** — no docs yet (new repo, or a mature project that was never documented). Scan the whole codebase and create the full doc set.
- **update** — docs already exist. A PR merged; update only the docs the change affects, and keep the architecture overview current.

The skill body below is agent-agnostic (works in Claude Code or Codex, locally or in CI). For the optional GitHub Actions integration see [GITHUB-ACTIONS.md](GITHUB-ACTIONS.md). For the canonical layout and per-file templates see [DOC-STRUCTURE.md](DOC-STRUCTURE.md).

## Quick start

1. Detect context (deterministic — don't eyeball it). The script ships **inside this skill's own directory**, not in the target repo — invoke it by its install path from anywhere inside the repo you're documenting (the script `cd`s to the repo root itself):
   ```sh
   # CI / installed skill:
   bash .claude/skills/auto-docs/scripts/detect-context.sh
   # locally: use the path your agent loaded this skill from, e.g.
   bash "<skill-dir>/scripts/detect-context.sh"             # diffs against the previous commit
   bash "<skill-dir>/scripts/detect-context.sh" <BASE_REF>  # explicit base, e.g. a release tag
   ```
   It prints `MODE`, `DOCS_EXIST`, `DOCS_DIR`, `BASE_REF`, and (in update mode) a `CHANGED_FILES` list — or an `<unknown: …>` marker when no usable base ref could be resolved.
2. Run the matching workflow below.
3. Verify the result against the code with the review loop (see *Verify before finishing*) **before** committing.
4. Write changes to a branch and open a PR titled `docs: …` — never commit straight to the default branch. Let a human review.

## Output layout

```
README.md            # entry point: what/why, quickstart, links into docs/
docs/
  overview.md        # purpose, domains, glossary of project terms
  architecture.md    # components, data flow, Mermaid diagrams
  modules/README.md  # index linking the per-module docs
  modules/<name>.md  # one per package / service / significant module
  api/README.md      # API reference (endpoints + types), from code or OpenAPI
```

Full templates for each file: [DOC-STRUCTURE.md](DOC-STRUCTURE.md).

## Workflow — bootstrap mode

1. **Map the repo before writing.** Read the build/manifest files (`package.json`, `go.mod`, `Cargo.toml`, etc.) to learn languages, frameworks, **exact versions**, scripts, and entry points. Identify packages/services/modules and the boundaries between them.
2. **Establish vocabulary.** Note the domain terms the code uses (types, routes, table names). Use those exact words in the docs — do not invent synonyms.
3. **Write in this order**, committing as you go for large repos: `README.md` → `docs/overview.md` → `docs/architecture.md` (with a Mermaid component/data-flow diagram) → `docs/modules/README.md` (the module index) → `docs/modules/<name>.md` per module → `docs/api/` if the project exposes an API or has an OpenAPI/`*.proto` spec. Only create the `docs/modules/` and `docs/api/` trees if the repo warrants them — and if you skip one, drop its link from the root README so there are no dead links.
4. **Work in passes for large/mature repos.** Don't try to document everything in one shot — cover the most-trafficked modules first, leave a checklist of `<!-- TODO: document X -->` markers for the rest, and note coverage in `docs/overview.md`.

## Workflow — update mode

1. Read the changed files reported by `detect-context.sh` and the PR/commit messages for the merge. If `CHANGED_FILES` is an `<unknown: …>` marker (the base ref didn't resolve), do **not** assume "no changes" — review the docs against the current code and refresh whatever is stale.
2. Map each change to the docs it touches: new/changed module → its `docs/modules/*.md`; new/changed endpoint or type → `docs/api/`; structural change (new service, new dependency, moved boundary) → `docs/architecture.md` + diagram; behaviour described in README/overview → refresh it.
3. **Edit in place. Do not rewrite untouched docs** and do not regenerate files no change affected. Preserve the existing voice and structure.
4. If the changed-file list is genuinely empty (not `<unknown>`) and nothing affects the docs, say so and make no edits — an empty diff is a valid result.

## Verify before finishing — the review loop

Generated docs drift from the code in ways the author can't see — a documented `400` that's really a `500`, a signature that's subtly wrong. Don't ship a pass without checking it against the source.

After writing (bootstrap) or editing (update) the docs, run a review loop:

1. **Run the cheap deterministic checks first.** A markdown link-checker (e.g. `lychee` or `markdown-link-check`) catches dead relative links, and `markdownlint` catches structural problems — both deterministically, and far cheaper than spending an LLM pass on them. Fix what they flag before reviewing.
2. **Review the docs against the code — independently.** If your runtime can spawn a sub-agent (e.g. Claude Code's `Task` tool), launch a *fresh* one as an adversarial reviewer — it has no stake in the prose and catches what self-review misses. If it can't, review the docs yourself in a clean pass. Give the reviewer this checklist:
   - Every function/type in `docs/modules/*` matches the source signature exactly — names, inputs, outputs.
   - Every endpoint in `docs/api/*` matches the router: method, path, request/response shape, and status codes. **Trace the real error path** — an uncaught `throw` bubbles to the top-level handler (often a `500`), so a documented `400`/`404` can be wrong.
   - No fabricated endpoints, flags, commands, or behaviour; no claim the code doesn't support.
   - Every relative link resolves.

   The reviewer returns findings grouped by severity — and the bar matters, or the loop never terminates (an adversarial reviewer can always nitpick wording): **INCORRECT** = the docs state something the code contradicts (wrong signature, wrong status code, fabricated behaviour); **OVERSTATED** = true but imprecise or over-emphasised; **OMISSION** = a real behaviour left out. Only **INCORRECT** blocks the loop.
3. **Fix every INCORRECT finding, then review again.** Address overstatements and omissions where the fix is cheap.
4. **Stop at zero INCORRECT, or after 3 passes — whichever comes first.** If you hit the cap with findings still open, leave them as `<!-- TODO: reviewer flagged … -->` rather than shipping a silent error. Record the final verdict (the INCORRECT count) in the PR body so a human sees it before merging.

## What kind of docs these are

Generated docs faithfully fill only two of the four [Diátaxis](https://diataxis.fr) modes — the two you can derive from source without guessing:

- **Reference** — `docs/modules/*`, `docs/api/*`. Neutral facts: signatures, inputs/outputs, error modes, endpoints. Structure mirrors the code; no interpretation.
- **Explanation** — `docs/overview.md`, `docs/architecture.md`. The *why*: purpose, boundaries, how a request flows.

Two rules follow:

- **Don't blur the modes on one page.** The classic failure of generated docs is a reference section padded with invented rationale. Keep reference factual; put every "why" in overview/architecture.
- **Don't fabricate tutorials or how-to guides** (the other two modes). They need a real user journey and product judgement you can't infer from code — leave a `<!-- TODO: tutorial — needs a human author -->` stub instead.

## Writing principles

- **Document what the code does, not what it should do.** If behaviour is unclear, read more code; if still unclear, leave a `<!-- TODO -->` rather than guessing. Never fabricate endpoints, flags, or behaviour — including commands: every command in the README or a quickstart must come from the project's real scripts and manifest, not an invented flag.
- **Respect the project's real versions.** Reference only APIs/features present in the versions pinned in the manifest files. (Joel's standard.)
- **Diagrams as Mermaid** — renders on GitHub, vendor-neutral, diffable.
- **Link, don't duplicate.** Cross-reference with relative links; keep each fact in one place.
- **Cite the source.** Where useful, point a doc section at the file it describes (e.g. `Source: src/auth/session.ts`).

## Voice & style

How the prose should read — grounded in the [Google developer documentation style guide](https://developers.google.com/style):

- **Second person, active voice, present tense.** "Call `start()` to open a session," not "a session is opened by calling `start()`." Address the reader as "you"; avoid "we/our."
- **Lead with the point.** The first sentence of a section says what the thing is or does; details follow. Readers scan — they don't read top to bottom.
- **Short, plain sentences, one idea each.** Expand an acronym on first use. Cut empty adjectives ("powerful", "seamless", "robust") — they carry no information.
- **Write for a developer new to this repo, not new to programming.** Assume language and tooling literacy; explain only what's specific to this codebase.
- **Keep it scannable.** One concept per heading; a list or table beats a paragraph when the content enumerates. Add a table of contents only once a doc grows long.

## Guardrails

- **Open a PR; never push to the default branch.** Aligns with PR-review-before-merge.
- **No AI attribution in commits or PRs** — no `Co-Authored-By: Claude` or similar. (Joel's standard.)
- **Never document secrets.** Don't copy values from `.env`, key files, or CI secrets into docs; reference variable *names* only.
- **Touch docs only** (`README.md`, `docs/**`). Don't modify source, config, or workflows unless explicitly asked.
- **Be honest about coverage.** State in `docs/overview.md` what is and isn't documented yet; don't imply completeness you didn't achieve.
