#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY test-accounts check (17 Oct 2026). Kuch badalta nahi. Koi password/hash print nahi (sirf "hai/nahi").
# Sawal: founder ke `basic.test` / `business_pro.test` accounts se login kyun nahi hota? Login ka store kahan hai,
#        yeh accounts wahan hain ya nahi, confirm/ban/plan kya hai.
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/test-accounts-check.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }
if [ ! -r /etc/anexomail/sync.env ]; then echo "/etc/anexomail/sync.env nahi mila"; exit 0; fi
. /etc/anexomail/sync.env 2>/dev/null
Q() { psql "$WORKING_URL" -X -At -F ' | ' -c "$1" 2>&1 | head -${2:-25}; }

hr "1. password wale tables (naam sirf; hash print nahi) — login ka store yahin hota hai"
Q "select table_schema||'.'||table_name||'.'||column_name from information_schema.columns where column_name in ('password_hash','encrypted_password','password_digest','pw_hash') and table_schema not in ('pg_catalog','information_schema') order by 1;"

hr "2. auth.users: email mein 'test' wale (email | confirmed | banned | deleted | pw hai? | last sign-in | created)"
Q "select email, (email_confirmed_at is not null) confirmed, banned_until, deleted_at, (encrypted_password is not null and encrypted_password<>'') has_pw, last_sign_in_at, created_at from auth.users where email ilike '%test%' or email ilike 'business_pro%' or email ilike 'basic.%' order by created_at;"

hr "3. in accounts ka plan / subscription / organisation (email | plan | state)"
Q "select u.email, s.plan, s.state from auth.users u left join public.workspace_subscriptions s on s.user_id=u.id where u.email ilike '%test%' order by 1;"
Q "select u.email, m.role, o.name from auth.users u join public.account_org_members m on m.user_id=u.id left join public.account_organisations o on o.id=m.org_id where u.email ilike '%test%' order by 1;"

hr "4. dusre identity tables (agar Rust ka alag identity store hai) — email mein 'test' ki ginti"
for t in $(Q "select table_schema||'.'||table_name from information_schema.columns where column_name in ('password_hash','pw_hash','password_digest') and table_schema not in ('pg_catalog','information_schema') group by 1;" 10 | grep -v '^ERROR'); do
  printf '%s: ' "$t"; Q "select count(*) from $t where email ilike '%test%';" 2
done

hr "5. mail address / mailbox (email | address) — test accounts ka inbox bana hai?"
Q "select u.email, a.address from auth.users u join public.mail_accounts a on a.org_id in (select org_id from public.account_org_members where user_id=u.id) where u.email ilike '%test%' limit 12;"

echo
echo "== done (read-only) =="
