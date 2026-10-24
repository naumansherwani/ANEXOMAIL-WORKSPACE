-- CHECK E86 — Follow-ups + draft versions. Sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E86 mail_followups table + RLS on' as item,
         to_regclass('public.mail_followups') is not null
         and coalesce((select relrowsecurity from pg_class where oid = 'public.mail_followups'::regclass), false) as ok, 1 as o
  union all select 'E86 mail_followups: anon/authenticated ko access nahi',
         not has_table_privilege('anon', 'public.mail_followups', 'select')
         and not has_table_privilege('authenticated', 'public.mail_followups', 'select')
         and has_table_privilege('service_role', 'public.mail_followups', 'select'), 2
  union all select 'E86 draft versions: (draft_id, version) unique index',
         exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'mail_drafts_versions_draft_version_uq'), 3
  union all select 'E86 draft versions: duplicate version nahi',
         not exists (select 1 from public.mail_drafts_versions group by draft_id, version having count(*) > 1), 4
) t order by o;
