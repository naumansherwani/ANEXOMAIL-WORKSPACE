-- E118 — Founder step 7 / phase 7-1b: the chairman protocol (SQL). Decisions of the founder, 1 Nov 2026 13:07 (design note, "7-0 DECIDED").
-- Technology: SQL (Supabase Postgres, RLS on). Rust webauthn-rs (7-2) and the Privacy tab (7-3) come after this is green on the server. No OTP and no SMS exist in this file.
--
--   1) ACTION HASH     founder_action_hash(): one canonical digest of "what the founder is about to do". The WebAuthn challenge of a T2/T3 assertion is this digest.
--   2) TIERS           founder_action_tiers (registry): T2 = fresh passkey bound to the action, T3 = two hardware keys + 10-minute delay + cancel window.
--   3) KEY CLASS       founder_passkeys.kind (platform | hardware) + aaguid; founder_aaguid_allow (starts EMPTY: the founder trusts the model his own key presents; nothing typed from memory).
--   4) PROTOCOL        founder_protocol (single row): t2_hardware_only (starts false = hybrid), T3 delay >= 600 s, window, minimum hardware keys = 2 (database constraints, not code).
--   5) GRANTS          step-up grants now carry (action, action_hash): a grant works for ONE action only. E117's doors passkey_add / passkey_revoke / recovery_codes_generate are replaced
--                      by action-bound versions (same names, new arguments).
--   6) T3              founder_t3_requests: first hardware key starts it, `ready_at >= created_at + 10 min` (constraint), a DIFFERENT hardware key approves inside the window,
--                      any approved device cancels, execution is single use and re-checks the action hash.
--   7) MOBILE FLARE    founder_mobile_flare: E.164 number for ALERT + CANCEL only, confirmed by an inbound reply in 7-5 (never by a code). Mobile recovery needs a confirmed number AND a second proof.
--   8) SELFTEST        behaviour of every door on a POPULATED account, all rolled back. E117's selftests are replaced here (they used the old unbound grants), exactly as E116 did for E113.
-- Safe to run again. Everything the selftest does is rolled back.

-- ==============================================================================================================================
-- 0) prerequisites
-- ==============================================================================================================================
do $$
begin
  if to_regclass('public.founder_passkeys') is null or to_regclass('public.founder_stepups') is null or to_regclass('public.founder_recovery_requests') is null
     or not exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace and proname = 'founder_stepup_issue') then
    raise exception 'E118 needs E117 first';
  end if;
end $$;

