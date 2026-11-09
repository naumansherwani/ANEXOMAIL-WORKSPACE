
-- ==============================================================================================================================
-- E148 (K6, 9 Nov 2026) — FOUNDER: WebTransport sessions in the live-session ledger (founder lane, SQL).
-- Rust (server/founder/src/wt.rs) carries the same live frames over QUIC/HTTP3 (AES-256). This file makes the transport PROVABLE in SQL:
--   1) founder_live_sessions.transport ('sse' | 'webtransport'), NOT NULL, CHECK-ed, IMMUTABLE after insert (trigger),
--   2) founder_live_session_open_t(auth_kind, transport)  (the E111 one-argument function is left untouched, E111 CHECK stays green),
--   3) founder_wt_report(hours)  one jsonb: sessions per transport, open now, p50/p95 duration, frames, close reasons, webtransport share,
--   4) founder_wt_selftest()  behaviour test that rolls back (nothing persists), run by CHECK_E148.sql.
-- PRIVACY (Rule 69 / FC18): no uid, IP, token, user agent, message body. Only transport kind, counts, times, reasons.
-- Idempotent: safe to run twice. Needs E111 first.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '30s';

do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_wt:ddl', 0));
  if to_regclass('public.founder_live_sessions') is null then raise exception 'E111 pehle chalao (founder_live_sessions nahi hai)' using errcode = '55000'; end if;
  alter table public.founder_live_sessions add column if not exists transport text not null default 'sse';
  if not exists (select 1 from pg_constraint where conrelid = 'public.founder_live_sessions'::regclass and conname = 'founder_live_sessions_transport_ck') then
    alter table public.founder_live_sessions add constraint founder_live_sessions_transport_ck check (transport in ('sse', 'webtransport'));
  end if;
  create index if not exists founder_live_sessions_transport_idx on public.founder_live_sessions (transport, opened_at desc);
end $$;

-- transport / auth_kind / opened_at never change after the row exists (a row cannot be re-labelled afterwards)
create or replace function public.founder_live_sessions_immutable() returns trigger
language plpgsql set search_path = pg_catalog, public as $$
begin
  if new.transport is distinct from old.transport or new.auth_kind is distinct from old.auth_kind or new.opened_at is distinct from old.opened_at then
    raise exception 'founder_live_sessions: transport, auth_kind and opened_at are immutable' using errcode = '23514';
  end if;
  return new;
end $$;
drop trigger if exists founder_live_sessions_immutable_trg on public.founder_live_sessions;
create trigger founder_live_sessions_immutable_trg before update on public.founder_live_sessions for each row execute function public.founder_live_sessions_immutable();

-- open (same cap as E111: 500 open in the last hour)
create or replace function public.founder_live_session_open_t(p_auth_kind text, p_transport text) returns bigint
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_id bigint; v_open integer;
begin
  if coalesce(p_auth_kind, '') not in ('device', 'legacy') then raise exception 'auth_kind galat' using errcode = '22023'; end if;
  if coalesce(p_transport, '') not in ('sse', 'webtransport') then raise exception 'transport galat' using errcode = '22023'; end if;
  select count(*) into v_open from public.founder_live_sessions where closed_at is null and opened_at > now() - interval '1 hour';
  if v_open >= 500 then raise exception 'bohat khule sessions' using errcode = '54000'; end if;
  insert into public.founder_live_sessions (auth_kind, transport) values (p_auth_kind, p_transport) returning id into v_id;
  return v_id;
end $$;

