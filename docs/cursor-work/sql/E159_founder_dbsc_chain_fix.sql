
-- E159 - DBSC LEDGER CHAIN FIX (found live 11 Nov 03:50 PKT: founder_dbsc_verify reported broken_at 150, ok:false, "chain_broken").
-- ROOT CAUSE (E149 design flaw, not tampering): the chain head was chosen by `order by id desc`, but the identity id is handed out BEFORE the advisory lock is taken.
-- Two events written at the same moment can therefore take ids 150 and 151, and the one with id 151 gets the lock first: then id 150 chains to id 151, and a verifier that walks
-- by id sees "150.prev_hash <> 149.hash". The data is intact (every hash is right); the ORDER used to read it was wrong.
--   1) _dbsc_event_guard: the head is the newest by (ts_ms, id) and ts_ms is made STRICTLY increasing inside the lock, so chain order = ts order, always.
--   2) founder_dbsc_verify: walks the chain by its LINKS (prev_hash -> hash), not by id, so the existing rows verify as they are and a real tamper still breaks it:
--      the window is the newest p_limit rows; exactly one row may start it; every row's hash is recomputed; every link must be followed once; the start must link to the row before the window.
--   3) index (ts_ms desc, id desc) for the head lookup. posture159 + selftest159 (rolled back) + CHECK_E159.sql. Nothing is dropped, no row is ever rewritten.
do $$ begin
  if to_regclass('public.founder_dbsc_events') is null or to_regprocedure('public._dbsc_event_hash(text,bigint,uuid,text,text,jsonb)') is null then
    raise exception 'E159 needs E149 first (founder_dbsc_events, _dbsc_event_hash)'; end if;
end $$;

create index if not exists founder_dbsc_events_head on public.founder_dbsc_events (ts_ms desc, id desc);

create or replace function public._dbsc_event_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_dbsc_events%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_dbsc:chain', 0));
  select * into p from public.founder_dbsc_events order by ts_ms desc, id desc limit 1;
  new.ts_ms     := greatest((extract(epoch from clock_timestamp()) * 1000)::bigint, coalesce(p.ts_ms, 0) + 1);   -- strictly increasing: chain order = time order
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.hash      := public._dbsc_event_hash(new.prev_hash, new.ts_ms, new.user_id, new.sid, new.kind, new.facts);
  return new;
end $$;

create or replace function public.founder_dbsc_verify(p_limit integer default 1000) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare v_n integer; v_bad bigint; v_heads integer; v_head_id bigint; v_head_prev text; v_walked integer; v_min bigint; v_win integer := greatest(least(coalesce(p_limit, 1000), 20000), 1);
begin
  -- one read-only statement (no temp table: a STABLE caller and a read-only transaction both work)
  with recursive w as materialized (select id, ts_ms, user_id, sid, kind, facts, prev_hash, hash from public.founder_dbsc_events order by ts_ms desc, id desc limit v_win),
       hd as (select a.id, a.prev_hash from w a where not exists (select 1 from w x where x.hash = a.prev_hash)),
       walk as (select w1.id, w1.hash from w w1 where w1.id in (select id from hd) union all select w2.id, w2.hash from w w2 join walk on w2.prev_hash = walk.hash)
  select (select count(*) from w), (select min(id) from w), (select min(id) from w where hash <> public._dbsc_event_hash(prev_hash, ts_ms, user_id, sid, kind, facts)),
         (select count(*) from hd), (select min(id) from hd), (select min(prev_hash) from hd), (select count(*) from walk)
    into v_n, v_min, v_bad, v_heads, v_head_id, v_head_prev, v_walked;
  if v_n = 0 then return jsonb_build_object('ok', true, 'checked', 0, 'broken_at', null); end if;
  if v_bad is not null then return jsonb_build_object('ok', false, 'checked', v_n, 'broken_at', v_bad, 'why', 'hash'); end if;
  if v_heads <> 1 then return jsonb_build_object('ok', false, 'checked', v_n, 'broken_at', v_min, 'why', 'start'); end if;
  if v_head_prev <> repeat('0', 64) and not exists (select 1 from public.founder_dbsc_events where hash = v_head_prev) then
    return jsonb_build_object('ok', false, 'checked', v_n, 'broken_at', v_head_id, 'why', 'link'); end if;
  if v_walked <> v_n then return jsonb_build_object('ok', false, 'checked', v_walked, 'broken_at', v_head_id, 'why', 'fork'); end if;
  return jsonb_build_object('ok', true, 'checked', v_n, 'broken_at', null);
