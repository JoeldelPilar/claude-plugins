#!/usr/bin/env bash
# detect-context.sh — report the documentation context for the auto-docs skill.
#
# Prints whether docs already exist, which mode to run (bootstrap|update),
# and — in update mode — the source files that changed since BASE_REF.
#
# Usage:
#   scripts/detect-context.sh [BASE_REF]
#
# BASE_REF resolution order:
#   1. first CLI argument, if given (e.g. a release tag or SHA)
#   2. $GITHUB_EVENT_BEFORE   (set by GitHub Actions on push events)
#   3. HEAD~1                 (the previous commit, for local runs)
#
# Output is plain `KEY=value` lines plus a CHANGED_FILES list, so an agent
# (or a later shell step) can read it without parsing prose.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

DOCS_DIR="docs"

# --- Do docs already exist? -------------------------------------------------
# Signal = a docs/ directory containing at least one Markdown file.
docs_exist=false
if [ -d "$DOCS_DIR" ] && find "$DOCS_DIR" -type f -name '*.md' 2>/dev/null | grep -q .; then
  docs_exist=true
fi

# --- Resolve the base ref for the diff --------------------------------------
base="${1:-${GITHUB_EVENT_BEFORE:-}}"

# GitHub sends an all-zero SHA for the first push to a branch — treat as none.
case "$base" in
  "" | 0000000000000000000000000000000000000000) base="" ;;
esac

if [ -z "$base" ] && git rev-parse --verify --quiet HEAD~1 >/dev/null 2>&1; then
  base="HEAD~1"
fi

# --- Decide mode ------------------------------------------------------------
if [ "$docs_exist" = true ]; then
  mode="update"
else
  mode="bootstrap"
fi

echo "MODE=$mode"
echo "DOCS_EXIST=$docs_exist"
echo "DOCS_DIR=$DOCS_DIR"
echo "BASE_REF=${base:-<none>}"

# --- Changed source files (update mode only) --------------------------------
# Exclude docs themselves and Markdown so a docs-only commit can't trigger a
# regeneration loop.
if [ "$mode" = "update" ] && [ -n "$base" ]; then
  echo "--- CHANGED_FILES ---"
  git diff --name-only "$base" HEAD -- \
    | grep -vE '^docs/|\.md$' \
    || true
fi
