#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK audit-export installer (D5a-4 OUTSIDE COPY, 23 Nov 2026). Every lookup-audit checkpoint is signed with the Desk's own Ed25519 key and written as one file OUTSIDE the database:
# 1) a local folder (/var/lib/anexomail-desk-audit), 2) his Hetzner Storage Box, folder /mnt/anexomail-box/desk-audit (the sshfs mount he already has; NO new password, NO new key, nothing of the founder or awam folders is touched).
# A systemd timer runs the job every 10 minutes. Every run compares ALL older files with the database: a rewritten or missing checkpoint = ledger line + high alert + failed run (exit 3).
# Own unit anexomail-desk-audit + timer. It does NOT touch Caddy, ufw, the founder or awam services, or the attachment folder of the Storage Box. Rerun is safe (files are never overwritten).
set -u
ROOT=/opt/anexomail-desk; SVC=anexomail-desk; AU=anexomail-desk-audit; BOX=/mnt/anexomail-box; LOCAL=/var/lib/anexomail-desk-audit
echo "== AUDIT 1/4 read-only facts (the Storage Box mount)"
if command -v findmnt >/dev/null 2>&1 && findmnt -n "$BOX" >/dev/null 2>&1; then echo "   Storage Box mount: $(findmnt -n -o SOURCE,FSTYPE "$BOX" | head -1)"; BOXOK=1
else echo "   Storage Box is NOT mounted at $BOX right now: the local signed copy still works, the box copy starts the moment the mount is back (the timer retries)"; BOXOK=0; fi
[ -x "$ROOT/anexomail-desk" ] || { echo "FAIL: $ROOT/anexomail-desk missing (run desk-install first)"; exit 2; }
timeout 5 "$ROOT/anexomail-desk" audit-verify /nonexistent-folder >/dev/null 2>&1; [ $? = 3 ] || { echo "FAIL: this Desk binary has no audit-export (run desk-install again)"; exit 2; }
echo "== AUDIT 2/4 unit + timer (own unit, same signing key and database login as the Desk, nothing else)"
D=/etc/systemd/system/$AU.service.d; mkdir -p "$D"
for f in sign.conf db.conf; do [ -f /etc/systemd/system/$SVC.service.d/$f ] && cp -f /etc/systemd/system/$SVC.service.d/$f "$D/$f"; done
[ -f "$D/sign.conf" ] && [ -f "$D/db.conf" ] || { echo "FAIL: the Desk's sign.conf or db.conf drop-in is missing (run desk-install first)"; exit 2; }
cat >/etc/systemd/system/$AU.service <<U
[Unit]
Description=Anexomail Admin Desk: sign and copy the lookup-audit checkpoints outside the database
After=network-online.target anexomail-desk.service
[Service]
Type=oneshot
User=$SVC
StateDirectory=$AU
ExecStart=$ROOT/anexomail-desk audit-export $LOCAL
# the Storage Box copy runs with the mount's rights (the + prefix); skipped, with a clear line, when the box is not mounted
ExecStartPost=+/bin/sh -c 'if mountpoint -q $BOX; then install -d -m 750 $BOX/desk-audit && exec $ROOT/anexomail-desk audit-export $BOX/desk-audit; else echo "AUDIT EXPORT: Storage Box not mounted, local copy only"; fi'
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
MemoryDenyWriteExecute=true
U
cat >/etc/systemd/system/$AU.timer <<U
[Unit]
Description=Anexomail Admin Desk: audit checkpoint copy every 10 minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
Persistent=true
[Install]
WantedBy=timers.target
U
systemctl daemon-reload && systemctl enable --now $AU.timer >/dev/null 2>&1
echo "== AUDIT 3/4 first run now"
systemctl start $AU.service; RC=$?
journalctl -u $AU.service -n 6 --no-pager -o cat 2>/dev/null | sed 's/^/   /'
echo "== AUDIT 4/4 proof: the files are checked WITHOUT the database (signatures + chain)"
V1="$("$ROOT/anexomail-desk" audit-verify "$LOCAL" 2>&1 | tail -1)"; echo "   local: $V1"
if [ "$BOXOK" = 1 ] && [ -d "$BOX/desk-audit" ]; then V2="$("$ROOT/anexomail-desk" audit-verify "$BOX/desk-audit" 2>&1 | tail -1)"; echo "   box:   $V2"; fi
case "$V1" in "AUDIT FILES OK"*|"AUDIT FILES: no checkpoint"*) [ $RC = 0 ] && echo "OK: audit copies are on (timer every 10 min). Check any time: $ROOT/anexomail-desk audit-verify $BOX/desk-audit" || { echo "FAIL: the first run failed (paste the lines above)"; exit 7; };; *) echo "FAIL: audit files do not verify (paste the lines above)"; exit 7;; esac
