-- E117 — Founder step 7 / phase 7-1: passkeys, G3 step-up grants and recovery (SQL only; Rust webauthn-rs is 7-2, the Privacy tab is 7-3).
-- Founder order 1 Nov 2026 12:45: "yeh sab kaam kero shuru" + "technology rule ko strictly follow kerna hai". Design: docs/claude/FOUNDER-PASSKEY-F2D-DESIGN-01NOV.md
-- Technology: SQL (Supabase Postgres, RLS on, service_role reaches the data only through the security-definer doors below). Nothing here sends an SMS, and nothing here
-- removes FOUNDER_PASSWORD: that comes in 7-4, after the founder has proven a passkey sign-in in his own Chrome (Rule 69).
--
-- What is in here
--   1) founder_passkeys             the credentials (webauthn-rs serialises the whole Passkey, counter included, as jsonb). Never deleted, only revoked (history kept). Max 5 active.
--   2) founder_passkey_ceremonies   server-side state of one registration / authentication: single use, 5 minutes.
--   3) founder_stepups              the G3 grant: one passkey assertion becomes ONE single-use grant, 5 minutes, bound to (founder, approved device, scope).
--   4) founder_recovery_codes       10 one-time offline codes, stored only as SHA-256.
--   5) founder_recovery_requests    recovery state machine: a recovery code opens it at once ("ready"); a mobile OTP (phase 7-5) opens it with a 24-hour cooling-off ("pending"),
--                                   cancellable from any approved device. Completing it issues a short 'recovery' grant that allows ONE new passkey.
--   6) doors (all write a ledger entry through founder_audit_append): ceremony begin/take, passkey add/list/touch/revoke/status, step-up issue/consume,
--      recovery codes generate/use, recovery open/cancel/tick/complete.
--   7) selftest + selftest2, both run on a POPULATED account and rolled back (lesson of E116: never assume an empty founder_settings).
-- Safe to run again (create-if-not-exists / create-or-replace). Everything the selftest does is rolled back.

-- ==============================================================================================================================
-- 0) prerequisites
-- ==============================================================================================================================
do $$
begin
  if to_regclass('public.founder_accounts') is null or to_regclass('public.founder_devices') is null or to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then
    raise exception 'E117 needs E102 (accounts, devices, audit) first';
  end if;
  if to_regprocedure('public._fs_current(uuid,text)') is null or to_regprocedure('public._fs_fails(text)') is null or to_regclass('public.founder_setting_registry') is null then
    raise exception 'E117 needs E113 / E114 (settings helpers, registry) first';
  end if;
end $$;

-- ==============================================================================================================================
-- 1) tables (RLS on; service_role may only READ; every write goes through a door)
-- ==============================================================================================================================
create table if not exists public.founder_passkeys (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.founder_accounts(user_id) on delete cascade,
  credential_id text not null unique check (credential_id ~ '^[A-Za-z0-9_-]{16,255}$'),
  passkey       jsonb not null check (jsonb_typeof(passkey) = 'object' and octet_length(passkey::text) <= 8000),
  label         text not null check (length(label) between 1 and 40 and label !~ '[\x00-\x1f\x7f<>]'),
  sign_count    bigint not null default 0 check (sign_count >= 0),
  created_at    timestamptz not null default now(),
  last_used_at  timestamptz,
  revoked_at    timestamptz,
  revoked_reason text check (revoked_reason is null or length(revoked_reason) between 8 and 300),
  constraint founder_passkeys_revoked_pair check ((revoked_at is null) = (revoked_reason is null))
);
create index if not exists founder_passkeys_user_active_idx on public.founder_passkeys (user_id) where revoked_at is null;

create table if not exists public.founder_passkey_ceremonies (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.founder_accounts(user_id) on delete cascade,
  kind       text not null check (kind in ('register','authenticate')),
  state      jsonb not null check (octet_length(state::text) <= 8000),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '5 minutes',
  used_at    timestamptz,
  constraint founder_ceremony_window check (expires_at > created_at and expires_at <= created_at + interval '5 minutes')
);
create index if not exists founder_ceremonies_open_idx on public.founder_passkey_ceremonies (user_id, kind) where used_at is null;

create table if not exists public.founder_stepups (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.founder_accounts(user_id) on delete cascade,
  device_id     uuid not null references public.founder_devices(id) on delete cascade,
  credential_id text,
  scope         text not null check (scope in ('g3','signin','recovery')),
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default now() + interval '5 minutes',
  used_at       timestamptz,
  used_for      text check (used_for is null or length(used_for) between 3 and 80),
  constraint founder_stepup_window check (expires_at > created_at and expires_at <= created_at + interval '10 minutes'),
  constraint founder_stepup_used_pair check ((used_at is null) = (used_for is null)),
  constraint founder_stepup_cred check ((scope = 'recovery') = (credential_id is null))
);
create index if not exists founder_stepups_open_idx on public.founder_stepups (user_id, device_id, scope) where used_at is null;

create table if not exists public.founder_recovery_codes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.founder_accounts(user_id) on delete cascade,
  batch_id   uuid not null,
  code_hash  text not null check (code_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  used_at    timestamptz,
  retired_at timestamptz,
  unique (user_id, code_hash)
);
create index if not exists founder_recovery_codes_live_idx on public.founder_recovery_codes (user_id) where used_at is null and retired_at is null;

create table if not exists public.founder_recovery_requests (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.founder_accounts(user_id) on delete cascade,
  channel             text not null check (channel in ('code','mobile')),
  state               text not null default 'pending' check (state in ('pending','ready','cancelled','completed','expired')),
  created_at          timestamptz not null default now(),
  ready_at            timestamptz not null,
  expires_at          timestamptz not null,
  cancelled_at        timestamptz,
  cancelled_by_device uuid references public.founder_devices(id),
  completed_at        timestamptz,
  constraint founder_recovery_window check (ready_at >= created_at and expires_at > ready_at and expires_at <= ready_at + interval '24 hours'),
  constraint founder_recovery_cooling check (channel <> 'mobile' or ready_at >= created_at + interval '24 hours')
);
-- at most ONE open recovery per founder
create unique index if not exists founder_recovery_one_open_idx on public.founder_recovery_requests (user_id) where state in ('pending','ready');

