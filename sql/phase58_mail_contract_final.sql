-- =============================================================================
-- ANEXOMAIL — Phase 58: FINAL MAIL CONTRACT (queue unblock, no data deletion)
-- Kahan: `bash sql/run.sh sql/phase58_mail_contract_final.sql`
--
-- Live proof se do schema drifts mile:
--   1) mail_ingest() purani `mb.org_id` reference chala rahi thi
--   2) /api/mail/deliver purana `cc_addrs` naam bhej raha tha, jabke canonical
--      table mein `cc_addresses` hai
--
-- Yeh patch koi table/row delete nahi karta. Canonical + legacy names ko sync
-- karta hai, mail_ingest ko poora replace karta hai, aur PostgREST cache reload
-- karta hai. Postfix ki deferred mail phir `postqueue -f` se deliver hoti hai.
-- =============================================================================

set search_path = public, extensions;

-- 1) Dono live schema generations ko ek contract par lao --------------------
alter table public.mailboxes
  add column if not exists org_id uuid,
  add column if not exists account_id uuid;

alter table public.mail_threads
  add column if not exists org_id uuid,
  add column if not exists account_id uuid;

alter table public.mail_messages
  add column if not exists org_id uuid,
  add column if not exists to_addresses text[] not null default '{}',
  add column if not exists cc_addresses text[] not null default '{}',
  add column if not exists bcc_addresses text[] not null default '{}',
  add column if not exists to_addrs text[] not null default '{}',
  add column if not exists cc_addrs text[] not null default '{}',
  add column if not exists bcc_addrs text[] not null default '{}';

-- Existing rows dono naming generations se readable rahen.
update public.mail_messages
   set to_addresses  = case when cardinality(to_addresses)  = 0 then to_addrs  else to_addresses  end,
       cc_addresses  = case when cardinality(cc_addresses)  = 0 then cc_addrs  else cc_addresses  end,
       bcc_addresses = case when cardinality(bcc_addresses) = 0 then bcc_addrs else bcc_addresses end,
       to_addrs      = case when cardinality(to_addrs)      = 0 then to_addresses  else to_addrs  end,
       cc_addrs      = case when cardinality(cc_addrs)      = 0 then cc_addresses  else cc_addrs  end,
       bcc_addrs     = case when cardinality(bcc_addrs)     = 0 then bcc_addresses else bcc_addrs end;

create or replace function public.mail_message_address_compat()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if cardinality(new.to_addresses) = 0 and cardinality(new.to_addrs) > 0 then
    new.to_addresses := new.to_addrs;
  elsif cardinality(new.to_addrs) = 0 and cardinality(new.to_addresses) > 0 then
    new.to_addrs := new.to_addresses;
  end if;
  if cardinality(new.cc_addresses) = 0 and cardinality(new.cc_addrs) > 0 then
    new.cc_addresses := new.cc_addrs;
  elsif cardinality(new.cc_addrs) = 0 and cardinality(new.cc_addresses) > 0 then
    new.cc_addrs := new.cc_addresses;
  end if;
  if cardinality(new.bcc_addresses) = 0 and cardinality(new.bcc_addrs) > 0 then
    new.bcc_addresses := new.bcc_addrs;
  elsif cardinality(new.bcc_addrs) = 0 and cardinality(new.bcc_addresses) > 0 then
    new.bcc_addrs := new.bcc_addresses;
  end if;
  return new;
end $$;

drop trigger if exists mail_message_address_compat_trigger on public.mail_messages;
create trigger mail_message_address_compat_trigger
before insert or update of to_addresses, cc_addresses, bcc_addresses, to_addrs, cc_addrs, bcc_addrs
on public.mail_messages
for each row execute function public.mail_message_address_compat();

-- 2) Mailbox ownership ko available live truth se backfill karo ---------------
do $$
begin
  if to_regclass('public.mail_accounts') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='mail_accounts' and column_name='address')
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='mail_accounts' and column_name='org_id') then
    execute $q$
      update public.mailboxes mb
         set org_id = coalesce(mb.org_id, a.org_id),
             account_id = coalesce(mb.account_id, a.id)
        from public.mail_accounts a
       where lower(a.address) = lower(mb.address)
    $q$;
  end if;

  update public.mailboxes mb
     set org_id = coalesce(
           mb.org_id,
           (select mt.org_id from public.mail_threads mt
             where lower(mt.mailbox_address)=lower(mb.address) and mt.org_id is not null
             order by mt.last_message_at desc limit 1)
         ),
         account_id = coalesce(
           mb.account_id,
           (select mt.account_id from public.mail_threads mt
             where lower(mt.mailbox_address)=lower(mb.address) and mt.org_id is not null
             order by mt.last_message_at desc limit 1)
         );
end $$;

