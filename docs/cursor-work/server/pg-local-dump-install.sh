#!/usr/bin/env bash
# pg-local-dump-install.sh (21 Nov 2026 01:15 PKT, QCONNECT step 10). His word 22:06: the dump stays on HIS SERVER ONLY, NEVER on the Hetzner Storage Box. Installs a nightly dump of anexo_copy: /var/backups/anexomail-pg (root, 0700), last 7 kept, SHA-256 beside each. Opens no port, sends nothing anywhere. Runs one dump now as the proof.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pg-local-dump-install.sh) 2>&1 | tail -20
set -uo pipefail
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
D=/var/backups/anexomail-pg; B=/usr/local/sbin/anexomail-pg-dump.sh
mkdir -p $D; chmod 700 $D
cat >$B <<'SH'
#!/usr/bin/env bash
set -uo pipefail
D=/var/backups/anexomail-pg; N="$D/anexo_copy-$(date +%Y%m%d-%H%M%S).dump"; umask 077
pg_dump -h /var/run/postgresql -d anexo_copy -Fc -f "$N" || { echo "dump FAILED"; rm -f "$N"; exit 1; }
( cd "$D" && sha256sum "$(basename "$N")" > "$(basename "$N").sha256" )
ls -1t "$D"/anexo_copy-*.dump 2>/dev/null | tail -n +8 | while read -r O; do rm -f "$O" "$O.sha256"; done
echo "dump ok: $N $(du -h "$N" | cut -f1)"
SH
chmod 700 $B
cat >/etc/systemd/system/anexomail-pg-dump.service <<UNIT
[Unit]
Description=ANEXOMAIL local PostgreSQL nightly dump (server only, 7 kept)
[Service]
Type=oneshot
ExecStart=$B
UNIT
cat >/etc/systemd/system/anexomail-pg-dump.timer <<UNIT
[Unit]
Description=ANEXOMAIL nightly local dump
[Timer]
OnCalendar=*-*-* 03:20:00
Persistent=true
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now anexomail-pg-dump.timer >/dev/null 2>&1
echo "== one dump now (proof)"; $B
echo "== sha256 check"; ( cd $D && sha256sum -c $(ls -1t *.sha256 | head -1) 2>&1 | tail -1 )
echo "== timer"; systemctl list-timers anexomail-pg-dump.timer --no-pager 2>/dev/null | head -3 | cut -c1-140
echo "OK: nightly dump on this server only (no Storage Box), 7 kept. Folder: $D"
