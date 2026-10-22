#!/usr/bin/env bash
# ANEXOMAIL — #3 iMIP reply: ASLI pipe saboot (22 Oct 2026). Gmail ke button ki zaroorat nahi.
#   bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/imip-reply-proof.sh)
# Kya karta hai: aap ki aakhri "iMIP test%" meeting par 4 REPLY mails asli anexomail-deliver-rs se guzaarta hai:
#   A) auth header NAHI -> lagni nahi chahiye    B) auth pass par From koi aur -> lagni nahi chahiye
#   C) auth pass + From == attendee -> lagni chahiye (accepted, rsvp_via=calendar_app)    D) wahi Message-ID dobara -> duplicate
# Koi email address print nahi hota. Mail organiser (pro.buyer) ke inbox mein 4 test mail ban kar aayegi (asli pipe).
set +e
BIN="${BIN:-/usr/local/bin/anexomail-deliver-rs}"; MAILENV="${MAILENV:-/etc/anexomail/mail.env}"
q() { ( . /etc/anexomail/sync.env 2>/dev/null; psql "$WORKING_URL" -tAX -c "$1" 2>&1 ) | tr -d '\r' | head -3; }
[ -x "$BIN" ] || { echo "FAIL: $BIN nahi"; exit 2; }
EV="$(q "select id from public.calendar_events where title like 'iMIP test%' and cancelled_at is null order by created_at desc limit 1")"
[ -n "$EV" ] || { echo "FAIL: 'iMIP test' meeting nahi mili"; exit 2; }
ORG="$(q "select lower(organiser) from public.calendar_events where id='$EV'")"
GUEST="$(q "select lower(address) from public.calendar_attendees where event_id='$EV' and lower(address)<>'$ORG' order by address limit 1")"
SEQ="$(q "select coalesce(sequence,0) from public.calendar_events where id='$EV'")"
[ -n "$GUEST" ] || { echo "FAIL: meeting mein guest nahi"; exit 2; }
ST="$(date +%s)"
state() { q "select response||' via='||coalesce(rsvp_via,'-') from public.calendar_attendees where event_id='$EV' and lower(address)='$GUEST'"; }
mk() { # $1=from  $2=auth header line (khali ho sakti)  $3=message-id  $4=partstat
  printf '%bFrom: <%s>\r\nTo: <%s>\r\nSubject: Accepted: iMIP test\r\nMessage-ID: <%s>\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary="B"\r\n\r\n--B\r\nContent-Type: text/plain\r\n\r\nreply\r\n--B\r\nContent-Type: text/calendar; method=REPLY; charset=UTF-8\r\n\r\nBEGIN:VCALENDAR\r\nVERSION:2.0\r\nMETHOD:REPLY\r\nBEGIN:VEVENT\r\nUID:%s@anexomail.com\r\nSEQUENCE:%s\r\nATTENDEE;PARTSTAT=%s:mailto:%s\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n--B--\r\n' "$2" "$1" "$ORG" "$3" "$EV" "$SEQ" "$4" "$GUEST"
}
run() { runuser -u vmail -- env ANEXOMAIL_MAIL_ENV="$MAILENV" "$BIN" "$1" "$ORG" 2>&1 | grep -E "imip:|OK " | head -2 | cut -c1-160; }
echo "event=$EV  (guest/organiser chhupe hain)  pehle: $(state)"
AUTH='Authentication-Results: mail.anexomail.com; spf=pass; dkim=pass\r\n'
echo "== A) auth NAHI"; mk "$GUEST" "" "imip-a-$ST@test" ACCEPTED | run "$GUEST"; echo "   ab: $(state)  (badla nahi hona chahiye)"
echo "== B) auth pass, From koi aur"; mk "mallory@evil.example" "$AUTH" "imip-b-$ST@test" ACCEPTED | run "mallory@evil.example"; echo "   ab: $(state)  (badla nahi hona chahiye)"
echo "== C) auth pass + From == attendee"; mk "$GUEST" "$AUTH" "imip-c-$ST@test" ACCEPTED | run "$GUEST"; S="$(state)"; echo "   ab: $S  (accepted via=calendar_app hona chahiye)"
echo "== D) wahi Message-ID dobara"; mk "$GUEST" "$AUTH" "imip-c-$ST@test" ACCEPTED | run "$GUEST"
echo "   log: $(q "select outcome||'='||count(*) from public.calendar_imip_log where message_id like 'imip-%-$ST@test' group by outcome order by 1" | tr '\n' ' ')"
case "$S" in "accepted via=calendar_app") echo "OK — iMIP reply asli pipe se lagi, jhoote reject hue.";; *) echo "KUCH GALAT — upar ka output claude ko paste karo."; exit 1;; esac