-- ==============================================================================================================================
-- 1) canonical action hash
-- ==============================================================================================================================
create or replace function public._fp_canonical(p_action text, p_target text, p_params jsonb, p_nonce text) returns text
language plpgsql immutable set search_path = pg_catalog as $$
declare v_params jsonb := coalesce(p_params, '{}'::jsonb); v_lines text;
begin
  if p_action is null or p_action !~ '^[a-z][a-z0-9_.]{2,63}$' then raise exception 'bad action name' using errcode = '22023'; end if;
  if p_target is null or length(p_target) > 200 or p_target ~ '[\x00-\x1f\x7f]' then raise exception 'bad action target' using errcode = '22023'; end if;
  if p_nonce is null or p_nonce !~ '^[A-Za-z0-9_-]{16,64}$' then raise exception 'bad nonce' using errcode = '22023'; end if;
  if jsonb_typeof(v_params) <> 'object' then raise exception 'params must be an object' using errcode = '22023'; end if;
  if exists (select 1 from jsonb_each(v_params) e where jsonb_typeof(e.value) <> 'string' or length(e.key) > 40 or e.key !~ '^[a-z][a-z0-9_]*$' or length(e.value #>> '{}') > 200 or (e.value #>> '{}') ~ '[\x00-\x1f\x7f]') then
    raise exception 'every param value must be a short string with a plain key' using errcode = '22023';
  end if;
  select coalesce(string_agg(k || '=' || v, E'\n' order by k collate "C"), '') into v_lines from jsonb_each_text(v_params) as t(k, v);
  return 'anexo-action-v1' || E'\n' || p_action || E'\n' || p_target || E'\n' || p_nonce || E'\n' || v_lines;
end $$;

create or replace function public.founder_action_hash(p_action text, p_target text, p_params jsonb, p_nonce text) returns text
language sql immutable set search_path = pg_catalog, extensions as $$
  select encode(digest(public._fp_canonical(p_action, p_target, p_params, p_nonce), 'sha256'), 'hex')
$$;

-- ==============================================================================================================================
-- 2) registries and the protocol row (read-only for service_role)
-- ==============================================================================================================================
create table if not exists public.founder_action_tiers (
  action text primary key check (action ~ '^[a-z][a-z0-9_.]{2,63}$'),
  tier   smallint not null check (tier in (2, 3)),
  label  text not null check (length(label) between 3 and 80),
  built  boolean not null default false                      -- false = the policy is declared, the action itself is built in a later step
);
insert into public.founder_action_tiers (action, tier, label, built) values
  ('passkey.add',                  2, 'Add a passkey',                          true),
  ('passkey.revoke',               2, 'Revoke a passkey',                       true),
  ('recovery.codes',               2, 'Generate new recovery codes',            true),
  ('aaguid.allow',                 2, 'Trust a hardware key model',             true),
  ('protocol.t2_hardware',         2, 'Require hardware keys for T2 steps',     true),
  ('mobile.flare',                 2, 'Change the alert mobile number',         true),
  ('setting.retention_days',       2, 'Change the mail retention window',       false),
  ('setting.require_passkey',      2, 'Change "require passkey for sign-in"',   false),
  ('device.revoke',                2, 'Revoke an approved device',              false),
  ('finance.refund',               2, 'Refund a payment',                       false),
  ('control.kill_switch',          3, 'Kill switch',                            false),
  ('key.rotate',                   3, 'Rotate a signing key',                   false),
  ('data.delete',                  3, 'Delete data',                            false)
on conflict (action) do update set tier = excluded.tier, label = excluded.label, built = excluded.built;

create table if not exists public.founder_aaguid_allow (
  aaguid     text primary key check (aaguid ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
  label      text not null check (length(label) between 2 and 60 and label !~ '[\x00-\x1f\x7f<>]'),
  enabled    boolean not null default true,
  added_by   uuid not null references public.founder_accounts(user_id),
  added_at   timestamptz not null default now(),
  disabled_at timestamptz,
  constraint founder_aaguid_pair check ((enabled and disabled_at is null) or (not enabled and disabled_at is not null))
);

create table if not exists public.founder_protocol (
  id                  boolean primary key default true check (id),
  t2_hardware_only    boolean not null default false,
  t3_delay_seconds    integer not null default 600  check (t3_delay_seconds >= 600),
  t3_window_seconds   integer not null default 1800 check (t3_window_seconds between 600 and 3600),
  t3_min_hardware_keys integer not null default 2   check (t3_min_hardware_keys >= 2),
  changed_at          timestamptz not null default now()
);
insert into public.founder_protocol (id) values (true) on conflict (id) do nothing;

create table if not exists public.founder_mobile_flare (
  user_id      uuid primary key references public.founder_accounts(user_id) on delete cascade,
  e164         text not null check (e164 ~ '^\+[1-9][0-9]{7,14}$'),
  added_at     timestamptz not null default now(),
  confirmed_at timestamptz,
  removed_at   timestamptz
);

create table if not exists public.founder_t3_requests (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.founder_accounts(user_id) on delete cascade,
  device_id          uuid not null references public.founder_devices(id) on delete cascade,
  action             text not null references public.founder_action_tiers(action),
  action_hash        text not null check (action_hash ~ '^[0-9a-f]{64}$'),
  first_credential   text not null,
  second_credential  text,
  state              text not null default 'waiting' check (state in ('waiting','approved','executed','cancelled','expired')),
  created_at         timestamptz not null default now(),
  ready_at           timestamptz not null,
  expires_at         timestamptz not null,
  approved_at        timestamptz,
  executed_at        timestamptz,
  cancelled_at       timestamptz,
  cancelled_by_device uuid references public.founder_devices(id),
  constraint founder_t3_delay check (ready_at >= created_at + interval '10 minutes'),
  constraint founder_t3_window check (expires_at > ready_at and expires_at <= ready_at + interval '60 minutes'),
  constraint founder_t3_two_keys check (second_credential is null or second_credential <> first_credential),
  constraint founder_t3_approved_pair check ((state in ('approved','executed')) = (second_credential is not null))
);
create unique index if not exists founder_t3_one_open_idx on public.founder_t3_requests (user_id, action_hash) where state in ('waiting','approved');

-- columns that classify a credential
alter table public.founder_passkeys add column if not exists kind text not null default 'platform';
alter table public.founder_passkeys add column if not exists aaguid text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'founder_passkeys_kind_ok') then
    alter table public.founder_passkeys add constraint founder_passkeys_kind_ok check (kind in ('platform','hardware'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'founder_passkeys_hardware_aaguid') then
    alter table public.founder_passkeys add constraint founder_passkeys_hardware_aaguid check (kind = 'platform' or aaguid ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  end if;
end $$;

-- grants carry the action they were issued for
alter table public.founder_stepups add column if not exists action text;
alter table public.founder_stepups add column if not exists action_hash text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'founder_stepup_action_pair') then
    -- a g3 grant now names its action and its digest; NOT VALID so nothing older is judged retroactively (the table holds no real grants: E117 selftest rolls back)
    alter table public.founder_stepups add constraint founder_stepup_action_pair check
      ((scope <> 'g3' or (action is not null and action_hash ~ '^[0-9a-f]{64}$')) and (scope = 'g3' or (action is null and action_hash is null))) not valid;
  end if;
end $$;

do $$
declare t text;
begin
  foreach t in array array['founder_action_tiers','founder_aaguid_allow','founder_protocol','founder_mobile_flare','founder_t3_requests'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to service_role', t);
  end loop;
  revoke select on public.founder_passkeys from service_role;
  grant select (id, user_id, credential_id, label, sign_count, created_at, last_used_at, revoked_at, revoked_reason, kind, aaguid) on public.founder_passkeys to service_role;
end $$;
comment on table public.founder_protocol is 'E118: the chairman protocol, one row. The T3 delay (>= 10 minutes) and the two-key minimum are CHECK constraints, not code.';
comment on table public.founder_aaguid_allow is 'E118: hardware key models the founder trusts. Starts empty; filled only by a T2 action on a model his own key presented.';

-- ==============================================================================================================================
-- 3) E117's doors become action-bound (old signatures dropped; E117 selftests dropped, replaced below)
-- ==============================================================================================================================
drop function if exists public.founder_passkey_selftest();
drop function if exists public.founder_passkey_selftest2();
drop function if exists public.founder_passkey_add(uuid, uuid, text, jsonb, text, uuid);
drop function if exists public.founder_passkey_revoke(uuid, uuid, uuid, text, uuid);
drop function if exists public.founder_recovery_codes_generate(uuid, uuid, uuid);
drop function if exists public.founder_stepup_issue(uuid, uuid, text, text);
drop function if exists public.founder_stepup_consume(uuid, uuid, uuid, text, text);

-- a credential's class: 'hardware' only when its AAGUID is an enabled allow-list entry; the check is made when it is used, so disabling a model takes effect at once
create or replace function public._fp_cred_is_hardware(p_uid uuid, p_credential text) returns boolean
language sql stable set search_path = pg_catalog, public as $$
  select exists (select 1 from public.founder_passkeys k join public.founder_aaguid_allow a on a.aaguid = k.aaguid and a.enabled
                  where k.user_id = p_uid and k.credential_id = p_credential and k.revoked_at is null and k.kind = 'hardware')
$$;

-- T2 grant: a fresh passkey assertion for ONE named action (the digest was the WebAuthn challenge). T3 actions are refused here: they go through founder_t3_begin.
create or replace function public.founder_stepup_issue(p_uid uuid, p_device uuid, p_credential_id text, p_action text, p_target text, p_params jsonb, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_tier smallint; v_hash text; v_id uuid; v_exp timestamptz; v_hw boolean;
begin
  perform public._fp_assert_device(p_uid, p_device);
  select tier into v_tier from public.founder_action_tiers where action = p_action;
  if v_tier is null then raise exception 'unknown action' using errcode = '22023'; end if;
  if v_tier <> 2 then raise exception 'this action is T3: it needs two hardware keys and a delay' using errcode = '42501'; end if;
  v_hash := public.founder_action_hash(p_action, p_target, p_params, p_nonce);
  if not exists (select 1 from public.founder_passkeys where user_id = p_uid and credential_id = p_credential_id and revoked_at is null) then raise exception 'unknown or revoked passkey' using errcode = '42501'; end if;
  v_hw := public._fp_cred_is_hardware(p_uid, p_credential_id);
  if (select t2_hardware_only from public.founder_protocol where id) and not v_hw then raise exception 'T2 steps need an allow-listed hardware key' using errcode = '42501'; end if;
  update public.founder_stepups set used_at = now(), used_for = 'replaced' where user_id = p_uid and device_id = p_device and scope = 'g3' and action = p_action and used_at is null;
  insert into public.founder_stepups (user_id, device_id, credential_id, scope, action, action_hash) values (p_uid, p_device, p_credential_id, 'g3', p_action, v_hash) returning id, expires_at into v_id, v_exp;
  perform public.founder_audit_append(p_uid, 'passkey.stepup', p_action, 'passkey assertion accepted for ' || p_action, jsonb_build_object('device', p_device, 'tier', 2, 'hash', v_hash, 'hardware', v_hw));
  return jsonb_build_object('grant', v_id, 'action', p_action, 'hash', v_hash, 'hardware', v_hw, 'expires_at_ms', (extract(epoch from v_exp) * 1000)::bigint);
end $$;

-- the ONE check a protected action goes through: same grant, same device, same action, same digest (recomputed here from the facts), unused, unexpired
create or replace function public._fp_consume_action(p_uid uuid, p_device uuid, p_grant uuid, p_action text, p_target text, p_params jsonb, p_nonce text) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid; v_hash text := public.founder_action_hash(p_action, p_target, p_params, p_nonce);
begin
  perform public._fp_assert_device(p_uid, p_device);
  update public.founder_stepups set used_at = now(), used_for = p_action
   where id = p_grant and user_id = p_uid and device_id = p_device and scope = 'g3' and action = p_action and action_hash = v_hash and used_at is null and expires_at > now()
   returning id into v_id;
  if v_id is null then raise exception 'step-up grant missing, used, expired, for another device or for another action' using errcode = '42501'; end if;
  perform public.founder_audit_append(p_uid, 'passkey.stepup_used', p_action, 'passkey grant used for ' || p_action, jsonb_build_object('device', p_device, 'hash', v_hash));
  return true;
end $$;
create or replace function public.founder_stepup_consume(p_uid uuid, p_device uuid, p_grant uuid, p_action text, p_target text, p_params jsonb, p_nonce text) returns boolean
language sql security definer set search_path = pg_catalog, public, extensions as $$
  select public._fp_consume_action(p_uid, p_device, p_grant, p_action, p_target, p_params, p_nonce)
$$;

-- add a passkey. The first one needs the approved device only; every further one is a T2 action ('passkey.add', target = the credential id, param label). A recovery grant also works, once.
create or replace function public.founder_passkey_add(p_uid uuid, p_device uuid, p_credential_id text, p_passkey jsonb, p_label text, p_aaguid text, p_grant uuid default null, p_nonce text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n integer; v_id uuid; v_via text; v_kind text := 'platform'; v_aag text := null;
begin
  perform public._fp_assert_device(p_uid, p_device);
  select public._fp_active_count(p_uid) into v_n;
  if v_n >= 5 then raise exception 'at most 5 passkeys' using errcode = '22023'; end if;
  if p_label is null or length(btrim(p_label)) not between 1 and 40 or p_label ~ '[\x00-\x1f\x7f<>]' then raise exception 'passkey name: 1 to 40 characters' using errcode = '22023'; end if;
  if p_aaguid is not null and p_aaguid ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and exists (select 1 from public.founder_aaguid_allow where aaguid = p_aaguid and enabled) then
    v_kind := 'hardware'; v_aag := p_aaguid;                              -- hardware only when the model is on the founder's own allow-list
  end if;
  if v_n = 0 then
    v_via := 'first';
  elsif p_grant is not null and exists (select 1 from public.founder_stepups where id = p_grant and user_id = p_uid and scope = 'recovery') then
    update public.founder_stepups set used_at = now(), used_for = 'passkey.add' where id = p_grant and user_id = p_uid and device_id = p_device and scope = 'recovery' and used_at is null and expires_at > now() returning id into v_id;
    if v_id is null then raise exception 'recovery grant used, expired or for another device' using errcode = '42501'; end if;
    v_via := 'recovery';
  else
    if p_grant is null or p_nonce is null then raise exception 'adding a passkey needs a T2 step-up grant' using errcode = '42501'; end if;
    perform public._fp_consume_action(p_uid, p_device, p_grant, 'passkey.add', p_credential_id, jsonb_build_object('label', btrim(p_label)), p_nonce);
    v_via := 't2';
  end if;
  insert into public.founder_passkeys (user_id, credential_id, passkey, label, kind, aaguid) values (p_uid, p_credential_id, p_passkey, btrim(p_label), v_kind, v_aag) returning id into v_id;
  perform public.founder_audit_append(p_uid, 'passkey.add', left(p_credential_id, 12), 'passkey added: ' || btrim(p_label), jsonb_build_object('device', p_device, 'via', v_via, 'active', v_n + 1, 'kind', v_kind));
  return jsonb_build_object('id', v_id, 'active', v_n + 1, 'via', v_via, 'kind', v_kind);
end $$;

create or replace function public.founder_passkey_revoke(p_uid uuid, p_device uuid, p_id uuid, p_reason text, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_passkeys%rowtype;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_reason is null or length(btrim(p_reason)) not between 8 and 300 then raise exception 'say why (8 to 300 characters)' using errcode = '22023'; end if;
  select * into r from public.founder_passkeys where id = p_id and user_id = p_uid and revoked_at is null for update;
  if not found then raise exception 'no such active passkey' using errcode = '22023'; end if;
  if public._fp_active_count(p_uid) <= 1 then raise exception 'the last passkey cannot be revoked; use recovery' using errcode = '22023'; end if;
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'passkey.revoke', r.credential_id, jsonb_build_object('reason', btrim(p_reason)), p_nonce);
  update public.founder_passkeys set revoked_at = now(), revoked_reason = btrim(p_reason) where id = r.id;
  perform public.founder_audit_append(p_uid, 'passkey.revoke', left(r.credential_id, 12), btrim(p_reason), jsonb_build_object('device', p_device, 'label', r.label));
  return jsonb_build_object('revoked', r.id, 'active', public._fp_active_count(p_uid));
end $$;

create or replace function public.founder_recovery_codes_generate(p_uid uuid, p_device uuid, p_grant uuid default null, p_nonce text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_batch uuid := gen_random_uuid(); v_codes text[] := '{}'; v_code text; v_raw bytea; i integer; j integer; v_alpha text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; v_plain text;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if public._fp_active_count(p_uid) > 0 then perform public._fp_consume_action(p_uid, p_device, p_grant, 'recovery.codes', 'new batch', '{}'::jsonb, p_nonce); end if;
  update public.founder_recovery_codes set retired_at = now() where user_id = p_uid and used_at is null and retired_at is null;
  for i in 1..10 loop
    v_raw := gen_random_bytes(20); v_plain := '';
    for j in 0..19 loop v_plain := v_plain || substr(v_alpha, (get_byte(v_raw, j) % 32) + 1, 1); end loop;
    v_code := substr(v_plain, 1, 5) || '-' || substr(v_plain, 6, 5) || '-' || substr(v_plain, 11, 5) || '-' || substr(v_plain, 16, 5);
    insert into public.founder_recovery_codes (user_id, batch_id, code_hash) values (p_uid, v_batch, public._fp_code_hash(v_code));
    v_codes := v_codes || v_code;
  end loop;
  perform public.founder_audit_append(p_uid, 'recovery.codes', 'new batch', 'ten recovery codes generated, older unused codes retired', jsonb_build_object('device', p_device, 'batch', v_batch));
  return jsonb_build_object('codes', to_jsonb(v_codes), 'batch', v_batch);
end $$;

-- ==============================================================================================================================
-- 4) hardware allow-list + protocol switch (both T2)
-- ==============================================================================================================================
create or replace function public.founder_aaguid_allow_set(p_uid uuid, p_device uuid, p_aaguid text, p_label text, p_enabled boolean, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_aaguid is null or p_aaguid !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'bad AAGUID' using errcode = '22023'; end if;
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'aaguid.allow', p_aaguid, jsonb_build_object('enabled', case when p_enabled then 'yes' else 'no' end), p_nonce);
  if p_enabled then
    insert into public.founder_aaguid_allow (aaguid, label, added_by) values (p_aaguid, btrim(coalesce(p_label, 'Hardware key')), p_uid)
      on conflict (aaguid) do update set enabled = true, disabled_at = null, label = excluded.label;
  else
    update public.founder_aaguid_allow set enabled = false, disabled_at = now() where aaguid = p_aaguid;
  end if;
  perform public.founder_audit_append(p_uid, 'protocol.aaguid', p_aaguid, case when p_enabled then 'hardware key model trusted' else 'hardware key model no longer trusted' end, jsonb_build_object('device', p_device, 'label', p_label));
  return jsonb_build_object('aaguid', p_aaguid, 'enabled', p_enabled);
end $$;

create or replace function public.founder_protocol_t2_hardware(p_uid uuid, p_device uuid, p_on boolean, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fp_assert_device(p_uid, p_device);
  -- switching it ON locks the founder out if no allow-listed hardware key exists: refuse that, in the database
  if p_on and (select count(*) from public.founder_passkeys k join public.founder_aaguid_allow a on a.aaguid = k.aaguid and a.enabled
                where k.user_id = p_uid and k.revoked_at is null and k.kind = 'hardware') < 2 then
    raise exception 'two active allow-listed hardware keys are needed before T2 can require hardware' using errcode = '22023';
  end if;
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'protocol.t2_hardware', 'protocol', jsonb_build_object('on', case when p_on then 'yes' else 'no' end), p_nonce);
  update public.founder_protocol set t2_hardware_only = p_on, changed_at = now() where id;
  perform public.founder_audit_append(p_uid, 'protocol.t2_hardware', case when p_on then 'on' else 'off' end, 'T2 steps now ' || case when p_on then 'require' else 'accept platform keys instead of' end || ' hardware keys', jsonb_build_object('device', p_device));
  return jsonb_build_object('t2_hardware_only', p_on);
end $$;

-- ==============================================================================================================================
-- 5) T3: two different hardware keys, a 10-minute delay, a cancel window
-- ==============================================================================================================================
-- first key: needs a T3 grant? No: T3 has its own door. The first assertion's challenge is the action digest; Rust verifies it and calls this with the credential id.
create or replace function public.founder_t3_begin(p_uid uuid, p_device uuid, p_credential_id text, p_action text, p_target text, p_params jsonb, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_hash text; v_id uuid; pr public.founder_protocol%rowtype; v_ready timestamptz;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if coalesce((select tier from public.founder_action_tiers where action = p_action), 0) <> 3 then raise exception 'not a T3 action' using errcode = '22023'; end if;
  select * into pr from public.founder_protocol where id;
  if (select count(*) from public.founder_passkeys k join public.founder_aaguid_allow a on a.aaguid = k.aaguid and a.enabled where k.user_id = p_uid and k.revoked_at is null and k.kind = 'hardware') < pr.t3_min_hardware_keys then
    raise exception 'T3 needs % active allow-listed hardware keys', pr.t3_min_hardware_keys using errcode = '42501';
  end if;
  if not public._fp_cred_is_hardware(p_uid, p_credential_id) then raise exception 'T3 needs an allow-listed hardware key' using errcode = '42501'; end if;
  v_hash := public.founder_action_hash(p_action, p_target, p_params, p_nonce);
  v_ready := now() + make_interval(secs => pr.t3_delay_seconds);
  insert into public.founder_t3_requests (user_id, device_id, action, action_hash, first_credential, ready_at, expires_at)
    values (p_uid, p_device, p_action, v_hash, p_credential_id, v_ready, v_ready + make_interval(secs => pr.t3_window_seconds)) returning id into v_id;
  perform public.founder_audit_append(p_uid, 't3.begin', p_action, 'T3 action started with the first hardware key; delay running', jsonb_build_object('device', p_device, 'hash', v_hash, 'request', v_id, 'ready_ms', (extract(epoch from v_ready) * 1000)::bigint));
  return jsonb_build_object('request', v_id, 'state', 'waiting', 'ready_ms', (extract(epoch from v_ready) * 1000)::bigint, 'hash', v_hash);
end $$;

-- second key: a DIFFERENT hardware credential, after the delay, inside the window, for the same digest
create or replace function public.founder_t3_approve(p_uid uuid, p_device uuid, p_request uuid, p_credential_id text, p_action text, p_target text, p_params jsonb, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_t3_requests%rowtype; v_hash text := public.founder_action_hash(p_action, p_target, p_params, p_nonce);
begin
  perform public._fp_assert_device(p_uid, p_device);
  select * into r from public.founder_t3_requests where id = p_request and user_id = p_uid for update;
  if not found or r.state <> 'waiting' then raise exception 'no waiting T3 request' using errcode = '22023'; end if;
  if r.action <> p_action or r.action_hash <> v_hash then raise exception 'this is not the action that was started' using errcode = '42501'; end if;
  if now() < r.ready_at then raise exception 'the T3 delay is still running' using errcode = '42501'; end if;
  if now() >= r.expires_at then raise exception 'the T3 window has closed' using errcode = '42501'; end if;
  if p_credential_id = r.first_credential then raise exception 'the second key must be a different key' using errcode = '42501'; end if;
  if not public._fp_cred_is_hardware(p_uid, p_credential_id) then raise exception 'T3 needs an allow-listed hardware key' using errcode = '42501'; end if;
  update public.founder_t3_requests set state = 'approved', second_credential = p_credential_id, approved_at = now() where id = r.id;
  perform public.founder_audit_append(p_uid, 't3.approve', p_action, 'T3 action approved by the second hardware key', jsonb_build_object('device', p_device, 'request', r.id, 'hash', v_hash));
  return jsonb_build_object('request', r.id, 'state', 'approved');
end $$;

-- execution is single use and re-checks the digest right before the action runs
create or replace function public.founder_t3_execute(p_uid uuid, p_device uuid, p_request uuid, p_action text, p_target text, p_params jsonb, p_nonce text) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid; v_hash text := public.founder_action_hash(p_action, p_target, p_params, p_nonce);
begin
  perform public._fp_assert_device(p_uid, p_device);
  update public.founder_t3_requests set state = 'executed', executed_at = now()
   where id = p_request and user_id = p_uid and state = 'approved' and action = p_action and action_hash = v_hash and now() < expires_at returning id into v_id;
  if v_id is null then raise exception 'T3 request not approved, used, expired or for another action' using errcode = '42501'; end if;
  perform public.founder_audit_append(p_uid, 't3.execute', p_action, 'T3 action executed', jsonb_build_object('device', p_device, 'request', p_request, 'hash', v_hash));
  return true;
end $$;

create or replace function public.founder_t3_cancel(p_uid uuid, p_device uuid, p_request uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n integer;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_reason is null or length(btrim(p_reason)) not between 8 and 300 then raise exception 'say why (8 to 300 characters)' using errcode = '22023'; end if;
  update public.founder_t3_requests set state = 'cancelled', cancelled_at = now(), cancelled_by_device = p_device where id = p_request and user_id = p_uid and state in ('waiting','approved');
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'nothing to cancel' using errcode = '22023'; end if;
  perform public.founder_audit_append(p_uid, 't3.cancel', p_request::text, btrim(p_reason), jsonb_build_object('device', p_device));
  return jsonb_build_object('cancelled', p_request);
end $$;

create or replace function public.founder_t3_tick(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare n integer;
begin
  update public.founder_t3_requests set state = 'expired' where state in ('waiting','approved') and expires_at <= p_now;
  get diagnostics n = row_count;
  return jsonb_build_object('expired', n);
end $$;

-- ==============================================================================================================================
-- 6) mobile flare (alert + cancel only; never a way in) and the recovery proof
-- ==============================================================================================================================
create or replace function public.founder_mobile_flare_set(p_uid uuid, p_device uuid, p_e164 text, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_e164 is null or p_e164 !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'number must be in international format, e.g. +923001234567' using errcode = '22023'; end if;
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'mobile.flare', 'alert number', jsonb_build_object('last4', right(p_e164, 4)), p_nonce);
  insert into public.founder_mobile_flare (user_id, e164) values (p_uid, p_e164)
    on conflict (user_id) do update set e164 = excluded.e164, added_at = now(), confirmed_at = null, removed_at = null;
  perform public.founder_audit_append(p_uid, 'mobile.flare', 'set', 'alert number registered; not confirmed until the owner replies from it', jsonb_build_object('device', p_device, 'last4', right(p_e164, 4)));
  return jsonb_build_object('registered', true, 'confirmed', false, 'last4', right(p_e164, 4));
end $$;

-- confirmation comes from an inbound reply (Rust, phase 7-5), never from a typed code
create or replace function public.founder_mobile_flare_confirm(p_uid uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n integer;
begin
  perform public._fs_assert_founder(p_uid);
  update public.founder_mobile_flare set confirmed_at = now() where user_id = p_uid and removed_at is null and confirmed_at is null;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'no unconfirmed number' using errcode = '22023'; end if;
  perform public.founder_audit_append(p_uid, 'mobile.flare', 'confirmed', 'alert number confirmed by an inbound reply', '{}'::jsonb);
  return jsonb_build_object('confirmed', true);
end $$;

create or replace function public.founder_mobile_flare_remove(p_uid uuid, p_device uuid, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fp_assert_device(p_uid, p_device);
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'mobile.flare', 'alert number', jsonb_build_object('last4', 'none'), p_nonce);
  update public.founder_mobile_flare set removed_at = now() where user_id = p_uid and removed_at is null;
  perform public.founder_audit_append(p_uid, 'mobile.flare', 'removed', 'alert number removed', jsonb_build_object('device', p_device));
  return jsonb_build_object('removed', true);
end $$;

alter table public.founder_recovery_requests add column if not exists proof text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'founder_recovery_proof_ok') then
    alter table public.founder_recovery_requests add constraint founder_recovery_proof_ok check (proof is null or proof in ('code','hardware'));
  end if;
end $$;

-- mobile recovery: a confirmed number, at most 3 requests a week; the request is only a flare (24 h pending, cancellable) and cannot complete without a second proof
create or replace function public.founder_recovery_open(p_uid uuid, p_channel text, p_code text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid; v_ready timestamptz; v_row uuid; v_fails integer;
begin
  perform public._fs_assert_founder(p_uid);
  if p_channel not in ('code','mobile') then raise exception 'unknown recovery channel' using errcode = '22023'; end if;
  select count(*) into v_fails from public.founder_recovery_failures where user_id = p_uid and at > now() - interval '1 hour';
  if v_fails >= 5 then raise exception 'too many wrong recovery attempts; try again in an hour' using errcode = '42501'; end if;
  if exists (select 1 from public.founder_recovery_requests where user_id = p_uid and state in ('pending','ready')) then raise exception 'a recovery is already open' using errcode = '22023'; end if;
  if p_channel = 'code' then
    select id into v_row from public.founder_recovery_codes where user_id = p_uid and code_hash = public._fp_code_hash(p_code) and used_at is null and retired_at is null for update;
    if v_row is null then
      insert into public.founder_recovery_failures (user_id) values (p_uid);
      perform public.founder_audit_append(p_uid, 'recovery.fail', 'code', 'a wrong recovery code was tried', jsonb_build_object('fails_last_hour', v_fails + 1));
      return jsonb_build_object('ok', false, 'reason', 'wrong or used code');
    end if;
    update public.founder_recovery_codes set used_at = now() where id = v_row;
    v_ready := now();
  else
    if not exists (select 1 from public.founder_mobile_flare where user_id = p_uid and confirmed_at is not null and removed_at is null) then raise exception 'no confirmed alert number' using errcode = '42501'; end if;
    if (select count(*) from public.founder_recovery_requests where user_id = p_uid and channel = 'mobile' and created_at > now() - interval '7 days') >= 3 then raise exception 'at most 3 mobile recovery requests a week' using errcode = '42501'; end if;
    v_ready := now() + interval '24 hours';
  end if;
  insert into public.founder_recovery_requests (user_id, channel, state, ready_at, expires_at, proof)
    values (p_uid, p_channel, case when p_channel = 'code' then 'ready' else 'pending' end, v_ready, v_ready + interval '24 hours', case when p_channel = 'code' then 'code' else null end) returning id into v_id;
  perform public.founder_audit_append(p_uid, 'recovery.open', p_channel, case when p_channel = 'code' then 'recovery opened with a recovery code' else 'recovery flare raised from the alert number; 24 hour cooling-off started' end,
                                      jsonb_build_object('request', v_id, 'ready_ms', (extract(epoch from v_ready) * 1000)::bigint));
  return jsonb_build_object('ok', true, 'request', v_id, 'state', case when p_channel = 'code' then 'ready' else 'pending' end, 'ready_ms', (extract(epoch from v_ready) * 1000)::bigint, 'needs_proof', p_channel = 'mobile');
end $$;

-- the second proof of a mobile recovery: a recovery code, or a hardware key (Rust verified the assertion; the key must be an active allow-listed hardware credential)
create or replace function public.founder_recovery_prove(p_uid uuid, p_request uuid, p_kind text, p_code text default null, p_credential_id text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_row uuid; v_n integer; v_fails integer;
begin
  perform public._fs_assert_founder(p_uid);
  if p_kind not in ('code','hardware') then raise exception 'unknown proof' using errcode = '22023'; end if;
  if not exists (select 1 from public.founder_recovery_requests where id = p_request and user_id = p_uid and channel = 'mobile' and state in ('pending','ready') and proof is null) then
    raise exception 'no mobile recovery waiting for a proof' using errcode = '22023';
  end if;
  if p_kind = 'hardware' then
    if not public._fp_cred_is_hardware(p_uid, p_credential_id) then raise exception 'the proof must be an allow-listed hardware key' using errcode = '42501'; end if;
  else
    select count(*) into v_fails from public.founder_recovery_failures where user_id = p_uid and at > now() - interval '1 hour';
    if v_fails >= 5 then raise exception 'too many wrong recovery attempts; try again in an hour' using errcode = '42501'; end if;
    select id into v_row from public.founder_recovery_codes where user_id = p_uid and code_hash = public._fp_code_hash(p_code) and used_at is null and retired_at is null for update;
    if v_row is null then
      insert into public.founder_recovery_failures (user_id) values (p_uid);
      return jsonb_build_object('ok', false, 'reason', 'wrong or used code');
    end if;
    update public.founder_recovery_codes set used_at = now() where id = v_row;
  end if;
  update public.founder_recovery_requests set proof = p_kind where id = p_request;
  get diagnostics v_n = row_count;
  perform public.founder_audit_append(p_uid, 'recovery.prove', p_kind, 'second proof given for a mobile recovery', jsonb_build_object('request', p_request));
  return jsonb_build_object('ok', true, 'proof', p_kind);
end $$;

-- completing a mobile recovery now needs the proof; a code recovery already has one
create or replace function public.founder_recovery_complete(p_uid uuid, p_device uuid, p_request uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n integer; v_id uuid; v_exp timestamptz;
begin
  perform public._fp_assert_device(p_uid, p_device);
  update public.founder_recovery_requests set state = 'completed', completed_at = now()
   where id = p_request and user_id = p_uid and state = 'ready' and ready_at <= now() and expires_at > now() and proof is not null;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'recovery is not ready (cooling off, no second proof, cancelled, expired or already used)' using errcode = '42501'; end if;
  insert into public.founder_stepups (user_id, device_id, credential_id, scope, expires_at) values (p_uid, p_device, null, 'recovery', now() + interval '10 minutes') returning id, expires_at into v_id, v_exp;
  perform public.founder_audit_append(p_uid, 'recovery.complete', p_request::text, 'recovery completed; one new passkey may be added', jsonb_build_object('device', p_device));
  return jsonb_build_object('grant', v_id, 'scope', 'recovery', 'expires_at_ms', (extract(epoch from v_exp) * 1000)::bigint);
end $$;

-- ==============================================================================================================================
-- 7) status for the Privacy tab (no secrets)
-- ==============================================================================================================================
create or replace function public.founder_protocol_status(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare pr public.founder_protocol%rowtype; v_hw integer;
begin
  perform public._fs_assert_founder(p_uid);
  select * into pr from public.founder_protocol where id;
  select count(*) into v_hw from public.founder_passkeys k join public.founder_aaguid_allow a on a.aaguid = k.aaguid and a.enabled where k.user_id = p_uid and k.revoked_at is null and k.kind = 'hardware';
  return public.founder_passkey_status(p_uid) || jsonb_build_object(
    'hardware_keys', v_hw, 'platform_keys', public._fp_active_count(p_uid) - v_hw, 't2_hardware_only', pr.t2_hardware_only,
    't3_ready', v_hw >= pr.t3_min_hardware_keys, 't3_delay_seconds', pr.t3_delay_seconds, 't3_window_seconds', pr.t3_window_seconds,
    'trusted_models', (select coalesce(jsonb_agg(jsonb_build_object('aaguid', aaguid, 'label', label) order by added_at), '[]'::jsonb) from public.founder_aaguid_allow where enabled),
    'mobile', (select jsonb_build_object('registered', removed_at is null, 'confirmed', confirmed_at is not null and removed_at is null, 'last4', right(e164, 4)) from public.founder_mobile_flare where user_id = p_uid),
    't3_open', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'action', action, 'state', state, 'ready_ms', (extract(epoch from ready_at) * 1000)::bigint, 'expires_ms', (extract(epoch from expires_at) * 1000)::bigint)), '[]'::jsonb)
                  from public.founder_t3_requests where user_id = p_uid and state in ('waiting','approved')),
    'tiers', (select coalesce(jsonb_agg(jsonb_build_object('action', action, 'tier', tier, 'label', label, 'built', built) order by tier, action), '[]'::jsonb) from public.founder_action_tiers));
end $$;

-- ==============================================================================================================================
-- 8) grants
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public.founder_action_hash(text,text,jsonb,text)','public.founder_stepup_issue(uuid,uuid,text,text,text,jsonb,text)','public.founder_stepup_consume(uuid,uuid,uuid,text,text,jsonb,text)',
    'public.founder_passkey_add(uuid,uuid,text,jsonb,text,text,uuid,text)','public.founder_passkey_revoke(uuid,uuid,uuid,text,uuid,text)','public.founder_recovery_codes_generate(uuid,uuid,uuid,text)',
    'public.founder_aaguid_allow_set(uuid,uuid,text,text,boolean,uuid,text)','public.founder_protocol_t2_hardware(uuid,uuid,boolean,uuid,text)',
    'public.founder_t3_begin(uuid,uuid,text,text,text,jsonb,text)','public.founder_t3_approve(uuid,uuid,uuid,text,text,text,jsonb,text)','public.founder_t3_execute(uuid,uuid,uuid,text,text,jsonb,text)',
    'public.founder_t3_cancel(uuid,uuid,uuid,text)','public.founder_t3_tick(timestamptz)','public.founder_mobile_flare_set(uuid,uuid,text,uuid,text)','public.founder_mobile_flare_confirm(uuid)',
    'public.founder_mobile_flare_remove(uuid,uuid,uuid,text)','public.founder_recovery_open(uuid,text,text)','public.founder_recovery_prove(uuid,uuid,text,text,text)',
    'public.founder_recovery_complete(uuid,uuid,uuid)','public.founder_protocol_status(uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
  revoke all on function public._fp_canonical(text,text,jsonb,text), public._fp_cred_is_hardware(uuid,text), public._fp_consume_action(uuid,uuid,uuid,text,text,jsonb,text) from public, anon, authenticated;
end $$;

-- ==============================================================================================================================
-- 9) selftest — behaviour of every door on a POPULATED account, all rolled back
-- ==============================================================================================================================
create or replace function public.founder_chairman_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '120s' as $$
declare
  u uuid; d uuid; d2 uuid; r text := ''; j jsonb; g uuid; n text; codes jsonb; req uuid; t3 uuid; pid uuid; k record;
  A1 constant text := 'AAAAAAAAAAAAAAAAAAAA1'; P2 constant text := 'PPPPPPPPPPPPPPPPPPPP2'; H1 constant text := 'HHHHHHHHHHHHHHHHHHHH1'; H2 constant text := 'HHHHHHHHHHHHHHHHHHHH2'; P3 constant text := 'QQQQQQQQQQQQQQQQQQQQ3';
  X constant text := '2fc0579f-8113-47ea-b116-bb5a8db9202a'; Y constant text := '0d1c2b3a-4f5e-4d6c-8b7a-9a8b7c6d5e4f';
  v_hash text; v_expected text;
  b_pk bigint; b_step bigint; b_aag bigint; b_t3 bigint; b_fl bigint; b_code bigint; b_req bigint; b_audit bigint; b_dev bigint; b_pro boolean;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E118 selftest SKIP — no founder account'; end if;
  select count(*) into b_pk from public.founder_passkeys; select count(*) into b_step from public.founder_stepups; select count(*) into b_aag from public.founder_aaguid_allow;
  select count(*) into b_t3 from public.founder_t3_requests; select count(*) into b_fl from public.founder_mobile_flare; select count(*) into b_code from public.founder_recovery_codes;
  select count(*) into b_req from public.founder_recovery_requests; select count(*) into b_audit from public.founder_audit; select count(*) into b_dev from public.founder_devices;
  select t2_hardware_only into b_pro from public.founder_protocol where id;
  begin
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'selftest clean slate' where user_id = u and revoked_at is null;
    update public.founder_recovery_requests set state = 'cancelled', cancelled_at = now() where user_id = u and state in ('pending','ready');
    update public.founder_recovery_codes set retired_at = now() where user_id = u and used_at is null and retired_at is null;
    update public.founder_aaguid_allow set enabled = false, disabled_at = now() where enabled;
    update public.founder_t3_requests set state = 'cancelled', cancelled_at = now() where user_id = u and state in ('waiting','approved');
    update public.founder_protocol set t2_hardware_only = false where id;
    delete from public.founder_recovery_failures where user_id = u;
    delete from public.founder_mobile_flare where user_id = u;
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (u, 'selftest device one', encode(digest('e118-one', 'sha256'), 'hex'), now()) returning id into d;
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (u, 'selftest device two', encode(digest('e118-two', 'sha256'), 'hex'), now()) returning id into d2;

    -- 1) the canonical action hash: matches an independent computation, ignores key order, changes with every field, refuses bad input
    v_expected := encode(digest(E'anexo-action-v1\npasskey.add\ntarget-1\nnonce00000000000001\na=1\nb=2', 'sha256'), 'hex');
    v_hash := public.founder_action_hash('passkey.add', 'target-1', '{"b":"2","a":"1"}'::jsonb, 'nonce00000000000001');
    if v_hash <> v_expected then raise exception 'action hash differs from the spec: % vs %', v_hash, v_expected; end if;
    if v_hash = public.founder_action_hash('passkey.add', 'target-1', '{"b":"2","a":"1"}'::jsonb, 'nonce00000000000002') then raise exception 'the nonce did not change the hash'; end if;
    if v_hash = public.founder_action_hash('passkey.add', 'target-2', '{"b":"2","a":"1"}'::jsonb, 'nonce00000000000001') then raise exception 'the target did not change the hash'; end if;
    if v_hash = public.founder_action_hash('passkey.revoke', 'target-1', '{"b":"2","a":"1"}'::jsonb, 'nonce00000000000001') then raise exception 'the action did not change the hash'; end if;
    if public.founder_action_hash('a.bc', 'x', null, 'nonce00000000000001') <> encode(digest(E'anexo-action-v1\na.bc\nx\nnonce00000000000001\n', 'sha256'), 'hex') then raise exception 'empty params must hash as an empty line list'; end if;
    if not public._fs_fails($q$select public.founder_action_hash('passkey.add','t','{"a":1}'::jsonb,'nonce00000000000001')$q$) then raise exception 'a number param was accepted'; end if;
    if not public._fs_fails($q$select public.founder_action_hash('passkey.add','t','[]'::jsonb,'nonce00000000000001')$q$) then raise exception 'array params were accepted'; end if;
    if not public._fs_fails($q$select public.founder_action_hash('passkey.add','t','{}'::jsonb,'short')$q$) then raise exception 'a short nonce was accepted'; end if;
    if not public._fs_fails($q$select public.founder_action_hash('Bad Action','t','{}'::jsonb,'nonce00000000000001')$q$) then raise exception 'a bad action name was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_action_hash('passkey.add',%L,'{}'::jsonb,'nonce00000000000001')$q$, 'new' || chr(10) || 'line')) then raise exception 'a newline in the target was accepted'; end if;
    r := r || 'action hash OK; ';

    -- 2) first passkey (platform), then a T2 grant bound to ONE action
    j := public.founder_passkey_add(u, d, A1, '{"cred":"one"}'::jsonb, 'Laptop passkey', null);
    if (j ->> 'via') <> 'first' or (j ->> 'kind') <> 'platform' then raise exception 'first passkey: %', j; end if;
    n := md5(random()::text);
    j := public.founder_stepup_issue(u, d, A1, 'recovery.codes', 'new batch', '{}'::jsonb, n); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'passkey.revoke', 'new batch', '{}'::jsonb, %L)$q$, u, d, g, n)) then raise exception 'a recovery.codes grant worked for another action'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'recovery.codes', 'other target', '{}'::jsonb, %L)$q$, u, d, g, n)) then raise exception 'a grant worked for another target'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'recovery.codes', 'new batch', '{}'::jsonb, %L)$q$, u, d, g, md5('x'))) then raise exception 'a grant worked with another nonce'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'recovery.codes', 'new batch', '{}'::jsonb, %L)$q$, u, d2, g, n)) then raise exception 'a grant worked on another device'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_issue(%L, %L, %L, 'control.kill_switch', 'all', '{}'::jsonb, %L)$q$, u, d, A1, md5('k'))) then raise exception 'a T3 action got a T2 grant'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_issue(%L, %L, 'NOSUCHCREDENTIAL0000', 'recovery.codes', 'new batch', '{}'::jsonb, %L)$q$, u, d, md5('u'))) then raise exception 'an unknown passkey got a grant'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_issue(%L, %L, %L, 'made.up', 'x', '{}'::jsonb, %L)$q$, u, d, A1, md5('m'))) then raise exception 'an unknown action got a grant'; end if;
    codes := public.founder_recovery_codes_generate(u, d, g, n) -> 'codes';
    if jsonb_array_length(codes) <> 10 then raise exception 'ten codes expected'; end if;
    if not public._fs_fails(format($q$select public.founder_recovery_codes_generate(%L, %L, %L, %L)$q$, u, d, g, n)) then raise exception 'one grant made two code batches'; end if;
    r := r || 'T2 binding OK; ';

    -- 3) recovery by code -> a recovery grant adds ONE passkey (platform: model Y is not on the allow-list)
    j := public.founder_recovery_open(u, 'code', 'WRONG-WRONG-WRONG-WRONG');
    if (j ->> 'ok')::boolean then raise exception 'a wrong code opened recovery'; end if;
    j := public.founder_recovery_open(u, 'code', codes ->> 0);
    if (j ->> 'state') <> 'ready' then raise exception 'a code should open a ready recovery: %', j; end if;
    req := (j ->> 'request')::uuid;
    j := public.founder_recovery_complete(u, d, req); g := (j ->> 'grant')::uuid;
    j := public.founder_passkey_add(u, d, P2, '{"cred":"p2"}'::jsonb, 'Phone passkey', Y, g, null);
    if (j ->> 'via') <> 'recovery' or (j ->> 'kind') <> 'platform' then raise exception 'recovery add: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_add(%L, %L, %L, '{}'::jsonb, 'Again', null, %L, null)$q$, u, d, 'RRRRRRRRRRRRRRRRRRRR9', g)) then raise exception 'a recovery grant added two passkeys'; end if;
    r := r || 'recovery by code OK; ';

    -- 4) hardware: T2 'aaguid.allow' on a model the key presented; hardware key is added only for allow-listed models
    delete from public.founder_recovery_failures where user_id = u;
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, A1, 'aaguid.allow', X, jsonb_build_object('enabled', 'yes'), n); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_aaguid_allow_set(%L, %L, %L, 'Wrong model', true, %L, %L)$q$, u, d, Y, g, n)) then raise exception 'a grant for model X allowed model Y'; end if;
    perform public.founder_aaguid_allow_set(u, d, X, 'Test FIDO2 key', true, g, n);
    if (select count(*) from public.founder_aaguid_allow where enabled) <> 1 then raise exception 'allow-list should hold exactly the one trusted model'; end if;
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, A1, 'passkey.add', H1, jsonb_build_object('label', 'Hardware one'), n); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_passkey_add(%L, %L, %L, '{}'::jsonb, 'Hardware ONE', %L, %L, %L)$q$, u, d, H1, X, g, n)) then raise exception 'a grant bound to one label allowed another'; end if;
    j := public.founder_passkey_add(u, d, H1, '{"cred":"h1"}'::jsonb, 'Hardware one', X, g, n);
    if (j ->> 'kind') <> 'hardware' or (j ->> 'via') <> 't2' then raise exception 'hardware add: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_add(%L, %L, %L, '{}'::jsonb, 'Hardware one', %L, %L, %L)$q$, u, d, H2, X, g, n)) then raise exception 'a used grant added a key'; end if;
    -- hardware_only cannot be switched on with only one hardware key
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, H1, 'protocol.t2_hardware', 'protocol', jsonb_build_object('on', 'yes'), n); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_protocol_t2_hardware(%L, %L, true, %L, %L)$q$, u, d, g, n)) then raise exception 'hardware-only was switched on with one hardware key'; end if;
    -- T3 cannot even start with one hardware key
    if not public._fs_fails(format($q$select public.founder_t3_begin(%L, %L, %L, 'control.kill_switch', 'all', '{}'::jsonb, %L)$q$, u, d, H1, md5('t3a'))) then raise exception 'T3 started with one hardware key'; end if;
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, H1, 'passkey.add', H2, jsonb_build_object('label', 'Hardware two'), n); g := (j ->> 'grant')::uuid;
    perform public.founder_passkey_add(u, d, H2, '{"cred":"h2"}'::jsonb, 'Hardware two', X, g, n);
    r := r || 'hardware + allow-list OK; ';

    -- 5) hardware-only for T2: on -> platform key refused, hardware accepted -> off
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, A1, 'protocol.t2_hardware', 'protocol', jsonb_build_object('on', 'yes'), n); g := (j ->> 'grant')::uuid;
    perform public.founder_protocol_t2_hardware(u, d, true, g, n);
    if not public._fs_fails(format($q$select public.founder_stepup_issue(%L, %L, %L, 'recovery.codes', 'new batch', '{}'::jsonb, %L)$q$, u, d, A1, md5('p1'))) then raise exception 'a platform key passed while T2 needs hardware'; end if;
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, H1, 'protocol.t2_hardware', 'protocol', jsonb_build_object('on', 'no'), n); g := (j ->> 'grant')::uuid;
    perform public.founder_protocol_t2_hardware(u, d, false, g, n);
    if (select t2_hardware_only from public.founder_protocol where id) then raise exception 'hardware-only should be off again'; end if;
    -- disabling the model takes effect at once
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, A1, 'aaguid.allow', X, jsonb_build_object('enabled', 'no'), n); g := (j ->> 'grant')::uuid;
    perform public.founder_aaguid_allow_set(u, d, X, null, false, g, n);
    if not public._fs_fails(format($q$select public.founder_t3_begin(%L, %L, %L, 'control.kill_switch', 'all', '{}'::jsonb, %L)$q$, u, d, H1, md5('t3b'))) then raise exception 'a disabled model still counted as hardware'; end if;
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, A1, 'aaguid.allow', X, jsonb_build_object('enabled', 'yes'), n); g := (j ->> 'grant')::uuid;
    perform public.founder_aaguid_allow_set(u, d, X, 'Test FIDO2 key', true, g, n);
    r := r || 'T2 hardware-only + model disable OK; ';

    -- 6) T3: two different hardware keys, 10-minute delay, window, single execution, cancel
    if not public._fs_fails(format($q$select public.founder_t3_begin(%L, %L, %L, 'control.kill_switch', 'all', '{}'::jsonb, %L)$q$, u, d, A1, md5('t3c'))) then raise exception 'T3 started with a platform key'; end if;
    if not public._fs_fails(format($q$select public.founder_t3_begin(%L, %L, %L, 'passkey.add', 'all', '{}'::jsonb, %L)$q$, u, d, H1, md5('t3d'))) then raise exception 'a T2 action went through T3'; end if;
    n := md5(random()::text);
    j := public.founder_t3_begin(u, d, H1, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, n); t3 := (j ->> 'request')::uuid;
    if ((j ->> 'ready_ms')::bigint - (extract(epoch from now()) * 1000)::bigint) < 590000 then raise exception 'the T3 delay is shorter than ten minutes: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_t3_begin(%L, %L, %L, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, %L)$q$, u, d, H2, n)) then raise exception 'the same T3 action started twice'; end if;
    if not public._fs_fails(format($q$select public.founder_t3_approve(%L, %L, %L, %L, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, %L)$q$, u, d, t3, H2, n)) then raise exception 'T3 approved inside the delay'; end if;
    if not public._fs_fails(format($q$insert into public.founder_t3_requests (user_id, device_id, action, action_hash, first_credential, ready_at, expires_at) values (%L, %L, 'key.rotate', %L, %L, now() + interval '1 minute', now() + interval '20 minutes')$q$, u, d, repeat('a', 64), H1)) then raise exception 'the database accepted a one-minute T3 delay'; end if;
    update public.founder_t3_requests set created_at = created_at - interval '11 minutes', ready_at = ready_at - interval '11 minutes', expires_at = expires_at - interval '11 minutes' where id = t3;
    if not public._fs_fails(format($q$select public.founder_t3_approve(%L, %L, %L, %L, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, %L)$q$, u, d, t3, H1, n)) then raise exception 'the same key approved its own T3'; end if;
    if not public._fs_fails(format($q$select public.founder_t3_approve(%L, %L, %L, %L, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, %L)$q$, u, d, t3, A1, n)) then raise exception 'a platform key approved T3'; end if;
    if not public._fs_fails(format($q$select public.founder_t3_approve(%L, %L, %L, %L, 'control.kill_switch', 'everything', '{"reason":"selftest"}'::jsonb, %L)$q$, u, d, t3, H2, n)) then raise exception 'T3 approved for another target'; end if;
    if not public._fs_fails(format($q$select public.founder_t3_execute(%L, %L, %L, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, %L)$q$, u, d, t3, n)) then raise exception 'T3 executed before approval'; end if;
    perform public.founder_t3_approve(u, d, t3, H2, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, n);
    if not public._fs_fails(format($q$select public.founder_t3_execute(%L, %L, %L, 'control.kill_switch', 'all', '{"reason":"changed"}'::jsonb, %L)$q$, u, d, t3, n)) then raise exception 'T3 executed with changed parameters'; end if;
    if public.founder_t3_execute(u, d, t3, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, n) is not true then raise exception 'T3 did not execute'; end if;
    if not public._fs_fails(format($q$select public.founder_t3_execute(%L, %L, %L, 'control.kill_switch', 'all', '{"reason":"selftest"}'::jsonb, %L)$q$, u, d, t3, n)) then raise exception 'T3 executed twice'; end if;
    -- cancel from ANOTHER approved device, and expiry by the ticker
    n := md5(random()::text); j := public.founder_t3_begin(u, d, H1, 'data.delete', 'archive', '{}'::jsonb, n); t3 := (j ->> 'request')::uuid;
    if not public._fs_fails(format($q$select public.founder_t3_cancel(%L, %L, %L, 'short')$q$, u, d2, t3)) then raise exception 'cancel without a real reason'; end if;
    perform public.founder_t3_cancel(u, d2, t3, 'selftest cancel from the second device');
    if (select state from public.founder_t3_requests where id = t3) <> 'cancelled' then raise exception 'cancel did not stick'; end if;
    if not public._fs_fails(format($q$select public.founder_t3_cancel(%L, %L, %L, 'selftest cancel twice here')$q$, u, d2, t3)) then raise exception 'cancelled twice'; end if;
    n := md5(random()::text); j := public.founder_t3_begin(u, d, H1, 'key.rotate', 'signing', '{}'::jsonb, n); t3 := (j ->> 'request')::uuid;
    update public.founder_t3_requests set created_at = created_at - interval '3 hours', ready_at = ready_at - interval '3 hours', expires_at = expires_at - interval '3 hours' where id = t3;
    if (public.founder_t3_tick() ->> 'expired')::integer < 1 then raise exception 'the ticker did not expire a stale T3'; end if;
    if not public._fs_fails(format($q$select public.founder_t3_approve(%L, %L, %L, %L, 'key.rotate', 'signing', '{}'::jsonb, %L)$q$, u, d, t3, H2, n)) then raise exception 'an expired T3 was approved'; end if;
    r := r || 'T3 OK; ';

    -- 7) mobile flare: alert + cancel only. Bad number refused, unconfirmed number cannot start recovery, confirmed needs a 2nd proof
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, A1, 'mobile.flare', 'alert number', jsonb_build_object('last4', '4567'), n); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_mobile_flare_set(%L, %L, '03001234567', %L, %L)$q$, u, d, g, n)) then raise exception 'a non-international number was accepted'; end if;
    j := public.founder_mobile_flare_set(u, d, '+923001234567', g, n);
    if (j ->> 'confirmed')::boolean then raise exception 'a number was confirmed without a reply'; end if;
    if not public._fs_fails(format($q$select public.founder_recovery_open(%L, 'mobile', null)$q$, u)) then raise exception 'an unconfirmed number started recovery'; end if;
    perform public.founder_mobile_flare_confirm(u);
    j := public.founder_recovery_open(u, 'mobile', null);
    if (j ->> 'state') <> 'pending' or not (j ->> 'needs_proof')::boolean then raise exception 'mobile recovery should be pending and need a proof: %', j; end if;
    req := (j ->> 'request')::uuid;
    if ((j ->> 'ready_ms')::bigint - (extract(epoch from now()) * 1000)::bigint) < 86300000 then raise exception 'mobile cooling-off is shorter than 24 h'; end if;
    if not public._fs_fails(format($q$select public.founder_recovery_complete(%L, %L, %L)$q$, u, d, req)) then raise exception 'recovery completed inside the 24 h'; end if;
    update public.founder_recovery_requests set created_at = created_at - interval '25 hours', ready_at = ready_at - interval '25 hours', expires_at = expires_at - interval '25 hours' where id = req;
    perform public.founder_recovery_tick();
    if not public._fs_fails(format($q$select public.founder_recovery_complete(%L, %L, %L)$q$, u, d, req)) then raise exception 'mobile recovery completed with no second proof'; end if;
    if not public._fs_fails(format($q$select public.founder_recovery_prove(%L, %L, 'hardware', null, %L)$q$, u, req, A1)) then raise exception 'a platform key counted as a hardware proof'; end if;
    j := public.founder_recovery_prove(u, req, 'code', 'WRONG-WRONG-WRONG-WRONG');
    if (j ->> 'ok')::boolean then raise exception 'a wrong code counted as a proof'; end if;
    j := public.founder_recovery_prove(u, req, 'hardware', null, H2);
    if not (j ->> 'ok')::boolean then raise exception 'a hardware key proof failed: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_recovery_prove(%L, %L, 'hardware', null, %L)$q$, u, req, H1)) then raise exception 'a second proof was accepted'; end if;
    j := public.founder_recovery_complete(u, d, req);
    if (j ->> 'scope') <> 'recovery' then raise exception 'mobile recovery result: %', j; end if;
    r := r || 'mobile flare + recovery proof OK; ';

    -- 8) revoking: reason, grant, and never the last passkey
    for k in select id, credential_id from public.founder_passkeys where user_id = u and revoked_at is null and credential_id <> H1 order by created_at loop
      n := md5(random()::text); j := public.founder_stepup_issue(u, d, H1, 'passkey.revoke', k.credential_id, jsonb_build_object('reason', 'selftest revoke all but one'), n); g := (j ->> 'grant')::uuid;
      if not public._fs_fails(format($q$select public.founder_passkey_revoke(%L, %L, %L, 'short', %L, %L)$q$, u, d, k.id, g, n)) then raise exception 'revoked with a 5-character reason'; end if;
      perform public.founder_passkey_revoke(u, d, k.id, 'selftest revoke all but one', g, n);
    end loop;
    if public._fp_active_count(u) <> 1 then raise exception 'one passkey should be left'; end if;
    select id into pid from public.founder_passkeys where user_id = u and credential_id = H1;
    n := md5(random()::text); j := public.founder_stepup_issue(u, d, H1, 'passkey.revoke', H1, jsonb_build_object('reason', 'selftest revoke the last'), n); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_passkey_revoke(%L, %L, %L, 'selftest revoke the last', %L, %L)$q$, u, d, pid, g, n)) then raise exception 'the last passkey was revoked'; end if;
    r := r || 'revoke OK; ';

    -- 9) status carries no secrets, audit chain and settings history still agree
    j := public.founder_protocol_status(u);
    if j::text like '%"cred":%' or j::text like '%HHHHHHHHHHHHHHHHHHHH1%' or j::text like '%+923001234567%' then raise exception 'status leaked key material or the full number: %', j; end if;
    if (j -> 'mobile' ->> 'last4') <> '4567' or (j ->> 't3_delay_seconds')::integer < 600 then raise exception 'status wrong: %', j; end if;
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain broken'; end if;
    if public.founder_settings_replay_check(u) is not null then raise exception 'settings replay dirty'; end if;
    r := r || 'status + ledger OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E118 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_passkeys) <> b_pk or (select count(*) from public.founder_stepups) <> b_step or (select count(*) from public.founder_aaguid_allow) <> b_aag
     or (select count(*) from public.founder_t3_requests) <> b_t3 or (select count(*) from public.founder_mobile_flare) <> b_fl or (select count(*) from public.founder_recovery_codes) <> b_code
     or (select count(*) from public.founder_recovery_requests) <> b_req or (select count(*) from public.founder_audit) <> b_audit or (select count(*) from public.founder_devices) <> b_dev
     or (select t2_hardware_only from public.founder_protocol where id) is distinct from b_pro then
    raise exception 'E118 selftest left rows behind';
  end if;
  return 'E118 selftest OK — ' || r || 'rollback clean';
