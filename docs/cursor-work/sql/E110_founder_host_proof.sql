-- E110 — FOUNDER HOST PROOF (L5 v2): "founder sirf founder host par" ka SABOOT database mein, pm2 log files mein nahi. 10/10 (FC27).
-- ---------------------------------------------------------------------------------------------------------------------------
-- Founder order 30 Oct 22:54: "L5 ke codes phir se likho aur latest technology pe likho".
-- PURANA RASTA (kyun fail): saboot pm2 log grep se aata tha; log files ghalat jagah / khali, aur script us par `enforce` rokti thi => 4 baar `status` khali.
-- NAYA RASTA: har host-faisla ek append-only table mein. Tin likhne wale, ek hi saboot:
--   (1) WEB   : awam Bun `founderHostGate` har login/signup par record karta hai (host, kind, is_founder, decision, mode). Email KABHI nahi.
--   (2) RUST  : anexomail-founder `exchange` (founder token ka darwaza) record karta hai kind='exchange' + Host header: yeh akela hi sabit karta hai
--               ke founder ne SAHI host par session banaya, awam Bun ke bina.
--   (3) SQL   : `founder_host_proof()` ek jsonb: ginti, aakhri founder-host login, aakhri awam-host founder koshish, `ready_to_enforce`.
-- Rust ka endpoint `/founder/v1/hostguard` isi proof ko SIGNED deta hai (kernel browser mein verify), Dashboard card "Host separation" dikhata hai.
-- `founder-hostguard.sh status/enforce` ab isi RPC se padhte hain (psql), log files se nahi.
-- PRIVACY: host (naam), kind, bool, decision, mode — email/IP/UA kuch nahi. Dobara chalana safe.

set lock_timeout = '10s';
set statement_timeout = '60s';
set search_path = pg_catalog, public, extensions;

do $$
begin
  if to_regclass('public.founder_accounts') is null then
    raise exception 'E110: pehle E102 (founder_accounts) chalayein' using errcode = '55000';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_host_events:ddl', 0));

  create table if not exists public.founder_host_events (
    id          bigint generated always as identity primary key,
    ts          timestamptz not null default now(),
    source      text not null check (source in ('web', 'rust')),
    kind        text not null check (kind in ('login', 'signup', 'exchange')),
    host        text not null check (host ~ '^[a-z0-9.-]{1,120}$' or host = '-'),
    founder_host boolean not null,
    is_founder  boolean not null,
    mode        text not null check (mode in ('off', 'probe', 'enforce', 'n/a')),
    decision    text not null check (decision in ('allow', 'log', 'refuse'))
  );
  create index if not exists founder_host_events_ts_idx on public.founder_host_events (ts desc);
  create index if not exists founder_host_events_proof_idx on public.founder_host_events (founder_host, is_founder, ts desc);
  alter table public.founder_host_events enable row level security;
  revoke all on public.founder_host_events from public, anon, authenticated;
  grant select, insert on public.founder_host_events to service_role;
  revoke update, truncate, references, trigger on public.founder_host_events from service_role;
end $$;

create or replace function public._founder_host_events_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' and coalesce(current_setting('founder.host_prune', true), '') = 'on' then return old; end if;
  raise exception 'founder_host_events append-only: % not allowed', tg_op using errcode = '42501';
end $$;

do $$
begin
  if to_regclass('public.founder_host_events') is null then return; end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_host_events'::regclass and tgname = 'founder_host_events_no_upd_del') then
    create trigger founder_host_events_no_upd_del before update or delete on public.founder_host_events for each row execute function public._founder_host_events_guard();
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_host_events'::regclass and tgname = 'founder_host_events_no_trunc') then
    create trigger founder_host_events_no_trunc before truncate on public.founder_host_events for each statement execute function public._founder_host_events_guard();
  end if;
end $$;

-- Likhne wala darwaza: har cheez validate, host chhota karke (lowercase, port hata), 5 s timeout.
create or replace function public.founder_host_record(p_source text, p_kind text, p_host text, p_founder_host boolean, p_is_founder boolean, p_mode text, p_decision text)
returns bigint language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_host text := coalesce(nullif(regexp_replace(lower(coalesce(p_host, '')), ':[0-9]+$', ''), ''), '-'); v_id bigint;
begin
  insert into public.founder_host_events (source, kind, host, founder_host, is_founder, mode, decision)
    values (p_source, p_kind, v_host, coalesce(p_founder_host, false), coalesce(p_is_founder, false), coalesce(p_mode, 'n/a'), coalesce(p_decision, 'allow'))
    returning id into v_id;
  return v_id;
end $$;

-- Saboot: ek jawab, sab kuch asli rows se. ready_to_enforce = founder ne founder host par session banaya (rust exchange ya web login) AUR hamare paas
-- awam-host par kam az kam ek login-rasta record hai (web) taake pata chale guard chalta hai.
create or replace function public.founder_host_proof() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare
  v_f timestamptz; v_a timestamptz; v_web timestamptz; v_ok boolean; v_cnt jsonb; v_refused bigint;
