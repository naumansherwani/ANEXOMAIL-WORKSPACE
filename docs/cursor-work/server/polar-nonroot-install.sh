#!/usr/bin/env bash
# ============================================================================
# polar-nonroot-install.sh — Polar engine ko ROOT se hata kar alag kam-haisiyat user 'polar' par chalana + .env 600 (22 Oct 2026).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/polar-nonroot-install.sh)
#
# KYUN: engine root chal raha tha aur .env (Polar token, DB url) 644 yani sab padh sakte the. Engine mein koi bug/exploit ho
#       to attacker ko ROOT milta. Ab: user 'polar' (nologin), .env 600 (sirf polar+root), pcp.key 640 root:polar.
# SAFETY: har qadam backup; engine band hone ka waqt chand second (Polar retry karta hai, WAL kuch nahi khota);
#         proof fail => purana tareeqa (root) wapas + chalu. Caddy / Brain / Rust app ko haath nahi lagta.
# ============================================================================
set -uo pipefail
ENG=/opt/polar-rust-payment; U=polar; PM2N=polar-rust-payment; BIN="$ENG/target/release/polar-rust-payment"
KEYF=/etc/anexomail/pcp.key; L=http://127.0.0.1:3400
STAMP="$(date +%Y%m%d-%H%M%S)"; BK="/root/anexomail-backups/polar-nonroot-$STAMP"
say(){ printf '\n==> %s\n' "$*"; }; ok(){ printf '    OK   %s\n' "$*"; }; bad(){ printf '    FAIL %s\n' "$*"; }

[ "$(id -u)" = "0" ] || { echo "!!! root se chalao"; exit 1; }
[ -x "$BIN" ] && [ -f "$ENG/.env" ] || { echo "!!! engine binary ya .env nahi mila"; exit 1; }
curl -fsS -m 6 "$L/ready" 2>/dev/null | grep -q '"ready":true' || { echo "!!! engine abhi ready nahi — pehle usay theek karo (kuch nahi badla)"; exit 1; }

say "1/5 backup -> $BK"
mkdir -p "$BK"; chmod 700 "$BK"
cp -a "$ENG/.env" "$BK/.env"; [ -f "$KEYF" ] && cp -a "$KEYF" "$BK/pcp.key"
stat -c '%U:%G %a %n' "$ENG" "$ENG/.env" "$ENG/wal" "$KEYF" /etc/anexomail 2>/dev/null >"$BK/perms-before.txt" || true
pm2 jlist >"$BK/pm2.json" 2>/dev/null || true
ok "backup + purani permissions note ($BK/perms-before.txt)"

rollback() {
  echo "!!! ROLLBACK: $1"
  pm2 delete "$PM2N" >/dev/null 2>&1 || true
  chown -R root:root "$ENG/wal" 2>/dev/null || true
  (cd "$ENG" && pm2 start "$BIN" --name "$PM2N" --cwd "$ENG" >/dev/null 2>&1) && pm2 save >/dev/null 2>&1
  sleep 3
  curl -fsS -m 8 "$L/ready" 2>/dev/null | grep -q '"ready":true' && echo "    purana (root) engine wapas chal raha hai. Backup: $BK" || echo "    !!! engine ready nahi — pm2 logs $PM2N --lines 40. Backup: $BK"
  exit 1
}

say "2/5 user '$U' + permissions"
id "$U" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$U" || { bad "useradd fail"; exit 1; }
ok "user $U maujood ($(id -u "$U"))"
# rasta (path) 'polar' ko dikhna chahiye
chmod o+x /opt "$ENG" "$ENG/target" "$ENG/target/release" 2>/dev/null || true
chmod o+rx "$BIN" 2>/dev/null || true
if [ -d /etc/anexomail ]; then chmod o+x /etc/anexomail; fi
if [ -f "$KEYF" ]; then chown root:"$U" "$KEYF"; chmod 640 "$KEYF"; fi
ok "pcp.key 640 root:$U (baqi dunya nahi padh sakti)"

