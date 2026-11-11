
-- E163 (11 Nov 2026 21:10 PKT) - fixes ONLY the E162 selftest function (E162 itself is applied and its posture is OK; applied SQL is never edited, so this is a new number).
-- WHY: his server has a LIVE chip binding; the selftest cleared it with revoke_reason 'e162test', which the E149 CHECK refuses (allowed: replaced, device_revoked, founder_revoked, lost_key, selftest).
--   The sandbox database had no live binding, so the local run never reached that line. The test now uses 'selftest' and the sandbox run is repeated WITH a live binding.
-- Nothing else changes; the selftest still ends in a rollback.

do $$ begin
  if to_regprocedure('public.founder_dbsc_selftest162()') is null or to_regprocedure('public.founder_dbsc_register_pq(uuid,text,text,text,text,text,text)') is null then raise exception 'E163 needs E162 first'; end if;
end $$;

create or replace function public.founder_dbsc_selftest162() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_msg text := 'E162 selftest FAIL: unknown'; v_uid uuid; v_dev text; j jsonb;
  pq1 text := repeat('ab', 1952); pq2 text := repeat('cd', 1952);
  k1 text := '04' || repeat('11', 64); k2 text := '04' || repeat('22', 64);
  h text := encode(extensions.digest('e162-j', 'sha256'), 'hex');
begin
  select d.user_id, d.ua_hash into v_uid, v_dev from public.founder_devices d where d.approved_at is not null and d.revoked_at is null order by d.created_at limit 1;
  if v_uid is null then return 'E162 selftest SKIP: no approved founder device yet'; end if;
  begin
    -- 1) a chip session ends first so the device is clean inside this rolled-back test
    update public.founder_dbsc_sessions set revoked_at = now(), revoke_reason = 'selftest' where user_id = v_uid and device_hash = v_dev and revoked_at is null;
    -- 2) classical-only registration works; a pq key is refused with source dbsc and with a bad shape
    j := public.founder_dbsc_register_pq(v_uid, v_dev, 'e162classic000001', k1, encode(extensions.digest('e162-1', 'sha256'), 'hex'), 'webcrypto', null);
    if j ->> 'ok' <> 'true' then raise exception 'classical registration refused: %', j; end if;
    if public.founder_dbsc_register_pq(v_uid, v_dev, 'e162bad000000001', k2, encode(extensions.digest('e162-2', 'sha256'), 'hex'), 'dbsc', pq1) ->> 'error' <> 'source' then raise exception 'pq with dbsc accepted'; end if;
    if public.founder_dbsc_register_pq(v_uid, v_dev, 'e162bad000000002', k2, encode(extensions.digest('e162-3', 'sha256'), 'hex'), 'webcrypto', 'abcd') ->> 'error' <> 'pq_shape' then raise exception 'short pq accepted'; end if;
    -- 3) upgrade to hybrid, state reports the pq key
    j := public.founder_dbsc_register_pq(v_uid, v_dev, 'e162hybrid0000001', k2, encode(extensions.digest('e162-4', 'sha256'), 'hex'), 'webcrypto', pq1);
    if j ->> 'ok' <> 'true' or (j ->> 'hybrid')::boolean is not true then raise exception 'hybrid registration refused: %', j; end if;
    if public.founder_dbsc_device_state(v_uid, v_dev) ->> 'pq' <> pq1 then raise exception 'device_state does not report the pq key'; end if;
    -- 4) NO DOWNGRADE: classical-only registration (new door and old wrapper) is refused while the hybrid binding is live
    if public.founder_dbsc_register_pq(v_uid, v_dev, 'e162down000000001', k1, encode(extensions.digest('e162-5', 'sha256'), 'hex'), 'webcrypto', null) ->> 'error' <> 'pq_downgrade' then raise exception 'downgrade accepted'; end if;
    if public.founder_dbsc_register_src(v_uid, v_dev, 'e162down000000002', k1, encode(extensions.digest('e162-6', 'sha256'), 'hex'), 'webcrypto') ->> 'error' <> 'pq_downgrade' then raise exception 'downgrade via the old door accepted'; end if;
    -- 5) the pq key cannot be changed or stripped in place
    begin update public.founder_dbsc_sessions set pq_pub = pq2 where sid = 'e162hybrid0000001'; raise exception 'pq key swapped in place';
    exception when insufficient_privilege then null; end;
    begin update public.founder_dbsc_sessions set pq_pub = null, pq_alg = null where sid = 'e162hybrid0000001'; raise exception 'pq key stripped in place';
    exception when insufficient_privilege then null; end;
    -- 6) a replacement hybrid (new key) is allowed and the old row is revoked
    j := public.founder_dbsc_register_pq(v_uid, v_dev, 'e162hybrid0000002', k1, encode(extensions.digest('e162-7', 'sha256'), 'hex'), 'webcrypto', pq2);
    if j ->> 'ok' <> 'true' or (j ->> 'replaced')::boolean is not true then raise exception 'hybrid replacement refused: %', j; end if;
    if (select count(*) from jsonb_each_text(public.founder_dbsc_posture162()) where value::boolean is not true) <> 0 then raise exception 'posture162: %', public.founder_dbsc_posture162(); end if;
    v_msg := 'E162 selftest PASS';
    raise exception using errcode = 'P0162', message = v_msg;
  exception
    when sqlstate 'P0162' then return v_msg;
    when others then return 'E162 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_dbsc_selftest162() from public, anon, authenticated;
grant execute on function public.founder_dbsc_selftest162() to service_role;