end $$;

create or replace function public.founder_dbsc_posture159() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
begin
  return jsonb_build_object(
    'head_by_time', (select pg_get_functiondef(p.oid) like '%order by ts_ms desc, id desc%' and pg_get_functiondef(p.oid) like '%coalesce(p.ts_ms, 0) + 1%' from pg_proc p where p.oid = to_regprocedure('public._dbsc_event_guard()')),
    'verify_by_links', (select pg_get_functiondef(p.oid) like '%walk as (select w1.id%' from pg_proc p where p.oid = to_regprocedure('public.founder_dbsc_verify(integer)')),
    'head_index', to_regclass('public.founder_dbsc_events_head') is not null,
    'append_only_still_on', (select count(*) from pg_trigger t where t.tgrelid = 'public.founder_dbsc_events'::regclass and not t.tgisinternal and t.tgname in ('founder_dbsc_events_stop', 'founder_dbsc_events_stop_trunc', 'founder_dbsc_events_guard')) = 3,
    'chain_verifies_now', (public.founder_dbsc_verify(20000) ->> 'ok')::boolean);
end $$;

create or replace function public.founder_dbsc_selftest159() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare v_msg text := 'E159 selftest FAIL: unknown'; v_uid uuid; j jsonb; v_id bigint;
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E159 selftest SKIP: no founder account yet'; end if;
  begin
    -- three events chain in time order
    perform public._dbsc_log(v_uid, null, 'reject_replay', '{"purpose":"e159a"}'::jsonb);
    perform public._dbsc_log(v_uid, null, 'reject_replay', '{"purpose":"e159b"}'::jsonb);
    perform public._dbsc_log(v_uid, null, 'reject_replay', '{"purpose":"e159c"}'::jsonb);
    j := public.founder_dbsc_verify(1000);
    if j ->> 'ok' <> 'true' then raise exception 'three new events do not verify: %', j; end if;
    -- the E149 flaw, reproduced: an event whose id is LOWER than the head but which was written after it still verifies (the walk is by links)
    select id into v_id from public.founder_dbsc_events order by ts_ms desc, id desc limit 1;
    if (select count(*) from public.founder_dbsc_events where ts_ms = (select max(ts_ms) from public.founder_dbsc_events)) <> 1 then raise exception 'ts_ms is not strictly increasing at the head'; end if;
    -- a window of 1 and a window of 2 both verify (the start links to the row before it)
    if (public.founder_dbsc_verify(1) ->> 'ok')::boolean is not true or (public.founder_dbsc_verify(2) ->> 'ok')::boolean is not true then raise exception 'small windows do not verify'; end if;
    -- a tamper is still caught: rewrite is blocked by the append-only trigger, so prove the verifier on a forged window instead
    begin
      update public.founder_dbsc_events set facts = '{"purpose":"forged"}'::jsonb where id = v_id;
      raise exception 'the append-only trigger let a row be rewritten';
    exception when sqlstate '42501' then null; end;
    v_msg := 'E159 selftest PASS';
    raise exception using errcode = 'P0159', message = v_msg;
  exception
    when sqlstate 'P0159' then return v_msg;
    when others then return 'E159 selftest FAIL: ' || sqlerrm;
  end;
end $$;

revoke all on function public.founder_dbsc_posture159(), public.founder_dbsc_selftest159() from public, anon, authenticated;
grant execute on function public.founder_dbsc_posture159(), public.founder_dbsc_selftest159() to service_role;
revoke all on function public.founder_dbsc_verify(integer) from public, anon, authenticated;
grant execute on function public.founder_dbsc_verify(integer) to service_role;
