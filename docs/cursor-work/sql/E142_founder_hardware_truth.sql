-- E142 — Founder J-hardening: "hardware key" must be TRUE, and the hardware-only switch must be reachable (founder order 3 Nov 2026 12:00 PKT: "hardware toggle ... fix kero green kero").
-- Two real defects found in E118/E139:
--   A) LOOPHOLE  `kind = 'hardware'` was decided by one thing only: the AAGUID a key CLAIMS is on the founder's allow-list. A software or synced passkey can claim any AAGUID (the attestation statement is not verified),
--                and a synced key (backup-eligible, BE=1) or a built-in platform key is not a security key at all. E142 makes the truth rule a database fact: a key is hardware only if its model is trusted AND
--                its stored facts (E139) say it is NOT backup-eligible (BE=0) AND its attachment is not 'platform'. The class is recomputed by triggers whenever the facts or the allow-list change.
--   B) DEAD END  nothing in the product could ever add a model to the allow-list for the key the founder had just registered, so hardware_keys stayed 0 for ever. E142 adds founder_hardware_readiness():
--                every active key with its model, BE, attachment, whether it counts and WHY NOT in words, the trusted models, and the exact next step. The UI shows it with a "Trust this model" button (T2 step aaguid.allow).
-- What does NOT change (on purpose): the lock-out guard. Switching "T2 needs hardware" ON still needs 2 active hardware keys (E118 CHECK + selftest). Nothing here fakes a hardware key: a physical security key must exist.
-- Needs E118 + E139. Safe to run again. Selftest rolls back.

do $$ begin
  if to_regclass('public.founder_webauthn_cred') is null or to_regclass('public.founder_aaguid_allow') is null then raise exception 'E142 needs E118 and E139 first'; end if;
end $$;

-- 1) the truth rule, in one place ----------------------------------------------------------------------------------------------------------------
create or replace function public._fh_hw_facts_ok(p_be boolean, p_attachment text) returns boolean language sql immutable set search_path = pg_catalog, public as $$
  select p_be is false and p_attachment is distinct from 'platform'
$$;
create or replace function public._fh_hw_why_not(p_be boolean, p_attachment text, p_trusted boolean) returns text language sql immutable set search_path = pg_catalog, public as $$
  select case when p_be then 'This key can be backed up or synced (backup-eligible), so it is not a security key.'
              when p_attachment = 'platform' then 'This is a built-in key of the device (platform), not a roaming security key.'
              when not p_trusted then 'Its model is not on your trusted list yet. Trust the model to count it.'
              else null end
$$;

-- 2) recompute the class of every active key from the facts + the allow-list (never trusts a claim alone) --------------------------------------------
create or replace function public._fh_reclassify(p_uid uuid) returns integer
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r record; v_n integer := 0; v_want text;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_hw:' || p_uid::text, 0));
  for r in
    select k.id, k.credential_id, k.kind as cur, c.aaguid, public._fh_hw_facts_ok(c.be, c.attachment) as facts_ok,
           exists (select 1 from public.founder_aaguid_allow a where a.aaguid = c.aaguid and a.enabled) as trusted
      from public.founder_passkeys k join public.founder_webauthn_cred c on c.credential_id = k.credential_id
     where k.user_id = p_uid and k.revoked_at is null and c.quarantined_ms is null
  loop
    v_want := case when r.facts_ok and r.trusted then 'hardware' else 'platform' end;
    if v_want <> r.cur then
      update public.founder_passkeys set kind = v_want, aaguid = case when v_want = 'hardware' then r.aaguid else aaguid end where id = r.id;
      v_n := v_n + 1;
      perform public._fw_log(p_uid, r.credential_id, 'policy_note', 'info', 0, 'key class is now ' || v_want || ' (facts + trusted model decide, not a claim)', jsonb_build_object('class', v_want));
      perform public.founder_audit_append(p_uid, 'passkey.class', left(r.credential_id, 12), 'key class is now ' || v_want, jsonb_build_object('class', v_want));
    end if;
  end loop;
  return v_n;
end $$;

