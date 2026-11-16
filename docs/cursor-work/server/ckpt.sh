#!/usr/bin/env bash
# COMPACTION SAFETY (his 16 Nov 05:34 order). Writes docs/claude/state/WORKING-NOW.md = where Claude is RIGHT NOW, so a compaction mid-code loses nothing.
#   manual (Claude, before and during a code step):  bash docs/cursor-work/server/ckpt.sh "what I am doing" "the exact next step" ["his last word"]
#   automatic (PreCompact hook, no Claude needed):   bash docs/cursor-work/server/ckpt.sh --auto
# It records PKT time, the last 5 commits, every uncommitted file (git status), and keeps the last manual doing/next. SessionStart prints it first.
cd "${CLAUDE_PROJECT_DIR:-/home/claude/anexomail-workspace}" || exit 0
F=docs/claude/state/WORKING-NOW.md; mkdir -p docs/claude/state
NOW="$(TZ=Asia/Karachi date '+%d %b %Y %H:%M PKT')"
if [ "${1:-}" = "--auto" ]; then
  DOING="$(sed -n 's/^DOING: //p' $F 2>/dev/null | head -1)"; NEXT="$(sed -n 's/^NEXT STEP: //p' $F 2>/dev/null | head -1)"; WORD="$(sed -n 's/^HIS LAST WORD: //p' $F 2>/dev/null | head -1)"; WHY="auto snapshot before a compaction"
else DOING="${1:-}"; NEXT="${2:-}"; WORD="${3:-$(sed -n 's/^HIS LAST WORD: //p' $F 2>/dev/null | head -1)}"; WHY="manual checkpoint"; fi
{
echo "# WORKING NOW ($WHY, $NOW) - read this FIRST after a compaction; it is where the work stopped"
echo "DOING: $DOING"
echo "NEXT STEP: $NEXT"
echo "HIS LAST WORD: $WORD"
echo "RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time."
echo; echo "## Last 5 commits"; git log -5 --format='- %h %ad %s' --date=format:'%d %b %H:%M' 2>/dev/null
echo; echo "## Uncommitted files (half-done work if any)"; git status --short 2>/dev/null | head -40
echo; echo "## Q state"; python3 docs/cursor-work/server/qstate.py brief 2>/dev/null | head -8 | cut -c1-300
} > $F
echo "checkpoint written: $F ($NOW)"
