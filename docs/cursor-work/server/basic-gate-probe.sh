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
gate "RUST calendar.files.list (Pro)" calendar.files.list "{\"event_id\":\"$NID\"}"
gate "RUST calendar.meta.set goal (Pro)" calendar.meta.set "{\"id\":\"$NID\",\"goal\":\"x\"}"
gate "RUST chat.bridge.rescue (Pro)" chat.bridge.rescue "{\"mail_thread_id\":\"$NID\",\"title\":\"probe\",\"owner_user_id\":\"$NID\",\"due_at\":\"$FUT\"}"
gate "RUST mail.followup.list (Pro)" mail.followup.list '{}'
gate "RUST mail.snippets.list (Pro)" mail.snippets.list '{}'
gate "RUST mail.handoff.list (Pro)" mail.handoff.list '{}'
gate "RUST analytics.threadEconomics (Pro)" analytics.threadEconomics '{}'
# --- CRM P1+P2 + workx (26 Oct): har config proc Basic ko 403. Pro mode mein inputs khali/nakli — koi data nahi banta (list sirf default pipeline ensure karta hai).
for P in crm.pipelines.list crm.pipelines.save crm.pipelines.delete crm.fields.list crm.fields.save crm.fields.delete crm.forms.list crm.forms.save crm.forms.delete crm.merge crm.custom.set crm.board crm.deals.move crm.deals.setPipeline work.tasks work.promises crm.overview crm.live; do
  gate "RUST $P (Pro)" "$P" '{}'
done
gate "RUST crm.dups.list (Pro)" crm.dups.list '{"kind":"lead"}'
chk "RUST crm.form.get public, nakli slug (open)" "$(rpc crm.form.get '{"slug":"0000000000000000"}')" 404
chk "RUST calendar.findtime (open to all plans)" "$(rpc calendar.findtime '{}')" 400
chk "RUST analytics.responseDebt (open to all)" "$(rpc analytics.responseDebt '{}')" 200
chk "BUN  /calendar/availability (Pro fallback)" "$(bun GET '/api/calendar/availability?date=2026-10-27')" $GATED
chk "BUN  /calendar/focus (Pro fallback)" "$(bun GET /api/calendar/focus)" $GATED
rm -f /tmp/.gp.$$; unset TOK
echo "---"; [ $FAILS -eq 0 ] && echo "ALL PASS ($MODE)" || echo "$FAILS FAIL — output Claude ko bhejein"
exit $FAILS
