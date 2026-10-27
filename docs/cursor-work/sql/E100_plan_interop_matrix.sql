
-- E100 — PLAN x PLAN INTEROP ENGINE (super advanced): poori website ke log ek dusre se contact kar sakte hain.
-- ---------------------------------------------------------------------------------------------------------------
-- RULE (founder, 27 Oct 2026): contact par koi plan-gate NAHI. Basic <-> Pro <-> Business <-> Business Pro <-> Enterprise <-> Personal,
-- har taraf, har action (mail, invite, booking, share_thread, chat). Gate sirf BHEJNE WALE ke APNE package ki limit par:
--   mail -> attachment MB, invite -> mailboxes nahi (sirf contact), booking -> public booking links, share_thread -> users cap, chat -> ANEXOChat badi-file GB (apne package ki).
-- Recipient ka plan KABHI bahar nahi jata (privacy): decide() sirf allowed/gate/reason lautata hai.
-- ---------------------------------------------------------------------------------------------------------------
-- Banata hai (sab idempotent, RLS on, anon/authenticated band, service_role only, search_path pinned):
--   1) plan_catalog        6 plan, rank + limits jsonb (sirf woh numbers jo public plans page par likhe hain; baqi key = "is registry mein cap nahi")
--   2) plan_interop        6 x 6 x 5 = 180 cell (allowed + gate) — contact matrix
--   3) plan_interop_gate_map  action -> limit_key + feature label (kaun si limit lagti hai)
--   4) plan_interop_keys   per-table HMAC key (32 random bytes) — kabhi bahar nahi
--   5) plan_interop_log    APPEND-ONLY, hash chain + HMAC-SHA256 seal (UPDATE/DELETE/TRUNCATE trigger se band)
--   6) functions: plan_rank, plan_limit, plan_interop_usage_check, plan_interop_allowed, plan_interop_decide,
--      plan_interop_decide_user, plan_interop_log_verify, plan_interop_audit, plan_interop_selftest
--   7) views: v_plan_interop_matrix, v_plan_limits_ladder, v_plan_interop_decisions_daily
-- Server (Rust) is function ko service_role se bulata hai; browser seedha nahi. Polar :3400 NO-TOUCH.
-- Dobara chalana safe.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = public, extensions;

-- ===============================================================================================================
-- 1) PLAN CATALOG
-- ===============================================================================================================
create table if not exists public.plan_catalog (
  plan        text primary key,
  rank        smallint not null,
  label       text not null,
  limits      jsonb not null default '{}'::jsonb,
  source      text not null default 'plans.ts (public plans page, v6)',
  updated_at  timestamptz not null default now()
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'plan_catalog_chk') then
    alter table public.plan_catalog add constraint plan_catalog_chk check (
      plan in ('personal','basic','pro','business','business_pro','enterprise')
      and rank between 0 and 10
      and jsonb_typeof(limits) = 'object') not valid;
    alter table public.plan_catalog validate constraint plan_catalog_chk;
  end if;
end $$;

-- Sirf public numbers (plans page): Basic 5 users/15GB/3 mailboxes/25MB/1 domain/1 booking link/2 devices;
-- Pro 20/300GB/10/35MB/3/3/4; Business 60 users/1.5TB/45MB; Business Pro 570 users/10TB/60MB.
-- chat_file_gb = ANEXOChat mein badi file (7GB/4K video tak): Basic/Pro 0 (ANEXOChat nahi), Business 2, Business Pro 5, Enterprise 7 (founder ka locked faisla); Enterprise attach_mb 100 (pricing docs).
-- Jo number repo/page par nahi likha (Business ke mailboxes/domains/links/devices, Enterprise users/storage, Personal) — key hi nahi: cap nahi = is registry se rokta nahi.
insert into public.plan_catalog (plan, rank, label, limits) values
  ('personal',     0, 'Personal',     '{}'::jsonb),
  ('basic',        1, 'Basic',        '{"users":5,"storage_gb":15,"mailboxes":3,"attach_mb":25,"domains":1,"booking_links":1,"devices":2,"chat_file_gb":0}'::jsonb),
  ('pro',          2, 'Pro',          '{"users":20,"storage_gb":300,"mailboxes":10,"attach_mb":35,"domains":3,"booking_links":3,"devices":4,"chat_file_gb":0}'::jsonb),
  ('business',     3, 'Business',     '{"users":60,"storage_gb":1500,"attach_mb":45,"chat_file_gb":2}'::jsonb),
  ('business_pro', 4, 'Business Pro', '{"users":570,"storage_gb":10000,"attach_mb":60,"chat_file_gb":5}'::jsonb),
  ('enterprise',   5, 'Enterprise',   '{"attach_mb":100,"chat_file_gb":7}'::jsonb)
