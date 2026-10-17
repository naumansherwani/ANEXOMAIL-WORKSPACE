#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY CRM tenant-isolation check (17 Oct 2026, M6 CRM audit). Kuch badalta nahi, koi secret print nahi.
# Sawal: kya live Brain ke CRM endpoints (shared / mentions / approvals / audit / permissions) har workspace ki rows sab ko dikhate hain?
# Repo ka `server/routes/crm.ts` in tables ko service-role se BINA org filter ke padhta tha (ab repo mein theek hai). Yeh script
# live Brain ka sach dikhata hai: (1) live source mein kya filter hai, (2) in tables mein rows kitni/kis org ki hain.
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/crm-tenant-check.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }

hr "1. live Brain: crm.ts kahan hai + sha (repo wali se milao)"
for f in $(find /opt/anexomail -name crm.ts -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -4); do
  echo "$f  sha256[:16]=$(sha256sum "$f" | cut -c1-16)  lines=$(wc -l < "$f")"
done
echo "repo (origin/main) server/routes/crm.ts sha256[:16]=$(git -C /opt/anexomail-web show origin/main:server/routes/crm.ts 2>/dev/null | sha256sum | cut -c1-16)"
echo "repo (PEHLE wali, f03c018) sha nahi — farq aana theek hai; sawal neeche wale filters ka hai."

hr "2. live source: in 5 tables ki lines (org_id filter wali lines mein 'org_id' dikhna chahiye)"
for f in $(find /opt/anexomail -name crm.ts -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -2); do
  echo "-- $f"
  grep -n 'from("crm_shared_items")\|from("crm_mentions")\|from("crm_approvals")\|from("crm_audit")\|from("crm_permissions")' "$f" | cut -c1-170
  echo "   org_id filters in file: $(grep -c 'eq("org_id", c.orgId)' "$f")"
done

hr "3. database: rows aur org spread (sirf ginti — content nahi)"
if [ -r /etc/anexomail/sync.env ]; then
  ( . /etc/anexomail/sync.env 2>/dev/null
    psql "$WORKING_URL" -Atc "
      select 'crm_shared_items' t, count(*) rows, count(distinct org_id) orgs, count(*) filter (where org_id is null) null_org from crm_shared_items
      union all select 'crm_mentions', count(*), count(distinct org_id), count(*) filter (where org_id is null) from crm_mentions
      union all select 'crm_approvals', count(*), count(distinct org_id), count(*) filter (where org_id is null) from crm_approvals
      union all select 'crm_permissions', count(*), count(distinct org_id), count(*) filter (where org_id is null) from crm_permissions
      union all select 'crm_audit (distinct actors)', count(*), count(distinct actor), 0 from crm_audit
      union all select 'crm_activities (distinct actors)', count(*), count(distinct actor), 0 from crm_activities;" 2>&1 | head -12 )
else
  echo "/etc/anexomail/sync.env nahi mila"
fi

hr "4. kaun in tables mein likhta hai (live source mein insert)"
grep -rn 'from("crm_shared_items")\.insert\|from("crm_mentions")\.insert\|from("crm_approvals")\.insert\|crm_shared_items\|crm_approvals' /opt/anexomail/src --include=*.ts 2>/dev/null | grep -i 'insert' | cut -c1-160 | head -8
echo "(khali = koi code in tables mein rows nahi banata => 'Shared work' page abhi khali hi rehta hai)"

echo
echo "== done (read-only) =="
