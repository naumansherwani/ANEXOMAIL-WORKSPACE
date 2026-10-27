
-- E101 — ACTIVITY ENGINE (super advanced): dashboard "Recent activity" khali kyun tha?  activity_log table ko KOI likhta hi nahi tha.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Ab ek poora engine: har asli cheez (mail aayi / gayi, thread assign / band, naya member, domain verify) apne aap likhi jaati hai.
--   1) activity_log ko seedha karta hai: naye columns (source_id, thread_id, meta, source) — purane columns/Rust SELECT NAHI tootte
--   2) EXACT dedupe: unique (org_id, kind, source_id) — ek event kabhi do baar nahi (purana "NOT EXISTS" andaza hata diya)
--   3) activity_record()      — ek hi likhne wala darwaza (clamp, saaf, ON CONFLICT DO NOTHING, hamesha mail ko mehfooz)
--   4) triggers (sirf jo table/column LIVE mein hain — information_schema se dekh kar):
--        mail_messages INSERT           -> message_received / message_sent
--        mail_threads  assignee badla   -> thread_assigned
--        mail_threads  state => done    -> thread_done
--        org_members   INSERT           -> member_joined
--        organisations domain_verified  -> domain_verified
--   5) activity_feed()        — keyset pagination (before + kinds filter), member-gated, ek hi SQL se
--   6) activity_daily rollup  — din-ba-din ginti (kind x din), refresh function, view
--   7) activity_heal()        — jo event trigger se chhoot gaya (purani mail) usay wapas bharta hai; dobara chalana safe
--   8) activity_prune()       — purani entries saaf (default 180 din), sirf service_role
--   9) activity_health()      — "kitni mail ki activity gayab hai" ek jsonb mein (0 honi chahiye)
--  10) activity_summary / activity_anomalies (z-score spike) / activity_search (wildcard escape)
--  11) selftest (asli org par, AAKHIR MEIN poora rollback)
-- PRIVACY (locked): activity_log mein mail ka BODY kabhi nahi. Sirf subject (200 akshar tak), bhejne wale ka naam/address (120 tak),
--   aur meta mein ginti (recipients, attachments). Sirf apni org ke members dekhte hain (activity_log ki policy pehle se).
--   Founder view mein content nahi — yeh table sirf customer ke apne workspace ki timeline hai.
-- Dobara chalana safe. Polar :3400 NO-TOUCH. Rust (dashboard.activity) ka SELECT id,kind,actor_label,subject,detail,created_at jaisa tha waisa chalta hai.

set lock_timeout = '10s';
set statement_timeout = '180s';
set search_path = public, extensions;

-- ===============================================================================================================
-- 1) activity_log — naye columns (sab nullable / default; purana kuch nahi tootta)
-- ===============================================================================================================
do $$ begin
  if to_regclass('public.activity_log') is null then
    create table public.activity_log (
      id          uuid primary key default gen_random_uuid(),
      org_id      uuid not null,
      actor_id    uuid,
      actor_label text,
      kind        text not null,
      subject     text not null,
      detail      text,
      created_at  timestamptz not null default now()
    );
    alter table public.activity_log enable row level security;
  end if;
end $$;

alter table public.activity_log add column if not exists source_id uuid;
alter table public.activity_log add column if not exists thread_id uuid;
alter table public.activity_log add column if not exists source    text not null default 'trigger';
alter table public.activity_log add column if not exists meta      jsonb not null default '{}'::jsonb;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'activity_log_meta_obj') then
    alter table public.activity_log add constraint activity_log_meta_obj check (jsonb_typeof(meta) = 'object') not valid;
    alter table public.activity_log validate constraint activity_log_meta_obj;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'activity_log_source_chk') then
    alter table public.activity_log add constraint activity_log_source_chk
      check (source in ('trigger','heal','backfill','manual')) not valid;
    alter table public.activity_log validate constraint activity_log_source_chk;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'activity_log_subject_len') then
    alter table public.activity_log add constraint activity_log_subject_len check (char_length(subject) <= 200) not valid;
    -- purani lambi rows ho sakti hain: validate nahi karte (sirf nayi rows par lagta hai)
  end if;
