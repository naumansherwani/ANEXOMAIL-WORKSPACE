
-- ============================================================================================================================
-- LOCAL_E198 — QCONNECT step 7 (20 Nov 2026): the SQL DOORS of the Rust identity engine (server/founder/src/localid.rs). FOUNDER; used only when FOUNDER_DB=local.
-- SCHEMA FIRST (his law 20 Nov 20:35): written on top of the REAL auth schema printed from his copy (his pg-local-authschema paste 23:5x): auth.users (bcrypt $2a$), auth.sessions (aal enum, refreshed_at WITHOUT time zone,
--   refresh_token_hmac_key left NULL = the legacy path his data still uses), auth.refresh_tokens (user_id VARCHAR, parent chain, revoked), and the E71 trigger identity_session_guard_trg (42501 account_pending) which stays in force.
-- What the doors do (Rust keeps only what SQL cannot: bcrypt compare and the signed token):
--   localid_user(email|uid)  one account row: id, email, password hash (bcrypt), banned, deleted, confirmed, verified second factors. service_role only.
--   localid_open(uid, ua, ip) a session + a root refresh token, exactly gotrue's legacy shape (a rollback to gotrue reads them). The E71 trigger decides pending/rejected.
--   localid_refresh(token)    (a refusal is the ANSWER {error:invalid_refresh}, never an exception: an exception would roll back the session kill of a reuse) rotation: old token revoked, child row with parent; REUSE of a revoked token (after a 10 s grace) kills the whole session; unknown token = the same generic refusal.
--   localid_close(session)    logout: tokens and session deleted.
--   founder_localid_events    append-only, HASH-CHAINED ledger of open / refresh / reuse / close (no token, no hash, no password in it); localid_verify() proves the chain; localid_selftest() proves the doors.
-- Why the password compare is NOT here: a slow statement is written to the Postgres log WITH its bound parameters; a password must never be a parameter. The hash comes out, the compare happens in Rust.
-- LOCAL ONLY: the file name does not start with E<number>, so sql-run AUTO never sends it to the managed database; it runs on the local copy through pg-local-run198.sh (the parameter-log setting is done there, ALTER SYSTEM cannot live in a SQL file run by sql-run).
-- Idempotent. No DROP of data. Rollback: unset FOUNDER_DB (gotrue path untouched); drop function public.localid_* if wanted.
-- ============================================================================================================================
set lock_timeout = '3s';
set statement_timeout = '60s';

create table if not exists public.founder_localid_events (
  seq        bigserial primary key,
  ts         timestamptz not null default now(),
  kind       text not null check (kind in ('open', 'refresh', 'reuse', 'close')),
  uid        uuid,
  session_id uuid,
  prev_hash  text not null,
  hash       text not null
);
alter table public.founder_localid_events enable row level security;
revoke all on public.founder_localid_events from public, anon, authenticated;
grant select on public.founder_localid_events to service_role;
create or replace function public._localid_no_change() returns trigger language plpgsql as $$ begin raise exception 'founder_localid_events is append-only' using errcode = '42501'; end $$;
drop trigger if exists localid_events_ro on public.founder_localid_events;
create trigger localid_events_ro before update or delete on public.founder_localid_events for each row execute function public._localid_no_change();

