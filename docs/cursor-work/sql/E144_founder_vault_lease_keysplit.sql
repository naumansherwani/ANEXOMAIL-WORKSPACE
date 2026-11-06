-- E144 — Founder J8 v2: KEY-SPLIT + PROOF-OF-POSSESSION + CRYPTO-SHRED (founder 6 Nov 2026 22:17 PKT: "aur advance kero").
-- E143 locks the vault by a clock. A clock can be wound back, and a copied vault file stays readable for ever. E144 makes the lock CRYPTOGRAPHIC:
--   1) KEY SPLIT   vault key = HKDF(local half, SERVER half). The server half is never stored: Rust derives it = HKDF(master secret held only in Rust, device id || shred_nonce).
--                  SQL holds only `shred_nonce` (random 32 bytes). Neither the database nor the Rust binary alone can derive the half. The half is released only inside a fresh lease, kept in browser MEMORY only, wiped when the lease ends.
--   2) CRYPTO-SHRED the moment a device is revoked, shred_nonce is overwritten with NULL for ever (trigger + guard: it can never be set again). The half can then never be derived again, by anyone, even with the master secret:
--                  every copy of that device's vault that was taken without its in-memory half is unreadable for ever. A `shredded` fact goes into the hash-chained ledger and the main audit chain.
--   3) PROOF OF POSSESSION (DPoP-style, RFC 9449 idea) a lease is bound to a non-extractable device key (ECDSA P-256 in WebCrypto): the SHA-256 thumbprint is bound ONCE (first lease) and is immutable. Every renewal carries a signed proof
--                  from that key (Rust verifies the signature; SQL checks thumbprint + a STRICTLY INCREASING proof time inside +-120 s of the server clock). A stolen session token without the device key cannot renew; a replayed proof is refused.
--   4) founder_vault_lease_grant  the ONE door Rust uses now (E143's issue becomes the internal core): bind/verify key, check proof, call the core, return the lease + `half_salt` (shred_nonce hex) only when everything passed.
-- Needs E143. Run it AFTER E143 (E143 re-defines the revoke trigger without the shred step). Safe to run again. Selftest rolls back.

do $$ begin
  if to_regprocedure('public.founder_vault_lease_issue(uuid,uuid,integer)') is null then raise exception 'E144 needs E143 first'; end if;
end $$;

-- 1) columns + rules -------------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:ddl', 0));
  alter table public.founder_vault_lease add column if not exists key_thumb text;
  alter table public.founder_vault_lease add column if not exists last_proof_ms bigint;
  alter table public.founder_vault_lease add column if not exists shred_nonce text;
  alter table public.founder_vault_lease add column if not exists shredded_ms bigint;
  if not exists (select 1 from pg_constraint where conrelid = 'public.founder_vault_lease'::regclass and conname = 'founder_vault_lease_keysplit_shape') then
    alter table public.founder_vault_lease add constraint founder_vault_lease_keysplit_shape check (
      (key_thumb is null or key_thumb ~ '^[A-Za-z0-9_-]{43}$')                       -- base64url SHA-256 JWK thumbprint (RFC 7638)
      and (shred_nonce is null or shred_nonce ~ '^[0-9a-f]{64}$')
      and (shredded_ms is null) = (shred_nonce is not null or revoked_ms is null)    -- shredded exactly when revoked: nonce gone + time set
      and (shredded_ms is null or revoked_ms is not null));
  end if;
  revoke select on public.founder_vault_lease from service_role;                                  -- table-level grant first, else a column revoke does nothing
  grant select (device_id, user_id, serial, issued_ms, expires_ms, ttl_s, revoked_ms, key_thumb, last_proof_ms, shredded_ms) on public.founder_vault_lease to service_role;
  revoke select (shred_nonce, nonce_hash) on public.founder_vault_lease from service_role;     -- the nonce is only ever handed out by the grant function
end $$;
alter table public.founder_vault_lease disable trigger founder_vault_lease_guard;
create or replace function public._fh_vl_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E143: a lease row is never deleted' using errcode = '42501'; end if;
  if new.device_id <> old.device_id or new.user_id <> old.user_id then raise exception 'E143: a lease belongs to one device for ever' using errcode = '42501'; end if;
  if new.serial < old.serial then raise exception 'E143: the lease serial only goes up' using errcode = '42501'; end if;
  if old.revoked_ms is not null and (new.revoked_ms is distinct from old.revoked_ms or new.expires_ms > old.expires_ms or new.serial <> old.serial or new.issued_ms <> old.issued_ms) then
    raise exception 'E143: a revoked device can never get its lease back' using errcode = '42501'; end if;
  if old.key_thumb is not null and new.key_thumb is distinct from old.key_thumb then raise exception 'E144: the device key is bound once and never changes' using errcode = '42501'; end if;
  if old.shred_nonce is null and new.shred_nonce is not null and old.serial >= 1 and old.shredded_ms is not null then raise exception 'E144: a shredded nonce never comes back' using errcode = '42501'; end if;
  if old.shred_nonce is not null and new.shred_nonce is not null and new.shred_nonce <> old.shred_nonce then raise exception 'E144: the shred nonce never changes (the half must stay derivable)' using errcode = '42501'; end if;
  if old.last_proof_ms is not null and new.last_proof_ms is not null and new.last_proof_ms < old.last_proof_ms then raise exception 'E144: proof time only goes up' using errcode = '42501'; end if;
  return new;
