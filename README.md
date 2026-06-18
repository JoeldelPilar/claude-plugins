# joeldelpilar — Claude Code plugin marketplace

Distributes Claude Code plugins for the team. Currently ships **auto-docs**.

## Install

```sh
# Add the marketplace from GitHub
/plugin marketplace add JoeldelPilar/claude-plugins
# or, while developing, from a local path:
/plugin marketplace add ./claude-plugins

# Install the plugin
/plugin install auto-docs@joeldelpilar
```

Update later with `/plugin marketplace update joeldelpilar` then `/plugin update auto-docs@joeldelpilar`.

## Plugins

| Plugin | What it does |
| ------ | ------------ |
| [auto-docs](plugins/auto-docs/skills/auto-docs/SKILL.md) | Generates/updates Markdown docs (README + `/docs`) from code and code changes. |

## Using auto-docs in CI

A plugin installed on a dev machine is **not** present in a CI checkout. For GitHub Actions, either:

1. **Vendor** the skill into the target repo (the verified path): copy `plugins/auto-docs/skills/auto-docs/` to that repo's `.claude/skills/auto-docs/`, then use the workflow in the skill's [GITHUB-ACTIONS.md](plugins/auto-docs/skills/auto-docs/GITHUB-ACTIONS.md); or
2. **Install via the action's own plugin inputs.** `claude-code-action` loads extensions only through its own configuration — a separate `claude plugin install` shell step mutates a different process and is **not** picked up by the action's Claude run. Pass the marketplace and plugin through the action's plugin/marketplace inputs and invoke the namespaced skill; check the action's current docs for the exact input names.

## Versioning

`version` is set in both `plugin.json` and the marketplace entry, so users only get updates when it's bumped. To make every commit an update instead (faster iteration), remove `version` from both and host in git.

## Develop

```sh
claude plugin validate ./plugins/auto-docs --strict
```
