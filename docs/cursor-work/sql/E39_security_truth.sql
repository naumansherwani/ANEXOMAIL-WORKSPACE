-- E39 — Security page sach bole — 20 Oct 2026 (Basic live audit)
--
-- Kyun: Security page ki har ginti khaali tables se aati thi jinhein koi likhta hi nahi (security_sessions,
-- security_devices, security_login_events, security_encryption_surfaces). Natija: user khud login hai magar
-- "Live sessions 0"; "Kill" kisi asli session ko nahi maarta tha; "Rotate keys" sirf ek row likhta tha.
--
-- Hal: asli jagah se padho (Rust :3200 `security.*` yeh functions bulata hai, service_role se):
--   - sessions  = auth.sessions (Supabase ka asli login record). Kill = auth.sessions se delete => us device ka
--                 refresh token khatam, aur /auth/v1/user (Rust + Bun dono) usi waqt us token ko mana kar deta hai.
--   - devices   = device_vault (har plan par pehle se likha ja raha hai).
--   - logins    = auth.audit_log_entries (Supabase khud likhta hai: login / logout / token_revoked).
--   - ledger    = security_ledger, sha256 zanjeer (har entry pichli ka hash pakadti hai) — ab har kill par likhi jati hai.
-- Koi naya table nahi. Purane tables/Bun routes waise hi (fallback). Kisi user ka data nahi badalta.
-- Supabase SQL Editor-safe (koi psql \-command, koi temp table nahi). Dobara chalana safe. Fail => poora rollback.
-- Server se: . /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -f E39_security_truth.sql
begin;
select pg_advisory_xact_lock(hashtext('E39_security_truth'));

do $$
begin
  if to_regclass('auth.sessions') is null then raise exception 'E39: auth.sessions nahi'; end if;
  if to_regclass('auth.audit_log_entries') is null then raise exception 'E39: auth.audit_log_entries nahi'; end if;
  if to_regclass('public.security_ledger') is null then raise exception 'E39: security_ledger nahi (phase26 pehle)'; end if;
  if to_regclass('public.security_kill_switches') is null then raise exception 'E39: security_kill_switches nahi'; end if;
  if to_regprocedure('extensions.digest(text,text)') is null and to_regprocedure('public.digest(text,text)') is null then
    raise exception 'E39: pgcrypto digest() nahi';
  end if;
end $$;