end $$;

-- EXACT dedupe: ek hi asli cheez (jaise ek mail ki id) ka ek hi event per kind
create unique index if not exists activity_log_source_uq
  on public.activity_log (org_id, kind, source_id) where source_id is not null;
create index if not exists activity_log_org_kind_idx on public.activity_log (org_id, kind, created_at desc);
create index if not exists activity_log_thread_idx   on public.activity_log (thread_id, created_at desc) where thread_id is not null;

alter table public.activity_log enable row level security;
revoke all on public.activity_log from public, anon;
-- authenticated ka sirf SELECT (policy activity_member_read pehle se); likhna sirf service_role / trigger
revoke insert, update, delete, truncate on public.activity_log from authenticated;
grant all on public.activity_log to service_role;

-- ===============================================================================================================
-- 2) aam saaf-safai ke helpers (pure, immutable)
-- ===============================================================================================================
create or replace function public.activity_clean(p_text text, p_max integer default 200)
returns text language sql immutable set search_path = public as $$
  select left(
           regexp_replace(
             regexp_replace(coalesce(p_text, ''), '[\u0001-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]', ' ', 'g'),
             '\s+', ' ', 'g'),
           greatest(p_max, 1));
$$;

create or replace function public.activity_subject(p_subject text)
returns text language sql immutable set search_path = public as $$
  select coalesce(nullif(btrim(public.activity_clean(p_subject, 200)), ''), '(no subject)');
$$;

create or replace function public.activity_actor_label(p_name text, p_address text)
returns text language sql immutable set search_path = public as $$
  select coalesce(nullif(btrim(public.activity_clean(p_name, 120)), ''),
                  nullif(btrim(public.activity_clean(p_address, 120)), ''),
                  'mail');
$$;

create or replace function public.activity_kind_ok(p_kind text)
returns boolean language sql immutable set search_path = public as $$
  select p_kind in ('message_received','message_sent','thread_assigned','thread_done','member_joined','domain_verified','login','admin_change');
$$;

-- ===============================================================================================================
-- 3) EK likhne wala darwaza — kabhi exception bahar nahi (mail/thread ka kaam activity ki wajah se nahi rukta)
-- ===============================================================================================================
create or replace function public.activity_record(
  p_org uuid, p_kind text, p_subject text, p_detail text default null,
  p_actor_id uuid default null, p_label text default null,
  p_source uuid default null, p_thread uuid default null,
  p_at timestamptz default null, p_meta jsonb default '{}'::jsonb,
  p_origin text default 'trigger')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if p_org is null or not public.activity_kind_ok(p_kind) then return null; end if;
  insert into public.activity_log (org_id, actor_id, actor_label, kind, subject, detail, created_at, source_id, thread_id, source, meta)
  values (p_org, p_actor_id, nullif(left(btrim(public.activity_clean(p_label, 120)), 120), ''), p_kind,
          public.activity_subject(p_subject), nullif(left(public.activity_clean(p_detail, 240), 240), ''),
          coalesce(p_at, now()), p_source, p_thread,
          case when p_origin in ('trigger','heal','backfill','manual') then p_origin else 'trigger' end,
          case when jsonb_typeof(coalesce(p_meta, '{}'::jsonb)) = 'object' then coalesce(p_meta, '{}'::jsonb) else '{}'::jsonb end)
  on conflict (org_id, kind, source_id) where source_id is not null do nothing
  returning id into v_id;
  return v_id;
exception when others then
  return null;
end $$;
revoke all on function public.activity_record(uuid,text,text,text,uuid,text,uuid,uuid,timestamptz,jsonb,text) from public, anon, authenticated;
grant execute on function public.activity_record(uuid,text,text,text,uuid,text,uuid,uuid,timestamptz,jsonb,text) to service_role;

-- ===============================================================================================================
-- 4a) TRIGGER: mail_messages INSERT -> message_received / message_sent
-- ===============================================================================================================
create or replace function public.activity_from_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_kind text;
  v_rcpt integer;
