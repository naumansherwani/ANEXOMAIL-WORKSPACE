#!/bin/bash
# K6.4 (founder lane, READ-ONLY, Rule 48): did the founder page open WebTransport (QUIC) sessions lately? Reads the service journal only. Changes nothing.
#   SINCE=-20min (default)   e.g. SINCE=-2h
set -u
SINCE="${SINCE:--20min}"; SVC=anexomail-founder
journalctl -u "$SVC" --since="$SINCE" --no-pager 2>/dev/null | grep -i "WebTransport" | tail -12
echo "---- listener (UDP):"; ss -lunp 2>/dev/null | grep -E ":4443 " || echo "no UDP 4443 listener"