say "3/5 engine ruko -> ownership -> .env 600 -> user polar par chalao"
pm2 stop "$PM2N" >/dev/null 2>&1 || true
chown -R "$U":"$U" "$ENG/wal"
chown "$U":"$U" "$ENG/.env"; chmod 600 "$ENG/.env"
# kill-switch folder (PCP_PAUSE_DIR = $ENG) mein polar nahi likhta — sirf padhta hai; root touch/rm karta hai
runuser -u "$U" -- test -r "$ENG/.env" || { bad ".env polar nahi padh sakta"; rollback ".env permission"; }
runuser -u "$U" -- test -x "$BIN" || { bad "binary polar nahi chala sakta"; rollback "binary path permission"; }
runuser -u "$U" -- sh -c "echo ok > '$ENG/wal/.w' && rm -f '$ENG/wal/.w'" || { bad "wal polar likh nahi sakta"; rollback "wal permission"; }
pm2 delete "$PM2N" >/dev/null 2>&1 || true
pm2 start "$BIN" --name "$PM2N" --cwd "$ENG" --user "$U" >/dev/null 2>&1 || rollback "pm2 start --user fail"
pm2 save >/dev/null 2>&1 || true
for i in $(seq 1 30); do curl -fsS -m 3 "$L/ready" 2>/dev/null | grep -q '"ready":true' && break; sleep 1; done

say "4/5 PROOF"
FAIL=0
curl -fsS -m 8 "$L/ready" | grep -q '"ready":true' && ok "/ready true" || { bad "/ready"; FAIL=1; }
PID="$(pm2 pid "$PM2N" 2>/dev/null | head -1)"; RU="$(ps -o user= -p "$PID" 2>/dev/null | tr -d ' ')"
[ "$RU" = "$U" ] && ok "engine ab user '$RU' par chal raha hai (root nahi)" || { bad "engine user = '${RU:-?}' ($U chahiye)"; FAIL=1; }
H="$(curl -fsS -m 8 "$L/health" 2>/dev/null)"
echo "$H" | grep -q '"wal_writable": *true' && ok "WAL likhne layak" || { bad "wal_writable nahi"; FAIL=1; }
echo "$H" | grep -q '"secrets_complete": *true' && ok "dono Polar secrets (.env se)" || { bad "secrets_complete nahi"; FAIL=1; }
C="$(curl -s -m 8 -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{}' "$L/api/v1/portal")"
[ "$C" = "401" ] && ok "bina muhar portal => 401 (muhar-chaabi polar ne padh li)" || { bad "portal => $C (401 chahiye; key nahi padhi?)"; FAIL=1; }
R="$(pcp-call POST /api/v1/portal '{"user_id":"00000000-0000-4000-8000-000000000000"}' 2>&1 | tr '\n' ' ')"
echo "$R" | grep -q "no_billing_account" && ok "signed call Polar tak => no_billing_account" || { bad "signed call jawab: ${R:0:120}"; FAIL=1; }
M0="$(curl -fsS -m 6 "$L/metrics" 2>/dev/null | grep -o '"received": *[0-9]*' | grep -o '[0-9]*$' || echo 0)"
git -C /opt/anexomail-web fetch -q origin main </dev/null 2>/dev/null || true
git -C /opt/anexomail-web show origin/main:server/rust/polar-payment/test-event.sh 2>/dev/null | bash >/dev/null 2>&1
M1="$(curl -fsS -m 6 "$L/metrics" 2>/dev/null | grep -o '"received": *[0-9]*' | grep -o '[0-9]*$' || echo 0)"
[ "${M1:-0}" -gt "${M0:-0}" ] && ok "webhook test: received $M0 -> $M1 (WAL-first zinda)" || { bad "webhook test received nahi barha ($M0 -> $M1)"; FAIL=1; }
touch "$ENG/PAUSE_PORTAL"; sleep 1; P="$(pcp-call POST /api/v1/portal '{"user_id":"00000000-0000-4000-8000-000000000000"}' 2>&1 | tr '\n' ' ')"; rm -f "$ENG/PAUSE_PORTAL"
echo "$P" | grep -q "portal_paused" && ok "kill switch (root ki file polar ko dikhi) => portal_paused" || { bad "kill switch kaam nahi: ${P:0:100}"; FAIL=1; }
[ "$FAIL" = "0" ] || rollback "proof fail"

say "5/5 permissions ka natija"
stat -c '    %U:%G %a  %n' "$ENG/.env" "$KEYF" "$ENG/wal"
echo; echo "==> TAYYAR. Backup: $BK"
echo "    Rollback haath se: pm2 delete $PM2N; chown -R root:root $ENG/wal; pm2 start $BIN --name $PM2N --cwd $ENG; pm2 save"