on conflict (plan) do update
  set rank = excluded.rank, label = excluded.label, limits = excluded.limits, updated_at = now()
  where (public.plan_catalog.rank, public.plan_catalog.label, public.plan_catalog.limits)
        is distinct from (excluded.rank, excluded.label, excluded.limits);

alter table public.plan_catalog enable row level security;
revoke all on public.plan_catalog from public, anon, authenticated;
grant all on public.plan_catalog to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plan_catalog' and policyname='plan_catalog_service') then
    create policy plan_catalog_service on public.plan_catalog for all to service_role using (true) with check (true);
  end if;
end $$;

-- ===============================================================================================================
-- 2) CONTACT MATRIX (6 x 6 x 5)
-- ===============================================================================================================
create table if not exists public.plan_interop (
  from_plan  text not null,
  to_plan    text not null,
  action     text not null,
  allowed    boolean not null default true,
  gate       text not null default 'own_plan_feature',
  note       text,
  updated_at timestamptz not null default now(),
  primary key (from_plan, to_plan, action)
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'plan_interop_chk') then
    alter table public.plan_interop add constraint plan_interop_chk check (
      from_plan in ('basic','pro','business','business_pro','enterprise','personal')
      and to_plan in ('basic','pro','business','business_pro','enterprise','personal')
      and action in ('mail','invite','booking','share_thread','chat')
      and gate in ('none','own_plan_feature')) not valid;
    alter table public.plan_interop validate constraint plan_interop_chk;
  end if;
end $$;

alter table public.plan_interop enable row level security;
revoke all on public.plan_interop from public, anon, authenticated;
grant all on public.plan_interop to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plan_interop' and policyname='plan_interop_service') then
    create policy plan_interop_service on public.plan_interop for all to service_role using (true) with check (true);
  end if;
end $$;

insert into public.plan_interop (from_plan, to_plan, action, allowed, gate, note)
select f, t, a, true,
       'own_plan_feature',
       'contact har plan ke beech khula; limit sirf bhejne wale ke apne plan ki'
from unnest(array['basic','pro','business','business_pro','enterprise','personal']) f
cross join unnest(array['basic','pro','business','business_pro','enterprise','personal']) t
cross join unnest(array['mail','invite','booking','share_thread','chat']) a
on conflict (from_plan, to_plan, action) do nothing;

-- purani run ke cell seedhe karo: mail = apni attachment limit, chat = apni ANEXOChat badi-file limit (contact dono mein phir bhi khula)
update public.plan_interop set gate = 'own_plan_feature', allowed = true, updated_at = now()
 where allowed is distinct from true or gate is distinct from 'own_plan_feature';

-- ===============================================================================================================
-- 3) ACTION -> LIMIT MAP (kaun si apni-plan limit kis action par lagti hai)
-- ===============================================================================================================
create table if not exists public.plan_interop_gate_map (
  action     text primary key,
  limit_key  text,
  feature    text not null,
  note       text
);

do $$ begin
  if exists (select 1 from pg_constraint where conname = 'plan_interop_gate_map_chk') and not exists (select 1 from pg_constraint where conname = 'plan_interop_gate_map_chk' and pg_get_constraintdef(oid) like '%chat_file_gb%') then
    alter table public.plan_interop_gate_map drop constraint plan_interop_gate_map_chk;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'plan_interop_gate_map_chk') then
    alter table public.plan_interop_gate_map add constraint plan_interop_gate_map_chk check (
      action in ('mail','invite','booking','share_thread','chat')
      and (limit_key is null or limit_key in ('users','storage_gb','mailboxes','attach_mb','domains','booking_links','devices','chat_file_gb'))) not valid;
    alter table public.plan_interop_gate_map validate constraint plan_interop_gate_map_chk;
  end if;
end $$;

