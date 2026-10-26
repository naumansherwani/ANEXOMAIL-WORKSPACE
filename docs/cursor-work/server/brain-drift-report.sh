#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY: live Brain ki routes/revenue.ts + routes/release.ts repo ke BASE (8be9a82^) se kaise alag hain. Kuch badalta nahi.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-drift-report.sh)
# Output Claude ko bhejein: usi se hunks banenge (guroh D).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"; BASE="${BASE:-8be9a82^}"
for f in routes/revenue.ts routes/release.ts; do
  echo "================ $f (BASE -> LIVE)"
  git -C "$REPO" show "$BASE:server/$f" > /tmp/.bd.base.$$ 2>/dev/null || { echo "base nahi mila"; continue; }
  diff -u /tmp/.bd.base.$$ "$SRC/$f" | head -300
done
rm -f /tmp/.bd.base.$$