begin
  if new.org_id is null then return new; end if;
  v_kind := case new.direction::text when 'in' then 'message_received' when 'out' then 'message_sent' else null end;
  if v_kind is null then return new; end if;
  v_rcpt := coalesce(cardinality(new.to_addresses), 0) + coalesce(cardinality(new.cc_addresses), 0);
  perform public.activity_record(
    new.org_id, v_kind, new.subject,
    case v_kind when 'message_received' then 'Received' else 'Sent' end,
    null, public.activity_actor_label(new.from_name, new.from_address),
    new.id, new.thread_id, coalesce(new.sent_at, now()),
    jsonb_build_object('recipients', v_rcpt), 'trigger');
  return new;
exception when others then
  return new;
end $$;
revoke all on function public.activity_from_message() from public, anon, authenticated;

-- ===============================================================================================================
-- 4b) TRIGGER: mail_threads — assign / done  (sirf agar table + columns maujood hon)
-- ===============================================================================================================
create or replace function public.activity_from_thread()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_subj text;
begin
  if new.org_id is null then return new; end if;
  begin v_subj := (to_jsonb(new) ->> 'subject'); exception when others then v_subj := null; end;
  if (to_jsonb(new) ->> 'assignee_id') is distinct from (to_jsonb(old) ->> 'assignee_id')
     and (to_jsonb(new) ->> 'assignee_id') is not null then
    perform public.activity_record(new.org_id, 'thread_assigned', v_subj, 'Assigned',
      nullif(to_jsonb(new) ->> 'assignee_id', '')::uuid, null,
      -- source_id: thread id + assign badalne ka waqt na ho to nayi uuid: har assign ek alag event
      gen_random_uuid(), new.id, now(), '{}'::jsonb, 'trigger');
  end if;
  if (to_jsonb(new) ->> 'state') = 'done' and (to_jsonb(old) ->> 'state') is distinct from 'done' then
    perform public.activity_record(new.org_id, 'thread_done', v_subj, 'Closed',
      null, null, gen_random_uuid(), new.id, now(), '{}'::jsonb, 'trigger');
  end if;
  return new;
exception when others then
  return new;
end $$;
revoke all on function public.activity_from_thread() from public, anon, authenticated;

-- ===============================================================================================================
-- 4c) TRIGGER: org_members INSERT -> member_joined  (naam/email NAHI likhte — sirf "A new member")
-- ===============================================================================================================
create or replace function public.activity_from_member()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_user uuid;
begin
  begin v_org := nullif(to_jsonb(new) ->> 'org_id', '')::uuid; exception when others then v_org := null; end;
  begin v_user := nullif(to_jsonb(new) ->> 'user_id', '')::uuid; exception when others then v_user := null; end;
  if v_org is null then return new; end if;
  perform public.activity_record(v_org, 'member_joined', 'A new member joined the workspace', 'Joined',
    v_user, null, coalesce(nullif(to_jsonb(new) ->> 'id', '')::uuid, gen_random_uuid()), null, now(), '{}'::jsonb, 'trigger');
  return new;
exception when others then
  return new;
end $$;
revoke all on function public.activity_from_member() from public, anon, authenticated;

-- ===============================================================================================================
-- 4d) TRIGGER: organisations.domain_verified false -> true  => domain_verified
-- ===============================================================================================================
create or replace function public.activity_from_org()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_dom text;
begin
  if coalesce((to_jsonb(new) ->> 'domain_verified')::boolean, false)
     and not coalesce((to_jsonb(old) ->> 'domain_verified')::boolean, false) then
    v_dom := coalesce(nullif(to_jsonb(new) ->> 'domain', ''), 'your domain');
    perform public.activity_record(new.id, 'domain_verified', v_dom || ' verified', 'Domain', null, null,
      gen_random_uuid(), null, now(), '{}'::jsonb, 'trigger');
  end if;
  return new;
exception when others then
  return new;
end $$;
revoke all on function public.activity_from_org() from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- triggers sirf tab lagte hain jab table aur zaroori columns LIVE mein hon (nahi to chup chap chhod dete hain)
-- ---------------------------------------------------------------------------------------------------------------
create or replace function public.activity_has_cols(p_table text, p_cols text[])
returns boolean language sql stable set search_path = public as $$
  select to_regclass('public.' || p_table) is not null
     and (select count(*) from information_schema.columns
           where table_schema = 'public' and table_name = p_table and column_name = any (p_cols)) = cardinality(p_cols);