create or replace function public._fh_reclassify_cred() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin perform public._fh_reclassify(new.user_id); return new; end $$;
drop trigger if exists founder_hw_truth_cred on public.founder_webauthn_cred;
create trigger founder_hw_truth_cred after insert on public.founder_webauthn_cred for each row execute function public._fh_reclassify_cred();

create or replace function public._fh_reclassify_allow() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare u uuid;
begin for u in select user_id from public.founder_accounts loop perform public._fh_reclassify(u); end loop; return null; end $$;
drop trigger if exists founder_hw_truth_allow on public.founder_aaguid_allow;
create trigger founder_hw_truth_allow after insert or update of enabled on public.founder_aaguid_allow for each statement execute function public._fh_reclassify_allow();

-- 3) readiness: what counts, what does not, why, and the next step ----------------------------------------------------------------------------------
create or replace function public.founder_hardware_readiness(p_uid uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_hw integer; v_need integer; v_keys jsonb; v_next text; v_cands integer;
begin
  perform public._fs_assert_founder(p_uid);
  select t3_min_hardware_keys into v_need from public.founder_protocol where id;
  select count(*) into v_hw from public.founder_passkeys k join public.founder_aaguid_allow a on a.aaguid = k.aaguid and a.enabled where k.user_id = p_uid and k.revoked_at is null and k.kind = 'hardware';
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', k.id, 'label', k.label, 'aaguid', c.aaguid, 'be', c.be, 'attachment', c.attachment, 'transports', to_jsonb(c.transports),
           'counts', k.kind = 'hardware' and t.trusted, 'trusted', t.trusted, 'trustable', public._fh_hw_facts_ok(c.be, c.attachment) and c.aaguid is not null and c.aaguid <> '00000000-0000-0000-0000-000000000000' and not t.trusted,
           'why_not', case when k.kind = 'hardware' and t.trusted then null
                           when c.aaguid is null or c.aaguid = '00000000-0000-0000-0000-000000000000' then 'This key did not tell its model (anonymous), so it cannot be trusted as a security key.'
                           else public._fh_hw_why_not(c.be, c.attachment, t.trusted) end) order by k.created_at), '[]'::jsonb)
    into v_keys
    from public.founder_passkeys k
    left join public.founder_webauthn_cred c on c.credential_id = k.credential_id
    cross join lateral (select exists (select 1 from public.founder_aaguid_allow a where a.aaguid = c.aaguid and a.enabled) as trusted) t
   where k.user_id = p_uid and k.revoked_at is null;
  select count(*) into v_cands from jsonb_array_elements(v_keys) x where (x ->> 'trustable')::boolean;
  v_next := case when v_hw >= v_need then 'You have enough hardware keys. The hardware-only switch can be turned on.'
                 when v_cands > 0 then 'Trust the model of the security key you registered (button below), then add a second security key.'
                 when v_hw = 0 then 'Add a physical security key (for example a FIDO2 USB or NFC key) with "Add a key". Synced and built-in keys can never count as hardware.'
                 else 'Add another physical security key: ' || (v_need - v_hw) || ' more needed.' end;
  return jsonb_build_object('hardware_keys', v_hw, 'needed', v_need, 'ready', v_hw >= v_need, 'keys', v_keys, 'next', v_next,
    'trusted_models', (select coalesce(jsonb_agg(jsonb_build_object('aaguid', aaguid, 'label', label) order by added_at), '[]'::jsonb) from public.founder_aaguid_allow where enabled));
end $$;

