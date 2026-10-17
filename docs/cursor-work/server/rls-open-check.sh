#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY: kaun si tables customers (anon/authenticated) ke liye public database API se khuli hain?  (18 Oct 2026)
# Kuch badalta nahi, koi row/data print nahi karta — sirf table ke naam, huqooq aur policies ki ginti.
# Wajah: phase52/60/61/62/64 ne kuch tables par `authenticated` ko `using (true)` policies di thin (mail, org_members, contacts, calendar,
#        CRM, founder tables). Browser mein publishable key hoti hai => har customer apne JWT se seedha REST kholkar padh/likh sakta tha.
# Ilaaj: docs/cursor-work/sql/E32_tenant_lock.sql (app service_role par hai, usay kuch nahi hota).
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rls-open-check.sh)
set +e
[ -r /etc/anexomail/sync.env ] || { echo "(/etc/anexomail/sync.env nahi mila)"; exit 0; }
. /etc/anexomail/sync.env 2>/dev/null
Q() { psql "$WORKING_URL" -Atc "$1" 2>&1 | head -${2:-60}; }

echo "== 1. E32 ki list: har maujood table par customers (anon/authenticated) ke huqooq =="
echo "   (table | authenticated select/write | anon select | permissive-true policies | verdict)"
Q "
with t(name) as (select unnest(array[
 'mail_domains','mailboxes','mail_threads','mail_messages','mail_attachments','mail_inbound_raw','mail_outbox_log',
 'orgs','org_members','mail_accounts',
 'calendar_events','calendar_attendees','calendar_focus_windows','work_tasks','work_promises','work_notes','mail_thread_events',
 'companies','contacts','contact_stats','contact_tags','contact_tag_map',
 'crm_leads','crm_deals','crm_activities','crm_audit','crm_shared_items','crm_mentions','crm_approvals','crm_permissions','crm_graph_edges','crm_evidence',
 'delivery_checks','delivery_blocklists',
 'release_checklist','deployments','release_locks','roadmap_items','subscription_pipeline','movein_transitions','movein_capacity']))
select t.name || ' | ' ||
  case when has_table_privilege('authenticated','public.'||t.name,'select') then 'sel' else '-' end || '/' ||
  case when has_table_privilege('authenticated','public.'||t.name,'insert,update,delete') or has_table_privilege('authenticated','public.'||t.name,'insert') or has_table_privilege('authenticated','public.'||t.name,'update') or has_table_privilege('authenticated','public.'||t.name,'delete') then 'WRITE' else '-' end || ' | ' ||
  case when has_table_privilege('anon','public.'||t.name,'select') then 'sel' else '-' end || ' | ' ||
  (select count(*) from pg_policies p where p.schemaname='public' and p.tablename=t.name and (p.roles && array['anon','authenticated','public']::name[]) and (coalesce(p.qual,'')='true' or coalesce(p.with_check,'')='true')) || ' | ' ||
  case when has_table_privilege('authenticated','public.'||t.name,'select') or has_table_privilege('anon','public.'||t.name,'select')
            or has_table_privilege('authenticated','public.'||t.name,'insert') or has_table_privilege('authenticated','public.'||t.name,'update') or has_table_privilege('authenticated','public.'||t.name,'delete')
       then 'OPEN' else 'locked' end
from t where to_regclass('public.'||t.name) is not null order by 1" 70

echo
echo "== 2. KHULI ginti (E32 ki list mein) =="
Q "select count(*) from (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname = any (array['mail_domains','mailboxes','mail_threads','mail_messages','mail_attachments','mail_inbound_raw','mail_outbox_log','orgs','org_members','mail_accounts','calendar_events','calendar_attendees','calendar_focus_windows','work_tasks','work_promises','work_notes','mail_thread_events','companies','contacts','contact_stats','contact_tags','contact_tag_map','crm_leads','crm_deals','crm_activities','crm_audit','crm_shared_items','crm_mentions','crm_approvals','crm_permissions','crm_graph_edges','crm_evidence','delivery_checks','delivery_blocklists','release_checklist','deployments','release_locks','roadmap_items','subscription_pipeline','movein_transitions','movein_capacity']) and (has_table_privilege('authenticated', c.oid, 'select') or has_table_privilege('anon', c.oid, 'select') or has_table_privilege('authenticated', c.oid, 'insert') or has_table_privilege('authenticated', c.oid, 'update') or has_table_privilege('authenticated', c.oid, 'delete'))) x"

echo
echo "== 3. E32 ki list ke BAHAR: customers ke liye 'true' policies (inhein dekhna hai — kuch jaan-boojh kar public hain: setting_defs, storage_plans, locale_registry …) =="
Q "select p.tablename || ' | ' || p.cmd || ' | ' || array_to_string(p.roles,',') from pg_policies p where p.schemaname='public' and (p.roles && array['anon','authenticated','public']::name[]) and (coalesce(p.qual,'')='true' or coalesce(p.with_check,'')='true') and p.tablename <> all (array['mail_domains','mailboxes','mail_threads','mail_messages','mail_attachments','mail_inbound_raw','mail_outbox_log','orgs','org_members','mail_accounts','calendar_events','calendar_attendees','calendar_focus_windows','work_tasks','work_promises','work_notes','mail_thread_events','companies','contacts','contact_stats','contact_tags','contact_tag_map','crm_leads','crm_deals','crm_activities','crm_audit','crm_shared_items','crm_mentions','crm_approvals','crm_permissions','crm_graph_edges','crm_evidence','delivery_checks','delivery_blocklists','release_checklist','deployments','release_locks','roadmap_items','subscription_pipeline','movein_transitions','movein_capacity']) order by 1" 50

echo
echo "== natija kaise parhein =="
echo "Section 2 ki ginti 0 => customers ke liye sab band (E32 lag chuka). Ginti > 0 => E32 chalayen:"
echo "  git -C /opt/anexomail-web show origin/main:docs/cursor-work/sql/E32_tenant_lock.sql > /tmp/E32.sql && . /etc/anexomail/sync.env && psql \"\$WORKING_URL\" -v ON_ERROR_STOP=1 -q -f /tmp/E32.sql 2>&1 | grep -v NOTICE | tail -5; echo \"SQL exit: \${PIPESTATUS[0]}\""
