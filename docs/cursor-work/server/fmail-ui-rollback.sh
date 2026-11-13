#!/bin/bash
# ROLLBACK to the backup taken by fmail-ui-backup.sh (SPA + Rust binary). Verifies the manifest first; keeps the bad copy aside; restarts the service.
set -e
ROOT=/opt/anexomail-founder; B=/root/backups/ledger-hybrid-13nov
[ -f "$B/MANIFEST.sha256" ] || { echo "FAIL: backup nahi mila ($B)"; exit 2; }
( cd "$B" && sha256sum -c --quiet MANIFEST.sha256 ) || { echo "FAIL: backup ka hash match nahi karta, ruk gaya"; exit 3; }
S=$(date +%Y%m%d-%H%M%S); mv "$ROOT/web" "$ROOT/web.rejected.$S"; cp -a "$B/web" "$ROOT/web"
if [ -f "$B/anexomail-founder.bin" ]; then
  BIN="$(ls "$ROOT"/target/release/anexomail-founder "$ROOT"/anexomail-founder 2>/dev/null | head -1)"
  [ -n "$BIN" ] && { cp -a "$BIN" "$BIN.rejected.$S"; systemctl stop anexomail-founder; cp -a "$B/anexomail-founder.bin" "$BIN"; }
fi
systemctl restart anexomail-founder; sleep 2
echo "ROLLBACK OK. healthz=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/healthz 2>/dev/null || echo na) | web: $(grep -o 'index-[A-Za-z0-9_-]*\.js' "$ROOT/web/index.html" | head -1)"