$$;

do $$
begin
  -- mail_messages (zaroori)
  if public.activity_has_cols('mail_messages', array['org_id','direction','subject','from_address','sent_at','id','thread_id','to_addresses','cc_addresses','from_name']) then
    execute 'drop trigger if exists mail_messages_activity on public.mail_messages';
    execute 'create trigger mail_messages_activity after insert on public.mail_messages for each row execute function public.activity_from_message()';
  else
    raise notice 'E101: mail_messages ke columns poore nahi — message trigger nahi laga';
  end if;

  -- mail_threads
  if public.activity_has_cols('mail_threads', array['org_id','assignee_id','state']) then
    execute 'drop trigger if exists mail_threads_activity on public.mail_threads';
    execute 'create trigger mail_threads_activity after update on public.mail_threads for each row '
            'when (old.assignee_id is distinct from new.assignee_id or old.state::text is distinct from new.state::text) '
            'execute function public.activity_from_thread()';
  else
    raise notice 'E101: mail_threads (org_id, assignee_id, state) nahi — thread trigger nahi laga';
  end if;

  -- org_members
  if public.activity_has_cols('org_members', array['org_id','user_id']) then
    execute 'drop trigger if exists org_members_activity on public.org_members';
    execute 'create trigger org_members_activity after insert on public.org_members for each row execute function public.activity_from_member()';
  else
    raise notice 'E101: org_members (org_id, user_id) nahi — member trigger nahi laga';
  end if;

  -- organisations
  if public.activity_has_cols('organisations', array['id','domain_verified']) then
    execute 'drop trigger if exists organisations_activity on public.organisations';
    execute 'create trigger organisations_activity after update on public.organisations for each row '
            'when (old.domain_verified is distinct from new.domain_verified) execute function public.activity_from_org()';
  else
    raise notice 'E101: organisations.domain_verified nahi — domain trigger nahi laga';
  end if;
end $$;

-- ===============================================================================================================
-- 5) activity_feed() — keyset pagination: ek SQL, member-gated (service_role Rust org ki pehchan ke saath bulata hai)
-- ===============================================================================================================
create or replace function public.activity_feed(
  p_org uuid, p_limit integer default 20, p_before timestamptz default null, p_kinds text[] default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_rows jsonb; v_more boolean; v_next timestamptz;
begin
  if p_org is null then return jsonb_build_object('ok', false, 'error', 'no_org'); end if;
  with page as (
    select a.id, a.kind, a.actor_label, a.subject, a.detail, a.created_at, a.thread_id
      from public.activity_log a
     where a.org_id = p_org
       and (p_before is null or a.created_at < p_before)
       and (p_kinds is null or a.kind = any (p_kinds))
     order by a.created_at desc, a.id desc
     limit v_lim + 1)
  select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc, p.id desc) filter (where p.rn <= v_lim), '[]'::jsonb),
         coalesce(bool_or(p.rn > v_lim), false),
         min(p.created_at) filter (where p.rn <= v_lim)
    into v_rows, v_more, v_next
    from (select pg.*, row_number() over (order by pg.created_at desc, pg.id desc) rn from page pg) p;
  return jsonb_build_object('ok', true, 'items', v_rows, 'has_more', v_more, 'next_before', v_next);
end $$;
revoke all on function public.activity_feed(uuid,integer,timestamptz,text[]) from public, anon, authenticated;
grant execute on function public.activity_feed(uuid,integer,timestamptz,text[]) to service_role;

-- ===============================================================================================================
-- 6) DAILY ROLLUP — kind x din (dashboard/analytics ko tez ginti)
-- ===============================================================================================================
create table if not exists public.activity_daily (
  org_id     uuid not null,
  day        date not null,
  kind       text not null,
  n          integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (org_id, day, kind)
);
alter table public.activity_daily enable row level security;
revoke all on public.activity_daily from public, anon, authenticated;
grant all on public.activity_daily to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='activity_daily' and policyname='activity_daily_service') then
    create policy activity_daily_service on public.activity_daily for all to service_role using (true) with check (true);
  end if;
