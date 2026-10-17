#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY: does saving a calendar event with attendees EMAIL those attendees? (18 Oct 2026)
# Kuch badalta nahi, koi mail nahi bhejta, koi secret/email-address print nahi karta (sirf ginti + file/line naam).
# Sawal: .ics import (aur normal "New meeting") mein "attendees" bharne par kya server unhein invitation mail bhejta hai?
# Repo ka saboot: Brain `calendar.create` sirf `calendar_attendees` mein rows likhta hai, mail nahi. Live ka saboot is script se.
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/calendar-invite-check.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }
MAILWORDS='sendmail|send_mail|sendMail|nodemailer|smtp|lettre|mail_outbox|mail_scheduled|mail_queue|invitation|invite|text/calendar|METHOD:REQUEST'

# live Brain ka SRC (jahan routes/ + index.ts hain) — KABHI backups/dist/node_modules nahi. Pehle /opt/anexomail/src (founder ka system map), phir pm2 se, phir filtered find.
find_brain_src() {
  local c cands=() base="${BRAIN:-/opt/anexomail}"
  [ -n "${BRAIN_SRC:-}" ] && cands+=("$BRAIN_SRC")
  cands+=("$base/src" "$base/server" "$base")
  while IFS= read -r c; do [ -n "$c" ] && cands+=("$c"); done < <(pm2 jlist 2>/dev/null | python3 -c 'import json,sys,os
try:
    for p in json.load(sys.stdin):
        if p.get("name")=="anexomail-leo":
            e=p["pm2_env"]; x=e.get("pm_exec_path") or ""; w=e.get("pm_cwd") or ""
            for d in (os.path.dirname(x), w, w+"/src", w+"/server"): print(d)
except Exception: pass' 2>/dev/null)
  while IFS= read -r c; do cands+=("$(dirname "$c")"); done < <(find "$base" -maxdepth 4 -type d -name routes -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*backup*' -not -path '*/dist/*' -not -path '*/build/*' 2>/dev/null)
  for c in "${cands[@]}"; do
    case "$c" in *backup*|*/node_modules/*|*/.git/*|*/dist|*/dist/*|*/build|*/build/*) continue ;; esac
    if [ -d "$c/routes" ] && [ -f "$c/index.ts" ]; then echo "$c"; return 0; fi
  done
  return 1
}
hr "1. live Brain: routes/calendar.ts — attendees likhne ke paas mail wala koi kaam?"
CAL="$(find_brain_src)/routes/calendar.ts"; [ -f "$CAL" ] || CAL=""
if [ -n "$CAL" ]; then
  echo "$CAL  sha256[:16]=$(sha256sum "$CAL" | cut -c1-16)  lines=$(wc -l < "$CAL")"
  echo "repo origin/main sha256[:16]=$(git -C /opt/anexomail-web show origin/main:server/routes/calendar.ts 2>/dev/null | sha256sum | cut -c1-16)"
  echo "-- mail-jaise shabd (0 = kuch nahi):"
  grep -n -i -E "$MAILWORDS" "$CAL" | cut -c1-140 | head -20
  echo "count: $(grep -c -i -E "$MAILWORDS" "$CAL")"
  echo "-- calendar_attendees insert:"
  grep -n 'calendar_attendees' "$CAL" | cut -c1-140 | head -8
else
  echo "(live Brain mein routes/calendar.ts nahi mili)"
fi

hr "2. live Rust: kya calendar.* proc hai, aur kya woh mail/invite ke paas kuch karta hai?"
RS="$(find /opt/anexomail-rust -maxdepth 3 -name '*.rs' -not -path '*/target/*' 2>/dev/null)"
if [ -n "$RS" ]; then
  echo "calendar naam wali jagah (file:line):"
  grep -n -i -E 'calendar\.(create|events|event|update|delete)|"calendar' $RS 2>/dev/null | cut -c1-150 | head -15
  echo "count calendar proc lines: $(grep -c -i -E 'calendar\.' $RS 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')   (0 = Rust mein calendar nahi => woh Bun fallback par chalta hai)"
  echo "-- mail-jaise shabd calendar ke paas:"
  grep -n -i -E "invitation|invite|METHOD:REQUEST|text/calendar" $RS 2>/dev/null | cut -c1-150 | head -10
else
  echo "(/opt/anexomail-rust mein .rs files nahi mili)"
fi

hr "3. database: attendees par koi trigger/function jo mail banaye?"
if [ -r /etc/anexomail/sync.env ]; then
  ( . /etc/anexomail/sync.env 2>/dev/null
    echo "-- triggers calendar tables par (khali = koi nahi):"
    psql "$WORKING_URL" -Atc "select c.relname||'  '||t.tgname from pg_trigger t join pg_class c on c.oid=t.tgrelid where not t.tgisinternal and c.relname in ('calendar_events','calendar_attendees') order by 1" 2>&1 | head -10
    echo "-- functions jo 'attendee' aur mail-table dono ka zikr karte hain (khali = koi nahi):"
    psql "$WORKING_URL" -Atc "select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and p.prosrc ilike '%attendee%' and (p.prosrc ilike '%mail_outbox%' or p.prosrc ilike '%mail_scheduled%' or p.prosrc ilike '%mail_messages%') limit 10" 2>&1 | head -10
    echo "-- pichle 30 din mein bheji 'invitation' wali mail ki ginti (0 = kabhi nahi gayi):"
    psql "$WORKING_URL" -Atc "select count(*) from public.mail_messages where direction='out' and subject ilike '%invitation%' and sent_at > now() - interval '30 days'" 2>&1 | head -2
    echo "-- calendar_attendees rows (sirf ginti): $(psql "$WORKING_URL" -Atc 'select count(*) from public.calendar_attendees' 2>&1 | head -1)"
  )
else
  echo "(/etc/anexomail/sync.env nahi mila)"
fi

hr "natija kaise parhein"
echo "Sab jagah 'count: 0' / khali / 0 => attendees sirf event par likhe jate hain, kisi ko mail nahi jati => import ki copy 'no invitation emails are sent' ab sach hai."
echo "Kahin mail-jaisa shabd mile => us line ka output Claude ko paste karein; copy tab tak 'Off by default' hi rahegi."
