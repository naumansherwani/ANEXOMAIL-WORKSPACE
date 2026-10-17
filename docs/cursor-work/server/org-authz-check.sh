#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY Organisation authorisation + audit-ledger check (17 Oct 2026). Kuch badalta nahi, koi secret/email print nahi.
# Sawal: (1) kya live Brain `routes/org.ts` mein founder-gate / role-gate hai? (2) kya audit-chain table + functions maujood hain (sql/phase64_org_audit_ledger.sql) aur purani org_audit_ledger ki shakal kya hai?
# (3) kya har organisation ka koi owner hai (warna role-gate ke baad koi revoke/policy nahi badal sakega)?
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/org-authz-check.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }

hr "1. live Brain routes/org.ts vs repo"
for f in $(find /opt/anexomail -name org.ts -path '*routes*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -2); do
  echo "$f  sha256[:16]=$(sha256sum "$f" | cut -c1-16)  lines=$(wc -l < "$f")"
  echo "   founderGuard( uses : $(grep -c 'founderGuard(' "$f")   (repo-fixed file: 5)"
  echo "   guardCap( uses     : $(grep -c 'guardCap(' "$f")   (repo-fixed file: 8)"
  echo "   OLD pattern (first-org fallback 'from(\"organizations\").select(\"id\").limit(1)') : $(grep -c 'from("organizations").select("id").limit(1)' "$f")   (0 = fixed)"
done
echo "repo (origin/main) server/routes/org.ts sha256[:16]=$(git -C /opt/anexomail-web show origin/main:server/routes/org.ts 2>/dev/null | sha256sum | cut -c1-16)"

hr "2. database: tables + functions"
if [ -r /etc/anexomail/sync.env ]; then
  ( . /etc/anexomail/sync.env 2>/dev/null
    psql "$WORKING_URL" -Atc "
      select t, coalesce(to_regclass('public.'||t)::text,'MISSING') from unnest(array['org_members','organisations','organizations','orgs','org_audit_chain','org_audit_ledger','org_policies','org_sessions','org_break_glass','org_switches','founder_accounts']) t order by 1" 2>&1 | sed 's/|/  ->  /'
    echo "-- chain functions (phase64 ke baad: org_chain_append(text,text,text,text,uuid) + org_chain_verify(uuid))"
    psql "$WORKING_URL" -Atc "select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.proname like 'org_chain%' or p.proname like 'org_ledger%') order by 1" 2>&1 | head -8
    echo "-- chain rows (naya table)"
    psql "$WORKING_URL" -Atc "select count(*) rows, count(distinct org_id) orgs, count(*) filter (where org_id is null) platform_rows from public.org_audit_chain" 2>&1 | head -2
    echo "-- chain verify (platform chain): ok|checked|broken_at"
    psql "$WORKING_URL" -Atc "select ok, checked, broken_at_seq from public.org_chain_verify(null)" 2>&1 | head -2
    echo "-- PURANI org_audit_ledger (phase64 isko chhoo-ti nahi): columns + rows"
    psql "$WORKING_URL" -Atc "select column_name||' '||data_type||case when is_nullable='NO' then ' NOT NULL' else '' end from information_schema.columns where table_schema='public' and table_name='org_audit_ledger' order by ordinal_position" 2>&1 | head -20
    psql "$WORKING_URL" -Atc "select count(*) from public.org_audit_ledger" 2>&1 | head -1
  )
else
  echo "(/etc/anexomail/sync.env nahi mila)"
fi

hr "3. roles: har organisation ka owner (sirf ginti)"
if [ -r /etc/anexomail/sync.env ]; then
  ( . /etc/anexomail/sync.env 2>/dev/null
    psql "$WORKING_URL" -Atc "select coalesce(role::text,'(null)') role, coalesce(status,'(null)') status, count(*) from public.org_members group by 1,2 order by 3 desc" 2>&1 | sed 's/|/  /g' | head -12
    echo "-- organisations jinke paas ACTIVE owner NAHI hai (role-gate ke baad yeh orgs koi admin kaam nahi kar payengi):"
    psql "$WORKING_URL" -Atc "select count(*) from (select org_id from public.org_members group by org_id having count(*) filter (where role::text='owner' and coalesce(status,'active')='active')=0) x" 2>&1 | head -2
    echo "-- founder_accounts rows: $(psql "$WORKING_URL" -Atc 'select count(*) from public.founder_accounts' 2>&1 | head -1)"
  )
fi
echo
echo "Matlab: step 1 mein founderGuard>0 aur OLD pattern=0 ho to Brain fix live hai. Step 2 mein org_audit_chain MISSING ho to phase64 chalao."