end $$;
alter table public.founder_vault_lease enable trigger founder_vault_lease_guard;

-- 2) revoke now also SHREDS --------------------------------------------------------------------------------------------------------------------------
create or replace function public._fh_vl_on_revoke() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_now bigint := public._fh_now_ms(); l public.founder_vault_lease%rowtype; v_ok boolean;
begin
  if old.revoked_at is null and new.revoked_at is not null then
    perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:' || new.id::text, 0));
    update public.founder_vault_lease set revoked_ms = v_now, expires_ms = least(expires_ms, v_now), shred_nonce = null, shredded_ms = v_now where device_id = new.id and revoked_ms is null returning * into l;
    v_ok := public._fh_vl_audit(new.user_id, 'device.vault_lease_cut', new.id::text, 'Device revoked: its vault lease was cut and its key half destroyed for ever', jsonb_build_object('had_lease', l.device_id is not null, 'serial', l.serial, 'label', new.label, 'shredded', l.device_id is not null));
    perform public._fh_vl_log(new.user_id, new.id, l.serial, 'revoked', jsonb_build_object('had_lease', l.device_id is not null, 'cut_at_ms', v_now, 'shredded', l.device_id is not null, 'audited', v_ok));
  end if;
  return new;
end $$;

-- 3) the grant door ----------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_grant(p_uid uuid, p_device uuid, p_key_thumb text, p_proof_ms bigint, p_ttl_s integer default 900) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_now bigint := public._fh_now_ms(); l public.founder_vault_lease%rowtype; r jsonb; v_why text; v_nonce text;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:' || p_device::text, 0));
  v_why := case when p_key_thumb is null or p_key_thumb !~ '^[A-Za-z0-9_-]{43}$' then 'key_required'
                when p_proof_ms is null or abs(p_proof_ms - v_now) > 120000 then 'proof_stale' end;
  if v_why is null then
    select * into l from public.founder_vault_lease where device_id = p_device and user_id = p_uid for update;
    if found then
      v_why := case when l.revoked_ms is not null then 'revoked'
                    when l.key_thumb is not null and l.key_thumb <> p_key_thumb then 'key_mismatch'
                    when l.last_proof_ms is not null and p_proof_ms <= l.last_proof_ms then 'proof_replayed' end;
    end if;
  end if;
  if v_why is not null then
    if v_why <> 'revoked' and exists (select 1 from public.founder_devices d where d.id = p_device and d.user_id = p_uid)
       and not exists (select 1 from public.founder_vault_lease_event e where e.device_id = p_device and e.kind = 'refused' and e.facts ->> 'why' = v_why and e.ts_ms > v_now - 60000) then
      perform public._fh_vl_log(p_uid, p_device, null, 'refused', jsonb_build_object('why', v_why)); end if;
    if v_why <> 'revoked' then return jsonb_build_object('ok', false, 'why', v_why); end if;
  end if;
  r := public.founder_vault_lease_issue(p_uid, p_device, p_ttl_s);                      -- E143 core: owner, approved, not revoked, rate limits, clock guard, ledger
  if (r ->> 'ok')::boolean is not true then return r; end if;
  v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
  update public.founder_vault_lease set key_thumb = coalesce(key_thumb, p_key_thumb), last_proof_ms = p_proof_ms, shred_nonce = coalesce(shred_nonce, v_nonce) where device_id = p_device returning * into l;
  return r || jsonb_build_object('half_salt', l.shred_nonce, 'key_thumb', l.key_thumb);
end $$;

revoke all on function public.founder_vault_lease_grant(uuid, uuid, text, bigint, integer) from public, anon, authenticated;
grant execute on function public.founder_vault_lease_grant(uuid, uuid, text, bigint, integer) to service_role;
-- LOOPHOLE CLOSED: the E143 core skips the device-key proof, so nobody but the grant function (security definer) may call it any more
revoke execute on function public.founder_vault_lease_issue(uuid, uuid, integer) from service_role;

