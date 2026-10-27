#!/usr/bin/env bash
# ANEXOMAIL — BASIC-USER GATE PROBE: koi typing nahi (password nahi poochta; login-probe.sh jaisa server-key se token).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh)
# Kya: Basic account (default basic.test@anexomail.com) se Pro-wali cheezein Rust :3200 AUR Bun :3100 par try karta hai.
#   MODE=basic (default): Pro-gate wali calls 403 honi chahiye, baqi (drafts, threads) 200.
#   MODE=pro EMAIL=pro.buyer@anexomail.com: sab 200 (positive control).
# Koi data nahi badalta: basic mode mein gate PEHLE reject karta hai (assign sirf basic mode mein chalta hai); pro mode mein sirf wahi test thread par wapas "bring back" aur
# template/schedule turant delete/cancel hoti hai. Token/key kabhi screen par nahi aata.
set -uo pipefail
EMAIL="${EMAIL:-basic.test@anexomail.com}"; MODE="${MODE:-basic}"
envv(){ for f in /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
URL="${SUPABASE4_URL:-$(envv SUPABASE4_URL)}"; [ -n "$URL" ] || URL="$(envv SUPABASE_URL)"
KEY="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; [ -n "$KEY" ] || KEY="$(envv SUPABASE_SERVICE_ROLE_KEY)"
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "FAIL: /opt/anexomail/.env mein SUPABASE4_URL / SERVICE_ROLE_KEY nahi mili"; exit 2; }
URL="${URL%/}"
jget(){ python3 -c 'import json,sys
try: print(json.load(sys.stdin).get(sys.argv[1],""))
except Exception: print("")' "$1"; }
LINK="$(curl -s -m 20 -H "apikey: $KEY" -H "authorization: Bearer $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"email\":\"$EMAIL\"}" "$URL/auth/v1/admin/generate_link")"
HASH="$(printf '%s' "$LINK" | jget hashed_token)"
[ -n "$HASH" ] || { echo "FAIL: $EMAIL ka login-token nahi bana (account hai?)"; exit 1; }
SESS="$(curl -s -m 20 -H "apikey: $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"token_hash\":\"$HASH\"}" "$URL/auth/v1/verify")"
TOK="$(printf '%s' "$SESS" | jget access_token)"; unset SESS LINK HASH KEY SUPABASE4_SERVICE_ROLE_KEY SUPABASE_SERVICE_ROLE_KEY
[ -n "$TOK" ] || { echo "FAIL: session token nahi mila"; exit 1; }
RUST="${RUST:-http://127.0.0.1:3200}"; BRAIN="${BRAIN:-http://127.0.0.1:3100}"
FUT="$(python3 -c 'import datetime as d;print((d.datetime.utcnow()+d.timedelta(days=2)).strftime("%Y-%m-%dT%H:%M:%S.000Z"))')"
rpc(){ curl -s -o /tmp/.gp.$$ -m 20 -w "%{http_code}" -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d "{\"input\":$2}" "$RUST/rpc/$1"; }
bun(){ curl -s -o /dev/null -m 20 -w "%{http_code}" -X "$1" -H "authorization: Bearer $TOK" -H 'content-type: application/json' ${3:+-d "$3"} "$BRAIN$2"; }
rpc mail.threads '{"folder":"inbox"}' >/dev/null
TH="$(python3 -c 'import json
try:
  d=json.load(open("/tmp/.gp.'$$'"))["result"]["data"]["threads"]; print(d[0]["id"] if d else "")
