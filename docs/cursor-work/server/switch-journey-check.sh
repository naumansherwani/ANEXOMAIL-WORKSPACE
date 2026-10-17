#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY switch-journey check (17 Oct 2026): "Google Workspace / Zoho se anexomail.com par shift" kitna asli hai?
# Sawal 1: Integrations ki "migrate in one run" jobs (integration_migrations, state=queued) ko koi worker chalata hai?
# Sawal 2: contacts / calendar import ka koi live endpoint hai?  Kuch badalta nahi, koi secret print nahi.
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/switch-journey-check.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

hr "1. migration jobs ka haal (state | ginti | sab se purani job kitne ghante purani)"
if [ -r /etc/anexomail/sync.env ]; then
  . /etc/anexomail/sync.env 2>/dev/null
  psql "$WORKING_URL" -X -At -F ' | ' -c "select state, count(*), round(extract(epoch from (now()-min(created_at)))/3600) from public.integration_migrations group by state order by 1;" 2>&1 | head -8
  echo "-- connections (provider | ginti):"
  psql "$WORKING_URL" -X -At -F ' | ' -c "select provider, count(*) from public.integration_connections group by 1 order by 2 desc;" 2>&1 | head -8
else
  echo "/etc/anexomail/sync.env nahi mila"
fi

hr "2. koi worker/code jo integration_migrations ko chhoota hai? (sirf file:line; matn nahi)"
grep -rIn --include=*.rs --include=*.ts --include=*.js --include=*.sh --include=*.py "integration_migrations" /opt/anexomail-rust/src /opt/anexomail/server /opt/anexomail/src /etc/cron.d /etc/cron.daily /etc/systemd/system 2>/dev/null | grep -v node_modules | cut -c1-140 | head -12
echo "(sirf server/routes/integrations.ts ki lines => jobs bante hain, chalane wala koi nahi)"

hr "3. pm2 ke naam + migration tools"
have pm2 && pm2 jlist 2>/dev/null | python3 -c 'import json,sys
try:
    print(", ".join(p["name"] for p in json.load(sys.stdin)))
except Exception as e:
    print("pm2 parse fail", e)'
for t in imapsync doveadm offlineimap isync mbsync; do printf '%s: ' "$t"; command -v $t || echo "nahi"; done
have doveconf && { echo "-- dovecot imapc (remote IMAP se khinchne ki salahiyat):"; doveconf -n 2>/dev/null | grep -iE 'imapc|mail_plugins' | head -4; }

hr "4. contacts / calendar import endpoints (live Brain)"
for f in /opt/anexomail/server/routes/contacts.ts /opt/anexomail/server/routes/calendar.ts; do
  [ -f "$f" ] && { echo "$f:"; grep -nE '\.(post|put)\(\s*["'"'"'`][^"'"'"'`]*import' "$f" | cut -c1-120; echo "   import routes: $(grep -cE '\.(post|put)\(\s*["'"'"'`][^"'"'"'`]*import' "$f")"; }
done

echo
echo "== done (read-only) =="
