#!/usr/bin/env bash
# Q1b-3 T3 (NOT deferred, his 13 Nov 19:11 order: "complete kero"): a REAL end-to-end mail test that needs NO outside sender.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-intake-selftest.sh)
# It hands THREE real mails to Postfix itself (sendmail submission). Each one then travels the real path: Postfix -> transport_maps (founder address only) -> LMTP 127.0.0.1:18025
#   -> ClamAV INSTREAM -> opaque-attachment guard -> AES-256-GCM seal -> PostgreSQL (RLS) -> ledger. Nothing is faked: the answer comes from Postfix's own delivery log.
#   mail 1: plain text                       expect  status=sent (250 2.0.0 stored) and it lands in the INBOX
#   mail 2: EICAR test file as attachment    expect  stored, folder QUARANTINE (clamd FOUND)
#   mail 3: encrypted-ZIP stub as attachment expect  stored, folder QUARANTINE (clamd Heuristics.Encrypted.Zip / opaque guard)
# Then look at the Mail page (Inbox + Quarantine). Changes nothing else; the three test mails stay as sealed rows (they are real rows in his mailbox, subject "T3 selftest ...").
set -uo pipefail
ADDR="${FOUNDER_MAIL_ADDR:-naumansherwani.founder@anexomail.com}"; TS="$(date +%s)"; LOG=/var/log/mail.log
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }; command -v sendmail >/dev/null || { echo "FAIL: sendmail not found"; exit 2; }
ss -H -tlnp | grep -q "127.0.0.1:18025.*anexomail-found" || { echo "FAIL: founder LMTP not listening (fmail-intake-on.sh first)"; exit 3; }
[ "$(postconf -h transport_maps)" = "hash:/etc/postfix/founder-transport" ] || { echo "FAIL: founder transport entry missing (fmail-intake-postfix.sh first)"; exit 3; }
mk() { python3 - "$1" "$2" "$ADDR" "$TS" <<'PY'
import sys,email.message,base64,struct,zlib
kind,n,addr,ts=sys.argv[1:5]
m=email.message.EmailMessage(); m["From"]="T3 selftest <t3-selftest@mail.anexomail.com>"; m["To"]=addr; m["Subject"]=f"T3 selftest {n} {kind} {ts}"; m["Message-ID"]=f"<t3-{n}-{ts}@mail.anexomail.com>"
m.set_content(f"Q1b-3 T3 end-to-end self-test mail {n} ({kind}). Sent by Postfix itself, travels the real intake path.")
if kind=="eicar":
    e=("X5O!P%@AP[4\\PZX54(P^)7CC)7}$"+"EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*").encode(); m.add_attachment(e,maintype="application",subtype="octet-stream",filename="eicar.com")
if kind=="encrypted-zip":
    name=b"a.txt"; data=b"x"*20; crc=zlib.crc32(b"hello")&0xffffffff; fl=1
    lh=struct.pack("<4sHHHHHIIIHH",b"PK\x03\x04",20,fl,0,0,0,crc,len(data),5,len(name),0)+name+data
    cd=struct.pack("<4sHHHHHHIIIHHHHHII",b"PK\x01\x02",20,20,fl,0,0,0,crc,len(data),5,len(name),0,0,0,0,0,0)+name
    eo=struct.pack("<4sHHHHIIH",b"PK\x05\x06",0,0,1,1,len(cd),len(lh),0); m.add_attachment(lh+cd+eo,maintype="application",subtype="zip",filename="stub.zip")
sys.stdout.buffer.write(bytes(m))
PY
}
logsrc() { if [ -r "$LOG" ]; then cat "$LOG"; else journalctl -u postfix --since "-10 min" --no-pager 2>/dev/null; fi; }
echo "== sending 3 mails through Postfix"; for spec in "1 plain" "2 eicar" "3 encrypted-zip"; do set -- $spec; mk "$2" "$1" | sendmail -t -i && echo "  queued: T3 selftest $1 $2 (t3-$1-$TS)"; done
echo "== waiting for delivery (up to 60 s)"; for i in $(seq 1 30); do sleep 2; N="$(logsrc | grep -F "t3-" | grep -c "message-id=<t3-[123]-$TS@")"; D="$(logsrc | grep -E "relay=127\.0\.0\.1\[127\.0\.0\.1\]:18025" | grep -cE "status=(sent|deferred|bounced)")"; [ "$N" -ge 3 ] && [ "$D" -ge 3 ] && break; done
echo "== Postfix delivery results"; for n in 1 2 3; do
  QID="$(logsrc | grep -F "message-id=<t3-$n-$TS@" | head -1 | sed -E 's/.*postfix\/cleanup\[[0-9]+\]: ([A-F0-9]+):.*/\1/; s/.* ([A-F0-9]{8,}): message-id.*/\1/')"
  echo "  mail $n queue-id ${QID:-?}"; [ -n "${QID:-}" ] && logsrc | grep -F "$QID" | grep -E "to=<$ADDR>" | tail -1 | sed -E 's/^.*(relay=.*)$/    \1/' | cut -c1-260
done
echo "== queue now"; postqueue -p | tail -3
echo "== founder service (last lines)"; journalctl -u anexomail-founder -n 6 --no-pager 2>/dev/null | cut -c1-220 | sed 's/^/  /'
echo "READ: 'status=sent (250 2.0.0 stored)' for all three = the real path works end to end. Now open Mail: mail 1 in INBOX; mails 2 and 3 in QUARANTINE (Quarantine needs a passkey touch to open). Send me this output."
