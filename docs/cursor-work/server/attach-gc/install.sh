#!/usr/bin/env bash
# ANEXOMAIL — attachments safai timer install (idempotent). SQL E48 PEHLE chalayen.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/attach-gc/install.sh)
# Roz 03:41 (random 10 min) — sirf purani adhoori uploads aur be-malik files. Mail/Caddy/Rust/web kuch nahi badalta. Abhi ek baar chalata hai.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
DIR="docs/cursor-work/server/attach-gc"
BIN="${BIN:-/usr/local/bin/anexomail-attach-gc}"
UNITS="${UNITS:-/etc/systemd/system}"
src_get() { if [ -n "${SRC_DIR:-}" ]; then cat "$SRC_DIR/$1"; else git -C "$REPO" show "origin/main:$DIR/$1"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for f in anexomail-attach-gc.py anexomail-attach-gc.service anexomail-attach-gc.timer; do
  src_get "$f" >"$T/$f" 2>/dev/null && [ -s "$T/$f" ] || { echo "FAIL: $f repo se nahi mili (git fetch hua?)"; exit 2; }
done
python3 -I "$T/anexomail-attach-gc.py" --selftest || { echo "FAIL: selftest"; exit 1; }
mkdir -p "$(dirname "$BIN")" "$UNITS"
install -m 755 "$T/anexomail-attach-gc.py" "$BIN"
install -m 644 "$T/anexomail-attach-gc.service" "$UNITS/anexomail-attach-gc.service"
install -m 644 "$T/anexomail-attach-gc.timer" "$UNITS/anexomail-attach-gc.timer"
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl enable --now anexomail-attach-gc.timer >/dev/null 2>&1 || echo "WARN: timer enable nahi hua"
  systemctl list-timers 'anexomail-attach-gc.timer' --no-pager 2>&1 | head -4
else
  echo "WARN: systemd nahi mila — timer nahi laga (runner haath se: $BIN)"
fi
echo "== abhi ek baar chalate hain"
"$BIN"; rc=$?
echo "exit $rc  (0 = theek; 1 = RPC jawab galat — SQL E48 chala hai?; 2 = env nahi mila; 3 = Storage Box mount nahi — kuch nahi kiya)"
exit "$rc"
