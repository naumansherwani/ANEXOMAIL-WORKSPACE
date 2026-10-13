# WIRE 11 — MAIL LAUNCH SQL (Supabase SQL editor mein direct copy-paste)

Yeh Phase 52 hai: mail ka source of truth + 13 asli `anexomail.com` addresses ka seed.
Runner se RED aaya tha kyunke purane phase ki `mail_threads` / `mail_messages` ka
dhaancha alag tha. Ab file khud self-heal karti hai (purani conflicting table
`_legacy_<timestamp>` ban jati hai) aur `mail_ingest` / `mail_outbox_record` ka
purana signature pehle drop hota hai.

Do raaste — koi bhi:

**A) Supabase SQL editor (aap ka tareeqa):** neeche ka poora block copy karo →
Supabase #4 → SQL Editor → paste → Run. Aakhir mein `mailboxes = 13`,
`domains = 1` aana chahiye.

**B) Server se ek line:**

```bash
cd /opt/anexomail-web && git pull && bash sql/run.sh sql/phase52_mail_launch.sql
```

Dono ka natija ek hi hai. Yeh file idempotent hai — jitni baar chalao, safe.

---

## POORA SQL (copy from here)

```sql
-- =============================================================================
-- ANEXOMAIL — Phase 52: MAIL LAUNCH (real inbound + outbound truth)
-- Supabase #4 SQL editor mein poori file copy-paste karo. Idempotent + self-healing.
--
-- Yeh file mail ka SOURCE OF TRUTH banati hai:
--   mail_domains · mailboxes · mail_threads · mail_messages · mail_attachments
--   mail_inbound_raw (har aane wali mail ka raw proof) · mail_outbox_log
--   RPC mail_ingest(jsonb)  -> Postfix pipe isi ko call karta hai (service_role)
--   RPC mail_outbox_record(jsonb) -> outbound proof
-- Koi dummy row nahi: sirf 13 asli anexomail.com addresses seed hote hain.
-- =============================================================================

-- pg_trgm: Supabase par pehle se `extensions` schema mein hota hai. Agar create
-- ki ijazat na ho to rukna nahi — trigram index neeche khud skip ho jata hai.
do $$
begin
  create extension if not exists pg_trgm;
exception when others then
  raise notice 'pg_trgm create skip: %', sqlerrm;
end $$;

-- ---------- self-heal: purani conflicting tables _legacy_<ts> rename ----------
-- Har table ka ek "required column" hai. Agar table maujood hai magar us column
-- ke baghair (purane phase ka dhaancha), to usay rename kar ke fresh banate hain.
do $$
declare
  ts   text := to_char(now(), 'YYYYMMDDHH24MISS');
  pair text;
  tbl  text;
  col  text;
begin
  foreach pair in array array[
    'mail_inbound_raw:created_at',
    'mail_outbox_log:created_at',
    'mail_domains:dkim_selector',
    'mailboxes:box_type',
    'mail_threads:mailbox_address',
    'mail_messages:direction',
    'mail_attachments:disk_path'
  ] loop
    tbl := split_part(pair, ':', 1);
    col := split_part(pair, ':', 2);
    if exists (select 1 from information_schema.tables
                where table_schema = 'public' and table_name = tbl)
       and not exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = tbl and column_name = col) then
      -- dependent views/functions se na rukein
      execute format('alter table public.%I rename to %I', tbl, tbl || '_legacy_' || ts);
      raise notice 'self-heal: % -> %', tbl, tbl || '_legacy_' || ts;
    end if;
  end loop;
end $$;


-- ---------- domains ----------
create table if not exists public.mail_domains (
  id          uuid primary key default gen_random_uuid(),
  domain      text not null unique,
  is_primary  boolean not null default false,
  mx_host     text,
  dkim_selector text default 'mail',
  created_at  timestamptz not null default now()
);

-- ---------- mailboxes ----------
do $$ begin
  create type public.mailbox_type as enum ('mailbox','alias','sendonly');
exception when duplicate_object then null; end $$;

create table if not exists public.mailboxes (
  id            uuid primary key default gen_random_uuid(),
  address       text not null unique,
  display_name  text not null,
  box_type      public.mailbox_type not null default 'mailbox',
  alias_target  text,
  purpose       text not null,
  is_public     boolean not null default false,
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

-- ---------- threads ----------
create table if not exists public.mail_threads (
  id               uuid primary key default gen_random_uuid(),
  mailbox_address  text not null,
  subject          text not null default '(no subject)',
  snippet          text,
  from_name        text,
  from_address     text,
  message_count    integer not null default 0,
  unread           boolean not null default true,
  starred          boolean not null default false,
  has_attachments  boolean not null default false,
  status           text not null default 'open',
  folder           text not null default 'inbox',
  last_message_at  timestamptz not null default now(),
  created_at       timestamptz not null default now()
);
create index if not exists mail_threads_box_idx on public.mail_threads (mailbox_address, last_message_at desc);
-- trigram index: opclass ka schema runtime par dhoondo (Supabase par pg_trgm `extensions` mein hai)
do $$
declare op text;
begin
  select n.nspname into op
    from pg_opclass c join pg_namespace n on n.oid = c.opcnamespace
   where c.opcname = 'gin_trgm_ops' limit 1;
  if op is null then raise notice 'pg_trgm missing — trigram index skip'; return; end if;
  execute format('create index if not exists mail_threads_subject_trgm on public.mail_threads using gin (subject %I.gin_trgm_ops)', op);
end $$;

-- ---------- messages ----------
create table if not exists public.mail_messages (
  id            uuid primary key default gen_random_uuid(),
  thread_id     uuid not null references public.mail_threads(id) on delete cascade,
  direction     text not null check (direction in ('in','out')),
  message_id    text,
  in_reply_to   text,
  from_name     text,
  from_address  text not null,
  to_addresses  text[] not null default '{}',
  cc_addresses  text[] not null default '{}',
  subject       text,
  body_text     text,
  body_html     text,
  spf_result    text,
  dkim_result   text,
  sent_at       timestamptz not null default now(),
  created_at    timestamptz not null default now()
);
create unique index if not exists mail_messages_msgid_uniq
  on public.mail_messages (message_id) where message_id is not null;
create index if not exists mail_messages_thread_idx on public.mail_messages (thread_id, sent_at);
do $$
declare op text;
begin
  select n.nspname into op
    from pg_opclass c join pg_namespace n on n.oid = c.opcnamespace
   where c.opcname = 'gin_trgm_ops' limit 1;
  if op is null then raise notice 'pg_trgm missing — trigram index skip'; return; end if;
  execute format('create index if not exists mail_messages_body_trgm on public.mail_messages using gin (body_text %I.gin_trgm_ops)', op);
end $$;

-- ---------- attachments ----------
create table if not exists public.mail_attachments (
  id          uuid primary key default gen_random_uuid(),
  message_id  uuid not null references public.mail_messages(id) on delete cascade,
  filename    text not null,
  mime_type   text,
  size_bytes  bigint not null default 0,
  disk_path   text,
  created_at  timestamptz not null default now()
);

-- ---------- raw inbound proof (append-only) ----------
create table if not exists public.mail_inbound_raw (
  id          uuid primary key default gen_random_uuid(),
  envelope_from text,
  envelope_to   text,
  raw_size    integer not null default 0,
  raw_sha256  text,
  headers     jsonb not null default '{}'::jsonb,
  accepted    boolean not null default true,
  reason      text,
  created_at  timestamptz not null default now()
);
create index if not exists mail_inbound_raw_time_idx on public.mail_inbound_raw (created_at desc);

-- ---------- outbound proof ----------
create table if not exists public.mail_outbox_log (
  id            uuid primary key default gen_random_uuid(),
  from_address  text not null,
  to_addresses  text[] not null,
  subject       text,
  message_id    text,
  smtp_response text,
  ok            boolean not null default false,
  error         text,
  created_at    timestamptz not null default now()
);
create index if not exists mail_outbox_log_time_idx on public.mail_outbox_log (created_at desc);

-- ---------- GRANTS (RLS se pehle, warna PostgREST band) ----------
grant select on public.mail_domains, public.mailboxes to authenticated;
grant select, insert, update, delete on public.mail_threads, public.mail_messages, public.mail_attachments to authenticated;
grant select on public.mail_inbound_raw, public.mail_outbox_log to authenticated;
grant all on public.mail_domains, public.mailboxes, public.mail_threads, public.mail_messages,
             public.mail_attachments, public.mail_inbound_raw, public.mail_outbox_log to service_role;

alter table public.mail_domains       enable row level security;
alter table public.mailboxes          enable row level security;
alter table public.mail_threads       enable row level security;
alter table public.mail_messages      enable row level security;
alter table public.mail_attachments   enable row level security;
alter table public.mail_inbound_raw   enable row level security;
alter table public.mail_outbox_log    enable row level security;

do $$
declare r record;
begin
  for r in
    select unnest(array['mail_domains','mailboxes','mail_threads','mail_messages',
                        'mail_attachments','mail_inbound_raw','mail_outbox_log']) as t
  loop
    execute format('drop policy if exists auth_read on public.%I', r.t);
    execute format('create policy auth_read on public.%I for select to authenticated using (true)', r.t);
  end loop;
  -- workspace users mail par kaam kar sakte hain (status/folder/read flags)
  for r in select unnest(array['mail_threads','mail_messages','mail_attachments']) as t loop
    execute format('drop policy if exists auth_write on public.%I', r.t);
    execute format('create policy auth_write on public.%I for all to authenticated using (true) with check (true)', r.t);
  end loop;
end $$;

-- append-only: raw inbound aur outbox log kabhi edit/delete nahi
create or replace function public.mail_append_only() returns trigger
language plpgsql as $$
begin
  raise exception 'append-only table: % ki row change nahi ho sakti', tg_table_name;
end $$;

drop trigger if exists mail_inbound_raw_immutable on public.mail_inbound_raw;
create trigger mail_inbound_raw_immutable before update or delete on public.mail_inbound_raw
  for each row execute function public.mail_append_only();
drop trigger if exists mail_outbox_log_immutable on public.mail_outbox_log;
create trigger mail_outbox_log_immutable before update or delete on public.mail_outbox_log
  for each row execute function public.mail_append_only();

-- =============================================================================
-- RPC: mail_ingest — Postfix pipe (service_role) isko call karta hai
-- payload: { envelope_from, envelope_to, message_id, in_reply_to, from_name,
--            from_address, to:[], cc:[], subject, body_text, body_html,
--            spf, dkim, sent_at, raw_size, raw_sha256, headers }
-- =============================================================================
drop function if exists public.mail_ingest(jsonb) cascade;
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
  v_sent   timestamptz := coalesce((payload->>'sent_at')::timestamptz, now());
  v_thread uuid;
  v_msg    uuid;
begin
  insert into public.mail_inbound_raw (envelope_from, envelope_to, raw_size, raw_sha256, headers)
  values (payload->>'envelope_from', v_box,
          coalesce((payload->>'raw_size')::int, 0), payload->>'raw_sha256',
          coalesce(payload->'headers','{}'::jsonb));

  -- duplicate delivery (Postfix retry) — chup-chaap wahi message id wapas
  if v_msgid is not null then
    select id into v_msg from public.mail_messages where message_id = v_msgid;
    if v_msg is not null then
      return jsonb_build_object('ok', true, 'duplicate', true, 'message_id', v_msg);
    end if;
  end if;

  -- reply chain: pehle In-Reply-To se thread dhoondo, warna subject+mailbox
  if v_reply is not null then
    select thread_id into v_thread from public.mail_messages where message_id = v_reply limit 1;
  end if;
  if v_thread is null then
    select id into v_thread from public.mail_threads
     where mailbox_address = v_box
       and subject = regexp_replace(v_subj, '^((re|fwd|fw)\s*:\s*)+', '', 'i')
       and last_message_at > now() - interval '30 days'
     order by last_message_at desc limit 1;
  end if;

  if v_thread is null then
    insert into public.mail_threads (mailbox_address, subject, snippet, from_name, from_address,
                                     message_count, unread, last_message_at)
    values (v_box, regexp_replace(v_subj, '^((re|fwd|fw)\s*:\s*)+', '', 'i'),
            left(coalesce(payload->>'body_text',''), 180),
            payload->>'from_name', lower(coalesce(payload->>'from_address','unknown')),
            0, true, v_sent)
    returning id into v_thread;
  end if;

  insert into public.mail_messages (thread_id, direction, message_id, in_reply_to, from_name,
    from_address, to_addresses, cc_addresses, subject, body_text, body_html,
    spf_result, dkim_result, sent_at)
  values (v_thread, 'in', v_msgid, v_reply, payload->>'from_name',
    lower(coalesce(payload->>'from_address','unknown')),
    coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(payload->'to','[]'::jsonb)) x), array[v_box]),
    coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(payload->'cc','[]'::jsonb)) x), '{}'),
    v_subj, payload->>'body_text', payload->>'body_html',
    payload->>'spf', payload->>'dkim', v_sent)
  returning id into v_msg;

  update public.mail_threads
     set message_count = message_count + 1,
         unread = true,
         snippet = left(coalesce(payload->>'body_text', snippet, ''), 180),
         last_message_at = greatest(last_message_at, v_sent)
   where id = v_thread;

  return jsonb_build_object('ok', true, 'thread_id', v_thread, 'message_id', v_msg);
end $$;

revoke all on function public.mail_ingest(jsonb) from public, anon, authenticated;
grant execute on function public.mail_ingest(jsonb) to service_role;

-- =============================================================================
-- RPC: mail_outbox_record — outbound proof (sirf server)
-- =============================================================================
drop function if exists public.mail_outbox_record(jsonb) cascade;
create or replace function public.mail_outbox_record(payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_id uuid;
begin
  insert into public.mail_outbox_log (from_address, to_addresses, subject, message_id, smtp_response, ok, error)
  values (lower(payload->>'from_address'),
          coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(payload->'to','[]'::jsonb)) x), '{}'),
          payload->>'subject', nullif(payload->>'message_id',''),
          payload->>'smtp_response', coalesce((payload->>'ok')::boolean, false), payload->>'error')
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.mail_outbox_record(jsonb) from public, anon, authenticated;
grant execute on function public.mail_outbox_record(jsonb) to service_role;

-- =============================================================================
-- SEED — sirf asli anexomail.com addresses (nexatect is launch mein nahi)
-- =============================================================================
insert into public.mail_domains (domain, is_primary, mx_host, dkim_selector)
values ('anexomail.com', true, 'mail.anexomail.com', 'mail')
on conflict (domain) do update
  set is_primary = true, mx_host = excluded.mx_host, dkim_selector = excluded.dkim_selector;

insert into public.mailboxes (address, display_name, box_type, alias_target, purpose, is_public) values
 ('hello@anexomail.com','ANEXOMAIL','mailbox',null,'Footer, get-started, AI page, checkout-done, trial-ended, AI top-up',true),
 ('moveyourbusiness@anexomail.com','ANEXOMAIL Move-Ins','mailbox',null,'Landing hero CTA, migration, enterprise, plans, LeadForm',true),
 ('support@anexomail.com','ANEXOMAIL Support (alias)','alias','resolved@anexomail.com','Purani support address — sirf alias, sab kuch resolved@ par jaata hai',false),
 ('billing@anexomail.com','ANEXOMAIL Billing','mailbox',null,'/docs — invoices and plan questions',true),
 ('noreply@anexomail.com','ANEXOMAIL (no reply)','sendonly',null,'Outbound system mail (glitch alerts). Inbound discarded.',true),
 ('resolved@anexomail.com','ANEXOMAIL Resolved log','mailbox',null,'Silent BCC log of resolved support replies',false),
 ('trials@anexomail.com','ANEXOMAIL Trials','mailbox',null,'Trial start/expiry reply-to',false),
 ('abuse@anexomail.com','ANEXOMAIL Abuse','mailbox',null,'RFC required abuse reports',false),
 ('postmaster@anexomail.com','ANEXOMAIL Postmaster','alias','abuse@anexomail.com','RFC required, alias to abuse@',false),
 ('dmarc@anexomail.com','ANEXOMAIL DMARC','mailbox',null,'DMARC rua/ruf reports',false),
 ('naumansherwani.founder@anexomail.com','Muhammad Nauman Sherwani','mailbox',null,'Founder primary (/app/founder)',false),
 ('nauman@anexomail.com','Nauman','alias','naumansherwani.founder@anexomail.com','Short alias to founder primary',false),
 ('leo@anexomail.com','Leo — ANEXOMAIL AI','mailbox',null,'LEO auto-reply pipeline (/app/founder)',false)
on conflict (address) do update
  set display_name = excluded.display_name,
      box_type     = excluded.box_type,
      alias_target = excluded.alias_target,
      purpose      = excluded.purpose,
      is_public    = excluded.is_public,
      active       = true;

-- verify
select (select count(*) from public.mailboxes)     as mailboxes,
       (select count(*) from public.mail_domains)  as domains;
```

---

## Verify (isi editor mein alag se)

```sql
select count(*) as mailboxes from public.mailboxes;
select address, box_type, alias_target, is_public from public.mailboxes order by address;
select proname from pg_proc where proname in ('mail_ingest','mail_outbox_record');
select relname, relrowsecurity from pg_class
 where relname in ('mail_domains','mailboxes','mail_threads','mail_messages',
                   'mail_attachments','mail_inbound_raw','mail_outbox_log');
```

GREEN ka matlab: `mailboxes = 13`, dono function maujood, saari 7 tables par
`relrowsecurity = true`.

Iske baad mail block ka agla dot: `docs/wire/06-mail.md`.