-- 4) selftest (rolls back) -----------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_keysplit_selftest() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_uid uuid; v_dev uuid := gen_random_uuid(); v_dev2 uuid := gen_random_uuid(); r text := ''; a jsonb; b jsonb; v_ok boolean; v_now bigint; k1 text := repeat('A', 43); k2 text := repeat('B', 43);
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E144 selftest SKIP: founder_accounts is empty'; end if;
  begin
    perform set_config('anexo.vl_min_gap_ms', '0', true);
    v_now := public._fh_now_ms();
    insert into public.founder_devices (id, user_id, label, ua_hash, approved_at) values (v_dev, v_uid, 'e144 a', repeat('e', 64), now()), (v_dev2, v_uid, 'e144 b', repeat('f', 64), now());
    a := public.founder_vault_lease_grant(v_uid, v_dev, k1, v_now);
    if (a ->> 'ok')::boolean is not true or length(a ->> 'half_salt') <> 64 or a ->> 'key_thumb' <> k1 then raise exception 'first grant wrong: %', a; end if;
    b := public.founder_vault_lease_grant(v_uid, v_dev, k1, v_now + 1);
    if b ->> 'half_salt' <> a ->> 'half_salt' then raise exception 'half salt changed between renewals (the half must stay derivable)'; end if;
    r := r || 'grant binds key once, salt stable OK; ';
    if (public.founder_vault_lease_grant(v_uid, v_dev, k2, v_now + 2) ->> 'why') <> 'key_mismatch' then raise exception 'a different device key was accepted'; end if;
    if (public.founder_vault_lease_grant(v_uid, v_dev, k1, v_now + 1) ->> 'why') <> 'proof_replayed' then raise exception 'replayed proof accepted'; end if;
    if (public.founder_vault_lease_grant(v_uid, v_dev, k1, v_now - 500000) ->> 'why') <> 'proof_stale' then raise exception 'stale proof accepted'; end if;
    if (public.founder_vault_lease_grant(v_uid, v_dev, null, v_now + 3) ->> 'why') <> 'key_required' or (public.founder_vault_lease_grant(v_uid, v_dev, 'short', v_now + 3) ->> 'why') <> 'key_required' then raise exception 'missing / malformed key accepted'; end if;
    r := r || 'key_mismatch / replay / stale / key_required refused OK; ';
    v_ok := false; begin update public.founder_vault_lease set key_thumb = k2 where device_id = v_dev; exception when others then v_ok := true; end; if not v_ok then raise exception 'key thumb changed'; end if;
    v_ok := false; begin update public.founder_vault_lease set shred_nonce = repeat('1', 64) where device_id = v_dev; exception when others then v_ok := true; end; if not v_ok then raise exception 'shred nonce changed'; end if;
    if has_column_privilege('service_role', 'public.founder_vault_lease', 'shred_nonce', 'select') then raise exception 'service_role can read the nonce'; end if;
    r := r || 'key + nonce immutable, nonce unreadable OK; ';
    update public.founder_devices set revoked_at = now() where id = v_dev;
    if (select shred_nonce from public.founder_vault_lease where device_id = v_dev) is not null or (select shredded_ms from public.founder_vault_lease where device_id = v_dev) is null then raise exception 'revoke did not shred'; end if;
    if (public.founder_vault_lease_grant(v_uid, v_dev, k1, v_now + 10) ->> 'why') <> 'revoked' then raise exception 'revoked device was granted'; end if;
    v_ok := false; begin update public.founder_vault_lease set shred_nonce = repeat('2', 64) where device_id = v_dev; exception when others then v_ok := true; end; if not v_ok then raise exception 'shredded nonce came back'; end if;
    if (select facts ->> 'shredded' from public.founder_vault_lease_event where device_id = v_dev and kind = 'revoked' order by id desc limit 1) <> 'true' then raise exception 'shred not in ledger'; end if;
    r := r || 'revoke shreds for ever + ledger OK; ';
    if public.founder_vault_lease_verify(100000) ->> 'ok' <> 'true' then raise exception 'chain broken after E144 flow'; end if;
    r := r || 'chains still clean OK';
    raise exception 'E144_ROLLBACK:%', r;
  exception when others then
    if sqlerrm like 'E144_ROLLBACK:%' then return 'E144 selftest PASS: ' || substr(sqlerrm, 15); end if;
    return 'E144 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_vault_lease_keysplit_selftest() from public, anon, authenticated;
grant execute on function public.founder_vault_lease_keysplit_selftest() to service_role;
select public.founder_vault_lease_keysplit_selftest();