insert into public.plan_interop_gate_map (action, limit_key, feature, note) values
  ('mail',         'attach_mb',     'Email attachments',        'mail contact khula; sirf attachment ka size bhejne wale ke plan ki limit se'),
  ('invite',       null,            'Meeting invite',           'invite par koi cap nahi; calendar feature ka gate resolve_plan se'),
  ('booking',      'booking_links', 'Public booking links',     'Basic 1, Pro 3 — bhejne wale ki apni limit'),
  ('share_thread', 'users',         'Thread sharing (seats)',   'share karne par apni org ke users ki cap'),
  ('chat',         'chat_file_gb',  'ANEXOChat big file (GB)',  'chat contact khula; badi file ki limit bhejne wale ke apne ANEXOChat package ki (Business 2 / Business Pro 5 / Enterprise 7 GB)')
on conflict (action) do update set limit_key = excluded.limit_key, feature = excluded.feature, note = excluded.note
  where (public.plan_interop_gate_map.limit_key, public.plan_interop_gate_map.feature, public.plan_interop_gate_map.note)
        is distinct from (excluded.limit_key, excluded.feature, excluded.note);

alter table public.plan_interop_gate_map enable row level security;
revoke all on public.plan_interop_gate_map from public, anon, authenticated;
grant all on public.plan_interop_gate_map to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plan_interop_gate_map' and policyname='plan_interop_gate_map_service') then
    create policy plan_interop_gate_map_service on public.plan_interop_gate_map for all to service_role using (true) with check (true);
  end if;
end $$;

-- ===============================================================================================================
-- 4) HMAC KEY (har table ka apna; bahar kabhi nahi jata) + 5) APPEND-ONLY LOG
-- ===============================================================================================================
create table if not exists public.plan_interop_keys (
  id         smallint primary key default 1,
  key        bytea not null,
  created_at timestamptz not null default now(),
  constraint plan_interop_keys_one check (id = 1),
  constraint plan_interop_keys_len check (octet_length(key) = 32)
);
alter table public.plan_interop_keys enable row level security;
revoke all on public.plan_interop_keys from public, anon, authenticated;
grant all on public.plan_interop_keys to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plan_interop_keys' and policyname='plan_interop_keys_service') then
    create policy plan_interop_keys_service on public.plan_interop_keys for all to service_role using (true) with check (true);
  end if;
end $$;

insert into public.plan_interop_keys (id, key)
select 1, extensions.gen_random_bytes(32)
where not exists (select 1 from public.plan_interop_keys where id = 1);

create table if not exists public.plan_interop_log (
  seq          bigint generated always as identity primary key,
  org_id       uuid,
  from_plan    text not null,
  to_plan      text not null,
  action       text not null,
  allowed      boolean not null,
  gate_key     text,
  gate_cap     integer,
  gate_used    integer,
  reason       text not null,
  prev_hash    text not null,
  row_hash     text not null,
  seal         text not null,
  created_at   timestamptz not null default now()
);
create index if not exists plan_interop_log_org_idx on public.plan_interop_log (org_id, created_at desc);
create index if not exists plan_interop_log_day_idx on public.plan_interop_log (created_at desc);

alter table public.plan_interop_log enable row level security;
revoke all on public.plan_interop_log from public, anon, authenticated;
grant all on public.plan_interop_log to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plan_interop_log' and policyname='plan_interop_log_service') then
    create policy plan_interop_log_service on public.plan_interop_log for all to service_role using (true) with check (true);
  end if;
end $$;

-- append-only: koi UPDATE / DELETE / TRUNCATE nahi
create or replace function public.plan_interop_log_guard()
returns trigger language plpgsql set search_path = public as $$
begin
  raise exception 'plan_interop_log append-only hai: % allowed nahi', tg_op using errcode = '42501';
end $$;
revoke all on function public.plan_interop_log_guard() from public, anon, authenticated;

drop trigger if exists plan_interop_log_noupd on public.plan_interop_log;
create trigger plan_interop_log_noupd before update or delete on public.plan_interop_log
  for each row execute function public.plan_interop_log_guard();
drop trigger if exists plan_interop_log_notrunc on public.plan_interop_log;
create trigger plan_interop_log_notrunc before truncate on public.plan_interop_log
  for each statement execute function public.plan_interop_log_guard();

-- ===============================================================================================================
-- 6a) CHHOTE HELPERS
-- ===============================================================================================================
create or replace function public.plan_norm(p_plan text)
returns text language sql immutable set search_path = public as $$
  select case lower(trim(coalesce(p_plan, '')))
           when 'business pro' then 'business_pro'
           when 'business-pro' then 'business_pro'
           when 'businesspro'  then 'business_pro'
           when ''             then 'basic'
           else lower(trim(p_plan)) end;
