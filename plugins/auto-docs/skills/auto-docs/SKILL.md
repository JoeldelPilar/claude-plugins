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

1. Detect context (deterministic — don't eyeball it):
   ```sh
   ./scripts/detect-context.sh            # local: diffs against HEAD~1
   ./scripts/detect-context.sh <BASE_REF> # explicit base, e.g. a release tag
   ```
   It prints `MODE`, `DOCS_EXIST`, `DOCS_DIR`, `BASE_REF`, and (in update mode) the list of changed source files.
2. Run the matching workflow below.
3. Write changes to a branch and open a PR titled `docs: …` — never commit straight to the default branch. Let a human review.

## Output layout

```
README.md            # entry point: what/why, quickstart, links into docs/
docs/
  overview.md        # purpose, domains, glossary of project terms
  architecture.md    # components, data flow, Mermaid diagrams
  modules/<name>.md  # one per package / service / significant module
  api/README.md      # API reference (endpoints + types), from code or OpenAPI
```

Full templates for each file: [DOC-STRUCTURE.md](DOC-STRUCTURE.md).

## Workflow — bootstrap mode

1. **Map the repo before writing.** Read the build/manifest files (`package.json`, `go.mod`, `Cargo.toml`, etc.) to learn languages, frameworks, **exact versions**, scripts, and entry points. Identify packages/services/modules and the boundaries between them.
2. **Establish vocabulary.** Note the domain terms the code uses (types, routes, table names). Use those exact words in the docs — do not invent synonyms.
3. **Write in this order**, committing as you go for large repos: `README.md` → `docs/overview.md` → `docs/architecture.md` (with a Mermaid component/data-flow diagram) → `docs/modules/<name>.md` per module → `docs/api/` if the project exposes an API or has an OpenAPI/`*.proto` spec.
4. **Work in passes for large/mature repos.** Don't try to document everything in one shot — cover the most-trafficked modules first, leave a checklist of `<!-- TODO: document X -->` markers for the rest, and note coverage in `docs/overview.md`.

## Workflow — update mode

1. Read the changed files reported by `detect-context.sh` and the PR/commit messages for the merge.
2. Map each change to the docs it touches: new/changed module → its `docs/modules/*.md`; new/changed endpoint or type → `docs/api/`; structural change (new service, new dependency, moved boundary) → `docs/architecture.md` + diagram; behaviour described in README/overview → refresh it.
3. **Edit in place. Do not rewrite untouched docs** and do not regenerate files no change affected. Preserve the existing voice and structure.
4. If a change has no doc impact, say so and make no edits — an empty diff is a valid result.

## Writing principles

- **Document what the code does, not what it should do.** If behaviour is unclear, read more code; if still unclear, leave a `<!-- TODO -->` rather than guessing. Never fabricate endpoints, flags, or behaviour.
- **Respect the project's real versions.** Reference only APIs/features present in the versions pinned in the manifest files. (Joel's standard.)
- **Diagrams as Mermaid** — renders on GitHub, vendor-neutral, diffable.
- **Link, don't duplicate.** Cross-reference with relative links; keep each fact in one place.
- **Cite the source.** Where useful, point a doc section at the file it describes (e.g. `Source: src/auth/session.ts`).

## Guardrails

- **Open a PR; never push to the default branch.** Aligns with PR-review-before-merge.
- **No AI attribution in commits or PRs** — no `Co-Authored-By: Claude` or similar. (Joel's standard.)
- **Never document secrets.** Don't copy values from `.env`, key files, or CI secrets into docs; reference variable *names* only.
- **Touch docs only** (`README.md`, `docs/**`). Don't modify source, config, or workflows unless explicitly asked.
- **Be honest about coverage.** State in `docs/overview.md` what is and isn't documented yet; don't imply completeness you didn't achieve.