-- ── ledger: sha256 zanjeer ──────────────────────────────────────────────────────────────────────────────
create or replace function public.sec_ledger_add(_user uuid, _action text, _payload jsonb, _actor text default 'owner')
returns text language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v_prev text; v_at timestamptz := clock_timestamp(); v_hash text;
begin
  perform pg_advisory_xact_lock(hashtext('sec_ledger:' || _user::text));
  select hash into v_prev from public.security_ledger where user_id = _user order by at desc, id desc limit 1;
  v_hash := encode(digest(concat_ws('|', _user::text, _action, _actor, coalesce(_payload, '{}'::jsonb)::text,
                                     coalesce(v_prev, ''), to_char(v_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')), 'sha256'), 'hex');
  insert into public.security_ledger (user_id, action, actor, payload, prev_hash, hash, at)
  values (_user, _action, _actor, coalesce(_payload, '{}'::jsonb), v_prev, v_hash, v_at);
  return v_hash;
end $$;

-- ── sessions: auth.sessions (columns Supabase version ke hisab se — to_jsonb se, jo na ho woh null) ──────
create or replace function public.sec_sessions(_user uuid, _current uuid default null)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(x order by (x->>'current')::boolean desc, x->>'last_seen_at' desc), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', s.id,
      'user_agent', j->>'user_agent',
      'ip', nullif(split_part(coalesce(j->>'ip', ''), '/', 1), ''),
      'started_at', s.created_at,
      'last_seen_at', coalesce((j->>'refreshed_at')::timestamptz, (j->>'updated_at')::timestamptz, s.created_at),
      'expires_at', (j->>'not_after')::timestamptz,
      'aal', j->>'aal',
      'idle_days', floor(extract(epoch from (now() - coalesce((j->>'refreshed_at')::timestamptz, (j->>'updated_at')::timestamptz, s.created_at))) / 86400)::int,
      'current', coalesce(s.id = _current, false)
    ) as x
    from auth.sessions s, lateral (select to_jsonb(s) as j) t
    where s.user_id = _user
      and ((j->>'not_after') is null or (j->>'not_after')::timestamptz > now())
  ) q;
$$;

create or replace function public.sec_session_kill(_user uuid, _session uuid, _current uuid default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_n int; v_hash text;
begin
  if _session is null then raise exception 'session_id_required'; end if;
  if _session = _current then raise exception 'this_session_use_sign_out'; end if;
  delete from auth.sessions where id = _session and user_id = _user;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'session_not_found'; end if;
  v_hash := public.sec_ledger_add(_user, 'session_killed', jsonb_build_object('session_id', _session));
  return jsonb_build_object('ok', true, 'sessions_killed', v_n, 'hash', v_hash);
end $$;

-- Kill switch: is device ke ilawa HAR session khatam (asli). Devices ko chhedte nahi (current device ka pata server
-- ko yaqeeni nahi — galat device band karna user ko bahar kar sakta hai); is liye devices_blocked = 0, sach.
create or replace function public.sec_kill_switch(_user uuid, _current uuid, _reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_n int; v_hash text;
begin
  if _current is null then raise exception 'current_session_unknown'; end if;
  delete from auth.sessions where user_id = _user and id <> _current;
  get diagnostics v_n = row_count;
  v_hash := public.sec_ledger_add(_user, 'kill_switch',
              jsonb_build_object('reason', left(coalesce(_reason, 'kill switch'), 300), 'sessions_killed', v_n));
  insert into public.security_kill_switches (user_id, reason, sessions_killed, devices_blocked, hash)
  values (_user, left(coalesce(_reason, 'kill switch'), 300), v_n, 0, v_hash);
  return jsonb_build_object('ok', true, 'sessions_killed', v_n, 'devices_blocked', 0, 'hash', v_hash);
end $$;

-- ── login history: auth.audit_log_entries (sirf is user ke, 90 din) ─────────────────────────────────────
create or replace function public.sec_logins(_user uuid, _limit int default 50)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(x order by x->>'at' desc), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', e.id, 'at', e.created_at, 'action', e.action, 'email', e.email, 'provider', e.provider, 'ip', e.ip,
      -- is network (ip) se is user ka pehle bhi login hua tha?
      'seen_before', coalesce(e.ip is not null and count(*) filter (where e.action = 'login') over (
                        partition by e.ip order by e.created_at rows between unbounded preceding and 1 preceding) > 0, false)
    ) as x, e.created_at
    from (
      select a.id, a.created_at, a.payload->>'action' as action, coalesce(a.payload->>'actor_username', '') as email,
             coalesce(a.payload->'traits'->>'provider', a.payload->>'provider', 'email') as provider,
             nullif(to_jsonb(a)->>'ip_address', '') as ip
      from auth.audit_log_entries a
      where a.created_at > now() - interval '90 days'
        and a.payload->>'actor_id' = _user::text
        and a.payload->>'action' in ('login', 'logout', 'token_revoked', 'user_recovery_requested',
                                     'user_reauthenticate', 'user_updated_password', 'user_modified')
    ) e
    order by e.created_at desc
    limit greatest(1, least(coalesce(_limit, 50), 200))
  ) q;
$$;

-- ── dashboard: ek call, sab asli ──────────────────────────────────────────────────────────────────────────
create or replace function public.sec_dashboard(_user uuid, _current uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v jsonb;
begin
  select jsonb_build_object(
    'sessions', public.sec_sessions(_user, _current),
    'devices_trusted', (select count(*) from public.device_vault d where d.user_id = _user and d.state = 'trusted'),
    'devices_pending', (select count(*) from public.device_vault d where d.user_id = _user and d.state in ('pending', 'suspicious')),
    'devices_total', (select count(*) from public.device_vault d where d.user_id = _user),
    'failed_logins_24h', (select count(*) from public.security_login_events e
                           where e.user_id = _user and e.outcome in ('failed', 'blocked') and e.at > now() - interval '24 hours'),
    'anomalies', coalesce((select jsonb_agg(jsonb_build_object('kind', a.kind, 'severity', a.severity, 'detail', a.detail))
                             from public.security_anomalies a where a.user_id = _user and a.state = 'open'), '[]'::jsonb),
    'last_proof', (select jsonb_build_object('domain', p.domain, 'ran_at', p.ran_at, 'passed', p.passed, 'failed', p.failed)
                     from public.security_proofs p where p.user_id = _user order by p.ran_at desc limit 1),
    'ledger', coalesce((select jsonb_agg(jsonb_build_object('at', l.at, 'action', l.action, 'actor', l.actor,
                                                            'hash', l.hash, 'prev_hash', l.prev_hash) order by l.at desc)
                          from (select * from public.security_ledger where user_id = _user order by at desc limit 12) l), '[]'::jsonb)
  ) into v;
  return v;
end $$;

-- device_vault ho hi na (purana install) to dashboard toot-ta nahi
do $$
begin
  if to_regclass('public.device_vault') is null then
    raise exception 'E39: device_vault nahi (anexochat phase19_22 pehle)';
  end if;
end $$;

-- sirf server (service_role) bulaye — browser seedha kabhi nahi (warna koi doosre ka _user bhej sakta)
do $$
declare f text;
begin
  foreach f in array array[
    'public.sec_ledger_add(uuid,text,jsonb,text)', 'public.sec_sessions(uuid,uuid)',
    'public.sec_session_kill(uuid,uuid,uuid)', 'public.sec_kill_switch(uuid,uuid,text)',
    'public.sec_logins(uuid,integer)', 'public.sec_dashboard(uuid,uuid)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- self-test (sab wapas): ledger zanjeer + sessions + kill + dashboard
do $$
declare v_u uuid; v_s1 uuid := gen_random_uuid(); v_s2 uuid := gen_random_uuid(); v jsonb; h1 text; h2 text;
begin
  begin
    select id into v_u from auth.users limit 1;
    if v_u is null then raise exception 'E39_SELFTEST_OK'; end if;
    insert into auth.sessions (id, user_id, created_at, updated_at) values (v_s1, v_u, now(), now()), (v_s2, v_u, now(), now());
    v := public.sec_sessions(v_u, v_s1);
    if not exists (select 1 from jsonb_array_elements(v) e where (e->>'id')::uuid = v_s1 and (e->>'current')::boolean) then
      raise exception 'E39 SELFTEST FAIL: current session nahi mila';
    end if;
    begin
      perform public.sec_session_kill(v_u, v_s1, v_s1);
      raise exception 'E39 SELFTEST FAIL: apna session kill ho gaya';
    exception when others then
      if sqlerrm <> 'this_session_use_sign_out' then raise; end if;
    end;
    perform public.sec_session_kill(v_u, v_s2, v_s1);
    if exists (select 1 from auth.sessions where id = v_s2) then raise exception 'E39 SELFTEST FAIL: kill ke baad session baqi'; end if;
    h1 := public.sec_ledger_add(v_u, 'e39_selftest_a', '{}'::jsonb);
    h2 := public.sec_ledger_add(v_u, 'e39_selftest_b', '{}'::jsonb);
    if (select prev_hash from public.security_ledger where hash = h2) is distinct from h1 then
      raise exception 'E39 SELFTEST FAIL: ledger zanjeer nahi judi';
    end if;
    v := public.sec_dashboard(v_u, v_s1);
    if jsonb_typeof(v->'sessions') <> 'array' or jsonb_typeof(v->'ledger') <> 'array' then
      raise exception 'E39 SELFTEST FAIL: dashboard shape';
    end if;
    perform public.sec_logins(v_u, 5);
    raise exception 'E39_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'E39_SELFTEST_OK' then raise; end if;
  end;
end $$;

select 'functions' as cheez,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname in ('sec_ledger_add', 'sec_sessions', 'sec_session_kill',
                                                      'sec_kill_switch', 'sec_logins', 'sec_dashboard'))::text || ' / 6' as haal
union all select 'self-test', 'PASSED (sab rollback)'
union all select 'live sessions (sab users)', (select count(*) from auth.sessions)::text
union all select 'auth.sessions columns', (select string_agg(column_name, ',' order by ordinal_position)
                                             from information_schema.columns where table_schema = 'auth' and table_name = 'sessions');

commit;