$$;

create or replace function public.plan_rank(p_plan text)
returns integer language sql stable set search_path = public as $$
  select coalesce((select rank::integer from public.plan_catalog where plan = public.plan_norm(p_plan)), -1);
$$;

-- NULL = is registry mein cap nahi
create or replace function public.plan_limit(p_plan text, p_key text)
returns integer language sql stable set search_path = public as $$
  select (limits ->> p_key)::integer from public.plan_catalog where plan = public.plan_norm(p_plan);
$$;

create or replace function public.plan_interop_usage_check(p_plan text, p_key text, p_used integer)
returns jsonb language plpgsql stable set search_path = public as $$
declare v_cap integer; v_used integer := greatest(coalesce(p_used, 0), 0);
begin
  if p_key is null then
    return jsonb_build_object('ok', true, 'key', null, 'cap', null, 'used', v_used, 'remaining', null, 'why', 'no_cap_for_action');
  end if;
  v_cap := public.plan_limit(p_plan, p_key);
  if v_cap is null then
    return jsonb_build_object('ok', true, 'key', p_key, 'cap', null, 'used', v_used, 'remaining', null, 'why', 'no_cap_in_registry');
  end if;
  return jsonb_build_object('ok', v_used <= v_cap, 'key', p_key, 'cap', v_cap, 'used', v_used,
                            'remaining', greatest(v_cap - v_used, 0),
                            'why', case when v_used <= v_cap then 'within_own_plan_limit' else 'own_plan_limit_exceeded' end);
end $$;

create or replace function public.plan_interop_allowed(p_from text, p_to text, p_action text)
returns boolean language sql stable set search_path = public as $$
  select coalesce((select allowed from public.plan_interop
                    where from_plan = public.plan_norm(p_from) and to_plan = public.plan_norm(p_to) and action = lower(p_action)), false);
$$;

-- ===============================================================================================================
-- 6b) LOG WRITER (hash chain + HMAC-SHA256 seal) — serialised, taake chain tootay nahi
-- ===============================================================================================================
create or replace function public.plan_interop_log_write(
  p_org uuid, p_from text, p_to text, p_action text, p_allowed boolean,
  p_key text, p_cap integer, p_used integer, p_reason text)
returns bigint language plpgsql security definer set search_path = public, extensions as $$
declare
  v_prev text; v_hash text; v_seal text; v_key bytea; v_seq bigint; v_body text;
begin
  perform pg_advisory_xact_lock(hashtextextended('plan_interop_log', 0));
  select row_hash into v_prev from public.plan_interop_log order by seq desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  select key into v_key from public.plan_interop_keys where id = 1;
  if v_key is null then raise exception 'plan_interop_keys khali'; end if;
  v_seq := nextval(pg_get_serial_sequence('public.plan_interop_log', 'seq'));
  v_body := concat_ws('|', v_seq, coalesce(p_org::text, '-'), p_from, p_to, p_action, p_allowed::text,
                      coalesce(p_key, '-'), coalesce(p_cap::text, '-'), coalesce(p_used::text, '-'), p_reason, v_prev);
  v_hash := encode(extensions.digest(v_body, 'sha256'), 'hex');
  v_seal := encode(extensions.hmac(convert_to(v_hash, 'UTF8'), v_key, 'sha256'), 'hex');
  insert into public.plan_interop_log
    (seq, org_id, from_plan, to_plan, action, allowed, gate_key, gate_cap, gate_used, reason, prev_hash, row_hash, seal)
  overriding system value
  values (v_seq, p_org, p_from, p_to, p_action, p_allowed, p_key, p_cap, p_used, p_reason, v_prev, v_hash, v_seal);
  return v_seq;
end $$;
revoke all on function public.plan_interop_log_write(uuid,text,text,text,boolean,text,integer,integer,text) from public, anon, authenticated;
grant execute on function public.plan_interop_log_write(uuid,text,text,text,boolean,text,integer,integer,text) to service_role;