create table if not exists public.founder_recovery_failures (
  id      bigint generated always as identity primary key,
  user_id uuid not null references public.founder_accounts(user_id) on delete cascade,
  at      timestamptz not null default now()
);
create index if not exists founder_recovery_failures_idx on public.founder_recovery_failures (user_id, at desc);

do $$
declare t text;
begin
  foreach t in array array['founder_passkeys','founder_passkey_ceremonies','founder_stepups','founder_recovery_codes','founder_recovery_requests','founder_recovery_failures'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to service_role', t);
  end loop;
  -- the secrets are not even readable: the hash of a recovery code and the passkey bodies never leave through a plain select
  revoke select on public.founder_recovery_codes, public.founder_passkey_ceremonies from service_role;
  revoke select on public.founder_passkeys from service_role;
  grant select (id, user_id, credential_id, label, sign_count, created_at, last_used_at, revoked_at, revoked_reason) on public.founder_passkeys to service_role;
end $$;
comment on table public.founder_passkeys is 'E117: founder passkey credentials. Revoked, never deleted. The serialised key body is readable only through founder_passkey_active().';
comment on table public.founder_stepups is 'E117: G3 grants. One passkey assertion = one grant, single use, 5 minutes, bound to an approved device.';

-- ==============================================================================================================================
-- 2) small helpers (private)
-- ==============================================================================================================================
create or replace function public._fp_assert_device(p_uid uuid, p_device uuid) returns void language plpgsql stable set search_path = pg_catalog, public as $$
begin
  perform public._fs_assert_founder(p_uid);
  if p_device is null or not exists (select 1 from public.founder_devices where id = p_device and user_id = p_uid and approved_at is not null and revoked_at is null) then
    raise exception 'device not approved' using errcode = '42501';
  end if;
end $$;

create or replace function public._fp_active_count(p_uid uuid) returns integer language sql stable set search_path = pg_catalog, public as $$
  select count(*)::integer from public.founder_passkeys where user_id = p_uid and revoked_at is null
$$;

create or replace function public._fp_norm_code(p_code text) returns text language sql immutable set search_path = pg_catalog as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'))
$$;

create or replace function public._fp_code_hash(p_code text) returns text language sql immutable set search_path = pg_catalog, extensions as $$
  select encode(digest(public._fp_norm_code(p_code), 'sha256'), 'hex')
$$;

-- ==============================================================================================================================
-- 3) ceremonies (registration / authentication state, kept on the server, single use)
-- ==============================================================================================================================
create or replace function public.founder_passkey_ceremony_begin(p_uid uuid, p_kind text, p_state jsonb) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid;
begin
  perform public._fs_assert_founder(p_uid);
  if p_kind not in ('register','authenticate') then raise exception 'unknown ceremony' using errcode = '22023'; end if;
  if p_state is null or jsonb_typeof(p_state) <> 'object' then raise exception 'ceremony state must be an object' using errcode = '22023'; end if;
  delete from public.founder_passkey_ceremonies where user_id = p_uid and (expires_at < now() or used_at is not null) and created_at < now() - interval '1 hour';
  if p_kind = 'register' and public._fp_active_count(p_uid) >= 5 then raise exception 'at most 5 passkeys' using errcode = '22023'; end if;
  if (select count(*) from public.founder_passkey_ceremonies where user_id = p_uid and used_at is null and expires_at > now()) >= 6 then raise exception 'too many open ceremonies' using errcode = '22023'; end if;
  insert into public.founder_passkey_ceremonies (user_id, kind, state) values (p_uid, p_kind, p_state) returning id into v_id;
  return v_id;
end $$;

create or replace function public.founder_passkey_ceremony_take(p_uid uuid, p_id uuid, p_kind text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_state jsonb;
begin
  perform public._fs_assert_founder(p_uid);
  update public.founder_passkey_ceremonies set used_at = now()
   where id = p_id and user_id = p_uid and kind = p_kind and used_at is null and expires_at > now()
   returning state into v_state;
  if v_state is null then raise exception 'ceremony expired or already used' using errcode = '22023'; end if;
  return v_state;
end $$;

-- ==============================================================================================================================
-- 4) step-up grants
-- ==============================================================================================================================
create or replace function public.founder_stepup_issue(p_uid uuid, p_device uuid, p_credential_id text, p_scope text default 'g3') returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid; v_exp timestamptz;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_scope not in ('g3','signin') then raise exception 'a passkey issues g3 or signin grants only' using errcode = '22023'; end if;
  if not exists (select 1 from public.founder_passkeys where user_id = p_uid and credential_id = p_credential_id and revoked_at is null) then raise exception 'unknown or revoked passkey' using errcode = '42501'; end if;
  -- a newer assertion replaces any unused grant of the same scope on the same device
  update public.founder_stepups set used_at = now(), used_for = 'replaced' where user_id = p_uid and device_id = p_device and scope = p_scope and used_at is null;
  insert into public.founder_stepups (user_id, device_id, credential_id, scope) values (p_uid, p_device, p_credential_id, p_scope) returning id, expires_at into v_id, v_exp;
  perform public.founder_audit_append(p_uid, 'passkey.stepup', p_scope, 'passkey assertion accepted, grant issued', jsonb_build_object('device', p_device, 'scope', p_scope));
  return jsonb_build_object('grant', v_id, 'scope', p_scope, 'expires_at_ms', (extract(epoch from v_exp) * 1000)::bigint);
end $$;

