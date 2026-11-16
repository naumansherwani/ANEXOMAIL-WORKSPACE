#!/usr/bin/env bash
# Installs the repo-kept git hook(s) into .git/hooks (git does not version .git/hooks). Safe to run again; SessionStart runs it.
cd "${CLAUDE_PROJECT_DIR:-/home/claude/anexomail-workspace}" || exit 0
cp -f docs/cursor-work/server/hooks/post-commit .git/hooks/post-commit && chmod +x .git/hooks/post-commit