create or replace function public._localid_log(p_kind text, p_uid uuid, p_sid uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare prev text; t timestamptz := clock_timestamp(); h text;
begin
  perform pg_advisory_xact_lock(hashtext('founder_localid_events'));
  select e.hash into prev from public.founder_localid_events e order by e.seq desc limit 1;
  prev := coalesce(prev, repeat('0', 64));
  h := encode(extensions.digest(prev || '|' || p_kind || '|' || coalesce(p_uid::text, '') || '|' || coalesce(p_sid::text, '') || '|' || extract(epoch from t)::text, 'sha256'), 'hex');
  insert into public.founder_localid_events(ts, kind, uid, session_id, prev_hash, hash) values (t, p_kind, p_uid, p_sid, prev, h);
end $$;
revoke all on function public._localid_log(text, uuid, uuid) from public, anon, authenticated;

create or replace function public.localid_user(p_email text default null, p_uid uuid default null) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, auth as $$
  select jsonb_build_object('id', u.id, 'email', u.email, 'hash', u.encrypted_password,
           'banned', (u.banned_until is not null and u.banned_until > now()), 'deleted', (u.deleted_at is not null),
           'confirmed', (u.email_confirmed_at is not null), 'anonymous', coalesce(u.is_anonymous, false) or coalesce(u.is_sso_user, false),
           'factors', (select count(*) from auth.mfa_factors f where f.user_id = u.id and f.status::text = 'verified'))
    from auth.users u
   where (p_uid is not null and u.id = p_uid) or (p_uid is null and p_email is not null and lower(u.email) = lower(p_email))
   limit 1 $$;
revoke all on function public.localid_user(text, uuid) from public, anon, authenticated;

create or replace function public._localid_token() returns text language sql volatile set search_path = pg_catalog, extensions as $$
  select translate(rtrim(encode(extensions.gen_random_bytes(9), 'base64'), '='), '+/', '-_') $$;
revoke all on function public._localid_token() from public, anon, authenticated;

create or replace function public.localid_open(p_uid uuid, p_ua text default null, p_ip text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, auth, extensions as $$
declare sid uuid := gen_random_uuid(); tok text := public._localid_token(); aaltype text := coalesce(to_regtype('auth.aal_level')::text, 'text'); ipv inet;
begin
  begin ipv := nullif(p_ip, '')::inet; exception when others then ipv := null; end;
  execute format('insert into auth.sessions(id, user_id, created_at, updated_at, aal, refreshed_at, user_agent, ip) values ($1, $2, now(), now(), %L::%s, now()::timestamp, $3, $4)', 'aal1', aaltype)
    using sid, p_uid, left(p_ua, 400), ipv;
  insert into auth.refresh_tokens(instance_id, token, user_id, revoked, created_at, updated_at, parent, session_id)
    values ('00000000-0000-0000-0000-000000000000', tok, p_uid::text, false, now(), now(), null, sid);
  update auth.users set last_sign_in_at = now() where id = p_uid;
  perform public._localid_log('open', p_uid, sid);
  return jsonb_build_object('session_id', sid, 'refresh', tok);
end $$;
revoke all on function public.localid_open(uuid, text, text) from public, anon, authenticated;

create or replace function public.localid_refresh(p_token text, p_ua text default null, p_ip text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, auth, extensions as $$
declare r record; tok text; u record;
begin
  if p_token is null or length(p_token) < 8 or length(p_token) > 200 then return jsonb_build_object('error', 'invalid_refresh'); end if;
  select * into r from auth.refresh_tokens t where t.token = p_token for update;
  if not found or r.session_id is null then return jsonb_build_object('error', 'invalid_refresh'); end if;
  if r.revoked then
    -- a used token again: a copy of it exists somewhere. 10 s grace for a double click, after that the whole session ends.
    if r.updated_at < now() - interval '10 seconds' then
      delete from auth.refresh_tokens where session_id = r.session_id; delete from auth.sessions where id = r.session_id;
      perform public._localid_log('reuse', r.user_id::uuid, r.session_id);
    end if;
    return jsonb_build_object('error', 'invalid_refresh');
  end if;
  select s.not_after into u from auth.sessions s where s.id = r.session_id;
  if not found or (u.not_after is not null and u.not_after < now()) then return jsonb_build_object('error', 'invalid_refresh'); end if;
  update auth.refresh_tokens set revoked = true, updated_at = now() where id = r.id;
  tok := public._localid_token();
  insert into auth.refresh_tokens(instance_id, token, user_id, revoked, created_at, updated_at, parent, session_id)
    values ('00000000-0000-0000-0000-000000000000', tok, r.user_id, false, now(), now(), p_token, r.session_id);
  update auth.sessions set updated_at = now(), refreshed_at = now()::timestamp where id = r.session_id;
  perform public._localid_log('refresh', r.user_id::uuid, r.session_id);
  return jsonb_build_object('session_id', r.session_id, 'uid', r.user_id, 'refresh', tok);
end $$;
revoke all on function public.localid_refresh(text, text, text) from public, anon, authenticated;

create or replace function public.localid_close(p_session uuid) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, auth as $$
declare uid uuid;
begin
  select s.user_id into uid from auth.sessions s where s.id = p_session;
  if not found then return false; end if;
  delete from auth.refresh_tokens where session_id = p_session; delete from auth.sessions where id = p_session;
  perform public._localid_log('close', uid, p_session);
  return true;
end $$;
revoke all on function public.localid_close(uuid) from public, anon, authenticated;

create or replace function public.localid_verify() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare prev text := repeat('0', 64); r record; broken int := 0; n int := 0; h text;
begin
  for r in select * from public.founder_localid_events order by seq loop
    n := n + 1;
    h := encode(extensions.digest(r.prev_hash || '|' || r.kind || '|' || coalesce(r.uid::text, '') || '|' || coalesce(r.session_id::text, '') || '|' || extract(epoch from r.ts)::text, 'sha256'), 'hex');
    if r.prev_hash <> prev or r.hash <> h then broken := broken + 1; end if;
    prev := r.hash;
  end loop;
  return jsonb_build_object('checked', n, 'broken', broken);
end $$;
revoke all on function public.localid_verify() from public, anon, authenticated;

grant execute on function public.localid_user(text, uuid), public.localid_open(uuid, text, text), public.localid_refresh(text, text, text), public.localid_close(uuid), public.localid_verify() to service_role;

-- the fail-closed take-out of a passkey whose WebAuthn facts were refused (was a REST PATCH in passkey.rs): only an ACTIVE key, only the two columns E117 defines.
create or replace function public.localid_passkey_unregister(p_id uuid, p_reason text) returns boolean
language plpgsql security definer set search_path = pg_catalog, public as $$
declare n int;
begin
  update public.founder_passkeys set revoked_at = now(), revoked_reason = left(p_reason, 200) where id = p_id and revoked_at is null;
  get diagnostics n = row_count; return n = 1;
end $$;
revoke all on function public.localid_passkey_unregister(uuid, text) from public, anon, authenticated;
grant execute on function public.localid_passkey_unregister(uuid, text) to service_role;

-- selftest: runs inside one transaction and rolls back, leaves no row behind.
create or replace function public.localid_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, auth, extensions as $$
declare uid uuid := gen_random_uuid(); o jsonb; r1 jsonb; r2 jsonb; ok int := 0; tot int := 0; e text;
begin
  insert into auth.users(id, email, encrypted_password, email_confirmed_at) values (uid, 'selftest-' || uid || '@invalid.test', 'x', now());
  tot := tot + 1; if (public.localid_user(null, uid)->>'email') like 'selftest-%' then ok := ok + 1; end if;
  o := public.localid_open(uid, 'ua', '127.0.0.1');
  tot := tot + 1; if o ? 'session_id' and (select count(*) from auth.refresh_tokens where session_id = (o->>'session_id')::uuid) = 1 then ok := ok + 1; end if;
  r1 := public.localid_refresh(o->>'refresh');
  tot := tot + 1; if (r1->>'refresh') <> (o->>'refresh') and (select revoked from auth.refresh_tokens where token = o->>'refresh') then ok := ok + 1; end if;
  tot := tot + 1; if (select parent from auth.refresh_tokens where token = r1->>'refresh') = o->>'refresh' then ok := ok + 1; end if;
  tot := tot + 1; if public.localid_refresh('nope-nope-nope') ? 'error' then ok := ok + 1; end if;
  update auth.refresh_tokens set updated_at = now() - interval '1 minute' where token = o->>'refresh';
  tot := tot + 1; if public.localid_refresh(o->>'refresh') ? 'error' then ok := ok + 1; end if;
  tot := tot + 1; if not exists (select 1 from auth.sessions where id = (o->>'session_id')::uuid) then ok := ok + 1; end if;
  o := public.localid_open(uid, null, 'not-an-ip');
  tot := tot + 1; if public.localid_close((o->>'session_id')::uuid) and not public.localid_close((o->>'session_id')::uuid) then ok := ok + 1; end if;
  tot := tot + 1; if (public.localid_verify()->>'broken')::int = 0 then ok := ok + 1; end if;
  tot := tot + 1; begin update public.founder_localid_events set kind = 'open' where seq = (select max(seq) from public.founder_localid_events); exception when sqlstate '42501' then ok := ok + 1; end;
  raise exception 'SELFTEST_ROLLBACK %/%', ok, tot using errcode = 'P0001';
exception when sqlstate 'P0001' then
  get stacked diagnostics e = message_text;
  if e like 'SELFTEST_ROLLBACK%' then return 'localid selftest ' || substr(e, 19); end if; raise;
end $$;
revoke all on function public.localid_selftest() from public, anon, authenticated;
grant execute on function public.localid_selftest() to service_role;

select public.localid_selftest() as result;
