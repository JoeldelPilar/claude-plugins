# Documentation structure & templates

The canonical layout the skill produces, and a template per file type. Keep it
Markdown, keep it in the repo, keep it diffable. Adapt headings to the project —
these are starting points, not a straitjacket.

## Layout

```
README.md                 # entry point — read first
docs/
  overview.md             # what the project is, the domains it covers, glossary
  architecture.md         # components, how they fit, data flow (Mermaid)
  modules/
    README.md             # index linking each per-module doc
    <module-a>.md         # one file per package / service / significant module
    <module-b>.md
  api/
    README.md             # API reference: endpoints + request/response types
```

Scale to the repo: a small library may only need `README.md` + `docs/overview.md`.
A monorepo or microservice fleet warrants the full `modules/` and `api/` trees.

## Conventions

- **Relative links** between docs (`[architecture](architecture.md)`) so they work on GitHub and after a checkout.
- **Mermaid** for every diagram — ```` ```mermaid ```` fenced blocks render natively on GitHub.
- **Cite sources** with a trailing `Source: path/to/file` where it helps a reader jump to the code.
- **One fact, one home.** Cross-link instead of repeating.
- **TODO markers** for gaps: `<!-- TODO: document the billing webhook -->`. They're greppable and honest.

---

## `README.md` (root)

```markdown
# <Project name>

<One sentence: what this is and who it's for.>

## What it does

<2–4 sentences. The problem it solves, the shape of the solution.>

## Quickstart

​```sh
<install — use the project's real package manager and scripts>
<run / dev>
<test>
​```

## Documentation

- [Overview](docs/overview.md) — concepts and glossary
- [Architecture](docs/architecture.md) — how the pieces fit
- [Modules](docs/modules/README.md) — per-component docs
- [API reference](docs/api/README.md)

## Requirements

<languages, runtimes, services, and their versions — read from the manifest files>
```

---

## `docs/modules/README.md` (index)

So the `[Modules](docs/modules/README.md)` link from the root README resolves in every renderer, not just GitHub's directory view.

```markdown
# Modules

| Module | Responsibility |
| ------ | -------------- |
| [<module-a>](<module-a>.md) | <one line> |
| [<module-b>](<module-b>.md) | <one line> |
```

---

## `docs/overview.md`

```markdown
# Overview

## Purpose

<What the system is for, in domain terms.>

## Domains / capabilities

<The main areas of functionality, each in a line or two.>

## Glossary

| Term | Meaning |
| ---- | ------- |
| <term used in the code> | <plain definition> |

## Documentation coverage

<Honest note on what is documented and what still has TODO markers.>
```

---

## `docs/architecture.md`

```markdown
# Architecture

## Components

<Each major component: responsibility and the boundary it owns.>

## Diagram

​```mermaid
flowchart LR
  client[Client] --> api[API service]
  api --> db[(PostgreSQL)]
  api --> queue[[Job queue]]
​```

## Data flow

<Walk one or two key requests/flows end to end.>

## External dependencies

<Third-party services, why each is used, and where it's configured (names only — no secrets).>
```

---

## `docs/modules/<name>.md`

```markdown
# <Module name>

**Source:** `<path/to/module>`

## Responsibility

<What this module owns. What it deliberately does not do.>

## Public interface

<The functions/types/endpoints other code depends on — names, inputs, outputs, error modes.>

## Dependencies

<What it depends on, and what depends on it.>

## Notes

<Gotchas, invariants, anything non-obvious from the signatures.>
```

---

## `docs/api/README.md`

Generate from the code, or from an OpenAPI / `*.proto` / GraphQL schema if one exists — prefer the spec as the source of truth when present.

```markdown
# API reference

Base URL: `<...>` · Auth: `<scheme — name the mechanism, not the secret>`

## Endpoints

### `POST /things`

Create a thing.

**Request**

​```json
{ "name": "string" }
​```

**Response `201`**

​```json
{ "id": "uuid", "name": "string", "createdAt": "ISO-8601" }
​```

**Errors:** `400` invalid body · `409` name taken

_Source: `<path/to/handler>`_
```
