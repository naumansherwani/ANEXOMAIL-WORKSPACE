#!/usr/bin/env bash
# ANEXOMAIL — G38 attachments: server ka asli haal (READ-ONLY; sirf storage mein ek chhoti test-file likh kar hata deta hai).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/attach-check.sh)
# Dikhata hai: (1) Storage Box mount + likhne ki salahiyat + jagah, (2) Postfix ki mail-size limit vs hamari cap, (3) virus scanner (clamd),
# (4) Rust ke teeno raaste zinda. Kuch badalta nahi. Postfix badalna ho to founder ki "haan" ke baad hi (neeche likha hai).
set -uo pipefail
ROOT="${ATTACH_DIR:-/mnt/anexomail-box/attachments}"
RPC="${RPC:-http://127.0.0.1:3200}"
CAP="${CAP:-7000000}"          # SQL mail_attach_limits.server_ceiling_bytes ki default; DB se mil jaye to wahi (neeche)
if [ -r /etc/anexomail/sync.env ] && command -v psql >/dev/null 2>&1; then
  _c="$( . /etc/anexomail/sync.env 2>/dev/null; psql "${WORKING_URL:-}" -X -At -c "select value from public.mail_attach_limits where key='server_ceiling_bytes'" 2>/dev/null | head -1 )"
  [[ "$_c" =~ ^[0-9]+$ ]] && CAP="$_c"
fi
bad=0
say() { printf '%-9s %s\n' "$1" "$2"; }

echo "== 1) storage"
if command -v findmnt >/dev/null 2>&1 && findmnt -n /mnt/anexomail-box >/dev/null 2>&1; then say OK "/mnt/anexomail-box mount hai: $(findmnt -n -o SOURCE,FSTYPE /mnt/anexomail-box | head -1)"
else say FAIL "/mnt/anexomail-box mount NAHI — bash server/storage/mount-box.sh u659696 (upload tab tak 503 deta hai; local disk par kuch nahi likhta)"; bad=1; fi
if [ -d "$ROOT" ]; then
  say OK "$ROOT maujood"
  t="$ROOT/.check-$$"
  if ( printf x >"$t" ) 2>/dev/null && rm -f "$t"; then say OK "likh/mita sakte hain"; else say FAIL "$ROOT mein likh nahi sakte"; bad=1; fi
  say INFO "jagah: $(df -h "$ROOT" 2>/dev/null | awk 'NR==2{print $4" khali / "$2" ("$5" bhara)"}')"
else say FAIL "$ROOT nahi hai"; bad=1; fi

echo "== 2) Postfix limit vs hamari cap"
if command -v postconf >/dev/null 2>&1; then
  L="$(postconf -h message_size_limit 2>/dev/null | head -1)"
  if [[ "$L" =~ ^[0-9]+$ ]]; then
    NEED=$(( CAP * 4 / 3 + 200000 ))
    SAFE=$(( (L - 200000) * 3 / 4 ))
    say INFO "Postfix message_size_limit = $L bytes; cap $CAP raw => mail ~$NEED bytes"
    if [ "$NEED" -le "$L" ]; then say OK "cap Postfix ki limit ke andar hai (bounce nahi hoga). Is limit par sabse bari mehfooz cap: $SAFE raw bytes"
    else say FAIL "cap Postfix se bari hai — attachment wali mail bounce hogi. Ya SQL se cap kam karein: update public.mail_attach_limits set value=$SAFE where key='server_ceiling_bytes';"; bad=1; fi
    if [ "$SAFE" -lt 18874368 ]; then say INFO "18 MB tak ke liye Postfix limit badhani hogi (founder 'haan' ke baad): postconf -e message_size_limit=26214400 && systemctl reload postfix"; fi
  else say WARN "postconf se limit nahi mili"; fi
else say WARN "postconf nahi mila (yeh server Postfix wala nahi?)"; fi

echo "== 3) virus scanner (clamd)"
CA="${CLAMD_ADDR:-127.0.0.1:3310}"; CH="${CA%:*}"; CP="${CA##*:}"
if timeout 2 bash -c "exec 3<>/dev/tcp/$CH/$CP" 2>/dev/null; then say OK "clamd chal raha hai ($CA) — upload scan hoga (scanned:true)"
else say WARN "clamd band ($CA) — upload chalega par 'scanned:false' likha jayega. Theek karne ke liye: INSTALL=1 bash server file-safety-check.sh"; fi

echo "== 3b) kya koi attachment seedha web par khula hai? (Caddy /files/* static)"
if [ -d "$ROOT" ]; then
  probe="$ROOT/.public-probe-$$"
  if ( printf 'probe' >"$probe" ) 2>/dev/null; then
    code="$(curl -sk -m 8 -o /dev/null -w '%{http_code}' --resolve anexomail.com:443:127.0.0.1 "https://anexomail.com/files/$(basename "$probe")" 2>/dev/null)"
    rm -f "$probe"
    if [ "$code" = 200 ]; then say FAIL "Caddy /files/* attachments folder ko BINA LOGIN seedha parosta hai (probe 200). App isey istemal nahi karti. Band karne ke liye (founder ki 'haan' ke baad): bash docs/cursor-work/server/attach-caddy-close-files.sh"; bad=1
    else say OK "/files/* se attachments seedha nahi milte (probe $code)"; fi
  fi
fi

echo "== 4) Rust raaste (bina login)"
a="$(curl -s -m 6 -o /dev/null -w '%{http_code}' -X POST -H 'authorization: Bearer x' --data-binary x "$RPC/file/attach")"
b="$(curl -s -m 6 -o /dev/null -w '%{http_code}' "$RPC/file/attach/get?id=00000000-0000-0000-0000-000000000000")"
c="$(curl -s -m 6 -o /dev/null -w '%{http_code}' -X POST -H 'authorization: Bearer x' -H 'content-type: application/json' -d '{"input":{}}' "$RPC/rpc/mail.attach.limits")"
if [ "$a" = 401 ] && [ "$b" = 401 ] && [ "$c" = 401 ]; then say OK "upload $a · download $b · limits $c (401 = Rust ne pakda)"; else say FAIL "upload $a · download $b · limits $c — Rust par MODULES=\"attach\" install chalayen"; bad=1; fi

echo; [ "$bad" = 0 ] && echo "RESULT: GREEN" || echo "RESULT: RED (upar FAIL wali lines)"
exit "$bad"
