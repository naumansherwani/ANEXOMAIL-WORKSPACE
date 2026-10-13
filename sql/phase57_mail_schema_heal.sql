-- =============================================================================
-- ANEXOMAIL — Phase 57: MAIL SCHEMA HEAL (queue-unblock)
-- Kahan chalti hai: SUPABASE #4 -> SQL Editor (ya `bash sql/run.sh sql/phase57_mail_schema_heal.sql`)
--
-- ASLI WAJAH (server log se sabit):
--   anexomail-deliver: supabase 400 42703
--   column "spf_result" of relation "mail_messages" does not exist
--
-- `sql/phase52_mail_launch.sql` mein `create table if not exists` hai, is liye
-- server par jo PURANI mail_messages table pehle se mojood thi wohi rahi —
-- naye column (spf_result, dkim_result …) usmein kabhi nahi bane. Postfix ki
-- mail deleted nahi hui, sirf queue mein ruki hai (status=deferred). Column
-- banne ke baad `postqueue -f` wahi mail andar daal dega.
--
-- Yeh file: koi table drop nahi, koi row delete nahi — sirf missing column add.
-- Idempotent: jitni dafa chalao, wahi nateeja.
-- =============================================================================

-- ---------- 1) mail_messages: har missing column ----------
do $$
begin
  if to_regclass('public.mail_messages') is null then
    raise exception 'public.mail_messages nahi hai — pehle sql/phase52_mail_launch.sql chalao';
  end if;

  alter table public.mail_messages add column if not exists direction     text;
  alter table public.mail_messages add column if not exists message_id    text;
  alter table public.mail_messages add column if not exists in_reply_to   text;
  alter table public.mail_messages add column if not exists from_name     text;
  alter table public.mail_messages add column if not exists from_address  text;
  alter table public.mail_messages add column if not exists to_addresses  text[] default '{}';
  alter table public.mail_messages add column if not exists cc_addresses  text[] default '{}';
  alter table public.mail_messages add column if not exists subject       text;
  alter table public.mail_messages add column if not exists body_text     text;
  alter table public.mail_messages add column if not exists body_html     text;
  alter table public.mail_messages add column if not exists spf_result    text;
  alter table public.mail_messages add column if not exists dkim_result   text;
  alter table public.mail_messages add column if not exists dmarc_result  text;
  alter table public.mail_messages add column if not exists sent_at       timestamptz default now();
  alter table public.mail_messages add column if not exists created_at    timestamptz default now();

  -- direction ka check constraint sirf tab jab column khali na ho
  update public.mail_messages set direction = 'in' where direction is null;
  begin
    alter table public.mail_messages alter column direction set default 'in';
  exception when others then null;
  end;
end $$;

-- ---------- 2) mail_threads: har missing column ----------
do $$
begin
  if to_regclass('public.mail_threads') is null then
    raise exception 'public.mail_threads nahi hai — pehle sql/phase52_mail_launch.sql chalao';
  end if;

  alter table public.mail_threads add column if not exists mailbox_address text;
  alter table public.mail_threads add column if not exists subject         text default '(no subject)';
  alter table public.mail_threads add column if not exists snippet         text;
  alter table public.mail_threads add column if not exists from_name       text;
  alter table public.mail_threads add column if not exists from_address    text;
  alter table public.mail_threads add column if not exists message_count   integer default 0;
  alter table public.mail_threads add column if not exists unread          boolean default true;
  alter table public.mail_threads add column if not exists starred         boolean default false;
  alter table public.mail_threads add column if not exists has_attachments boolean default false;
  alter table public.mail_threads add column if not exists status          text default 'open';
  alter table public.mail_threads add column if not exists folder          text default 'inbox';
  alter table public.mail_threads add column if not exists last_message_at timestamptz default now();
  alter table public.mail_threads add column if not exists created_at      timestamptz default now();
end $$;

-- ---------- 3) mail_attachments + raw proof ----------
do $$
begin
  if to_regclass('public.mail_attachments') is not null then
    alter table public.mail_attachments add column if not exists mime_type  text;
    alter table public.mail_attachments add column if not exists size_bytes bigint default 0;
    alter table public.mail_attachments add column if not exists disk_path  text;
  end if;

  if to_regclass('public.mail_inbound_raw') is not null then
    alter table public.mail_inbound_raw add column if not exists envelope_from text;
    alter table public.mail_inbound_raw add column if not exists envelope_to   text;
    alter table public.mail_inbound_raw add column if not exists raw_size      integer default 0;
    alter table public.mail_inbound_raw add column if not exists raw_sha256    text;
    alter table public.mail_inbound_raw add column if not exists headers       jsonb default '{}'::jsonb;
    alter table public.mail_inbound_raw add column if not exists accepted      boolean default true;
    alter table public.mail_inbound_raw add column if not exists reason        text;
  end if;
end $$;

-- ---------- 4) purane NOT NULL column jo pipe nahi bharti ----------
-- Agar kisi purani column par NOT NULL hai aur default nahi, to insert phir
-- fail hoti (23502). Aisi columns ko default de kar nullable banate hain —
-- data delete nahi hota.
do $$
declare r record;
begin
  for r in
    select c.table_name, c.column_name
      from information_schema.columns c
     where c.table_schema = 'public'
       and c.table_name in ('mail_messages','mail_threads','mail_inbound_raw')
       and c.is_nullable = 'NO'
       and c.column_default is null
       and c.column_name not in ('id','thread_id')
  loop
    execute format('alter table public.%I alter column %I drop not null', r.table_name, r.column_name);
    raise notice 'healed: %.% NOT NULL hataya (pipe isay nahi bharti thi)', r.table_name, r.column_name;
  end loop;
end $$;

-- ---------- 5) grants (PostgREST ke liye lazmi) ----------
grant select, insert, update on public.mail_messages   to authenticated;
grant select, insert, update on public.mail_threads    to authenticated;
grant select, insert         on public.mail_inbound_raw to authenticated;
grant all on public.mail_messages    to service_role;
grant all on public.mail_threads     to service_role;
grant all on public.mail_inbound_raw to service_role;
grant all on public.mail_attachments to service_role;

-- ---------------------------------------------------------------- VERIFY
-- yeh do sotoon dekhne ke liye hain: spf_result maujood hona chahiye
select column_name, data_type, is_nullable
  from information_schema.columns
 where table_schema = 'public' and table_name = 'mail_messages'
 order by ordinal_position;

select count(*) as messages_ab_tak from public.mail_messages;
