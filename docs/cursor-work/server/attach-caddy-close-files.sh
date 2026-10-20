#!/usr/bin/env bash
# ANEXOMAIL — Caddy ka `handle_path /files/*` (attachments folder seedha web par) band karna. SIRF founder ki "haan" ke baad chalayen.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/attach-caddy-close-files.sh)
# Kyun: yeh block /mnt/anexomail-box/attachments ko bina login `file_server` se parosta hai. App mein kahin `/files/` istemal nahi hota
#       (download ab login-wali `/file/attach/get` se). Backup + `caddy validate` pehle; fail => purani Caddyfile wapas, reload nahi.
set -uo pipefail
CF="${CADDYFILE:-/etc/caddy/Caddyfile}"
[ -f "$CF" ] || { echo "FAIL: $CF nahi mili"; exit 2; }
STAMP="$(date +%Y%m%d-%H%M%S)"; BAK="$CF.bak.attach-$STAMP"
T="$(mktemp)"; trap 'rm -f "$T"' EXIT
python3 -I - "$CF" "$T" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
n = 0
while True:
    m = re.search(r'^[ \t]*(?:#[^\n]*\n[ \t]*)*handle_path[ \t]+/files/\*[ \t]*\{', s, re.M)
    if not m:
        break
    start = m.start()
    i = m.end(); depth = 1
    while i < len(s) and depth:
        depth += {'{': 1, '}': -1}.get(s[i], 0); i += 1
    if depth:
        print("STOP: /files/* block ka end nahi mila"); sys.exit(4)
    block = s[m.start():i]
    if "anexomail-box/attachments" not in block:
        print("STOP: /files/* block attachments ka nahi lagta — haath se dekhna padega"); sys.exit(4)
    s = s[:start] + "# (G38) /files/* band: attachments ab sirf login-wali /file/attach/get se milte hain\n" + s[i:].lstrip("\n")
    n += 1
open(sys.argv[2], "w").write(s)
print("blocks hataye: %d" % n)
PY
rc=$?; [ $rc -eq 0 ] || exit 3
if cmp -s "$CF" "$T"; then echo "Pehle se band hai (Caddyfile mein /files/* attachments block nahi)."; exit 0; fi
cp -p "$CF" "$BAK"; cp "$T" "$CF"
if caddy validate --config "$CF" >/tmp/caddy-validate.$$ 2>&1; then
  systemctl reload caddy && echo "DONE: /files/* band, Caddy reload ho gaya. Backup: $BAK"
else
  tail -5 /tmp/caddy-validate.$$; cp -p "$BAK" "$CF"; echo "!! validate FAIL — purani Caddyfile wapas, reload nahi hua"; exit 1
fi