-- consume = the ONE check every dangerous action goes through (Rust calls it before acting; a missing / used / expired / other-device grant is a 403)
create or replace function public.founder_stepup_consume(p_uid uuid, p_device uuid, p_grant uuid, p_scope text, p_for text) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_for is null or length(p_for) not between 3 and 80 then raise exception 'say what the grant is used for' using errcode = '22023'; end if;
  update public.founder_stepups set used_at = now(), used_for = p_for
   where id = p_grant and user_id = p_uid and device_id = p_device and scope = p_scope and used_at is null and expires_at > now()
   returning id into v_id;
  if v_id is null then raise exception 'step-up grant missing, used, expired or for another device' using errcode = '42501'; end if;
  perform public.founder_audit_append(p_uid, 'passkey.stepup_used', p_for, 'passkey grant used for a protected action', jsonb_build_object('device', p_device, 'scope', p_scope));
  return true;
end $$;

-- ==============================================================================================================================
-- 5) passkeys: add / list / active / touch / revoke / status
-- ==============================================================================================================================
create or replace function public.founder_passkey_add(p_uid uuid, p_device uuid, p_credential_id text, p_passkey jsonb, p_label text, p_grant uuid default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n integer; v_id uuid; v_scope text;
begin
  perform public._fp_assert_device(p_uid, p_device);
  select public._fp_active_count(p_uid) into v_n;
  if v_n >= 5 then raise exception 'at most 5 passkeys' using errcode = '22023'; end if;
  if p_label is null or length(btrim(p_label)) not between 1 and 40 or p_label ~ '[\x00-\x1f\x7f<>]' then raise exception 'passkey name: 1 to 40 characters' using errcode = '22023'; end if;
  if v_n = 0 then
    v_scope := 'first';                                                     -- the very first passkey needs the approved device only
  else
    -- every further passkey is G3 (a passkey assertion) or a completed recovery
    if p_grant is null then raise exception 'adding a passkey needs a step-up grant' using errcode = '42501'; end if;
    if (select scope from public.founder_stepups where id = p_grant and user_id = p_uid) = 'recovery' then
      perform public.founder_stepup_consume(p_uid, p_device, p_grant, 'recovery', 'passkey.add');
      v_scope := 'recovery';
    else
      perform public.founder_stepup_consume(p_uid, p_device, p_grant, 'g3', 'passkey.add');
      v_scope := 'g3';
    end if;
  end if;
  insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (p_uid, p_credential_id, p_passkey, btrim(p_label)) returning id into v_id;
  perform public.founder_audit_append(p_uid, 'passkey.add', left(p_credential_id, 12), 'passkey added: ' || btrim(p_label), jsonb_build_object('device', p_device, 'via', v_scope, 'active', v_n + 1));
  return jsonb_build_object('id', v_id, 'active', v_n + 1, 'via', v_scope);
end $$;

-- the list the Privacy tab shows: no key material
create or replace function public.founder_passkey_list(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
begin
  perform public._fs_assert_founder(p_uid);
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'label', label, 'credential', left(credential_id, 8), 'created_ms', (extract(epoch from created_at) * 1000)::bigint,
                    'last_used_ms', case when last_used_at is null then null else (extract(epoch from last_used_at) * 1000)::bigint end,
                    'revoked', revoked_at is not null, 'revoked_reason', revoked_reason) order by created_at) from public.founder_passkeys where user_id = p_uid), '[]'::jsonb);
end $$;