end $$;

create or replace function public.activity_daily_refresh(p_days integer default 7)
returns integer language plpgsql security definer set search_path = public as $$
declare v_from date := (now() at time zone 'utc')::date - (least(greatest(coalesce(p_days, 7), 1), 400) - 1); v_n integer;
begin
  with agg as (
    select a.org_id, (a.created_at at time zone 'utc')::date as day, a.kind, count(*)::integer as n
      from public.activity_log a
     where a.created_at >= v_from::timestamptz
     group by 1, 2, 3)
  insert into public.activity_daily (org_id, day, kind, n, updated_at)
  select org_id, day, kind, n, now() from agg
  on conflict (org_id, day, kind) do update set n = excluded.n, updated_at = now()
    where public.activity_daily.n is distinct from excluded.n;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke all on function public.activity_daily_refresh(integer) from public, anon, authenticated;
grant execute on function public.activity_daily_refresh(integer) to service_role;

create or replace view public.v_activity_daily with (security_invoker = true) as
select org_id, day, kind, n from public.activity_daily;
revoke all on public.v_activity_daily from public, anon, authenticated;
grant select on public.v_activity_daily to service_role;

create or replace view public.v_activity_recent with (security_invoker = true) as
select org_id, id, kind, actor_label, subject, detail, created_at, thread_id, source
  from public.activity_log
 where created_at > now() - interval '7 days';
revoke all on public.v_activity_recent from public, anon, authenticated;
grant select on public.v_activity_recent to service_role;

-- ===============================================================================================================
-- 7) HEAL — purani / chhooti hui mail ki activity wapas (dobara chalana safe: source_id se exact dedupe)
-- ===============================================================================================================
create or replace function public.activity_heal(p_days integer default 30, p_org uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 30), 1), 400);
  v_added bigint := 0; v_try bigint := 0;
begin
  if not public.activity_has_cols('mail_messages', array['id','org_id','direction','subject','from_name','from_address','sent_at','thread_id','to_addresses','cc_addresses']) then
    return jsonb_build_object('ok', false, 'error', 'mail_messages_columns_missing');
  end if;
  with src as (
    select m.id, m.org_id, m.thread_id, m.subject, m.from_name, m.from_address, m.sent_at,
           case m.direction::text when 'in' then 'message_received' else 'message_sent' end as kind,
           coalesce(cardinality(m.to_addresses), 0) + coalesce(cardinality(m.cc_addresses), 0) as rc
      from public.mail_messages m
     where m.org_id is not null
       and m.direction::text in ('in','out')
       and m.sent_at > now() - make_interval(days => v_days)
       and (p_org is null or m.org_id = p_org)),
  ins as (
    insert into public.activity_log (org_id, actor_label, kind, subject, detail, created_at, source_id, thread_id, source, meta)
    select s.org_id, public.activity_actor_label(s.from_name, s.from_address), s.kind, public.activity_subject(s.subject),
           case s.kind when 'message_received' then 'Received' else 'Sent' end,
           s.sent_at, s.id, s.thread_id, 'heal', jsonb_build_object('recipients', s.rc)
      from src s
    on conflict (org_id, kind, source_id) where source_id is not null do nothing
    returning 1)
  select (select count(*) from src), (select count(*) from ins) into v_try, v_added;
  return jsonb_build_object('ok', true, 'scanned', v_try, 'added', v_added, 'days', v_days);
end $$;
revoke all on function public.activity_heal(integer, uuid) from public, anon, authenticated;
grant execute on function public.activity_heal(integer, uuid) to service_role;

-- ===============================================================================================================
-- 8) PRUNE — purani entries (activity timeline hai, audit nahi); default 180 din, kam se kam 30 din hamesha bachte hain
-- ===============================================================================================================
create or replace function public.activity_prune(p_keep_days integer default 180)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_keep integer := greatest(coalesce(p_keep_days, 180), 30); v_n bigint;
begin
  delete from public.activity_log where created_at < now() - make_interval(days => v_keep);
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke all on function public.activity_prune(integer) from public, anon, authenticated;
grant execute on function public.activity_prune(integer) to service_role;

