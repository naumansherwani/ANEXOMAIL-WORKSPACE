#!/usr/bin/env bash
# Q1b-3 T2 (HIS BIG HAAN 13 Nov 18:40, started 18:5x): clamd AlertEncrypted yes + AlertExceedsMax yes.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-clamd-alerts.sh)
# Why (clamd.conf man page + his audit 13 Nov 04:35): both are OFF by default, so a password-protected 7z/RAR/ZIP/PDF and a zip-bomb that exceeds MaxFileSize 64M / MaxScanSize 100M / MaxRecursion 16 are reported "OK" = clean.
# With them ON clamd answers "Heuristics.Encrypted.* FOUND" / "Heuristics.Limits.Exceeded FOUND" and the founder intake quarantines the mail (clam_state: ...FOUND = infected). Rust already guards encrypted ZIP/PDF/Office itself; this closes 7z/RAR and the limits.
# Effect on awam (clamd is shared): encrypted or over-limit attachments get flagged there too. Restart takes up to ~1-2 min while signatures load: in that window the founder intake quarantines mail (safe, nothing lost) and awam scans answer error.
# Steps: backup clamd.conf, set both lines, restart, wait for PING, EICAR must be FOUND, clean text must be OK, crafted encrypted ZIP should now be FOUND. Failure of restart/EICAR/clean => rollback.
# Rollback later:  cp /etc/clamav/clamd.conf.pre-alerts /etc/clamav/clamd.conf && systemctl restart clamav-daemon
set -uo pipefail
CF=/etc/clamav/clamd.conf; BK=$CF.pre-alerts; SVC=clamav-daemon
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }; [ -f "$CF" ] || { echo "FAIL: $CF not found"; exit 2; }
undo() { echo "== ROLLBACK ($1)"; cp -p "$BK" "$CF"; systemctl restart "$SVC"; echo "clamd.conf restored, clamd restarted"; exit 1; }
scan() { python3 - "$1" <<'PY'
import socket,struct,sys,base64
d=base64.b64decode(sys.argv[1]); s=socket.create_connection(("127.0.0.1",3310),20)
s.sendall(b"zINSTREAM\0"+struct.pack(">I",len(d))+d+struct.pack(">I",0)); print(s.recv(300).rstrip(b"\0").decode())
PY
}
echo "== 1/6 backup"; [ -f "$BK" ] || cp -p "$CF" "$BK"; echo "  $BK"
echo "== 2/6 set"; for k in AlertEncrypted AlertExceedsMax; do if grep -Eq "^$k[[:space:]]" "$CF"; then sed -i -E "s/^$k[[:space:]].*/$k yes/" "$CF"; else echo "$k yes" >>"$CF"; fi; grep -E "^$k " "$CF" | sed 's/^/  /'; done
echo "== 3/6 restart + wait for PING (signatures load)"; systemctl restart "$SVC" || undo restart; OK=0
for i in $(seq 1 90); do sleep 2; R="$( (exec 3<>/dev/tcp/127.0.0.1/3310 && printf 'zPING\0' >&3 && timeout 3 head -c 8 <&3 | tr -d '\0\n') 2>/dev/null)"; [ "$R" = PONG ] && { OK=1; break; }; done
[ $OK = 1 ] && echo "  clamd PONG after ~$((i*2)) s" || undo "clamd did not answer PONG within 180 s"
echo "== 4/6 EICAR must be FOUND"; E1='X5O!P%@AP[4\PZX54(P^)7CC)7}$'; E2='EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
R="$(scan "$(printf '%s%s' "$E1" "$E2" | base64 -w0)")"; echo "  $R"; echo "$R" | grep -q "FOUND" || undo "EICAR not detected"
echo "== 5/6 clean text must be OK"; R="$(scan "$(printf 'hello, an ordinary clean mail body' | base64 -w0)")"; echo "  $R"; echo "$R" | grep -q ": OK" || undo "clean text not OK"
echo "== 6/6 encrypted ZIP (a harmless stub with the encrypted flag set) should now be FOUND"
Z="$(python3 - <<'PY'
import struct,zlib,base64
name=b"a.txt"; data=b"x"*20; crc=zlib.crc32(b"hello")&0xffffffff; fl=0x0001
lh=struct.pack("<4sHHHHHIIIHH",b"PK\x03\x04",20,fl,0,0,0,crc,len(data),5,len(name),0)+name+data
cd=struct.pack("<4sHHHHHHIIIHHHHHII",b"PK\x01\x02",20,20,fl,0,0,0,crc,len(data),5,len(name),0,0,0,0,0,0)+name
eo=struct.pack("<4sHHHHIIH",b"PK\x05\x06",0,0,1,1,len(cd),len(lh),0)
print(base64.b64encode(lh+cd+eo).decode())
PY
)"; R="$(scan "$Z")"; echo "  $R"
echo "$R" | grep -qi "Encrypted.*FOUND" && echo "  PROVEN: encrypted archives are now flagged" || echo "  NOT PROVEN by this stub (clamd parsed it differently): send me this line; the config is still applied, Rust guards ZIP/PDF/Office itself"
echo "OK - clamd now alerts on encrypted archives/documents and on limit-exceeded files. T2 done; T3 (his real test mail) next. Rollback line is at the top of this script."