-- what webauthn-rs needs to START an authentication: the stored Passkey bodies of the active credentials
create or replace function public.founder_passkey_active(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
begin
  perform public._fs_assert_founder(p_uid);
  return coalesce((select jsonb_agg(jsonb_build_object('credential_id', credential_id, 'passkey', passkey) order by created_at) from public.founder_passkeys where user_id = p_uid and revoked_at is null), '[]'::jsonb);
end $$;

-- after a successful authentication: store the updated Passkey (new counter). A counter that did not go up = cloned authenticator: revoke it and say so in the ledger.
create or replace function public.founder_passkey_touch(p_uid uuid, p_credential_id text, p_passkey jsonb, p_sign_count bigint) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_passkeys%rowtype;
begin
  perform public._fs_assert_founder(p_uid);
  select * into r from public.founder_passkeys where user_id = p_uid and credential_id = p_credential_id and revoked_at is null for update;
  if not found then raise exception 'unknown or revoked passkey' using errcode = '42501'; end if;
  if p_sign_count is null or p_sign_count < 0 then raise exception 'bad counter' using errcode = '22023'; end if;
  if p_sign_count > 0 and p_sign_count <= r.sign_count then
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'clone suspected: the counter did not increase' where id = r.id;
    perform public.founder_audit_append(p_uid, 'passkey.clone', left(p_credential_id, 12), 'passkey revoked: the signature counter did not increase', jsonb_build_object('was', r.sign_count, 'got', p_sign_count));
    return jsonb_build_object('clone', true);
  end if;
  update public.founder_passkeys set passkey = p_passkey, sign_count = greatest(r.sign_count, p_sign_count), last_used_at = now() where id = r.id;
  return jsonb_build_object('clone', false);
end $$;

create or replace function public.founder_passkey_revoke(p_uid uuid, p_device uuid, p_id uuid, p_reason text, p_grant uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_passkeys%rowtype;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_reason is null or length(btrim(p_reason)) not between 8 and 300 then raise exception 'say why (8 to 300 characters)' using errcode = '22023'; end if;
  select * into r from public.founder_passkeys where id = p_id and user_id = p_uid and revoked_at is null for update;
  if not found then raise exception 'no such active passkey' using errcode = '22023'; end if;
  perform public.founder_stepup_consume(p_uid, p_device, p_grant, 'g3', 'passkey.revoke');
  update public.founder_passkeys set revoked_at = now(), revoked_reason = btrim(p_reason) where id = r.id;
  perform public.founder_audit_append(p_uid, 'passkey.revoke', left(r.credential_id, 12), btrim(p_reason), jsonb_build_object('device', p_device, 'label', r.label));
  return jsonb_build_object('revoked', r.id, 'active', public._fp_active_count(p_uid));
end $$;

create or replace function public.founder_passkey_status(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_req jsonb;
begin
  perform public._fs_assert_founder(p_uid);
  select jsonb_build_object('id', id, 'channel', channel, 'state', state, 'ready_ms', (extract(epoch from ready_at) * 1000)::bigint, 'expires_ms', (extract(epoch from expires_at) * 1000)::bigint)
    into v_req from public.founder_recovery_requests where user_id = p_uid and state in ('pending','ready');
  return jsonb_build_object(
    'active_passkeys', public._fp_active_count(p_uid),
    'max_passkeys', 5,
    'recovery_codes_left', (select count(*) from public.founder_recovery_codes where user_id = p_uid and used_at is null and retired_at is null),
    'recovery_open', v_req,
    'require_passkey', coalesce(public._fs_current(p_uid, 'workspace.require_passkey'), (select default_value from public.founder_setting_registry where key = 'workspace.require_passkey')),
    'password_path_removed', false);   -- becomes true in phase 7-4, only after the passkey sign-in is proven in the founder's Chrome
end $$;

-- ==============================================================================================================================
-- 6) recovery codes + recovery state machine
-- ==============================================================================================================================
-- 10 codes, shown ONCE (returned here, stored only as SHA-256). 20 random characters from a 32-letter alphabet = 100 bits each.
create or replace function public.founder_recovery_codes_generate(p_uid uuid, p_device uuid, p_grant uuid default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_batch uuid := gen_random_uuid(); v_codes text[] := '{}'; v_code text; v_raw bytea; i integer; j integer; v_alpha text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; v_plain text;
begin
  perform public._fp_assert_device(p_uid, p_device);
  -- once a passkey exists, new codes are G3 (they are a way back in); before that the approved device is enough
  if public._fp_active_count(p_uid) > 0 then perform public.founder_stepup_consume(p_uid, p_device, p_grant, 'g3', 'recovery.codes'); end if;
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

-- opening a recovery. channel 'code': the code is checked here and the request is READY at once (an offline secret is the founder's own proof).
-- channel 'mobile': Rust calls this only AFTER a verified OTP (phase 7-5); the request is PENDING for 24 hours and any approved device can cancel it.
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
      insert into public.founder_recovery_failures (user_id) values (p_uid);         -- recorded, so this function must RETURN (a raise would roll the failure back)
      perform public.founder_audit_append(p_uid, 'recovery.fail', 'code', 'a wrong recovery code was tried', jsonb_build_object('fails_last_hour', v_fails + 1));
      return jsonb_build_object('ok', false, 'reason', 'wrong or used code');
    end if;
    update public.founder_recovery_codes set used_at = now() where id = v_row;
    v_ready := now();
  else
    v_ready := now() + interval '24 hours';
  end if;
  insert into public.founder_recovery_requests (user_id, channel, state, ready_at, expires_at)
    values (p_uid, p_channel, case when p_channel = 'code' then 'ready' else 'pending' end, v_ready, v_ready + interval '24 hours') returning id into v_id;
  perform public.founder_audit_append(p_uid, 'recovery.open', p_channel, case when p_channel = 'code' then 'recovery opened with a recovery code' else 'recovery opened by mobile verification; 24 hour cooling-off started' end,
                                      jsonb_build_object('request', v_id, 'ready_ms', (extract(epoch from v_ready) * 1000)::bigint));
  return jsonb_build_object('ok', true, 'request', v_id, 'state', case when p_channel = 'code' then 'ready' else 'pending' end, 'ready_ms', (extract(epoch from v_ready) * 1000)::bigint);
end $$;

-- any APPROVED device can cancel a recovery that is still cooling off
create or replace function public.founder_recovery_cancel(p_uid uuid, p_device uuid, p_request uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n integer;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_reason is null or length(btrim(p_reason)) not between 8 and 300 then raise exception 'say why (8 to 300 characters)' using errcode = '22023'; end if;
  update public.founder_recovery_requests set state = 'cancelled', cancelled_at = now(), cancelled_by_device = p_device
   where id = p_request and user_id = p_uid and state = 'pending';
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'no pending recovery to cancel (a ready one has already passed its cooling-off)' using errcode = '22023'; end if;
  perform public.founder_audit_append(p_uid, 'recovery.cancel', p_request::text, btrim(p_reason), jsonb_build_object('device', p_device));
  return jsonb_build_object('cancelled', p_request);
end $$;

-- time passes: pending -> ready when the cooling-off is over; ready -> expired after its 24 h window (p_now is for tests; the scheduler calls it with now())
create or replace function public.founder_recovery_tick(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare a integer; b integer;
begin
  update public.founder_recovery_requests set state = 'ready' where state = 'pending' and ready_at <= p_now and expires_at > p_now;
  get diagnostics a = row_count;
  update public.founder_recovery_requests set state = 'expired' where state in ('pending','ready') and expires_at <= p_now;
  get diagnostics b = row_count;
  return jsonb_build_object('ready', a, 'expired', b);
end $$;

-- a READY recovery is completed ONCE by an approved device and yields a 'recovery' grant (10 minutes) that allows exactly one new passkey
create or replace function public.founder_recovery_complete(p_uid uuid, p_device uuid, p_request uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n integer; v_id uuid; v_exp timestamptz;
begin
  perform public._fp_assert_device(p_uid, p_device);
  update public.founder_recovery_requests set state = 'completed', completed_at = now()
   where id = p_request and user_id = p_uid and state = 'ready' and ready_at <= now() and expires_at > now();
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'recovery is not ready (still cooling off, cancelled, expired or already used)' using errcode = '42501'; end if;
  insert into public.founder_stepups (user_id, device_id, credential_id, scope, expires_at) values (p_uid, p_device, null, 'recovery', now() + interval '10 minutes') returning id, expires_at into v_id, v_exp;
  perform public.founder_audit_append(p_uid, 'recovery.complete', p_request::text, 'recovery completed; one new passkey may be added', jsonb_build_object('device', p_device));
  return jsonb_build_object('grant', v_id, 'scope', 'recovery', 'expires_at_ms', (extract(epoch from v_exp) * 1000)::bigint);
end $$;

-- ==============================================================================================================================
-- 7) grants
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public.founder_passkey_ceremony_begin(uuid,text,jsonb)','public.founder_passkey_ceremony_take(uuid,uuid,text)','public.founder_stepup_issue(uuid,uuid,text,text)',
    'public.founder_stepup_consume(uuid,uuid,uuid,text,text)','public.founder_passkey_add(uuid,uuid,text,jsonb,text,uuid)','public.founder_passkey_list(uuid)','public.founder_passkey_active(uuid)',
    'public.founder_passkey_touch(uuid,text,jsonb,bigint)','public.founder_passkey_revoke(uuid,uuid,uuid,text,uuid)','public.founder_passkey_status(uuid)',
    'public.founder_recovery_codes_generate(uuid,uuid,uuid)','public.founder_recovery_open(uuid,text,text)','public.founder_recovery_cancel(uuid,uuid,uuid,text)',
    'public.founder_recovery_tick(timestamptz)','public.founder_recovery_complete(uuid,uuid,uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
  revoke all on function public._fp_assert_device(uuid, uuid), public._fp_active_count(uuid), public._fp_norm_code(text), public._fp_code_hash(text) from public, anon, authenticated;
end $$;

-- ==============================================================================================================================
-- 8) selftest — behaviour of every door, on a POPULATED account, all rolled back
-- ==============================================================================================================================
create or replace function public.founder_passkey_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '90s' as $$
declare
  u uuid; d uuid; d2 uuid; r text := ''; j jsonb; cer uuid; g uuid; g2 uuid; codes jsonb; code text; req uuid; n integer; pid uuid; st jsonb;
  b_pk bigint; b_cer bigint; b_step bigint; b_code bigint; b_req bigint; b_fail bigint; b_audit bigint; b_dev bigint;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E117 selftest SKIP — no founder account'; end if;
  select count(*) into b_pk from public.founder_passkeys; select count(*) into b_cer from public.founder_passkey_ceremonies; select count(*) into b_step from public.founder_stepups;
  select count(*) into b_code from public.founder_recovery_codes; select count(*) into b_req from public.founder_recovery_requests; select count(*) into b_fail from public.founder_recovery_failures;
  select count(*) into b_audit from public.founder_audit; select count(*) into b_dev from public.founder_devices;
  begin
    -- a clean slate for THIS test only, through plain updates that are rolled back (no raw delete of anything the chain depends on)
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'selftest clean slate' where user_id = u and revoked_at is null;
    update public.founder_recovery_requests set state = 'cancelled', cancelled_at = now() where user_id = u and state in ('pending','ready');
    update public.founder_recovery_codes set retired_at = now() where user_id = u and used_at is null and retired_at is null;
    delete from public.founder_recovery_failures where user_id = u;

    -- two approved test devices
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (u, 'selftest device one', encode(digest('e117-one', 'sha256'), 'hex'), now()) returning id into d;
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (u, 'selftest device two', encode(digest('e117-two', 'sha256'), 'hex'), now()) returning id into d2;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, gen_random_uuid(), 'g3', 'selftest')$q$, u, gen_random_uuid())) then raise exception 'an unknown device passed'; end if;
    r := r || 'devices OK; ';

    -- ceremonies: single use, wrong kind refused, state returned exactly
    cer := public.founder_passkey_ceremony_begin(u, 'register', '{"x":1}'::jsonb);
    if public.founder_passkey_ceremony_take(u, cer, 'register') <> '{"x":1}'::jsonb then raise exception 'ceremony state changed'; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_ceremony_take(%L, %L, 'register')$q$, u, cer)) then raise exception 'a ceremony was used twice'; end if;
    cer := public.founder_passkey_ceremony_begin(u, 'authenticate', '{"y":2}'::jsonb);
    if not public._fs_fails(format($q$select public.founder_passkey_ceremony_take(%L, %L, 'register')$q$, u, cer)) then raise exception 'a ceremony was taken as the wrong kind'; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_ceremony_begin(%L, 'nope', '{}'::jsonb)$q$, u)) then raise exception 'unknown ceremony kind accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_ceremony_begin(%L, 'register', '[1]'::jsonb)$q$, gen_random_uuid())) then raise exception 'a non-founder opened a ceremony'; end if;
    update public.founder_passkey_ceremonies set created_at = now() - interval '10 minutes', expires_at = now() - interval '5 minutes' where id = cer;
    if not public._fs_fails(format($q$select public.founder_passkey_ceremony_take(%L, %L, 'authenticate')$q$, u, cer)) then raise exception 'an expired ceremony was taken'; end if;
    r := r || 'ceremonies OK; ';

    -- the FIRST passkey needs only the approved device; the second needs a grant
    j := public.founder_passkey_add(u, d, 'AAAAAAAAAAAAAAAAAAAA1', '{"cred":"one"}'::jsonb, 'Test key one');
    if (j ->> 'via') <> 'first' or (j ->> 'active')::integer <> 1 then raise exception 'first passkey: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_add(%L, %L, 'BBBBBBBBBBBBBBBBBBBB2', '{"cred":"two"}'::jsonb, 'Test key two')$q$, u, d)) then raise exception 'a second passkey was added without a grant'; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_add(%L, %L, 'AAAAAAAAAAAAAAAAAAAA1', '{"cred":"dup"}'::jsonb, 'Duplicate')$q$, u, d)) then raise exception 'a duplicate credential was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_add(%L, %L, 'CCCCCCCCCCCCCCCCCCCC3', '{}'::jsonb, '<b>x</b>')$q$, u, d)) then raise exception 'markup in a passkey name accepted'; end if;
    r := r || 'first passkey OK; ';

    -- step-up: one assertion -> one grant, single use, bound to its device and scope, expiring
    j := public.founder_stepup_issue(u, d, 'AAAAAAAAAAAAAAAAAAAA1', 'g3'); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'g3', 'selftest wrong device')$q$, u, d2, g)) then raise exception 'a grant worked on another device'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'signin', 'selftest wrong scope')$q$, u, d, g)) then raise exception 'a grant worked for another scope'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_issue(%L, %L, 'NOSUCHCREDENTIAL0000', 'g3')$q$, u, d)) then raise exception 'a grant was issued for an unknown passkey'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_issue(%L, %L, 'AAAAAAAAAAAAAAAAAAAA1', 'recovery')$q$, u, d)) then raise exception 'a passkey issued a recovery grant'; end if;
    if public.founder_stepup_consume(u, d, g, 'g3', 'selftest first use') is not true then raise exception 'a good grant was refused'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'g3', 'selftest second use')$q$, u, d, g)) then raise exception 'a grant was used twice'; end if;
    j := public.founder_stepup_issue(u, d, 'AAAAAAAAAAAAAAAAAAAA1', 'g3'); g := (j ->> 'grant')::uuid;
    update public.founder_stepups set created_at = now() - interval '6 minutes', expires_at = now() - interval '1 minute' where id = g;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'g3', 'selftest expired')$q$, u, d, g)) then raise exception 'an expired grant was used'; end if;
    j := public.founder_stepup_issue(u, d, 'AAAAAAAAAAAAAAAAAAAA1', 'g3'); g := (j ->> 'grant')::uuid;
    j := public.founder_stepup_issue(u, d, 'AAAAAAAAAAAAAAAAAAAA1', 'g3'); g2 := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'g3', 'selftest replaced grant')$q$, u, d, g)) then raise exception 'a replaced grant still worked'; end if;
    r := r || 'step-up OK; ';

    -- the second passkey with a grant; list shows no key material; revoke needs a grant and a reason; the history stays
    j := public.founder_passkey_add(u, d, 'BBBBBBBBBBBBBBBBBBBB2', '{"cred":"two"}'::jsonb, 'Test key two', g2);
    if (j ->> 'via') <> 'g3' or (j ->> 'active')::integer <> 2 then raise exception 'second passkey: %', j; end if;
    j := public.founder_passkey_list(u);
    if jsonb_array_length(j) < 2 or j::text like '%"cred":%' or j::text like '%AAAAAAAAAAAAAAAAAAAA1%' then raise exception 'the list leaked key material: %', j; end if;
    if jsonb_array_length(public.founder_passkey_active(u)) <> 2 then raise exception 'active passkeys must be 2'; end if;
    select id into pid from public.founder_passkeys where user_id = u and credential_id = 'BBBBBBBBBBBBBBBBBBBB2';
    if not public._fs_fails(format($q$select public.founder_passkey_revoke(%L, %L, %L, 'selftest without a grant', gen_random_uuid())$q$, u, d, pid)) then raise exception 'revoked without a grant'; end if;
    j := public.founder_stepup_issue(u, d, 'AAAAAAAAAAAAAAAAAAAA1', 'g3'); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_passkey_revoke(%L, %L, %L, 'short', %L)$q$, u, d, pid, g)) then raise exception 'revoked with a 5-character reason'; end if;
    j := public.founder_passkey_revoke(u, d, pid, 'selftest revoke the second key', g);
    if (j ->> 'active')::integer <> 1 then raise exception 'revoke result: %', j; end if;
    if (select count(*) from public.founder_passkeys where id = pid and revoked_at is not null) <> 1 then raise exception 'a revoked passkey must stay as history'; end if;
    if not public._fs_fails(format($q$select public.founder_stepup_issue(%L, %L, 'BBBBBBBBBBBBBBBBBBBB2', 'g3')$q$, u, d)) then raise exception 'a revoked passkey issued a grant'; end if;
    r := r || 'second passkey, list, revoke OK; ';

    -- the sixth passkey is refused (max 5 active)
    for n in 3..6 loop
      j := public.founder_stepup_issue(u, d, 'AAAAAAAAAAAAAAAAAAAA1', 'g3');
      perform public.founder_passkey_add(u, d, 'KEYNUMBER000000000' || n, jsonb_build_object('n', n), 'Test key ' || n, (j ->> 'grant')::uuid);
    end loop;
    if public._fp_active_count(u) <> 5 then raise exception 'five active passkeys expected, got %', public._fp_active_count(u); end if;
    j := public.founder_stepup_issue(u, d, 'AAAAAAAAAAAAAAAAAAAA1', 'g3');
    if not public._fs_fails(format($q$select public.founder_passkey_add(%L, %L, 'KEYNUMBER0000000007', '{}'::jsonb, 'Sixth', %L)$q$, u, d, (j ->> 'grant'))) then raise exception 'a sixth passkey was accepted'; end if;
    r := r || 'max 5 OK; ';

    -- counter: a higher counter is stored; a lower or equal one (>0) revokes the key as a suspected clone
    j := public.founder_passkey_touch(u, 'AAAAAAAAAAAAAAAAAAAA1', '{"cred":"one","n":5}'::jsonb, 5);
    if (j ->> 'clone')::boolean then raise exception 'a rising counter was called a clone'; end if;
    j := public.founder_passkey_touch(u, 'AAAAAAAAAAAAAAAAAAAA1', '{"cred":"one","n":9}'::jsonb, 9);
    if (select sign_count from public.founder_passkeys where credential_id = 'AAAAAAAAAAAAAAAAAAAA1') <> 9 then raise exception 'counter not stored'; end if;
    j := public.founder_passkey_touch(u, 'KEYNUMBER0000000003', '{}'::jsonb, 0);                      -- counter 0 = authenticator without a counter: allowed
    if (j ->> 'clone')::boolean then raise exception 'a zero counter must be allowed'; end if;
    j := public.founder_passkey_touch(u, 'AAAAAAAAAAAAAAAAAAAA1', '{"cred":"one","n":3}'::jsonb, 3);
    if not (j ->> 'clone')::boolean then raise exception 'a falling counter must be a clone'; end if;
    if (select revoked_at from public.founder_passkeys where credential_id = 'AAAAAAAAAAAAAAAAAAAA1') is null then raise exception 'the cloned passkey was not revoked'; end if;
    if not public._fs_fails(format($q$select public.founder_passkey_touch(%L, 'AAAAAAAAAAAAAAAAAAAA1', '{}'::jsonb, 99)$q$, u)) then raise exception 'a revoked passkey authenticated'; end if;
    r := r || 'counter + clone OK; ';

    -- recovery codes: 10 codes shown once, stored hashed, G3 once a passkey exists, a new batch retires the old
    j := public.founder_stepup_issue(u, d, 'KEYNUMBER0000000003', 'g3');
    if not public._fs_fails(format($q$select public.founder_recovery_codes_generate(%L, %L, NULL)$q$, u, d)) then raise exception 'codes were generated without a grant while a passkey exists'; end if;
    codes := public.founder_recovery_codes_generate(u, d, (j ->> 'grant')::uuid) -> 'codes';
    if jsonb_array_length(codes) <> 10 or (select count(distinct x) from jsonb_array_elements_text(codes) x) <> 10 then raise exception 'ten distinct codes expected'; end if;
    code := codes ->> 0;
    if code !~ '^[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}$' then raise exception 'code shape: %', code; end if;
    if exists (select 1 from public.founder_recovery_codes where code_hash = code or code_hash like '%' || replace(code, '-', '') || '%') then raise exception 'a plain code is stored'; end if;
    if (public.founder_passkey_status(u) ->> 'recovery_codes_left')::integer <> 10 then raise exception 'ten codes left expected'; end if;
    r := r || 'recovery codes OK; ';

    -- a wrong code is counted (and RETURNS ok=false); five wrong in an hour lock the door; a right code opens a READY recovery at once, once
    for n in 1..5 loop
      j := public.founder_recovery_open(u, 'code', 'AAAAA-AAAAA-AAAAA-AAAA' || n);
      if (j ->> 'ok')::boolean then raise exception 'a wrong code was accepted'; end if;
    end loop;
    if (select count(*) from public.founder_recovery_failures where user_id = u) <> 5 then raise exception 'wrong attempts were not recorded'; end if;
    if not public._fs_fails(format($q$select public.founder_recovery_open(%L, 'code', %L)$q$, u, code)) then raise exception 'the lockout did not hold'; end if;
    delete from public.founder_recovery_failures where user_id = u;
    j := public.founder_recovery_open(u, 'code', lower(replace(code, '-', ' ')));                 -- spaces / case do not matter
    if not (j ->> 'ok')::boolean or (j ->> 'state') <> 'ready' then raise exception 'a right code did not open a ready recovery: %', j; end if;
    req := (j ->> 'request')::uuid;
    if not public._fs_fails(format($q$select public.founder_recovery_open(%L, 'mobile')$q$, u)) then raise exception 'two recoveries were open at once'; end if;
    if public._fs_fails(format($q$select public.founder_recovery_cancel(%L, %L, %L, 'selftest cancel a ready one')$q$, u, d, req)) is not true then raise exception 'a ready recovery was cancellable'; end if;
    r := r || 'recovery by code OK; ';

    -- complete: ONE 'recovery' grant, which allows ONE passkey (after revoking one so the max is not hit), and only once
    j := public.founder_stepup_issue(u, d, 'KEYNUMBER0000000003', 'g3');
    perform public.founder_passkey_revoke(u, d, (select id from public.founder_passkeys where credential_id = 'KEYNUMBER0000000004'), 'selftest make room for the recovery key', (j ->> 'grant')::uuid);
    j := public.founder_recovery_complete(u, d, req); g := (j ->> 'grant')::uuid;
    if (j ->> 'scope') <> 'recovery' then raise exception 'recovery grant scope: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_recovery_complete(%L, %L, %L)$q$, u, d, req)) then raise exception 'a recovery was completed twice'; end if;
    j := public.founder_passkey_add(u, d, 'RECOVERYKEY00000001', '{"cred":"recovered"}'::jsonb, 'Recovered key', g);
    if (j ->> 'via') <> 'recovery' then raise exception 'recovery add: %', j; end if;
    if public._fs_fails(format($q$select public.founder_stepup_consume(%L, %L, %L, 'recovery', 'selftest reuse')$q$, u, d, g)) is not true then raise exception 'a recovery grant worked twice'; end if;
    r := r || 'recovery complete OK; ';

    -- mobile recovery: PENDING for 24 h, the database itself refuses a shorter cooling-off, any approved device can cancel, tick makes it ready, tick expires it
    if not public._fs_fails(format($q$insert into public.founder_recovery_requests (user_id, channel, state, ready_at, expires_at) values (%L, 'mobile', 'pending', now() + interval '1 hour', now() + interval '2 hours')$q$, u)) then raise exception 'the 24 h cooling-off can be bypassed in SQL'; end if;
    j := public.founder_recovery_open(u, 'mobile'); req := (j ->> 'request')::uuid;
    if (j ->> 'state') <> 'pending' then raise exception 'mobile recovery must start pending: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_recovery_complete(%L, %L, %L)$q$, u, d, req)) then raise exception 'a pending recovery was completed'; end if;
    j := public.founder_recovery_tick(now() + interval '23 hours');
    if (select state from public.founder_recovery_requests where id = req) <> 'pending' then raise exception 'ready too early'; end if;
    j := public.founder_recovery_cancel(u, d2, req, 'selftest cancelled from the other device');
    if (select state from public.founder_recovery_requests where id = req) <> 'cancelled' then raise exception 'cancel did not stick'; end if;
    j := public.founder_recovery_open(u, 'mobile'); req := (j ->> 'request')::uuid;
    j := public.founder_recovery_tick(now() + interval '25 hours');
    if (select state from public.founder_recovery_requests where id = req) <> 'ready' then raise exception 'not ready after 25 hours'; end if;
    j := public.founder_recovery_tick(now() + interval '50 hours');
    if (select state from public.founder_recovery_requests where id = req) <> 'expired' then raise exception 'a ready recovery must expire after its window'; end if;
    r := r || 'mobile cooling-off OK; ';

    -- status + ledger + chain
    st := public.founder_passkey_status(u);
    if (st ->> 'active_passkeys')::integer <> public._fp_active_count(u) or (st ->> 'password_path_removed')::boolean then raise exception 'status wrong: %', st; end if;
    if (select count(*) from public.founder_audit where seq > (select max(seq) from public.founder_audit) - 200 and action like 'passkey.%') < 5 then raise exception 'passkey actions are not in the ledger'; end if;
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain broken'; end if;
    if public.founder_settings_replay_check(u) is not null then raise exception 'settings replay dirty'; end if;
    r := r || 'status + ledger OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E117 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_passkeys) <> b_pk or (select count(*) from public.founder_passkey_ceremonies) <> b_cer or (select count(*) from public.founder_stepups) <> b_step
     or (select count(*) from public.founder_recovery_codes) <> b_code or (select count(*) from public.founder_recovery_requests) <> b_req or (select count(*) from public.founder_recovery_failures) <> b_fail
     or (select count(*) from public.founder_audit) <> b_audit or (select count(*) from public.founder_devices) <> b_dev then
    raise exception 'E117 selftest left rows behind';
  end if;
  return 'E117 selftest OK — ' || r || 'rollback clean';