-- ===============================================================================================================
-- 9) HEALTH — ek nazar mein: kitni mail ki activity gayab hai (0 honi chahiye), kaun se triggers laage
-- ===============================================================================================================
create or replace function public.activity_health(p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 7), 1), 400);
  v_missing bigint := 0; v_total bigint := 0; v_logged bigint := 0; v_trg jsonb;
begin
  if public.activity_has_cols('mail_messages', array['id','org_id','direction','sent_at']) then
    select count(*) into v_total
      from public.mail_messages m
     where m.org_id is not null and m.direction::text in ('in','out') and m.sent_at > now() - make_interval(days => v_days);
    select count(*) into v_missing
      from public.mail_messages m
     where m.org_id is not null and m.direction::text in ('in','out') and m.sent_at > now() - make_interval(days => v_days)
       and not exists (select 1 from public.activity_log a
                        where a.org_id = m.org_id and a.source_id = m.id
                          and a.kind = case m.direction::text when 'in' then 'message_received' else 'message_sent' end);
  end if;
  select count(*) into v_logged from public.activity_log where created_at > now() - make_interval(days => v_days);
  select coalesce(jsonb_object_agg(tgname, true), '{}'::jsonb) into v_trg
    from pg_trigger
   where not tgisinternal and tgname in ('mail_messages_activity','mail_threads_activity','org_members_activity','organisations_activity');
  return jsonb_build_object('ok', v_missing = 0, 'days', v_days, 'messages', v_total, 'logged_events', v_logged,
                            'messages_without_activity', v_missing, 'triggers', v_trg);
end $$;
revoke all on function public.activity_health(integer) from public, anon, authenticated;
grant execute on function public.activity_health(integer) to service_role;

-- ===============================================================================================================
-- 10) BACKFILL (pehli baar): pichle 30 din — exact dedupe, dobara chalana safe
-- ===============================================================================================================
do $$
declare r jsonb;
begin
  r := public.activity_heal(30, null);
  raise notice 'E101 backfill: %', r::text;
  perform public.activity_daily_refresh(30);
end $$;


-- ===============================================================================================================
-- 10b) SUMMARY — ek org ka khulasa: kind ke hisaab se ginti, din-ba-din, sab se zyada active log (naam/label, email nahi)
-- ===============================================================================================================
create or replace function public.activity_summary(p_org uuid, p_days integer default 14)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 14), 1), 90);
  v_from timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc' - make_interval(days => v_days - 1);
  v_kinds jsonb; v_series jsonb; v_actors jsonb; v_total bigint;
begin
  if p_org is null then return jsonb_build_object('ok', false, 'error', 'no_org'); end if;
  select coalesce(jsonb_object_agg(kind, n), '{}'::jsonb), coalesce(sum(n), 0)
    into v_kinds, v_total
    from (select kind, count(*) n from public.activity_log where org_id = p_org and created_at >= v_from group by kind) k;
  select coalesce(jsonb_agg(jsonb_build_object('day', d::date, 'n', coalesce(c.n, 0)) order by d), '[]'::jsonb)
    into v_series
    from generate_series((v_from at time zone 'utc')::date, (now() at time zone 'utc')::date, interval '1 day') d
    left join (select (created_at at time zone 'utc')::date as day, count(*) n
                 from public.activity_log where org_id = p_org and created_at >= v_from group by 1) c on c.day = d::date;
  select coalesce(jsonb_agg(jsonb_build_object('actor', actor_label, 'n', n) order by n desc), '[]'::jsonb)
    into v_actors
    from (select actor_label, count(*) n from public.activity_log
           where org_id = p_org and created_at >= v_from and actor_label is not null
           group by actor_label order by n desc limit 5) a;
  return jsonb_build_object('ok', true, 'days', v_days, 'total', v_total, 'by_kind', v_kinds, 'series', v_series, 'top_actors', v_actors);
end $$;
revoke all on function public.activity_summary(uuid, integer) from public, anon, authenticated;
grant execute on function public.activity_summary(uuid, integer) to service_role;