end $$;

-- structure, privileges, hygiene (read-only)
create or replace function public.founder_chairman_selftest2() returns text
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '20s' as $$
declare r text := ''; t text; f text;
begin
  foreach t in array array['public.founder_action_tiers','public.founder_aaguid_allow','public.founder_protocol','public.founder_mobile_flare','public.founder_t3_requests'] loop
    if to_regclass(t) is null then raise exception 'table missing: %', t; end if;
    if not (select relrowsecurity from pg_class where oid = to_regclass(t)) then raise exception 'RLS off on %', t; end if;
    if has_table_privilege('anon', t, 'select') or has_table_privilege('authenticated', t, 'select') then raise exception 'anon/authenticated can read %', t; end if;
    if has_table_privilege('service_role', t, 'insert') or has_table_privilege('service_role', t, 'update') or has_table_privilege('service_role', t, 'delete') then raise exception 'service_role can write % directly', t; end if;
  end loop;
  r := r || 'tables OK; ';
  foreach f in array array['public.founder_action_hash(text,text,jsonb,text)','public.founder_stepup_issue(uuid,uuid,text,text,text,jsonb,text)','public.founder_stepup_consume(uuid,uuid,uuid,text,text,jsonb,text)',
    'public.founder_passkey_add(uuid,uuid,text,jsonb,text,text,uuid,text)','public.founder_passkey_revoke(uuid,uuid,uuid,text,uuid,text)','public.founder_recovery_codes_generate(uuid,uuid,uuid,text)',
    'public.founder_aaguid_allow_set(uuid,uuid,text,text,boolean,uuid,text)','public.founder_protocol_t2_hardware(uuid,uuid,boolean,uuid,text)','public.founder_t3_begin(uuid,uuid,text,text,text,jsonb,text)',
    'public.founder_t3_approve(uuid,uuid,uuid,text,text,text,jsonb,text)','public.founder_t3_execute(uuid,uuid,uuid,text,text,jsonb,text)','public.founder_t3_cancel(uuid,uuid,uuid,text)','public.founder_t3_tick(timestamptz)',
    'public.founder_mobile_flare_set(uuid,uuid,text,uuid,text)','public.founder_mobile_flare_confirm(uuid)','public.founder_mobile_flare_remove(uuid,uuid,uuid,text)','public.founder_recovery_open(uuid,text,text)',
    'public.founder_recovery_prove(uuid,uuid,text,text,text)','public.founder_recovery_complete(uuid,uuid,uuid)','public.founder_protocol_status(uuid)'] loop
    if to_regprocedure(f) is null then raise exception 'function missing: %', f; end if;
    if has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute') or not has_function_privilege('service_role', f, 'execute') then raise exception 'wrong execute privileges on %', f; end if;
  end loop;
  foreach f in array array['public._fp_canonical(text,text,jsonb,text)','public._fp_cred_is_hardware(uuid,text)','public._fp_consume_action(uuid,uuid,uuid,text,text,jsonb,text)'] loop
    if has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute') then raise exception 'private helper % is reachable', f; end if;
  end loop;
  r := r || 'functions OK; ';
  if (select count(*) from public.founder_action_tiers where tier = 3) < 3 or (select count(*) from public.founder_action_tiers where tier = 2 and built) < 6 then raise exception 'tier registry incomplete'; end if;
  if not exists (select 1 from pg_constraint where conname = 'founder_t3_delay') or not exists (select 1 from pg_constraint where conname = 'founder_t3_two_keys') then raise exception 'T3 constraints missing'; end if;
  if (select t3_delay_seconds from public.founder_protocol where id) < 600 or (select t3_min_hardware_keys from public.founder_protocol where id) < 2 then raise exception 'protocol below the decided minimum'; end if;
  r := r || 'registry + protocol OK; ';
  return 'E118 selftest2 OK — ' || r;
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.founder_chairman_selftest()','public.founder_chairman_selftest2()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