end $$;

-- ==============================================================================================================================
-- 9) selftest2 — structure, privileges, hygiene (read-only)
-- ==============================================================================================================================
create or replace function public.founder_passkey_selftest2() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r text := ''; t text; f text;
begin
  foreach t in array array['public.founder_passkeys','public.founder_passkey_ceremonies','public.founder_stepups','public.founder_recovery_codes','public.founder_recovery_requests','public.founder_recovery_failures'] loop
    if to_regclass(t) is null then raise exception 'table missing: %', t; end if;
    if not (select relrowsecurity from pg_class where oid = to_regclass(t)) then raise exception 'RLS off on %', t; end if;
    if has_table_privilege('anon', t, 'select') or has_table_privilege('authenticated', t, 'select') or has_table_privilege('anon', t, 'insert') or has_table_privilege('authenticated', t, 'insert') then raise exception 'anon/authenticated can reach %', t; end if;
    if has_table_privilege('service_role', t, 'insert') or has_table_privilege('service_role', t, 'update') or has_table_privilege('service_role', t, 'delete') then raise exception 'service_role can write % directly', t; end if;
  end loop;
  if has_table_privilege('service_role', 'public.founder_recovery_codes', 'select') or has_table_privilege('service_role', 'public.founder_passkey_ceremonies', 'select') then raise exception 'the secret tables must not even be readable'; end if;
  if has_column_privilege('service_role', 'public.founder_passkeys', 'passkey', 'select') then raise exception 'the passkey body must not be readable by a plain select'; end if;
  r := r || 'tables OK; ';
  foreach f in array array['public.founder_passkey_ceremony_begin(uuid,text,jsonb)','public.founder_passkey_ceremony_take(uuid,uuid,text)','public.founder_stepup_issue(uuid,uuid,text,text)',
    'public.founder_stepup_consume(uuid,uuid,uuid,text,text)','public.founder_passkey_add(uuid,uuid,text,jsonb,text,uuid)','public.founder_passkey_list(uuid)','public.founder_passkey_active(uuid)',
    'public.founder_passkey_touch(uuid,text,jsonb,bigint)','public.founder_passkey_revoke(uuid,uuid,uuid,text,uuid)','public.founder_passkey_status(uuid)',
    'public.founder_recovery_codes_generate(uuid,uuid,uuid)','public.founder_recovery_open(uuid,text,text)','public.founder_recovery_cancel(uuid,uuid,uuid,text)',
    'public.founder_recovery_tick(timestamptz)','public.founder_recovery_complete(uuid,uuid,uuid)','public.founder_passkey_selftest()','public.founder_passkey_selftest2()'] loop
    if to_regprocedure(f) is null then raise exception 'function missing: %', f; end if;
    if has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute') or not has_function_privilege('service_role', f, 'execute') then raise exception 'wrong execute privileges on %', f; end if;
  end loop;
  foreach f in array array['public._fp_assert_device(uuid,uuid)','public._fp_active_count(uuid)','public._fp_norm_code(text)','public._fp_code_hash(text)'] loop
    if has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute') then raise exception 'private helper % is reachable', f; end if;
  end loop;
  r := r || 'functions OK; ';
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'founder\_passkey%' and p.prosecdef and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')) then raise exception 'a security definer passkey function has no pinned search_path'; end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'founder\_recovery%' and p.prosecdef and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')) then raise exception 'a security definer recovery function has no pinned search_path'; end if;
  r := r || 'search_path pinned OK; ';
  return 'E117 selftest2 OK — ' || r || 'done';
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.founder_passkey_selftest()','public.founder_passkey_selftest2()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ==============================================================================================================================
-- 10) run the selftests now (output shows in sql-run.sh)
-- ==============================================================================================================================
do $$ begin
  raise notice '%', public.founder_passkey_selftest();
  raise notice '%', public.founder_passkey_selftest2();
end $$;

-- ==============================================================================================================================
-- RUNBOOK (comments only)
-- ==============================================================================================================================
-- Run:        bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E117_founder_passkey_stepup_recovery CHECK_E117   (after the usual fetch)
-- Order:      ... E115 -> E116 -> E117. Safe to run again.
-- Rust (7-2): webauthn-rs registration + authentication ceremonies call founder_passkey_ceremony_begin/take, founder_passkey_add/active/touch, founder_stepup_issue; every protected route calls
--             founder_stepup_consume BEFORE it acts. A recovery tick runs from the existing scheduler.
-- Not here:   SMS (7-5), UI (7-3), FOUNDER_PASSWORD removal (7-4).
-- Undo plan:  drop the 6 tables and the functions named above (no other table references them).