-- 4) selftest ----------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_hardware_e142_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '120s' as $$
declare
  u uuid; d uuid; r text := ''; j jsonb; g uuid; n text; pol public.founder_webauthn_policy%rowtype; f jsonb;
  c_sync text := 'selftestHS_' || encode(extensions.gen_random_bytes(8), 'hex'); c_plat text := 'selftestHP_' || encode(extensions.gen_random_bytes(8), 'hex'); c_key1 text := 'selftestHK1_' || encode(extensions.gen_random_bytes(8), 'hex'); c_key2 text := 'selftestHK2_' || encode(extensions.gen_random_bytes(8), 'hex');
  v_m text := 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'; v_cred text := 'selftestHC_' || encode(extensions.gen_random_bytes(8), 'hex');
  b_pk bigint; b_cred bigint; b_al bigint; b_ev bigint; b_aud bigint; b_dev bigint; b_step bigint; b_pro boolean; v_head text;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E142 selftest SKIP — no founder account'; end if;
  select count(*) into b_pk from public.founder_passkeys; select count(*) into b_cred from public.founder_webauthn_cred; select count(*) into b_al from public.founder_aaguid_allow;
  select count(*), coalesce(max(hash), '') into b_ev, v_head from public.founder_webauthn_event; select count(*) into b_aud from public.founder_audit; select count(*) into b_dev from public.founder_devices;
  select count(*) into b_step from public.founder_stepups; select t2_hardware_only into b_pro from public.founder_protocol where id;
  select * into pol from public.founder_webauthn_policy where id;
  f := jsonb_build_object('origin', pol.origins[1], 'rp_id', pol.rp_id, 'aaguid', v_m, 'cose_alg', -7, 'pk_bytes', 77, 'attestation_fmt', 'packed', 'attestation_trust', 'basic', 'transports', jsonb_build_array('usb'),
                          'attachment', 'cross-platform', 'discoverable', true, 'be', false, 'bs', false, 'uv_initialized', true);
  begin
    update public.founder_protocol set t2_hardware_only = false where id;
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (u, 'selftest hw device', encode(extensions.digest('e142', 'sha256'), 'hex'), now()) returning id into d;
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (u, v_cred, '{"k":0}', 'selftest approver');
    -- 1) a synced key and a platform key that CLAIM a trusted model never count; two real device-bound keys do
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (u, c_sync, '{"k":1}', 'synced claimant'), (u, c_plat, '{"k":2}', 'platform claimant'), (u, c_key1, '{"k":3}', 'security key one'), (u, c_key2, '{"k":4}', 'security key two');
    j := public.founder_webauthn_register(u, c_sync, f || '{"be":true,"bs":true,"transports":["internal","hybrid"],"attachment":"platform"}'::jsonb); if not (j ->> 'ok')::boolean then raise exception 'register synced: %', j; end if;
    j := public.founder_webauthn_register(u, c_plat, f || '{"attachment":"platform","transports":["internal"]}'::jsonb); if not (j ->> 'ok')::boolean then raise exception 'register platform: %', j; end if;
    j := public.founder_webauthn_register(u, c_key1, f); if not (j ->> 'ok')::boolean then raise exception 'register key1: %', j; end if;
    j := public.founder_webauthn_register(u, c_key2, f); if not (j ->> 'ok')::boolean then raise exception 'register key2: %', j; end if;
    j := public.founder_hardware_readiness(u);
    if (j ->> 'hardware_keys')::int <> 0 or (j ->> 'ready')::boolean then raise exception 'nothing is trusted yet, so no key may count: %', j; end if;
    if (select count(*) from jsonb_array_elements(j -> 'keys') x where (x ->> 'trustable')::boolean) <> 2 then raise exception 'exactly the two device-bound keys must be trustable: %', j -> 'keys'; end if;
    if (select x ->> 'why_not' from jsonb_array_elements(j -> 'keys') x where x ->> 'label' = 'synced claimant') not like '%backed up or synced%' or (select x ->> 'why_not' from jsonb_array_elements(j -> 'keys') x where x ->> 'label' = 'platform claimant') not like '%built-in%' then raise exception 'the reasons are not said'; end if;
    if j ->> 'next' not like 'Trust the model%' then raise exception 'next step should be to trust the model: %', j ->> 'next'; end if;
    r := r || 'readiness lists every key with a reason; synced and platform keys are not trustable OK; ';
    -- 2) trust the model through the real T2 door: only the two device-bound keys become hardware, the claimants stay platform
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, v_cred, 'aaguid.allow', v_m, '{"enabled":"yes"}'::jsonb, n); g := (j ->> 'grant')::uuid;
    perform public.founder_aaguid_allow_set(u, d, v_m, 'Selftest security key', true, g, n);
    if (select count(*) from public.founder_passkeys where user_id = u and kind = 'hardware' and credential_id in (c_key1, c_key2)) <> 2 then raise exception 'the two device-bound keys did not become hardware'; end if;
    if exists (select 1 from public.founder_passkeys where credential_id in (c_sync, c_plat) and kind = 'hardware') then raise exception 'a synced or platform key became hardware by claiming a trusted model'; end if;
    j := public.founder_hardware_readiness(u);
    if (j ->> 'hardware_keys')::int <> 2 or not (j ->> 'ready')::boolean or j ->> 'next' not like 'You have enough%' then raise exception 'two real keys must make it ready: %', j; end if;
    r := r || 'trusting the model upgrades only the two device-bound keys OK; ';
    -- 3) the switch: now it can be turned ON (2 hardware keys), and the loophole stays shut when a key later turns out synced
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, c_key1, 'protocol.t2_hardware', 'protocol', jsonb_build_object('on', 'yes'), n); g := (j ->> 'grant')::uuid;
    j := public.founder_protocol_t2_hardware(u, d, true, g, n);
    if not (j ->> 't2_hardware_only')::boolean then raise exception 'the switch did not turn on with two real hardware keys'; end if;
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, c_key1, 'protocol.t2_hardware', 'protocol', jsonb_build_object('on', 'no'), n); g := (j ->> 'grant')::uuid;
    perform public.founder_protocol_t2_hardware(u, d, false, g, n);
    r := r || 'hardware-only turns on with 2 real keys and off again OK; ';
    -- 4) un-trusting the model demotes both keys at once; the ledger and the audit chain recorded the changes
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, v_cred, 'aaguid.allow', v_m, '{"enabled":"no"}'::jsonb, n); g := (j ->> 'grant')::uuid;
    perform public.founder_aaguid_allow_set(u, d, v_m, 'Selftest security key', false, g, n);
    if exists (select 1 from public.founder_passkeys where user_id = u and kind = 'hardware' and credential_id in (c_key1, c_key2)) then raise exception 'un-trusting the model did not demote its keys'; end if;
    if (public.founder_hardware_readiness(u) ->> 'hardware_keys')::int <> 0 then raise exception 'readiness still counts untrusted keys'; end if;
    if not exists (select 1 from public.founder_webauthn_event where credential_id in (c_key1, c_key2) and kind = 'policy_note' and reason like 'key class is now%') then raise exception 'no ledger note about the class change'; end if;
    if (public.founder_webauthn_verify(100000) ->> 'ok')::boolean is not true then raise exception 'event chain broke'; end if;
    r := r || 'un-trust demotes, ledger + chain OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E142 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_passkeys) <> b_pk or (select count(*) from public.founder_webauthn_cred) <> b_cred or (select count(*) from public.founder_aaguid_allow) <> b_al
     or (select count(*) from public.founder_webauthn_event) <> b_ev or coalesce((select max(hash) from public.founder_webauthn_event), '') <> v_head or (select count(*) from public.founder_audit) <> b_aud
     or (select count(*) from public.founder_devices) <> b_dev or (select count(*) from public.founder_stepups) <> b_step or (select t2_hardware_only from public.founder_protocol where id) is distinct from b_pro then
    raise exception 'E142 selftest left rows behind'; end if;
  return 'E142 selftest OK — ' || r || 'rollback clean';
end $$;

do $$ declare f text; begin
  foreach f in array array['public._fh_hw_facts_ok(boolean,text)', 'public._fh_hw_why_not(boolean,text,boolean)', 'public._fh_reclassify(uuid)', 'public._fh_reclassify_cred()', 'public._fh_reclassify_allow()',
                           'public.founder_hardware_readiness(uuid)', 'public.founder_hardware_e142_selftest()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
comment on function public.founder_hardware_readiness(uuid) is 'E142: every active key with model, BE, attachment, whether it counts as hardware and why not; the next step in words.';
comment on function public._fh_reclassify(uuid) is 'E142: key class (hardware/platform) is decided by trusted model AND facts (BE=0, not platform), never by a claim alone.';
do $$ begin raise notice '%', public.founder_hardware_e142_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E142_founder_hardware_truth CHECK_E142  (after fetch). Needs E118 + E139.
-- Undo: drop trigger founder_hw_truth_cred on founder_webauthn_cred; drop trigger founder_hw_truth_allow on founder_aaguid_allow; drop the _fh_hw_* / _fh_reclassify* functions and founder_hardware_*.