except Exception: print("")')"
FAILS=0
chk(){ # name got want
  if [ "$2" = "$3" ]; then printf "PASS  %-44s %s\n" "$1" "$2"; else printf "FAIL  %-44s got %s want %s\n" "$1" "$2" "$3"; FAILS=$((FAILS+1)); fi
}
GATED=403; [ "$MODE" = pro ] && GATED=200
echo "== $EMAIL  mode=$MODE  thread=${TH:-none}"
chk "RUST drafts.save (open to all plans)" "$(rpc mail.drafts.save '{"subject":"gate probe","body":"x","to":"a@b.com"}')" 200
chk "RUST threads (open to all plans)" "$(rpc mail.threads '{"folder":"inbox"}')" 200
if [ -n "$TH" ]; then
  chk "RUST snooze (Pro)" "$(rpc mail.snooze "{\"thread_id\":\"$TH\",\"until\":\"$FUT\"}")" $GATED
  [ "$MODE" = basic ] && chk "RUST assign (Pro, shared inbox)" "$(rpc mail.assign "{\"thread_id\":\"$TH\",\"assignee\":\"\"}")" 403
  [ "$MODE" = pro ] && rpc mail.snooze "{\"thread_id\":\"$TH\",\"until\":null}" >/dev/null
  chk "BUN  snooze (Pro fallback)" "$(bun POST /api/mail/thread/$TH/snooze "{\"until\":\"$FUT\"}")" $GATED
  [ "$MODE" = pro ] && bun POST /api/mail/thread/$TH/snooze '{"until":null}' >/dev/null
else echo "SKIP  snooze/assign: is account ke inbox mein koi thread nahi"; fi
chk "RUST templates.save (Pro)" "$(rpc mail.templates.save '{"name":"gate probe","subject":"s","body":"b"}')" $GATED
[ "$MODE" = pro ] && { ID="$(python3 -c 'import json;print(json.load(open("/tmp/.gp.'$$'"))["result"]["data"]["id"])' 2>/dev/null)"; [ -n "$ID" ] && rpc mail.templates.delete "{\"id\":\"$ID\"}" >/dev/null; }
chk "BUN  templates POST (Pro fallback)" "$(bun POST /api/mail/templates '{"name":"gate probe","subject":"s","body":"b"}')" $GATED
chk "RUST schedule send_at +2d (Pro)" "$(rpc mail.schedule "{\"to\":\"a@b.com\",\"subject\":\"gate probe\",\"body\":\"x\",\"send_at\":\"$FUT\"}")" $GATED
[ "$MODE" = pro ] && { ID="$(python3 -c 'import json;print(json.load(open("/tmp/.gp.'$$'"))["result"]["data"]["id"])' 2>/dev/null)"; [ -n "$ID" ] && rpc mail.schedule.cancel "{\"id\":\"$ID\"}" >/dev/null; }
chk "RUST mail.thread.insights (Pro)" "$(rpc mail.thread.insights "{\"id\":\"${TH:-00000000-0000-0000-0000-000000000000}\"}")" $GATED
# --- Pro green batch 1 (26 Oct): gate PEHLE reject karta hai, isliye basic mein koi data nahi badalta. Pro mode: 403/401 NAHI aana chahiye (200/400/404 theek: id nakli hai).
gate(){ st="$(rpc "$2" "$3")"
  if [ "$MODE" = basic ]; then chk "$1" "$st" 403
  elif [ "$st" != 403 ] && [ "$st" != 401 ]; then printf "PASS  %-44s %s\n" "$1" "$st"
  else printf "FAIL  %-44s got %s want not 403/401\n" "$1" "$st"; FAILS=$((FAILS+1)); fi; }
