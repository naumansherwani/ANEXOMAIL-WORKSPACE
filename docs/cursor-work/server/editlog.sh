#!/usr/bin/env bash
# MID-EDIT COMPACTION SAFETY (his 17 Nov 04:5x order: "if codes compact during an edit, make a way so my work never halts").
#   begin (before a multi-file edit):  bash docs/cursor-work/server/editlog.sh begin "what I am changing and why" file1 file2 ...
#   note  (after each file is done):   bash docs/cursor-work/server/editlog.sh note "file1 done; file2 next: <exact next edit>"
#   end   (after tests + rec.sh):      bash docs/cursor-work/server/editlog.sh end
# The intent file docs/claude/state/EDIT-INTENT.md is printed by the SessionStart hook with WORKING-NOW.md, and ckpt.sh --auto (PreCompact) also saves a snapshot commit object of every uncommitted file
# under refs/wip/last (git stash create: the working tree is NOT touched, nothing is pushed), so a half-written file can always be restored with: git diff refs/wip/last / git checkout refs/wip/last -- <file>.
cd "${CLAUDE_PROJECT_DIR:-/home/claude/anexomail-workspace}" || exit 0
F=docs/claude/state/EDIT-INTENT.md; mkdir -p docs/claude/state
NOW="$(TZ=Asia/Karachi date '+%d %b %Y %H:%M PKT')"
case "${1:-}" in
  begin) shift; { echo "# EDIT IN PROGRESS (started $NOW): a compaction may have cut it. Read this, run git status + git diff, finish the edit, then end it."; echo "WHAT: ${1:-}"; shift; echo "FILES: $*"; echo "PROGRESS:"; } > $F;;
  note) echo "- $NOW ${2:-}" >> $F;;
  end) rm -f $F; echo "edit intent closed";;
  *) echo "usage: editlog.sh begin|note|end"; exit 1;;
esac
[ -f $F ] && echo "edit intent: $F"
exit 0