-- ===============================================================================================================
-- 6c) DECIDE — asli faisla. Recipient ka plan sirf andar; bahar sirf allowed/gate/reason.
-- ===============================================================================================================
create or replace function public.plan_interop_decide(
  p_org uuid, p_from_plan text, p_to_plan text, p_action text,
  p_usage jsonb default '{}'::jsonb, p_log boolean default true)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_from text := public.plan_norm(p_from_plan);
  v_to   text := public.plan_norm(p_to_plan);
  v_act  text := lower(trim(coalesce(p_action, '')));
  v_cell public.plan_interop;
  v_map  public.plan_interop_gate_map;
  v_use  integer;
  v_chk  jsonb;
  v_ok   boolean;
  v_why  text;
  v_seq  bigint := null;
begin
  if v_act not in ('mail','invite','booking','share_thread','chat') then
    return jsonb_build_object('ok', false, 'allowed', false, 'error', 'unknown_action');
  end if;
  if public.plan_rank(v_from) < 0 then
    return jsonb_build_object('ok', false, 'allowed', false, 'error', 'unknown_from_plan');
  end if;
  -- recipient plan na mile (bahar ka email) => contact phir bhi khula: 'external'
  select * into v_cell from public.plan_interop where from_plan = v_from and to_plan = v_to and action = v_act;
  if not found then
    select * into v_cell from public.plan_interop where from_plan = v_from and to_plan = 'basic' and action = v_act;
  end if;
  select * into v_map from public.plan_interop_gate_map where action = v_act;

  v_use := case when jsonb_typeof(p_usage -> coalesce(v_map.limit_key, '_')) = 'number'
                then least((p_usage ->> v_map.limit_key)::numeric, 2147483647)::integer else 0 end;

  if coalesce(v_cell.gate, 'none') = 'own_plan_feature' and v_map.limit_key is not null then
    v_chk := public.plan_interop_usage_check(v_from, v_map.limit_key, v_use);
  else
    v_chk := public.plan_interop_usage_check(v_from, null, v_use);
  end if;

  v_ok  := coalesce(v_cell.allowed, true) and coalesce((v_chk ->> 'ok')::boolean, true);
  v_why := case
             when not coalesce(v_cell.allowed, true) then 'contact_blocked_by_matrix'
             when not coalesce((v_chk ->> 'ok')::boolean, true) then 'own_plan_limit_exceeded'
             else 'ok' end;

  if p_log then
    v_seq := public.plan_interop_log_write(p_org, v_from, v_to, v_act, v_ok,
               v_chk ->> 'key', (v_chk ->> 'cap')::integer, (v_chk ->> 'used')::integer, v_why);
  end if;

  return jsonb_build_object(
    'ok', true,
    'allowed', v_ok,
    'contact', coalesce(v_cell.allowed, true),
    'reason', v_why,
    'gate', jsonb_build_object(
        'feature', v_map.feature,
        'key', v_chk -> 'key',
        'cap', v_chk -> 'cap',
        'used', v_chk -> 'used',
        'remaining', v_chk -> 'remaining',
        'why', v_chk -> 'why'),
    'decision', v_seq);
end $$;
revoke all on function public.plan_interop_decide(uuid,text,text,text,jsonb,boolean) from public, anon, authenticated;
grant execute on function public.plan_interop_decide(uuid,text,text,text,jsonb,boolean) to service_role;

