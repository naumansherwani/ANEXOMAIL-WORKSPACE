#!/usr/bin/env bash
# ANEXOMAIL — (1) toote hue cron jobs theek ("%" bina "\" ke), (2) root ki system mail customer inbox mein kyun ja rahi — sirf DEKHNA.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/cron-root-mail-fix.sh)
# Kyun: Basic test account (basic.test) ke inbox mein root@anexomail.com ke 50+ "Cron <root@mail> ... /bin/sh: Syntax error" mails (live login, 20 Oct).
#   Matlab: kuch cron jobs har minute fail ho rahi hain (kabhi chali hi nahi) AUR root ki mail ek customer mailbox mein pahunch rahi hai.
# (1) cron: backup -> sirf "%" ko "\%" -> har line `sh -n` syntax check -> kharab => backup wapas. Postfix/Dovecot/Caddy/polar ko haath NAHI.
# (2) root mail ka raasta (aliases / virtual / mail.log / DB) sirf padha jata hai — mail ka raasta founder ke "haan" ke baghair nahi badalta.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; STAMP="$(date +%s)"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" show origin/main:docs/cursor-work/server/cron_pct_fix.py >"$T/fix.py" 2>/dev/null; [ -s "$T/fix.py" ] || { echo "FAIL: cron_pct_fix.py nahi — git fetch?"; exit 2; }
echo "== 1) cron: '%' bina '\\' ke"
TOTAL=0; BAD=0
for f in /etc/crontab /etc/cron.d/*; do
  [ -f "$f" ] || continue; case "$f" in *.bak*|*~|*.dpkg-*) continue;; esac
  cp -p "$f" "$T/try"; python3 -I "$T/fix.py" "$T/try" 1 >"$T/out" 2>&1; rc=$?
  if [ "$rc" = 3 ]; then cp -p "$f" "$f.bak.$STAMP"; cat "$T/try" >"$f"; echo "   $f — THEEK (backup $f.bak.$STAMP)"; cat "$T/out"; TOTAL=$((TOTAL+1))
  elif [ "$rc" = 4 ]; then echo "   $f — syntax kharab (sirf '%' ka masla nahi), CHHERA NAHI:"; cat "$T/out"; BAD=$((BAD+1)); fi
done
if crontab -l >"$T/root.cron" 2>/dev/null; then
  cp "$T/root.cron" "$T/root.try"; python3 -I "$T/fix.py" "$T/root.try" 0 >"$T/out" 2>&1; rc=$?
  if [ "$rc" = 3 ]; then cp "$T/root.cron" "/root/crontab.bak.$STAMP"; crontab "$T/root.try" && echo "   root crontab — THEEK (backup /root/crontab.bak.$STAMP)"; cat "$T/out"; TOTAL=$((TOTAL+1))
  elif [ "$rc" = 4 ]; then echo "   root crontab — syntax kharab (sirf '%' nahi), CHHERA NAHI:"; cat "$T/out"; BAD=$((BAD+1)); fi
fi
echo "   theek hui files: $TOTAL   khud dekhni wali: $BAD"
echo "== 2) root ki mail kahan jati hai (sirf padhna)"
echo "   /etc/aliases root: $(grep -E '^root[[:space:]]*:' /etc/aliases 2>/dev/null || echo '(nahi)')"
postconf -h myhostname mydestination alias_maps virtual_alias_maps virtual_mailbox_domains 2>/dev/null | sed 's/^/   postconf: /'
for m in $(postconf -h virtual_alias_maps 2>/dev/null | tr ',' ' '); do r="$(postmap -q root@anexomail.com "$m" 2>/dev/null)"; [ -n "$r" ] && echo "   $m: root@anexomail.com -> $r"; done
grep -h 'to=<' /var/log/mail.log 2>/dev/null | grep -iE 'orig_to=<root|to=<root' | tail -3 | sed -E 's/.*(to=<[^>]*>).*(orig_to=<[^>]*>)?.*(relay=[^,]*).*(status=[a-z]+).*/   mail.log: \1 \2 \3 \4/'
if [ -r /etc/anexomail/sync.env ]; then . /etc/anexomail/sync.env
  psql "$WORKING_URL" -At -F ' | ' -c "select 'DB: root@ se aayi mails', count(*), coalesce(string_agg(distinct org_id::text, ','), '-') from public.mail_messages where from_address ilike 'root@%'" 2>&1 | sed 's/^/   /' | head -3
fi
echo "== 3) agle minute ke baad naye cron error mail aane band hone chahiye. Ye output Claude ko bhejein."
