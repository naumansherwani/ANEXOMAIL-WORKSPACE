#!/usr/bin/env bash
# AUTO REFRESH every 5 minutes (his 17 Nov 01:43 order): keeps WORKING-NOW.md + the rules receipt fresh and reminds Claude of the technology law, the next step and how to address him.
#   hook (UserPromptSubmit, every message):  bash docs/cursor-work/server/autoref.sh --remind     (refreshes only if the file is older than 5 min, prints a short reminder into Claude's context)
#   loop (background in a session):          bash docs/cursor-work/server/autoref.sh --loop       (every 300 s)
cd "${CLAUDE_PROJECT_DIR:-/home/claude/anexomail-workspace}" || exit 0
F=docs/claude/state/WORKING-NOW.md; L=docs/claude/state/LIVE-5MIN.txt   # L is git-ignored: the 5-min stamp never dirties the repo; F is committed by rec.sh/ckpt.sh at each step
refresh() {
  local age=999999; [ -f "$L" ] && age=$(( $(date +%s) - $(stat -c %Y "$L") ))
  if [ "$age" -ge 300 ] || [ "${1:-}" = "force" ]; then { echo "5-min stamp $(TZ=Asia/Karachi date '+%d %b %Y %H:%M:%S PKT')"; git log -1 --format='last commit %h %s' 2>/dev/null; python3 docs/cursor-work/server/qstate.py brief 2>/dev/null | grep -m1 "^NOW:" | cut -c1-300; } > "$L"; python3 docs/cursor-work/server/rules-read.py >/dev/null 2>&1; fi
}
remind() {
  echo "##### AUTO REMINDER $(TZ=Asia/Karachi date '+%d %b %H:%M PKT') (refreshed every 5 min): address him ONLY as Aap / Nauman bhai (never tum). Roman Urdu short, ONE server command one line, end with Rule-70 table + 'Abhi code mein NAHI'."
  echo "TECH LAW: Rust+Tokio+axum, one Rust WASM kernel in the browser, HTTP/3 only + WebTransport (UDP 443), X25519MLKEM768 + AES-256-GCM, PostgreSQL RLS hash chains, React 19 TS + TanStack Router + Vite + Tailwind 4, ClamAV, Hetzner Storage Box; no Node/Bun/WebSocket; a listed technology missing from code = OPEN GAP, never GREEN."
  sed -n 's/^DOING: /DOING: /p;s/^NEXT STEP: /NEXT STEP: /p' "$F" 2>/dev/null | head -2 | cut -c1-400
  python3 docs/cursor-work/server/qstate.py brief 2>/dev/null | grep -m1 "^NOW:" | cut -c1-300
  echo "Read order after compaction: WORKING-NOW.md, RESUME-POINT.md, tech-contracts/CURRENT.md. Commit only via rec.sh."
}
case "${1:-}" in
  --loop) while true; do refresh force; sleep 300; done ;;
  --remind) refresh; remind ;;
  *) refresh force; echo "refreshed $F" ;;
esac