NID="00000000-0000-4000-8000-000000000001"
gate "RUST calendar.availability (Pro)" calendar.availability '{"date":"2026-10-27"}'
gate "RUST calendar.focus (Pro)" calendar.focus '{}'
[ "$MODE" = pro ] && chk "RUST calendar.availability {} (Pro: 502 nahi, 200)" "$(rpc calendar.availability '{}')" 200
[ "$MODE" = pro ] && chk "RUST calendar.focus {} (Pro: 502 nahi, 200)" "$(rpc calendar.focus '{}')" 200
gate "RUST calendar.rates (Pro)" calendar.rates '{}'
gate "RUST calendar.rates.set (Pro)" calendar.rates.set '{}'
[ "$MODE" = pro ] && chk "RUST calendar.rates {} (Pro 200)" "$(rpc calendar.rates '{}')" 200
[ "$MODE" = pro ] && chk "RUST calendar.rates.set bad value (400)" "$(rpc calendar.rates.set '{"self":-5}')" 400
[ "$MODE" = pro ] && { chk "RUST security.devices 200 (limit)" "$(rpc security.devices '{}')" 200; grep -q "\"limit\":4" /tmp/.gp.$$ && echo "  PASS device limit 4 (Pro)" || { echo "  FAIL device limit 4 (Pro)"; FAILS=$((FAILS+1)); }; }
gate "RUST calendar.files.list (Pro)" calendar.files.list "{\"event_id\":\"$NID\"}"
gate "RUST calendar.meta.set goal (Pro)" calendar.meta.set "{\"id\":\"$NID\",\"goal\":\"x\"}"
gate "RUST chat.bridge.rescue (Pro)" chat.bridge.rescue "{\"mail_thread_id\":\"$NID\",\"title\":\"probe\",\"owner_user_id\":\"$NID\",\"due_at\":\"$FUT\"}"
gate "RUST mail.followup.list (Pro)" mail.followup.list '{}'
gate "RUST mail.snippets.list (Pro)" mail.snippets.list '{}'
gate "RUST mail.handoff.list (Pro)" mail.handoff.list '{}'
gate "RUST mail.followup.delete (Pro, nakli id)" mail.followup.delete "{\"id\":\"$NID\"}"
gate "RUST mail.handoff.delete (Pro, nakli id)" mail.handoff.delete "{\"id\":\"$NID\"}"
chk "RUST mail.device.seen (heartbeat sab plans ko khula — mailx_core test; device_id nahi => 400)" "$(rpc mail.device.seen '{}')" 400
gate "RUST analytics.threadEconomics (Pro)" analytics.threadEconomics '{}'
# --- CRM P1+P2 + workx (26 Oct): har config proc Basic ko 403. Pro mode mein inputs khali/nakli — koi data nahi banta (list sirf default pipeline ensure karta hai).
for P in crm.pipelines.list crm.pipelines.save crm.pipelines.delete crm.fields.list crm.fields.save crm.fields.delete crm.forms.list crm.forms.save crm.forms.delete crm.merge crm.custom.set crm.board crm.deals.move crm.deals.setPipeline work.tasks work.promises crm.overview crm.live crm.leads crm.deals crm.insights crm.createLead crm.createDeal crm.moveDeal crm.convertLead crm.dealWork crm.dealThread work.promise.commit work.promise.dismiss crm.memory; do
  gate "RUST $P (Pro)" "$P" '{}'
done
[ "$MODE" = pro ] && { chk "RUST crm.createLead bad email (400)" "$(rpc crm.createLead '{"email":"nope"}')" 400; chk "RUST crm.createDeal short title (400)" "$(rpc crm.createDeal '{"title":"x"}')" 400; chk "RUST crm.moveDeal bad stage (400)" "$(rpc crm.moveDeal '{"id":"x","stage":"bogus"}')" 400; chk "RUST crm.memory no email (400)" "$(rpc crm.memory '{}')" 400; chk "RUST crm.memory (Pro 200)" "$(rpc crm.memory '{"email":"nobody@example.com"}')" 200; chk "RUST crm.leads (Pro 200)" "$(rpc crm.leads '{"state":"new"}')" 200; chk "RUST crm.deals (Pro 200)" "$(rpc crm.deals '{}')" 200; chk "RUST crm.insights (Pro 200)" "$(rpc crm.insights '{}')" 200; }
# --- Pro 7 (27 Oct): work.task.create/update, work.followThrough, work.note(.save), calendar.outcome.post. Basic = 403 (server gate); Pro = khali input par 400/200 (kuch banta nahi).
for P in work.task.create work.task.update work.note.save calendar.outcome.post; do
  chk "RUST $P (Pro)" "$(rpc $P '{}')" $([ "$MODE" = pro ] && echo 400 || echo 403)
