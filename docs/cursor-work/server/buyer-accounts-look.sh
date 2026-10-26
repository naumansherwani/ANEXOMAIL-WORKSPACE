#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY: *.buyer test accounts (basic/pro/business/bpro) + koi bhi test account: plan, workspace-kind (personal/company), org, mailbox.
# Kuch badalta nahi, restart nahi, password/hash print nahi (sirf /root/test-accounts ki file ke NAAM).
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/buyer-accounts-look.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }
[ -r /etc/anexomail/sync.env ] || { echo "/etc/anexomail/sync.env nahi mila"; exit 0; }
. /etc/anexomail/sync.env 2>/dev/null
Q() { psql "$WORKING_URL" -X -At -F ' | ' -c "$1" 2>&1 | head -${2:-40}; }
hr "1. accounts (email | confirmed | banned | pw hai | last sign-in)"
Q "select email, (email_confirmed_at is not null), banned_until, (encrypted_password is not null and encrypted_password<>''), last_sign_in_at from auth.users where email ilike '%.buyer@%' or email ilike '%test%' order by 1;"
hr "2. plan (email | plan | state)"
Q "select u.email, s.plan, s.state from auth.users u left join public.workspace_subscriptions s on s.user_id=u.id where u.email ilike '%.buyer@%' or u.email ilike '%test%' order by 1;"
hr "3. workspace kind (email | kind | onboarded) — personal ya company"
Q "select u.email, p.preferences->>'workspace_kind', p.onboarded from auth.users u left join public.account_profiles p on p.user_id=u.id where u.email ilike '%.buyer@%' or u.email ilike '%test%' order by 1;"
hr "4. organisation (email | role | org)"
Q "select u.email, m.role, o.name from auth.users u join public.account_org_members m on m.user_id=u.id left join public.account_organisations o on o.id=m.org_id where u.email ilike '%.buyer@%' or u.email ilike '%test%' order by 1;"
hr "5. password files (sirf naam; andar ka text nahi)"
ls -1 /root/test-accounts 2>&1 | head -20
echo; echo "== done (read-only) =="
