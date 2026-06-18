# eyevinn-claude — Claude Code plugin marketplace

Distributes Claude Code plugins for the team. Currently ships **auto-docs**.

## Install

```sh
# Add the marketplace (from GitHub once pushed, or a local path while developing)
/plugin marketplace add <owner>/claude-plugins      # e.g. eyevinn/claude-plugins
# or locally:
/plugin marketplace add ./claude-plugins

# Install the plugin
/plugin install auto-docs@eyevinn-claude
```

Update later with `/plugin marketplace update eyevinn-claude` then `/plugin update auto-docs@eyevinn-claude`.

## Plugins

| Plugin | What it does |
| ------ | ------------ |
| [auto-docs](plugins/auto-docs/skills/auto-docs/SKILL.md) | Generates/updates Markdown docs (README + `/docs`) from code and code changes. |

## Using auto-docs in CI

A plugin installed on a dev machine is **not** present in a CI checkout. For GitHub Actions, either:

1. **Vendor** the skill into the target repo: copy `plugins/auto-docs/skills/auto-docs/` to that repo's `.claude/skills/auto-docs/`, then use the workflow in the skill's `GITHUB-ACTIONS.md`; or
2. **Install in the workflow**: add a step running `claude plugin marketplace add <owner>/claude-plugins && claude plugin install auto-docs@eyevinn-claude` before invoking the action.

## Versioning

`version` is set in both `plugin.json` and the marketplace entry, so users only get updates when it's bumped. To make every commit an update instead (faster iteration), remove `version` from both and host in git.

## Develop

```sh
claude plugin validate ./plugins/auto-docs --strict
```