-- user + recipient email se: plan resolve_plan() se (agar maujood). Na mile to basic (kabhi zyada nahi kholta); recipient na mile to 'basic' cell.
create or replace function public.plan_interop_decide_user(
  p_user uuid, p_email text, p_org uuid, p_recipient_email text, p_action text,
  p_usage jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_from text := 'basic';
  v_to   text := 'basic';
  v_tmp  text;
begin
  if to_regprocedure('public.resolve_plan(uuid,text)') is not null then
    begin
      execute 'select public.resolve_plan($1,$2)::text' into v_tmp using p_user, p_email;
      v_from := public.plan_norm(trim(both '"' from coalesce(v_tmp, 'basic')));
    exception when others then v_from := 'basic';
    end;
    begin
      execute 'select public.resolve_plan(null::uuid,$1)::text' into v_tmp using lower(trim(coalesce(p_recipient_email, '')));
      v_to := public.plan_norm(trim(both '"' from coalesce(v_tmp, 'basic')));
    exception when others then v_to := 'basic';
    end;
  end if;
  if public.plan_rank(v_from) < 0 then v_from := 'basic'; end if;
  if public.plan_rank(v_to) < 0 then v_to := 'basic'; end if;
  return public.plan_interop_decide(p_org, v_from, v_to, p_action, p_usage, true);
end $$;
revoke all on function public.plan_interop_decide_user(uuid,text,uuid,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.plan_interop_decide_user(uuid,text,uuid,text,text,jsonb) to service_role;

-- ===============================================================================================================
-- 6d) CHAIN VERIFY — poori chain dobara hash + HMAC se
-- ===============================================================================================================
create or replace function public.plan_interop_log_verify()
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
declare
  r record; v_prev text := repeat('0', 64); v_key bytea; v_body text; v_hash text; v_seal text;
  v_n bigint := 0; v_bad bigint := null; v_what text := null;
begin
  select key into v_key from public.plan_interop_keys where id = 1;
  if v_key is null then return jsonb_build_object('ok', false, 'error', 'key_missing'); end if;
  for r in select * from public.plan_interop_log order by seq loop
    v_n := v_n + 1;
    v_body := concat_ws('|', r.seq, coalesce(r.org_id::text, '-'), r.from_plan, r.to_plan, r.action, r.allowed::text,
                        coalesce(r.gate_key, '-'), coalesce(r.gate_cap::text, '-'), coalesce(r.gate_used::text, '-'), r.reason, v_prev);
    v_hash := encode(extensions.digest(v_body, 'sha256'), 'hex');
    v_seal := encode(extensions.hmac(convert_to(v_hash, 'UTF8'), v_key, 'sha256'), 'hex');
    if r.prev_hash <> v_prev then v_bad := r.seq; v_what := 'prev_hash'; exit; end if;
    if r.row_hash <> v_hash then v_bad := r.seq; v_what := 'row_hash'; exit; end if;
    if r.seal <> v_seal then v_bad := r.seq; v_what := 'seal'; exit; end if;
    v_prev := r.row_hash;
  end loop;
  return jsonb_build_object('ok', v_bad is null, 'rows', v_n, 'first_bad_seq', v_bad, 'what', v_what);
end $$;
revoke all on function public.plan_interop_log_verify() from public, anon, authenticated;
grant execute on function public.plan_interop_log_verify() to service_role;

-- ===============================================================================================================
-- 6e) AUDIT — sirf jo rule toota
-- ===============================================================================================================
create or replace function public.plan_interop_audit()
returns table (from_plan text, to_plan text, action text, problem text)
language sql stable set search_path = public as $$
  -- 1) contact band
  select i.from_plan, i.to_plan, i.action, 'blocked: plan-to-plan contact band nahi hona chahiye'
    from public.plan_interop i where not i.allowed
  union all
  -- 2) mail aur chat: gate sirf bhejne wale ki apni limit (own_plan_feature); 'none' ya kuch aur nahi
  select i.from_plan, i.to_plan, i.action, 'mail/chat par gate sirf own_plan_feature hona chahiye'
    from public.plan_interop i where i.action in ('mail','chat') and i.gate <> 'own_plan_feature'
  union all
  -- 3) koi cell gayab (6x6x5)
  select f.p, t.p, a.p, 'cell gayab'
    from (select plan as p from public.plan_catalog) f
    cross join (select plan as p from public.plan_catalog) t
    cross join unnest(array['mail','invite','booking','share_thread','chat']) a(p)
   where not exists (select 1 from public.plan_interop i where i.from_plan = f.p and i.to_plan = t.p and i.action = a.p)
  union all
  -- 4) limit seedhi (ladder): upar ka plan kisi bhi key par neeche ke plan se kam nahi
  select lo.plan, hi.plan, k.key, 'ladder toota: upar ke plan ki limit kam hai'
    from public.plan_catalog lo
    join public.plan_catalog hi on hi.rank > lo.rank
    cross join (values ('users'),('storage_gb'),('mailboxes'),('attach_mb'),('domains'),('booking_links'),('devices'),('chat_file_gb')) k(key)
   where (lo.limits ->> k.key) is not null and (hi.limits ->> k.key) is not null
     and (hi.limits ->> k.key)::integer < (lo.limits ->> k.key)::integer
  union all
  -- 5) gate_map ka limit_key kisi plan mein hai hi nahi (typo pakadta hai)
  select 'n/a', 'n/a', g.action, 'gate_map ka limit_key kisi bhi plan mein nahi: ' || g.limit_key
    from public.plan_interop_gate_map g
   where g.limit_key is not null
     and not exists (select 1 from public.plan_catalog c where c.limits ? g.limit_key)
  union all
  -- 6) log chain toota
  select 'n/a', 'n/a', 'log', 'log chain toota: ' || coalesce(v ->> 'what', '?') || ' seq=' || coalesce(v ->> 'first_bad_seq', '?')
    from (select public.plan_interop_log_verify() as v) x
   where not coalesce((v ->> 'ok')::boolean, false);
