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
echo; echo "## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)"; sed -n '2,3p;8,16p' docs/claude/state/PORTS-LIVE.md 2>/dev/null | cut -c1-240
echo; echo "## Last 5 commits"; git log -5 --format='- %h %ad %s' --date=format:'%d %b %H:%M' 2>/dev/null
echo; echo "## Uncommitted files (half-done work if any)"; git status --short 2>/dev/null | head -40
echo; echo "## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)"; cat docs/claude/state/EDIT-INTENT.md 2>/dev/null | head -20
echo; echo "## Uncommitted size"; git diff --stat HEAD 2>/dev/null | tail -8
echo; echo "## Q state"; python3 docs/cursor-work/server/qstate.py brief 2>/dev/null | head -8 | cut -c1-300
} > $F
# snapshot of every uncommitted file as a git object (tree untouched, never pushed): restore with git checkout refs/wip/last -- <file>
W="$(git stash create 2>/dev/null)"; [ -n "$W" ] && git update-ref refs/wip/last "$W" && echo "WIP snapshot: refs/wip/last ($W)" >> $F

# ADMIN DESK WORKING-NOW (his 21 Nov 2026 10:04: "mujhe repo updated chahiye admin desk ke andar updated working now"): the same live pointer INSIDE the Desk folder, refreshed every time (and by the 2-minute loop); the root copy is synced in the same step.
DF=docs/claude/admin-desk/state/WORKING-NOW.md; mkdir -p docs/claude/admin-desk/state
{
echo "# ADMIN DESK WORKING NOW ($WHY, $NOW) - read this FIRST for the Desk after a compaction"
echo "DOING: $DOING"; echo "NEXT STEP: $NEXT"; echo "HIS LAST WORD: $WORD"
echo "LAWS: Desk isolation (never mix with founder/awam) / HTTP/1 + HTTP/2 BANNED, HTTP/3 only / Rule 52 kernel-verified calls / founder technology or MORE advanced / every phase row = feature + code + technology + HAAN / address him only as Aap, Roman Urdu short, end with Rule-70 table + 'Abhi code mein NAHI'."
echo "FOLDER: canonical docs/claude/admin-desk/ (edit here) + identical root copy admin-desk/ (python3 docs/cursor-work/server/desk-copy-sync.py sync)."
echo; echo "## Phase table (docs/claude/admin-desk/state/PHASES.md)"; sed -n '4,40p' docs/claude/admin-desk/state/PHASES.md 2>/dev/null
echo; echo "## Desk ports on his server: TCP 127.0.0.1:4400 (loopback) + UDP 4400 (own HTTP/3, ufw open); public TCP 443 via founder SNI front -> awam-edge -> Caddy -> Desk; Desk cert copy /etc/anexomail/tls/desk (root only, systemd LoadCredential)"
echo; echo "## Last 8 Desk commits"; git log -8 --format='- %h %ad %s' --date=format:'%d %b %H:%M' -- docs/claude/admin-desk admin-desk founder-web/src/desk 2>/dev/null
echo; echo "## Uncommitted Desk files"; git status --short -- docs/claude/admin-desk admin-desk founder-web/src/desk 2>/dev/null | head -20
echo; echo "## Gate rows (admin-desk/gates/DESK-FEATURES.json)"; python3 admin-desk/gates/desk_tech_gate.py 2>/dev/null | cut -c1-170 | head -14
} > $DF
python3 docs/cursor-work/server/desk-copy-sync.py sync >/dev/null 2>&1
echo "checkpoint written: $F ($NOW)"
