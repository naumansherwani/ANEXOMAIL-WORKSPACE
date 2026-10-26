#!/usr/bin/env bash
# ANEXOMAIL — 27 Oct 2026: workspace.personal bug (mojooda company workspace par "personal" stamp) se pro.buyer ka workspace_kind personal ho gaya tha.
# Yeh SIRF 4 *.buyer accounts ka workspace_kind wapas "business" karta hai (jo abhi "personal" ho), baaqi sab untouched. Pehle/baad dikhata hai.
# Pehle Rust install + restart karein (wsx fix), warna probe dobara bigaad dega.
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fix-buyer-kind.sh)
set +e
[ -r /etc/anexomail/sync.env ] || { echo "/etc/anexomail/sync.env nahi mila"; exit 0; }
. /etc/anexomail/sync.env 2>/dev/null
P() { psql "$WORKING_URL" -X -At -F ' | ' -c "$1" 2>&1 | head -20; }
LIST="('basic.buyer@anexomail.com','pro.buyer@anexomail.com','business.buyer@anexomail.com','bpro.buyer@anexomail.com')"
echo "== PEHLE (email | kind)"
P "select u.email, p.preferences->>'workspace_kind' from auth.users u join public.account_profiles p on p.user_id=u.id where u.email in $LIST order by 1;"
echo "== UPDATE (sirf jo personal hain)"
P "update public.account_profiles p set preferences=jsonb_set(coalesce(p.preferences,'{}'::jsonb),'{workspace_kind}','\"business\"'::jsonb,true) from auth.users u where u.id=p.user_id and u.email in $LIST and p.preferences->>'workspace_kind'='personal' returning u.email;"
echo "== BAAD (email | kind)"
P "select u.email, p.preferences->>'workspace_kind' from auth.users u join public.account_profiles p on p.user_id=u.id where u.email in $LIST order by 1;"
echo "== done. Browser mein Ctrl+Shift+R, phir dubara login/refresh."