begin
  select max(ts) into v_f from public.founder_host_events where is_founder and founder_host;
  select max(ts) into v_a from public.founder_host_events where is_founder and not founder_host;
  select max(ts) into v_web from public.founder_host_events where source = 'web';
  select count(*) into v_refused from public.founder_host_events where decision = 'refuse' and ts > now() - interval '30 days';
  select coalesce(jsonb_object_agg(k, n), '{}'::jsonb) into v_cnt
    from (select source || ':' || kind as k, count(*) as n from public.founder_host_events where ts > now() - interval '30 days' group by 1) s;
  v_ok := v_f is not null;
  return jsonb_build_object(
    'connected', true,
    'last_founder_host_at', v_f,                       -- founder ne SAHI host par kab session/login banaya
    'last_founder_on_awam_host_at', v_a,               -- koi founder koshish awam host par (probe: log, enforce: refuse)
    'web_guard_last_seen_at', v_web,                   -- awam Bun guard ne aakhri baar kab likha (chal raha hai ya nahi)
    'refused_30d', v_refused,
    'counts_30d', v_cnt,
    'ready_to_enforce', v_ok,
    'state', case when v_a is not null and v_a > coalesce(v_f, '-infinity') then 'warn' when v_ok then 'ok' else 'unknown' end,
    'note', case when not v_ok then 'founder host par abhi koi session record nahi: Sign out, /founderlogin par login karein' end);
end $$;

create or replace function public.founder_host_prune(p_keep interval default interval '180 days') returns bigint
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '30s' as $$
declare n bigint;
begin
  if p_keep < interval '30 days' then raise exception 'retention too short' using errcode = '22023'; end if;
  perform set_config('founder.host_prune', 'on', true);
  with d as (delete from public.founder_host_events where ts < now() - p_keep returning 1) select count(*) into n from d;
  perform set_config('founder.host_prune', 'off', true);
  return n;
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.founder_host_record(text,text,text,boolean,boolean,text,text)', 'public.founder_host_proof()', 'public.founder_host_prune(interval)', 'public._founder_host_events_guard()'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke all on function %s from public, anon, authenticated', f);
      if f !~ '_guard' then execute format('grant execute on function %s to service_role', f); end if;
    end if;
  end loop;
end $$;

create or replace function public.founder_host_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare p jsonb; id1 bigint; msg text := 'E110 selftest OK';
begin
  if to_regclass('public.founder_host_events') is null then return 'E110 selftest SKIP: E110 chalayein'; end if;
  begin
    perform set_config('founder.host_prune', 'on', true); delete from public.founder_host_events; perform set_config('founder.host_prune', 'off', true);
    p := public.founder_host_proof();
    if (p ->> 'ready_to_enforce')::boolean then raise exception 'khali table par ready nahi hona chahiye'; end if;
    if p ->> 'state' <> 'unknown' then raise exception 'khali par state unknown chahiye'; end if;
    -- awam host par founder (probe) => log, ab bhi ready nahi, state warn
    id1 := public.founder_host_record('web', 'login', 'Anexomail.com:443', false, true, 'probe', 'log');
    p := public.founder_host_proof();
    if (p ->> 'ready_to_enforce')::boolean then raise exception 'awam-host se ready nahi hona chahiye'; end if;
    if p ->> 'state' <> 'warn' then raise exception 'awam-host par founder => warn chahiye, mila %', p ->> 'state'; end if;
    if not exists (select 1 from public.founder_host_events where id = id1 and host = 'anexomail.com') then raise exception 'host normalise nahi hua'; end if;
    -- founder host par rust exchange => ready
    perform public.founder_host_record('rust', 'exchange', 'founderworkspace.anexomail.com', true, true, 'n/a', 'allow');
    p := public.founder_host_proof();
    if not (p ->> 'ready_to_enforce')::boolean then raise exception 'founder host session ke baad ready chahiye'; end if;
    if p ->> 'state' <> 'ok' then raise exception 'ok chahiye, mila %', p ->> 'state'; end if;
    if (p -> 'counts_30d' ->> 'rust:exchange')::int <> 1 or (p -> 'counts_30d' ->> 'web:login')::int <> 1 then raise exception 'counts galat: %', p -> 'counts_30d'; end if;
    -- append-only
    begin update public.founder_host_events set decision = 'allow'; raise exception 'update chal gaya'; exception when insufficient_privilege then null; end;
    begin delete from public.founder_host_events; raise exception 'delete chal gaya'; exception when insufficient_privilege then null; end;
    begin truncate public.founder_host_events; raise exception 'truncate chal gaya'; exception when insufficient_privilege then null; end;
    -- validation
    begin perform public.founder_host_record('web', 'login', 'bad host!', false, false, 'probe', 'log'); raise exception 'ghalat host chal gaya'; exception when check_violation then null; end;
    begin perform public.founder_host_record('x', 'login', 'a.com', false, false, 'probe', 'log'); raise exception 'ghalat source chal gaya'; exception when check_violation then null; end;
    -- PII: table mein email/ip column hi nahi
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_host_events' and column_name ~* '(email|ip|agent|user)') then raise exception 'PII column mili'; end if;
    -- prune: chhoti retention manzoor nahi
    begin perform public.founder_host_prune(interval '1 day'); raise exception 'chhoti retention chal gayi'; exception when invalid_parameter_value then null; end;
    raise exception 'E110_ROLLBACK';
  exception when others then
    if sqlerrm = 'E110_ROLLBACK' then msg := 'E110 selftest OK'; else msg := 'E110 selftest FAIL: ' || sqlerrm; end if;
  end;
  return msg;
end $$;
revoke all on function public.founder_host_selftest() from public, anon, authenticated;
grant execute on function public.founder_host_selftest() to service_role;
do $$ begin raise notice 'E110 founder_host_proof tayyar. Chalao: CHECK_E110.sql'; end $$;