-- ===============================================================================================================
-- 10c) ANOMALY — aaj ki ginti pichle 14 din ke average se kitni upar (z-score). Spike = shayad spam / loop / hamla.
--      Kam data (< 5 din) par kuch nahi kehta (jhoota alarm nahi); har kind alag.
-- ===============================================================================================================
create or replace function public.activity_anomalies(p_org uuid, p_min_n integer default 20, p_z numeric default 3)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_out jsonb;
begin
  if p_org is null then return jsonb_build_object('ok', false, 'error', 'no_org'); end if;
  with days as (
    select (created_at at time zone 'utc')::date as day, kind, count(*)::numeric n
      from public.activity_log
     where org_id = p_org and created_at >= (now() at time zone 'utc')::date - 14
     group by 1, 2),
  base as (
    select kind, avg(n) mean, coalesce(stddev_samp(n), 0) sd, count(*) days_seen
      from days where day < (now() at time zone 'utc')::date group by kind),
  today as (
    select kind, n from days where day = (now() at time zone 'utc')::date)
  select coalesce(jsonb_agg(jsonb_build_object('kind', t.kind, 'today', t.n, 'avg', round(b.mean, 1),
                  'z', round((t.n - b.mean) / greatest(b.sd, 1), 1)) order by (t.n - b.mean) desc), '[]'::jsonb)
    into v_out
    from today t join base b using (kind)
   where b.days_seen >= 5 and t.n >= greatest(p_min_n, 1)
     and (t.n - b.mean) / greatest(b.sd, 1) >= coalesce(p_z, 3);
  return jsonb_build_object('ok', true, 'spikes', v_out);
end $$;
revoke all on function public.activity_anomalies(uuid, integer, numeric) from public, anon, authenticated;
grant execute on function public.activity_anomalies(uuid, integer, numeric) to service_role;

-- ===============================================================================================================
-- 10d) SEARCH — subject / actor mein dhoondna (ILIKE, % aur _ ko escape kar ke, limit 50)
-- ===============================================================================================================
create or replace function public.activity_search(p_org uuid, p_q text, p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_q text := btrim(public.activity_clean(p_q, 80)); v_pat text; v_rows jsonb;
begin
  if p_org is null or char_length(v_q) < 2 then return jsonb_build_object('ok', true, 'items', '[]'::jsonb); end if;
  v_pat := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) into v_rows
    from (select id, kind, actor_label, subject, detail, created_at, thread_id
            from public.activity_log
           where org_id = p_org and (subject ilike v_pat escape '\' or actor_label ilike v_pat escape '\')
           order by created_at desc limit least(greatest(coalesce(p_limit, 20), 1), 50)) x;
  return jsonb_build_object('ok', true, 'items', v_rows);
end $$;
revoke all on function public.activity_search(uuid, text, integer) from public, anon, authenticated;
grant execute on function public.activity_search(uuid, text, integer) to service_role;

-- ===============================================================================================================
-- 11) SELFTEST — asli org par (FK ka sabaq), subtransaction mein, AAKHIR MEIN poora rollback
-- ===============================================================================================================
create or replace function public.activity_selftest()
returns text language plpgsql security definer set search_path = public as $$
declare
  v_org uuid; v_src uuid := gen_random_uuid(); v_id1 uuid; v_id2 uuid; v_feed jsonb; v_before bigint; v_after bigint; r text := '';