$$;
revoke all on function public.plan_interop_audit() from public, anon, authenticated;
grant execute on function public.plan_interop_audit() to service_role;

-- ===============================================================================================================
-- 7) VIEWS (security_invoker; service_role ke siwa koi nahi)
-- ===============================================================================================================
create or replace view public.v_plan_interop_matrix with (security_invoker = true) as
select from_plan,
       count(*) filter (where allowed)                            as cells_open,
       count(*) filter (where not allowed)                        as cells_blocked,
       count(*) filter (where gate = 'own_plan_feature')          as cells_own_plan_gate,
       count(*)                                                   as cells_total
  from public.plan_interop
 group by from_plan;

create or replace view public.v_plan_limits_ladder with (security_invoker = true) as
select c.rank, c.plan, c.label,
       (c.limits ->> 'users')::integer         as users,
       (c.limits ->> 'storage_gb')::integer    as storage_gb,
       (c.limits ->> 'mailboxes')::integer     as mailboxes,
       (c.limits ->> 'attach_mb')::integer     as attach_mb,
       (c.limits ->> 'domains')::integer       as domains,
       (c.limits ->> 'booking_links')::integer as booking_links,
       (c.limits ->> 'devices')::integer       as devices
  from public.plan_catalog c
 order by c.rank;

create or replace view public.v_plan_interop_decisions_daily with (security_invoker = true) as
select date_trunc('day', created_at) as day, action, allowed, reason, count(*) as n
  from public.plan_interop_log
 group by 1, 2, 3, 4;

revoke all on public.v_plan_interop_matrix, public.v_plan_limits_ladder, public.v_plan_interop_decisions_daily from public, anon, authenticated;
grant select on public.v_plan_interop_matrix, public.v_plan_limits_ladder, public.v_plan_interop_decisions_daily to service_role;

-- ===============================================================================================================
-- 8) SELF-TEST — log mein likhta hai par AAKHIR MEIN sab wapas (subtransaction rollback). Fail => exception.
-- ===============================================================================================================
create or replace function public.plan_interop_selftest()
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  d jsonb; v jsonb; n_before bigint; n_after bigint; r text := '';
  p text; q text;
