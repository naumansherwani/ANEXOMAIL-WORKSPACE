#!/usr/bin/env bash
# Local 2-minute checkpoint loop (his 20 Nov 19:25 order). Costs NO credit (plain shell, no model call). Stops when the session container stops.
cd /home/claude/anexomail-workspace || exit 0
while true; do bash docs/cursor-work/server/ckpt.sh --auto >/dev/null 2>&1; sleep 120; done