-- one jsonb for the founder screen / CHECK: real counts only, nothing invented
create or replace function public.founder_wt_report(p_hours integer default 24) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare v_h integer := least(greatest(coalesce(p_hours, 24), 1), 720); v_since timestamptz; v_out jsonb;
begin
  v_since := now() - make_interval(hours => v_h);
  select jsonb_build_object(
    'hours', v_h,
    'by_transport', coalesce((select jsonb_object_agg(transport, jsonb_build_object(
          'sessions', n, 'open_now', open_n, 'frames', frames, 'p50_ms', p50, 'p95_ms', p95))
        from (select transport, count(*) n, count(*) filter (where closed_at is null) open_n, coalesce(sum(frames_sent), 0) frames,
                     (percentile_cont(0.5) within group (order by duration_ms) filter (where duration_ms is not null))::bigint p50,
                     (percentile_cont(0.95) within group (order by duration_ms) filter (where duration_ms is not null))::bigint p95
                from public.founder_live_sessions where opened_at >= v_since group by transport) s), '{}'::jsonb),
    'close_reasons', coalesce((select jsonb_object_agg(k, n) from (select transport || ':' || close_reason k, count(*) n from public.founder_live_sessions
                                where opened_at >= v_since and close_reason is not null group by 1) r), '{}'::jsonb),
    'webtransport_share_pct', (select case when count(*) = 0 then null else round(100.0 * count(*) filter (where transport = 'webtransport') / count(*), 1) end
                                 from public.founder_live_sessions where opened_at >= v_since)
  ) into v_out;
  return v_out;
end $$;

-- behaviour selftest: everything happens inside a block that is rolled back (nothing persists)
create or replace function public.founder_wt_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '15s' as $$
declare a bigint; b bigint; r jsonb; ok boolean; e text;
begin
  begin
    a := public.founder_live_session_open_t('device', 'webtransport');
    b := public.founder_live_session_open_t('device', 'sse');
    if not public.founder_live_session_close(a, 'client_gone', 7) then raise exception 'SELFTEST close a failed'; end if;
    if public.founder_live_session_close(a, 'lifetime', 9) then raise exception 'SELFTEST second close must be refused'; end if;
    r := public.founder_wt_report(1);
    if (r -> 'by_transport' -> 'webtransport' ->> 'sessions')::int < 1 then raise exception 'SELFTEST report webtransport missing'; end if;
    if (r -> 'by_transport' -> 'sse' ->> 'open_now')::int < 1 then raise exception 'SELFTEST report sse open missing'; end if;
    -- bad transport and bad kind are refused
    ok := false; begin perform public.founder_live_session_open_t('device', 'carrier-pigeon'); exception when sqlstate '22023' then ok := true; end;
    if not ok then raise exception 'SELFTEST bad transport accepted'; end if;
    ok := false; begin perform public.founder_live_session_open_t('root', 'sse'); exception when sqlstate '22023' then ok := true; end;
    if not ok then raise exception 'SELFTEST bad auth_kind accepted'; end if;
    -- the transport cannot be re-labelled after the fact
    ok := false; begin update public.founder_live_sessions set transport = 'sse' where id = a; exception when sqlstate '23514' then ok := true; end;
    if not ok then raise exception 'SELFTEST transport was re-labelled'; end if;
    -- the table itself refuses a made-up transport
    ok := false; begin insert into public.founder_live_sessions (auth_kind, transport) values ('device', 'udp-magic'); exception when check_violation then ok := true; end;
    if not ok then raise exception 'SELFTEST CHECK constraint missing'; end if;
    raise exception 'E148_ROLLBACK_OK';
  exception when others then
    get stacked diagnostics e = message_text;
    if e = 'E148_ROLLBACK_OK' then return 'E148 selftest OK (transport label, immutable, caps, report, rolled back)'; end if;
    return 'E148 selftest FAIL: ' || e;
  end;
end $$;

-- access: only the Rust service role (RLS-protected table, no anon / authenticated)
revoke all on function public.founder_live_session_open_t(text, text) from public, anon, authenticated;
revoke all on function public.founder_wt_report(integer) from public, anon, authenticated;
revoke all on function public.founder_wt_selftest() from public, anon, authenticated;
grant execute on function public.founder_live_session_open_t(text, text) to service_role;
grant execute on function public.founder_wt_report(integer) to service_role;
grant execute on function public.founder_wt_selftest() to service_role;