done
for P in work.followThrough work.note; do chk "RUST $P (Pro)" "$(rpc $P '{}')" $GATED; done
chk "RUST account.signup.events (all plans 200)" "$(rpc account.signup.events '{}')" 200
chk "RUST account.signup.holds (all plans 200)" "$(rpc account.signup.holds '{}')" 200
chk "RUST account.signup.state (all plans 200)" "$(rpc account.signup.state '{}')" 200
for P in contacts.list contacts.tags companies.list; do chk "RUST $P (all plans 200)" "$(rpc $P '{}')" 200; done
chk "RUST search.universal short (200 empty)" "$(rpc search.universal '{"q":"a"}')" 200
chk "RUST search.universal real (200)" "$(rpc search.universal '{"q":"ab"}')" 200
chk "RUST contacts.get missing (409 not 404)" "$(rpc contacts.get '{"id":"00000000-0000-4000-8000-000000000009"}')" 409
chk "RUST contacts.update nothing (400)" "$(rpc contacts.update '{"id":"00000000-0000-4000-8000-000000000009"}')" 400
chk "RUST companies.get missing (409)" "$(rpc companies.get '{"domain":"nope.invalid"}')" 409
chk "RUST storage.state (all plans 200)" "$(rpc storage.state '{}')" 200
chk "RUST storage.preflight bad kind (400)" "$(rpc storage.preflight '{"mailbox":"a@b.com","kind":"video"}')" 400
chk "RUST support.drafts (login, own org 200)" "$(rpc support.drafts '{}')" 200
chk "RUST support.draftDiscard bad id (400)" "$(rpc support.draftDiscard '{"id":"x;y"}')" 400
chk "RUST workspace.setActive missing org (400)" "$(rpc workspace.setActive '{}')" 400
chk "RUST workspace.setActive not mine (409)" "$(rpc workspace.setActive '{"organisation_id":"00000000-0000-4000-8000-000000000009"}')" 409
chk "RUST billing.state 200" "$(rpc billing.state '{}')" 200
chk "RUST billing.stateHealth non-founder (403)" "$(rpc billing.stateHealth '{}')" 403
chk "RUST billing.claimGuest missing token (400)" "$(rpc billing.claimGuest '{}')" 400
chk "RUST billing.claimGuest bad token (400)" "$(rpc billing.claimGuest '{"guest_token":"bad token!!"}')" 400
chk "RUST settings.list personal 200" "$(rpc settings.list '{"scope":"personal"}')" 200
chk "RUST settings.list bad scope (422)" "$(rpc settings.list '{"scope":"admin"}')" 422
chk "RUST settings.save missing key (400)" "$(rpc settings.save '{}')" 400
chk "RUST settings.save unknown key (422)" "$(rpc settings.save '{"key":"zz.no.such.key","value":"x"}')" 422
chk "RUST settings.history 200" "$(rpc settings.history '{}')" 200
chk "RUST settings.revert bad id (422)" "$(rpc settings.revert '{"version_id":"nope"}')" 422
chk "RUST settings.explain unknown (422)" "$(rpc settings.explain '{"key":"zz.no.such.key"}')" 422
chk "RUST founderSettings.overview non-founder (403)" "$(rpc founderSettings.overview '{}')" 403
chk "RUST founderIntegrations.overview non-founder (403)" "$(rpc founderIntegrations.overview '{}')" 403
chk "RUST founderSecurity.overview non-founder (403)" "$(rpc founderSecurity.overview '{}')" 403
chk "RUST integrations.providers 200" "$(rpc integrations.providers '{}')" 200
chk "RUST integrations.connections 200" "$(rpc integrations.connections '{}')" 200
chk "RUST integrations.connect missing provider (400)" "$(rpc integrations.connect '{}')" 400
chk "RUST integrations.connect bad provider (400)" "$(rpc integrations.connect '{"provider":"Bad Provider!"}')" 400
chk "RUST integrations.disconnect bad id (422)" "$(rpc integrations.disconnect '{"id":"nope"}')" 422
chk "RUST integrations.migrations 200" "$(rpc integrations.migrations '{}')" 200
chk "RUST integrations.startMigration missing (400)" "$(rpc integrations.startMigration '{}')" 400
chk "RUST integrations.controlMigration bad action (400)" "$(rpc integrations.controlMigration '{"id":"x","action":"drop"}')" 400
chk "RUST integrations.delivery 200" "$(rpc integrations.delivery '{}')" 200
chk "RUST integrations.delivery bad domain (400)" "$(rpc integrations.delivery '{"domain":"bad domain!"}')" 400
chk "RUST integrations.exports 200" "$(rpc integrations.exports '{}')" 200
chk "RUST integrations.export bad scope (400)" "$(rpc integrations.export '{"scope":"all"}')" 400
chk "RUST integrations.export bad format (400)" "$(rpc integrations.export '{"format":"pdf"}')" 400
SLA="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 -X POST -H 'content-type: application/json' -d '{"input":{}}' "$RUST/rpc/support.sla")"; [ "$SLA" = 200 ] && echo "  PASS support.sla PUBLIC (bina login 200)" || { echo "  FAIL support.sla PUBLIC -> $SLA"; FAILS=$((FAILS+1)); }
chk "RUST workspace.organisations short name (400, kuch banta nahi)" "$(rpc workspace.organisations '{"name":"x","domain":"acme.com"}')" 400
chk "RUST workspace.organisations anexomail domain (400)" "$(rpc workspace.organisations '{"name":"Probe Co","domain":"anexomail.com"}')" 400
chk "RUST workspace.organisations bad domain (400)" "$(rpc workspace.organisations '{"name":"Probe Co","domain":"nodot"}')" 400
chk "RUST workspace.personal (existing workspace 200, naya nahi banta)" "$(rpc workspace.personal '{}')" 200
grep -q '"existing":true' /tmp/.gp.$$ && echo "  PASS workspace.personal existing:true" || { echo "  FAIL workspace.personal existing:true"; FAILS=$((FAILS+1)); }
chk "RUST auth.session (all plans 200)" "$(rpc auth.session '{}')" 200
grep -q '"workspace_plan"' /tmp/.gp.$$ && grep -q '"organisations"' /tmp/.gp.$$ && grep -q '"account_kind"' /tmp/.gp.$$ && echo "  PASS auth.session shape (user.workspace_plan/account_kind/organisations)" || { echo "  FAIL auth.session shape"; FAILS=$((FAILS+1)); }
chk "RUST account.signup.security nothing (400)" "$(rpc account.signup.security '{}')" 400
gate "RUST crm.dups.list (Pro)" crm.dups.list '{"kind":"lead"}'
chk "RUST crm.form.get public, nakli slug (open)" "$(rpc crm.form.get '{"slug":"0000000000000000"}')" 404
chk "RUST calendar.findtime (open to all plans)" "$(rpc calendar.findtime '{}')" 400
chk "RUST analytics.responseDebt (open to all)" "$(rpc analytics.responseDebt '{}')" 200
chk "BUN  /calendar/availability (Pro fallback)" "$(bun GET '/api/calendar/availability?date=2026-10-27')" $GATED
chk "BUN  /calendar/focus (Pro fallback)" "$(bun GET /api/calendar/focus)" $GATED
rm -f /tmp/.gp.$$; unset TOK
echo "---"; [ $FAILS -eq 0 ] && echo "ALL PASS ($MODE)" || echo "$FAILS FAIL — output Claude ko bhejein"
exit $FAILS
