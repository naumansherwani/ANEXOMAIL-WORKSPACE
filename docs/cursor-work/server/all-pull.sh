#!/usr/bin/env bash
# ANEXOMAIL — EK MEGA COMMAND (founder 28 Oct 2026): sab technologies, Rule 46 ki tarteeb mein, har step ke baad rukti hai agar fail ho.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/all-pull.sh)
# Tarteeb: SQL (+CHECK, sql-run.sh khud) -> Rust founder + SPA -> Caddy founder host -> Web (pull.sh, pm2 restart + save andar).
# Har step wohi purani aazmayi script hai (git pull kabhi nahi, sirf `git show origin/main:<script>`). Polar :3400 ko haath nahi.
set -u -o pipefail
W="${W:-/opt/anexomail-web}"
S="docs/cursor-work/server"
git -C "$W" fetch -q origin main || { echo "FAIL fetch"; exit 1; }
run() { # run <label> <tail-lines> <script-path> [args...]
  local label="$1" n="$2" path="$3"; shift 3
  echo; echo "=== $label ==="
  local out rc
  out="$(bash <(git -C "$W" show "origin/main:$path") "$@" 2>&1)"; rc=$?
  printf '%s\n' "$out" | tail -"$n"
  if [ $rc -ne 0 ]; then echo "!!! $label FAIL (exit $rc) - aage nahi badha. Upar ka output paste karein."; exit $rc; fi
  RESULTS="${RESULTS:-}$label OK; "
}
run "1/4 SQL"            25 "$S/sql-run.sh"
run "2/4 RUST+SPA founder" 12 "$S/founder-install.sh"
run "3/4 CADDY founder host" 15 "server/caddy/founder-host.sh"
run "4/4 WEB pull"       15 "$S/pull.sh"
echo; echo "=== SAB OK: ${RESULTS}==="