begin
  if to_regclass('public.organisations') is not null then
    execute 'select id from public.organisations limit 1' into v_org;
  end if;
  if v_org is null then
    -- organisations khali / nahi: sirf pure helpers jaanchte hain
    if public.activity_subject('  ') <> '(no subject)' then raise exception 'subject default galat'; end if;
    if length(public.activity_clean(repeat('x', 500), 200)) <> 200 then raise exception 'clean clamp galat'; end if;
    return 'E101 selftest OK (sirf helpers — koi org nahi)';
  end if;

  select count(*) into v_before from public.activity_log where org_id = v_org;
  begin
    -- (a) record + dedupe: wahi source do baar => ek hi row
    v_id1 := public.activity_record(v_org, 'message_received', 'Hello ' || chr(8238) || 'there', 'Received', null, 'Tester', v_src, null, now(), '{"recipients":2}'::jsonb, 'manual');
    v_id2 := public.activity_record(v_org, 'message_received', 'Hello again', 'Received', null, 'Tester', v_src, null, now(), '{}'::jsonb, 'manual');
    if v_id1 is null then raise exception 'pehli record nahi hui'; end if;
    if v_id2 is not null then raise exception 'dedupe toota: wahi source do baar'; end if;
    r := r || 'dedupe OK; ';

    -- (b) bidi/control akshar saaf
    if exists (select 1 from public.activity_log where id = v_id1 and subject ~ '[\u202A-\u202E]') then raise exception 'bidi akshar nahi hate'; end if;
    r := r || 'clean OK; ';

    -- (c) ghalat kind / null org => null, exception nahi
    if public.activity_record(v_org, 'not_a_kind', 'x') is not null then raise exception 'ghalat kind chal gaya'; end if;
    if public.activity_record(null, 'login', 'x') is not null then raise exception 'null org chal gaya'; end if;
    r := r || 'guards OK; ';

    -- (d) lambi subject 200 par kat'ti hai
    perform public.activity_record(v_org, 'admin_change', repeat('long ', 100), 'x', null, null, gen_random_uuid());
    if exists (select 1 from public.activity_log where org_id = v_org and kind = 'admin_change' and char_length(subject) > 200) then
      raise exception 'subject 200 se lamba';
    end if;
    r := r || 'clamp OK; ';

    -- (e) feed: keyset (limit 1 => has_more + next_before)
    perform public.activity_record(v_org, 'login', 'second', 'x', null, null, gen_random_uuid(), null, now() + interval '1 second');
    v_feed := public.activity_feed(v_org, 1, null, null);
    if not coalesce((v_feed ->> 'ok')::boolean, false) or jsonb_array_length(v_feed -> 'items') <> 1 then raise exception 'feed items galat: %', v_feed::text; end if;
    if not coalesce((v_feed ->> 'has_more')::boolean, false) then raise exception 'has_more false hona nahi chahiye'; end if;
    v_feed := public.activity_feed(v_org, 50, null, array['login']);
    if exists (select 1 from jsonb_array_elements(v_feed -> 'items') e where e ->> 'kind' <> 'login') then raise exception 'kinds filter toota'; end if;
    r := r || 'feed OK; ';

    -- (e2) summary / anomalies / search jawab dete hain, search wildcard escape karta hai
    if not coalesce((public.activity_summary(v_org, 7) ->> 'ok')::boolean, false) then raise exception 'summary toota'; end if;
    if not coalesce((public.activity_anomalies(v_org) ->> 'ok')::boolean, false) then raise exception 'anomalies toota'; end if;
    perform public.activity_record(v_org, 'login', '100% match_test', 'x', null, null, gen_random_uuid());
    if jsonb_array_length(public.activity_search(v_org, '100%', 10) -> 'items') < 1 then raise exception 'search literal percent nahi mila'; end if;
    -- sirf '%%' (do wildcard) literal dhoondta hai, sab kuch nahi lautata
    if jsonb_array_length(public.activity_search(v_org, '%%', 10) -> 'items') > 0 then raise exception 'search wildcard escape toota'; end if;
    r := r || 'summary+anomaly+search OK; ';

    -- (f) health jawab deta hai
    if (public.activity_health(1) -> 'ok') is null then raise exception 'health jawab nahi'; end if;
    r := r || 'health OK; ';

    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E101 selftest FAIL: %', sqlerrm; end if;
  end;
  select count(*) into v_after from public.activity_log where org_id = v_org;
  if v_after <> v_before then raise exception 'E101 selftest ne saaf nahi kiya (% -> %)', v_before, v_after; end if;
  return 'E101 selftest OK — ' || r || 'rollback saaf';
end $$;
revoke all on function public.activity_selftest() from public, anon, authenticated;
grant execute on function public.activity_selftest() to service_role;

do $$ begin
  raise notice '%', public.activity_selftest();
end $$;
