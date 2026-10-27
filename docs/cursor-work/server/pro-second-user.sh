#!/usr/bin/env bash
# ANEXOMAIL — doosra PRO test user (pro.buyer2), pro.buyer ki HI team mein member (shared-inbox + seat tests ke liye). 27 Oct 2026.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pro-second-user.sh)
# Asli buyer jaisa: E28 ka wohi seed (auth user + identity + profile + trial + org + mailbox + Pro entitlement) jo t16 chaaron *.buyer ke liye chalata hai;
# phir pro.buyer ki org mein member + active org wahi. Test registry (E76) wall se guzarta hai => asli buyer se kabhi nahi milta.
# Password sirf /root/test-accounts/pro.buyer2.pw (chmod 600), screen par NAHI. Dobara chalana safe. Kuch delete nahi karta. Polar/Brain/Rust ko haath nahi.
set -uo pipefail
G=/opt/anexomail-web; H=pro.buyer2; EM=$H@anexomail.com; PWF=/root/test-accounts/$H.pw
[ -r /etc/anexomail/sync.env ] || { echo "FAIL: /etc/anexomail/sync.env nahi"; exit 2; }
. /etc/anexomail/sync.env
command -v psql >/dev/null || { echo "FAIL: psql nahi"; exit 2; }
P(){ psql "$WORKING_URL" -X -Atq "$@"; }
mkdir -p /root/test-accounts; chmod 700 /root/test-accounts
OWN="$(P -c "select o.org_id from public.org_members o join auth.users u on u.id=o.user_id where u.email='pro.buyer@anexomail.com' and o.status='active' order by o.created_at nulls last limit 1")"
[ -n "$OWN" ] || { echo "FAIL: pro.buyer ki org nahi mili (pehle t16-accounts-look.sh)"; exit 3; }
echo "pro.buyer org: ${OWN:0:8}…"
git -C "$G" fetch -q origin main 2>/dev/null
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$G" show origin/main:docs/cursor-work/sql/E28_seed_buyer_test_account.sql > "$T/E28.sql" || { echo "FAIL: E28 nahi mili"; exit 2; }
if [ "$(P -c "select count(*) from auth.users where email='$EM'")" = 0 ]; then
  PW="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 14)"
  psql "$WORKING_URL" -X -v ON_ERROR_STOP=1 -q -v handle=$H -v nm="Pro Buyer Two" -v org="Pro Buyer Two Test" -v domain=probuyer2.axonetis.com -v plan=pro -v pw="$PW" -f "$T/E28.sql" >/dev/null 2>"$T/err" \
    || { echo "FAIL: seed ($(head -c 200 "$T/err"))"; exit 4; }
  (umask 077; printf '%s\n' "$PW" > "$PWF"); unset PW
  echo "ban gaya: $EM (Pro). password: $PWF (server par, chmod 600)"
else echo "$EM pehle se hai"; fi
UID2="$(P -c "select id from auth.users where email='$EM'")"
# pro.buyer ki team mein member (idempotent)
P -c "insert into public.org_members (org_id,user_id,role,status,email) select '$OWN','$UID2','member','active','$EM' where not exists (select 1 from public.org_members where org_id='$OWN' and user_id='$UID2')" >/dev/null
P -c "insert into public.account_org_members (org_id,user_id,role) select '$OWN','$UID2','member' where exists (select 1 from public.account_organisations where id='$OWN') and not exists (select 1 from public.account_org_members where org_id='$OWN' and user_id='$UID2')" >/dev/null 2>&1
P -c "update public.account_profiles set preferences = coalesce(preferences,'{}'::jsonb) || jsonb_build_object('active_organisation_id','$OWN') where user_id='$UID2'" >/dev/null 2>&1
echo "membership: $(P -c "select role||'/'||status from public.org_members where org_id='$OWN' and user_id='$UID2'")  plan: $(P -c "select plan from public.entitlement_state where user_id='$UID2'")"
echo "team size ab: $(P -c "select count(*) from public.org_members where org_id='$OWN' and status='active'") / Pro cap $(P -c "select (public.team_seat_calc('pro',0,0,0)->>'seats')")"
echo "DONE. Ab: pro-team-probe.sh (assign / seat cap), aur browser mein pro.buyer2 ka login aap khud (password file se)."