-- 3) Canonical mail_ingest: mailboxes.org_id par dependency nahi --------------
create or replace function public.mail_ingest(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_box    text := lower(coalesce(payload->>'envelope_to',''));
  v_subj   text := coalesce(nullif(trim(payload->>'subject'),''), '(no subject)');
  v_msgid  text := nullif(payload->>'message_id','');
  v_reply  text := nullif(payload->>'in_reply_to','');
  v_sent   timestamptz := coalesce(nullif(payload->>'sent_at','')::timestamptz, now());
  v_org    uuid;
  v_acct   uuid;
  v_thread uuid;
  v_msg    uuid;
  v_to     text[];
  v_cc     text[];
begin
  if v_box = '' then
    raise exception 'mail_ingest_missing_envelope_to';
  end if;

  insert into public.mail_inbound_raw
    (envelope_from, envelope_to, raw_size, raw_sha256, headers)
  values
    (payload->>'envelope_from', v_box,
     coalesce(nullif(payload->>'raw_size','')::integer, 0), payload->>'raw_sha256',
     coalesce(payload->'headers','{}'::jsonb));

  if v_msgid is not null then
    select id, thread_id into v_msg, v_thread
      from public.mail_messages where message_id = v_msgid limit 1;
    if v_msg is not null then
      return jsonb_build_object('ok', true, 'duplicate', true,
                                'thread_id', v_thread, 'message_id', v_msg);
    end if;
  end if;

  -- Owner resolution: account row -> mailbox row -> same mailbox thread -> any
  -- existing workspace org. Har query schema-safe hai; purana column na ho to skip.
  if to_regclass('public.mail_accounts') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='mail_accounts' and column_name='address')
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='mail_accounts' and column_name='org_id') then
    execute 'select id, org_id from public.mail_accounts where lower(address)=$1 limit 1'
      into v_acct, v_org using v_box;
  end if;

  if v_org is null then
    select mb.account_id, mb.org_id into v_acct, v_org
      from public.mailboxes mb where lower(mb.address)=v_box limit 1;
  end if;
  if v_org is null then
    select mt.account_id, mt.org_id into v_acct, v_org
      from public.mail_threads mt
     where lower(mt.mailbox_address)=v_box and mt.org_id is not null
     order by mt.last_message_at desc limit 1;
  end if;
  if v_org is null then
    select mt.org_id into v_org from public.mail_threads mt
     where mt.org_id is not null order by mt.last_message_at desc limit 1;
  end if;
  if v_org is null and to_regclass('public.orgs') is not null then
    execute 'select id from public.orgs limit 1' into v_org;
  end if;
  if v_org is null then
    v_org := 'dbd5aef3-8d6d-415f-9b5b-8d32f0adce3a';
  end if;

  update public.mailboxes
     set org_id=coalesce(org_id,v_org), account_id=coalesce(account_id,v_acct)
   where lower(address)=v_box;

  if v_reply is not null then
    select thread_id into v_thread from public.mail_messages
     where message_id=v_reply limit 1;
  end if;
  if v_thread is null then
    select id into v_thread from public.mail_threads
     where lower(mailbox_address)=v_box
       and subject=regexp_replace(v_subj, '^((re|fwd|fw)\s*:\s*)+', '', 'i')
       and last_message_at > now()-interval '30 days'
     order by last_message_at desc limit 1;
  end if;
  if v_thread is null then
    insert into public.mail_threads
      (org_id, account_id, mailbox_address, subject, snippet, from_name,
       from_address, message_count, unread, last_message_at)
    values
      (v_org, v_acct, v_box,
       regexp_replace(v_subj, '^((re|fwd|fw)\s*:\s*)+', '', 'i'),
       left(coalesce(payload->>'body_text',''),180), payload->>'from_name',
       lower(coalesce(payload->>'from_address','unknown')), 0, true, v_sent)
    returning id into v_thread;
  end if;

  select coalesce(array_agg(value), array[v_box]) into v_to
    from jsonb_array_elements_text(coalesce(payload->'to','[]'::jsonb));
  select coalesce(array_agg(value), '{}'::text[]) into v_cc
    from jsonb_array_elements_text(coalesce(payload->'cc','[]'::jsonb));

  insert into public.mail_messages
    (org_id, thread_id, direction, message_id, in_reply_to, from_name,
     from_address, to_addresses, cc_addresses, to_addrs, cc_addrs,
     subject, body_text, body_html, spf_result, dkim_result, sent_at)
  values
    (v_org, v_thread, 'in', v_msgid, v_reply, payload->>'from_name',
     lower(coalesce(payload->>'from_address','unknown')),
     v_to, v_cc, v_to, v_cc, v_subj, payload->>'body_text', payload->>'body_html',
     payload->>'spf', payload->>'dkim', v_sent)
  returning id into v_msg;

  update public.mail_threads
     set message_count=message_count+1, unread=true,
         org_id=coalesce(org_id,v_org), account_id=coalesce(account_id,v_acct),
         snippet=left(coalesce(payload->>'body_text',snippet,''),180),
         last_message_at=greatest(last_message_at,v_sent)
   where id=v_thread;

  return jsonb_build_object('ok',true,'thread_id',v_thread,'message_id',v_msg,'org_id',v_org);
end $$;

revoke all on function public.mail_ingest(jsonb) from public, anon, authenticated;
grant execute on function public.mail_ingest(jsonb) to service_role;
grant select, insert, update on public.mailboxes, public.mail_threads, public.mail_messages to authenticated;
grant all on public.mailboxes, public.mail_threads, public.mail_messages to service_role;

comment on function public.mail_ingest(jsonb) is 'anexomail-mail-contract-v59';

-- Data API ko naye columns/function foran dikhayein.
notify pgrst, 'reload schema';

-- VERIFY ---------------------------------------------------------------------
select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='mailboxes' and column_name='org_id') as mailbox_org_ready,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='mail_messages' and column_name='cc_addrs') as legacy_cc_ready,
  exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname='mail_ingest') as ingest_ready;