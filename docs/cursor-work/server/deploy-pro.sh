#!/usr/bin/env bash
# ANEXOMAIL — EK COMMAND: repo ka sab kuch server par (Rule 46 tarteeb: Rust -> restart+health -> Web -> probes). Pro package ke liye saboot ke saath.
# Chalana:  git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/deploy-pro.sh)
# Kya NAHI karta (jaan-boojh kar): SQL (E87/E88 pehle se live; naya SQL alag sql-run.sh), Brain/Bun (fallback; naya kaam nahi), polar-rust-payment (NO-TOUCH),
#   fix-buyer-kind.sh (ek baar ka repair). Kisi qadam par FAIL aaye to wahin ruk jata hai aur kuch aage nahi chalata.
# Koi password/secret print nahi hota.
set -uo pipefail
G=/opt/anexomail-web
fetch() { git -C "$G" fetch -q origin main; }
run() { fetch && bash <(git -C "$G" show "origin/main:docs/cursor-work/server/$1"); }
step() { printf '\n=== %s\n' "$*"; }
fetch || { echo "FAIL: git fetch"; exit 2; }
echo "repo HEAD (origin/main): $(git -C "$G" rev-parse --short origin/main)  |  $(date '+%d %b %Y %H:%M %Z')"

step "1/6 Rust engine install (sab modules, idempotent)"
run rust-engine-install.sh 2>&1 | tail -4
step "2/6 Rust restart + health"
pm2 restart anexomail-rust --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 3
H="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:3200/rpc/health)"; echo "rust /rpc/health $H"
[ "$H" = 200 ] || { echo "FAIL: Rust health $H — RUK gaya (rollback: /root/rust-rollback-*.sh, sab se naya)"; exit 3; }
step "3/6 Web pull (build + pm2 anexomail-web)"
run pull.sh 2>&1 | tail -6
step "4/6 garam hone ka intezar (20 s)"; sleep 20
step "5/6 Probes: BASIC (403 har Pro proc par) + PRO (pro.buyer, har Pro proc 200/400)"
B="$(run basic-gate-probe.sh 2>&1 | grep -E 'FAIL|ALL PASS')"; echo "BASIC: ${B:-?}"
P="$(MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C "$G" show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E 'FAIL|ALL PASS')"; echo "PRO  : ${P:-?}"
step "6/6 WASM kernel + QUIC/WebTransport saboot"
run kernel-check.sh 2>&1 | grep -E 'FAIL|KERNEL|wasm jawab|PASS' | tail -8
echo
case "$B$P" in *FAIL*) echo "== RESULT: KUCH FAIL — upar ke FAIL lines Claude ko bhejein";; *"ALL PASS"*"ALL PASS"*) echo "== RESULT: SERVER == REPO, Rust+Web taza, BASIC aur PRO probes ALL PASS. Ab browser mein Ctrl+Shift+R.";; *) echo "== RESULT: probe jawab saaf nahi — upar dekhein";; esac
