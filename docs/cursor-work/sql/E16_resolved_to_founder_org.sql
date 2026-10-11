-- E16: resolved@anexomail.com (platform support inbox) basic org se founder org mein.
-- Is file mein commit/rollback NAHI hai: shell file ke baad "rollback;" (dry-run) ya "commit;" (asli) lagata hai.
-- Sirf resolved@ ka mailbox + uske threads + un threads ke bachhe rows. Baqi kuch nahi chhua jata.
begin;

do $$
declare
  founder_org constant uuid := '56592e36-4a72-4624-95d2-087509d7bb08';
  old_org     constant uuid := '16e02f4b-cc52-438f-a2e7-bef4ef7f81cb';
  tids text[];
  mids text[];
  r record;
  n int;
begin
  if not exists (
    select 1 from public.org_members m
    join public.founder_accounts f on f.user_id = m.user_id
    where m.org_id = founder_org and m.role = 'owner'
  ) then
    raise exception 'E16: founder org % ka owner check fail', founder_org;
  end if;

  select coalesce(array_agg(id::text), '{}') into tids from public.mail_threads
   where org_id = old_org and lower(mailbox_address) = 'resolved@anexomail.com';
  select coalesce(array_agg(id::text), '{}') into mids from public.mail_messages
   where thread_id::text = any(tids);
  raise notice 'threads mile: %, messages mile: %', cardinality(tids), cardinality(mids);

  update public.mailboxes set org_id = founder_org
   where org_id = old_org and lower(address) = 'resolved@anexomail.com';
  get diagnostics n = row_count; raise notice 'mailboxes moved: %', n;

  update public.mail_threads set org_id = founder_org where id::text = any(tids);
  get diagnostics n = row_count; raise notice 'mail_threads moved: %', n;

  -- thread_id wali bachhi tables (mail_messages, events, follow_ups ...)
  for r in
    select c.table_name from information_schema.columns c
    where c.table_schema = 'public' and c.column_name = 'org_id'
      and c.table_name like 'mail%' and c.table_name !~ '(backup|legacy)'
      and c.table_name not in ('mailboxes', 'mail_threads', 'mail_accounts', 'mail_domains')
      and exists (select 1 from information_schema.columns d
                  where d.table_schema = 'public' and d.table_name = c.table_name and d.column_name = 'thread_id')
  loop
    execute format('update public.%I set org_id = $1 where org_id = $2 and thread_id::text = any($3)', r.table_name)
      using founder_org, old_org, tids;
    get diagnostics n = row_count; raise notice '% moved: %', r.table_name, n;
  end loop;

  -- sirf message_id wali bachhi tables (attachments ...)
  for r in
    select c.table_name from information_schema.columns c
    where c.table_schema = 'public' and c.column_name = 'org_id'
      and c.table_name like 'mail%' and c.table_name !~ '(backup|legacy)'
      and exists (select 1 from information_schema.columns d
                  where d.table_schema = 'public' and d.table_name = c.table_name and d.column_name = 'message_id')
      and not exists (select 1 from information_schema.columns d
                  where d.table_schema = 'public' and d.table_name = c.table_name and d.column_name = 'thread_id')
  loop
    execute format('update public.%I set org_id = $1 where org_id = $2 and message_id::text = any($3)', r.table_name)
      using founder_org, old_org, mids;
    get diagnostics n = row_count; raise notice '% moved: %', r.table_name, n;
  end loop;
end $$;

-- natija (transaction ke andar): resolved@ ab sirf founder org mein hona chahiye
select 'mailboxes' as what, org_id::text, count(*) from public.mailboxes
 where lower(address) = 'resolved@anexomail.com' group by 2
union all
select 'threads', org_id::text, count(*) from public.mail_threads
 where lower(mailbox_address) = 'resolved@anexomail.com' group by 2
union all
select 'basic_org_still_has_resolved', '16e02f4b', count(*) from public.mail_threads
 where org_id = '16e02f4b-cc52-438f-a2e7-bef4ef7f81cb' and lower(mailbox_address) = 'resolved@anexomail.com';
