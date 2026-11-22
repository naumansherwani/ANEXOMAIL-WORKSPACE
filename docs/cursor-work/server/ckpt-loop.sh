#!/usr/bin/env bash
# Local 2-minute checkpoint loop (his 20 Nov 19:25 order). Costs NO credit (plain shell, no model call). Stops when the session container stops.
# HIS LAW 22 Nov 2026 21:40 PKT (in anger): once everything is committed and pushed, this loop must NOT keep dirtying the repo (that made the stop hook ask "commit again" forever).
# So it snapshots ONLY while real work is uncommitted (any changed file besides the WORKING-NOW / COMPACT-SAVE snapshot files); with a clean tree it does nothing. docs/claude/LOOP-AFTER-COMMIT-BANNED-LAW-22NOV.md
cd /home/claude/anexomail-workspace || exit 0
while true; do
  if git status --porcelain 2>/dev/null | grep -v -E 'WORKING-NOW\.md|COMPACT-SAVE\.md|state/REMINDERS\.md' | grep -q .; then bash docs/cursor-work/server/ckpt.sh --auto >/dev/null 2>&1; fi
  sleep 120
done
