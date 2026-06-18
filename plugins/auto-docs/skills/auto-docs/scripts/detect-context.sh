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
# `-print -quit` stops find at the first match, so this never relies on a pipe.
# (A `… | grep -q .` here dies with SIGPIPE 141, which `set -o pipefail` turns
# into a false negative on docs/ trees with many Markdown files.)
if [ -d "$DOCS_DIR" ] && [ -n "$(find "$DOCS_DIR" -type f -name '*.md' -print -quit 2>/dev/null)" ]; then
  docs_exist=true
fi

# --- Resolve the base ref for the diff --------------------------------------
base="${1:-${GITHUB_EVENT_BEFORE:-}}"
base="${base%$'\r'}"   # strip a trailing CR from CRLF-sourced values

# GitHub sends an all-zero SHA for the first push of a branch. Distinguish it
# from a local run (empty base): a first push commonly lands many commits at
# once, so HEAD~1 would undercount — only fall back to HEAD~1 for a local run.
first_push=false
case "$base" in
  "") base="" ;;
  0000000000000000000000000000000000000000) base=""; first_push=true ;;
esac

if [ "$first_push" = false ] && [ -z "$base" ] \
   && git rev-parse --verify --quiet HEAD~1 >/dev/null 2>&1; then
  base="HEAD~1"
fi

# If a base was given but is unusable — doesn't resolve to a real commit
# (force-push-orphaned SHA, missing tag, shallow clone) OR shares no history
# with HEAD (orphan/unrelated history, where a three-dot diff would abort with
# "no merge base") — flag it as unknown rather than crashing or diffing nothing.
base_unresolved=false
if [ -n "$base" ]; then
  if ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null 2>&1; then
    base_unresolved=true; base=""
  elif ! git merge-base "$base" HEAD >/dev/null 2>&1; then
    base_unresolved=true; base=""
  fi
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
# Excludes the docs this skill writes (docs/** and the root README) so a
# docs-only commit can't trigger a regeneration loop — but keeps Markdown
# *source* elsewhere (e.g. content/*.md) visible to update mode.
if [ "$mode" = "update" ]; then
  echo "--- CHANGED_FILES ---"
  if [ "$base_unresolved" = true ]; then
    echo "<unknown: base ref unusable (missing or unrelated history) — cannot compute changes; do NOT treat as 'no changes'>"
  elif [ "$first_push" = true ]; then
    echo "<unknown: first push (many commits, no single prior base) — review all docs against the current code>"
  elif [ -z "$base" ]; then
    echo "<unknown: no base ref available — cannot compute changes; do NOT treat as 'no changes'>"
  else
    # core.quotePath=false → literal UTF-8 paths (no C-quoting of odd names).
    # Three-dot diff → only what this change introduced vs the merge base; the
    # merge-base check above guarantees one exists, so no "no merge base" abort.
    # The grep is brace-grouped so "no matches" (exit 1) doesn't abort, while a
    # real git failure still propagates under `set -o pipefail`.
    git -c core.quotePath=false diff --name-only "$base"...HEAD -- \
      | { grep -vE '^docs/|^README\.md$' || true; }
  fi
fi
