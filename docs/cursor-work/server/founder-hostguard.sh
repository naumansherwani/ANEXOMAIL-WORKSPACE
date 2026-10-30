#!/usr/bin/env bash
# F1a-2 — awam hosts par founder login/signup band (FOUNDER_HOST_GUARD). Teen mode, lock-out se bachao ke saath:
#   probe   = sirf log (kuch refuse nahi): founder host par ek baar login karo, phir `status` mein host header ka saboot
#   enforce = founder account awam host par refuse (403 founder_portal_only); founder host par chalta rahe
#   off     = purani halat (default)
#   diag    = SIRF PADHTA HAI: pm2/log/.env/code ka haal (login ka raasta kaun sa hai)
#   status  = abhi ka mode + aakhri [founder.host] log lines
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-hostguard.sh) probe
# Pehle pull.sh (awam web code), phir yeh. Env: /opt/anexomail-web/.env (backup banata hai). Sirf web restart; Polar/Rust/founder service nahi.
set -euo pipefail
W="${W:-/opt/anexomail-web}"; APP="${APP:-anexomail-web}"; ENVF="${ENVF:-$W/.env}"; M="${1:-status}"
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root chahiye"; exit 2; }
show() {
  echo "mode (.env file): $(grep -E '^FOUNDER_HOST_GUARD=' "$ENVF" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
  PID="$(pm2 pid "$APP" 2>/dev/null | head -1 || true)"
  if [ -n "${PID:-}" ] && [ "$PID" != 0 ] && [ -r "/proc/$PID/environ" ]; then echo "mode (running process): $(tr '\0' '\n' </proc/"$PID"/environ | grep -E '^FOUNDER_HOST_GUARD=' | cut -d= -f2- || true)"; else echo "mode (running process): pid nahi mila"; fi
  echo "--- aakhri [founder.host] log (pm2 ki poori log files, sirf aakhri 400 line nahi):"
  grep -hF "[founder.host]" "${PM2_HOME:-$HOME/.pm2}/logs/$APP"-*.log 2>/dev/null | tail -5 || true; }
diag() {  # READ-ONLY: kuch badalta nahi, koi secret value nahi chhapta (sirf naam/haan-nahi/ginti)
  L="${PM2_HOME:-$HOME/.pm2}/logs"
  echo "== pm2 app '$APP': pid=$(pm2 pid "$APP" 2>/dev/null | head -1) cwd=$(readlink "/proc/$(pm2 pid "$APP" 2>/dev/null | head -1)/cwd" 2>/dev/null || echo ?)"
  echo "== .env: FOUNDER_HOST_GUARD line: $(grep -cE '^FOUNDER_HOST_GUARD=' "$ENVF" 2>/dev/null || echo 0) | FOUNDER_EMAIL set: $(grep -qE '^FOUNDER_EMAIL=.+' "$ENVF" 2>/dev/null && echo yes || echo no-default-email)"
  echo "== log files:"; ls -l --time-style=+%F_%T "$L"/"$APP"-*.log 2>/dev/null | awk '{print $5" bytes "$6" "$7}' || echo "koi nahi"
  echo "== log lines: [founder.host]=$(cat "$L"/"$APP"-*.log 2>/dev/null | grep -cF '[founder.host]' || true)  /api/auth/login=$(cat "$L"/"$APP"-*.log 2>/dev/null | grep -c 'auth/login' || true)"
  echo "== code mein guard: $(grep -rlF 'founderHostGate' "$W/server" 2>/dev/null | head -3 | tr '\n' ' ')"
  echo "== founder login ka raasta (code mein 'founderlogin'/'exchange' ka zikr):"; grep -rlE "founderlogin|founder/v1/exchange" "$W/server" "$W/src" 2>/dev/null | head -6
  echo "== founder host par aaj ki auth requests (Caddy log, agar hai):"; grep -hE '"(host|Host)":\["?founderworkspace' /var/log/caddy/*.log 2>/dev/null | grep -E 'auth|login|exchange' | tail -3 | cut -c1-200 || true; }
case "$M" in
  status) show; exit 0;;
  diag) diag; exit 0;;
  off|probe|enforce) ;;
  *) echo "use: probe | enforce | off | status | diag"; exit 2;;
esac
[ -f "$ENVF" ] || { echo "FAIL: $ENVF nahi"; exit 2; }
if [ "$M" = enforce ]; then
  grep -hF "[founder.host]" "${PM2_HOME:-$HOME/.pm2}/logs/$APP"-*.log 2>/dev/null | grep -q "founder_host=true" \
    || { echo "FAIL: pehle probe chalao aur founder host par login karo — log mein founder_host=true ka saboot nahi mila (lock-out se bachao)"; exit 3; }
fi
cp -p "$ENVF" "$ENVF.bak.hostguard.$(date +%s)"
sed -i '/^FOUNDER_HOST_GUARD=/d' "$ENVF"; printf 'FOUNDER_HOST_GUARD=%s\n' "$M" >>"$ENVF"
pm2 restart "$APP" --update-env >/dev/null 2>&1 </dev/null; pm2 save >/dev/null 2>&1 </dev/null; sleep 3
show
[ "$M" = probe ] && echo "Ab https://founderworkspace.anexomail.com/founderlogin par ek baar login karein, phir: ...founder-hostguard.sh) status  (founder_host=true dikhna chahiye)"
[ "$M" = enforce ] && echo "Test: anexomail.com/auth par founder email se login = 'founder portal' wala 403; founderworkspace par login = chalta rahe."
exit 0