begin
  select count(*) into n_before from public.plan_interop_log;
  begin
    -- (a) har plan -> har plan, mail: hamesha allowed (36 jodi)
    for p in select plan from public.plan_catalog loop
      for q in select plan from public.plan_catalog loop
        d := public.plan_interop_decide(null, p, q, 'mail', '{"attach_mb":1}'::jsonb, true);
        if not coalesce((d ->> 'allowed')::boolean, false) then raise exception 'mail % -> % band hai', p, q; end if;
        d := public.plan_interop_decide(null, p, q, 'chat', '{}'::jsonb, true);
        if not coalesce((d ->> 'allowed')::boolean, false) then raise exception 'chat % -> % band hai', p, q; end if;
      end loop;
    end loop;
    r := r || 'mail+chat 36 jodi OK; ';

    -- (b) own-plan gate: Basic ka 2nd booking link refuse, Pro ka 3rd ok, 4th refuse
    d := public.plan_interop_decide(null, 'basic', 'pro', 'booking', '{"booking_links":1}'::jsonb, true);
    if not coalesce((d ->> 'allowed')::boolean, false) then raise exception 'basic 1 link ok hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'basic', 'pro', 'booking', '{"booking_links":2}'::jsonb, true);
    if coalesce((d ->> 'allowed')::boolean, true) then raise exception 'basic 2 link refuse hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'pro', 'basic', 'booking', '{"booking_links":3}'::jsonb, true);
    if not coalesce((d ->> 'allowed')::boolean, false) then raise exception 'pro 3 link ok hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'pro', 'basic', 'booking', '{"booking_links":4}'::jsonb, true);
    if coalesce((d ->> 'allowed')::boolean, true) or (d ->> 'reason') <> 'own_plan_limit_exceeded' then raise exception 'pro 4 link refuse hona chahiye'; end if;
    r := r || 'booking gate OK; ';

    -- (c) attachment: Pro 35MB ok, 36MB refuse (Basic ko bheje tab bhi bhejne wale ki limit)
    d := public.plan_interop_decide(null, 'pro', 'basic', 'mail', '{"attach_mb":35}'::jsonb, true);
    if not coalesce((d ->> 'allowed')::boolean, false) then raise exception 'pro 35MB ok hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'pro', 'basic', 'mail', '{"attach_mb":36}'::jsonb, true);
    if coalesce((d ->> 'allowed')::boolean, true) or (d ->> 'reason') <> 'own_plan_limit_exceeded' then raise exception 'pro 36MB refuse hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'pro', 'basic', 'mail', '{}'::jsonb, true);
    if not coalesce((d ->> 'contact')::boolean, false) then raise exception 'contact khula hona chahiye'; end if;
    r := r || 'attach OK; ';

    -- (d) users cap: Pro 20 ok / 21 refuse (share_thread)
    d := public.plan_interop_decide(null, 'pro', 'business_pro', 'share_thread', '{"users":20}'::jsonb, true);
    if not coalesce((d ->> 'allowed')::boolean, false) then raise exception 'pro 20 users ok hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'pro', 'business_pro', 'share_thread', '{"users":21}'::jsonb, true);
    if coalesce((d ->> 'allowed')::boolean, true) then raise exception 'pro 21 users refuse hona chahiye'; end if;
    r := r || 'users cap OK; ';

    -- (d2) ANEXOChat badi file: Basic/Pro 0, Business 2, Business Pro 5, Enterprise 7 GB (bhejne wale ka apna package)
    d := public.plan_interop_decide(null, 'business', 'basic', 'chat', '{"chat_file_gb":2}'::jsonb, true);
    if not coalesce((d ->> 'allowed')::boolean, false) then raise exception 'business 2GB chat ok hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'business', 'basic', 'chat', '{"chat_file_gb":3}'::jsonb, true);
    if coalesce((d ->> 'allowed')::boolean, true) then raise exception 'business 3GB chat refuse hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'enterprise', 'pro', 'chat', '{"chat_file_gb":7}'::jsonb, true);
    if not coalesce((d ->> 'allowed')::boolean, false) then raise exception 'enterprise 7GB chat ok hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'enterprise', 'pro', 'chat', '{"chat_file_gb":8}'::jsonb, true);
    if coalesce((d ->> 'allowed')::boolean, true) then raise exception 'enterprise 8GB chat refuse hona chahiye'; end if;
    d := public.plan_interop_decide(null, 'pro', 'enterprise', 'chat', '{"chat_file_gb":1}'::jsonb, true);
    if coalesce((d ->> 'allowed')::boolean, true) then raise exception 'pro ko ANEXOChat badi file nahi'; end if;
    r := r || 'chat big-file ladder OK; ';

    -- (e) privacy: jawab mein recipient ka plan nahi
    d := public.plan_interop_decide(null, 'basic', 'business_pro', 'invite', '{}'::jsonb, true);
    if d::text ilike '%business_pro%' then raise exception 'recipient ka plan bahar aa gaya'; end if;
    r := r || 'privacy OK; ';

    -- (f) chain verify
    v := public.plan_interop_log_verify();
    if not coalesce((v ->> 'ok')::boolean, false) then raise exception 'chain toota: %', v::text; end if;
    r := r || 'chain ' || (v ->> 'rows') || ' row OK; ';

    -- (g) audit khali
    if exists (select 1 from public.plan_interop_audit()) then raise exception 'audit mein masla: %', (select problem from public.plan_interop_audit() limit 1); end if;
    r := r || 'audit khali; ';

    -- sab test rows wapas
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then
      raise exception 'E100 selftest FAIL: %', sqlerrm;
    end if;
  end;
  select count(*) into n_after from public.plan_interop_log;
  if n_after <> n_before then raise exception 'E100 selftest ne log saaf nahi kiya (% -> %)', n_before, n_after; end if;
  return 'E100 selftest OK — ' || r || 'rollback saaf';
end $$;
revoke all on function public.plan_interop_selftest() from public, anon, authenticated;
grant execute on function public.plan_interop_selftest() to service_role;

-- Dono chalate hain (fail => poori E100 fail, ledger mein nahi likhi jati)
do $$ begin
  raise notice '%', public.plan_interop_selftest();
end $$;
