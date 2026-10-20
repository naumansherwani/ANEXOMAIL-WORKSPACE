#!/usr/bin/env bash
# ANEXOMAIL — blocked-account purge timer install (idempotent). SQL E45 aur E46 PEHLE chalayen.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/integrity-purge/install.sh)
# Kya karta hai: purge runner (har ghante :17) + notice mail worker (har 5 minute, Postfix se) lagata hai aur ABHI ek baar chalata hai. Mail/Caddy/Rust/web kuch nahi badalta.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
DIR="docs/cursor-work/server/integrity-purge"
BIN="${BIN:-/usr/local/bin/anexomail-integrity-purge}"
NBIN="${NBIN:-/usr/local/bin/anexomail-integrity-notify}"
UNITS="${UNITS:-/etc/systemd/system}"
src_get() { if [ -n "${SRC_DIR:-}" ]; then cat "$SRC_DIR/$1"; else git -C "$REPO" show "origin/main:$DIR/$1"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for f in anexomail-integrity-purge.sh anexomail-integrity-purge.service anexomail-integrity-purge.timer anexomail-integrity-notify.py anexomail-integrity-notify.service anexomail-integrity-notify.timer; do
  src_get "$f" >"$T/$f" 2>/dev/null && [ -s "$T/$f" ] || { echo "FAIL: $f repo se nahi mili (git fetch hua?)"; exit 2; }
done
bash -n "$T/anexomail-integrity-purge.sh" || { echo "FAIL: runner syntax"; exit 1; }
python3 -I -m py_compile "$T/anexomail-integrity-notify.py" || { echo "FAIL: notify syntax"; exit 1; }
mkdir -p "$(dirname "$BIN")" "$UNITS"
install -m 755 "$T/anexomail-integrity-purge.sh" "$BIN"
install -m 644 "$T/anexomail-integrity-purge.service" "$UNITS/anexomail-integrity-purge.service"
install -m 644 "$T/anexomail-integrity-purge.timer" "$UNITS/anexomail-integrity-purge.timer"
install -m 755 "$T/anexomail-integrity-notify.py" "$NBIN"
install -m 644 "$T/anexomail-integrity-notify.service" "$UNITS/anexomail-integrity-notify.service"
install -m 644 "$T/anexomail-integrity-notify.timer" "$UNITS/anexomail-integrity-notify.timer"
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl enable --now anexomail-integrity-purge.timer anexomail-integrity-notify.timer >/dev/null 2>&1 || echo "WARN: timer enable nahi hua"
  systemctl list-timers 'anexomail-integrity-*.timer' --no-pager 2>&1 | head -5
else
  echo "WARN: systemd nahi mila — timer nahi laga (runner haath se chal sakta hai: $BIN)"
fi
echo "== abhi ek baar chalate hain"
"$BIN"; rc=$?
"$NBIN"; nrc=$?
[ "$rc" -eq 0 ] && rc=$nrc
echo "exit $rc  (0 = theek; 1 = RPC jawab galat — SQL E45 chala hai?; 2 = env nahi mila)"
exit "$rc"
