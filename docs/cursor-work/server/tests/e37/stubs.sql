-- E37 self-test ke liye chhota stub schema (asli phase58 core ki nakal). core ka rawayya `stub_cfg.mode` se badalta hai.
create extension if not exists pgcrypto;
create table public.mail_accounts (id uuid primary key default gen_random_uuid(), address text, org_id uuid);
create table public.mailboxes (id uuid primary key default gen_random_uuid(), address text, org_id uuid, account_id uuid, box_type text default 'mailbox');
create table public.mail_threads (id uuid primary key default gen_random_uuid(), org_id uuid, account_id uuid, mailbox_address text, folder text default 'inbox');
create table public.mail_messages (id uuid primary key default gen_random_uuid(), thread_id uuid, org_id uuid, message_id text);
create table public.stub_cfg (mode text);
insert into public.stub_cfg values ('normal');
-- mode: normal = pate ke SABSE PEHLE owner (id order) ki org; other_owner = pate ke DOOSRE owner ki org; stray = kisi aur org (bug)
create function public.mail_ingest(payload jsonb) returns jsonb language plpgsql as $$
declare o uuid; m text := (select mode from public.stub_cfg); t uuid; a text := lower(payload->>'envelope_to');
begin
  if m = 'stray' then o := gen_random_uuid();
  elsif m = 'other_owner' then select org_id into o from public.mailboxes where lower(address) = a order by id desc limit 1;
  else select org_id into o from public.mailboxes where lower(address) = a order by id limit 1; end if;
  insert into public.mail_threads (org_id, mailbox_address) values (o, a) returning id into t;
  insert into public.mail_messages (thread_id, org_id, message_id) values (t, o, payload->>'message_id');
  return jsonb_build_object('ok', true, 'org_id', o, 'thread_id', t);
end $$;
