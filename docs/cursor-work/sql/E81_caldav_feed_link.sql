
-- E81 — CalDAV (#6) B: "Calendar link" (bina app ke Google Calendar mein URL se jodna). 23 Oct 2026. E80 ke baad. Dobara chalana safe. Koi DROP nahi.
-- Kyun: Android par CalDAV ke liye paid app (DAVx5) chahiye. Google Calendar "From URL" sirf ek secret https link maangta hai — to har user ko ek alag, kabhi bhi wapas li ja sakne wali, SIRF-PADHNE wali link.
-- Faisla: nayi table nahi — E80 ki `caldav_app_passwords` mein `kind` ('dav' | 'feed'). Wohi hash-only chaabi (token_id + sha256(pepper||secret)), wohi brute-force lock, wohi revoke, wohi "revoked member usi pal band".
--   * HIFAZAT ki jadd: ek kind ki chaabi doosre kind par KABHI nahi chalti. Basic-auth lookup sirf kind='dav'; feed lookup sirf kind='feed'. (Feed link leak ho to CalDAV login nahi khulta, aur ulta.)
--   * har user ki 10 'dav' aur 5 'feed' chaaliyan alag alag gini jaati hain (pehle sab ek saath 10 thin).
--   * `caldav_apppw_list` ab sirf 'dav' dikhata hai; feed ke liye `caldav_feed_list`.
--   * revoke ek hi (`caldav_apppw_revoke`): id + user_id se, dono kind ke liye; history rahti hai (revoked_at).
-- Advance: lock_timeout/statement_timeout, constant default wala ADD COLUMN (metadata-only, table rewrite nahi), NOT VALID -> VALIDATE constraint, pinned search_path, sab function par revoke + service_role grant, RLS pehle se on (E80),
--   naya index NAHI (har user ki <=15 live row; (user_id) wala E80 ka partial index kaafi hai — jo query nahi us ka index nahi).
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.caldav_app_passwords') is null then
    raise exception 'E81 PREFLIGHT: caldav_app_passwords maujood nahi — pehle E80 chalayen' using errcode = 'AX081';
  end if;
  if to_regprocedure('public.caldav_member_ok(uuid,uuid)') is null or to_regprocedure('public.caldav_auth_result(uuid,boolean)') is null then
    raise exception 'E81 PREFLIGHT: E80 ke functions maujood nahi — pehle E80 chalayen' using errcode = 'AX081';
  end if;
end $$;

-- 1. kind ----------------------------------------------------------------------------------------------------------------
alter table public.caldav_app_passwords add column if not exists kind text not null default 'dav';

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'caldav_app_passwords_kind' and conrelid = 'public.caldav_app_passwords'::regclass) then
    alter table public.caldav_app_passwords add constraint caldav_app_passwords_kind check (kind in ('dav', 'feed')) not valid;
  end if;
end $$;
alter table public.caldav_app_passwords validate constraint caldav_app_passwords_kind;

comment on column public.caldav_app_passwords.kind is 'E81: dav = CalDAV app password (Basic auth, /dav/c/...); feed = secret read-only .ics link (/dav/feed/<key>.ics). Ek kind ki chaabi doosre par kabhi nahi chalti.';

-- 2. 'dav' ke purane functions ab sirf kind='dav' par (CREATE OR REPLACE, wohi signature => grants salamat) -------------------
create or replace function public.caldav_apppw_create(p_user uuid, p_org uuid, p_email text, p_label text, p_token_id text, p_hash text)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare v_id uuid; v_n integer;
begin
  if not public.caldav_member_ok(p_org, p_user) then return jsonb_build_object('error', 'forbidden'); end if;
  if char_length(btrim(coalesce(p_label, ''))) not between 1 and 40 then return jsonb_build_object('error', 'bad_label'); end if;
  if not public.caldav_token_id_ok(p_token_id) or not public.caldav_hash_ok(p_hash) then return jsonb_build_object('error', 'bad_secret'); end if;
  select count(*) into v_n from public.caldav_app_passwords where user_id = p_user and kind = 'dav' and revoked_at is null;
  if v_n >= 10 then return jsonb_build_object('error', 'too_many'); end if;
  begin
    insert into public.caldav_app_passwords (user_id, org_id, email, label, token_id, secret_hash, kind)
    values (p_user, p_org, lower(btrim(p_email)), btrim(p_label), p_token_id, p_hash, 'dav') returning id into v_id;
  exception when unique_violation then
    return jsonb_build_object('error', 'retry');
  end;
  return jsonb_build_object('id', v_id);
end $$;

create or replace function public.caldav_apppw_list(p_user uuid)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', label, 'created_at', created_at, 'last_used_at', last_used_at) order by created_at desc), '[]'::jsonb)
  from public.caldav_app_passwords where user_id = p_user and kind = 'dav' and revoked_at is null $$;

create or replace function public.caldav_auth_lookup(p_token_id text)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select jsonb_build_object('id', a.id, 'user_id', a.user_id, 'org_id', a.org_id, 'email', a.email, 'secret_hash', a.secret_hash)
  from public.caldav_app_passwords a
  where a.token_id = p_token_id and a.kind = 'dav' and a.revoked_at is null and (a.locked_until is null or a.locked_until <= now())
    and public.caldav_member_ok(a.org_id, a.user_id) $$;

-- 3. 'feed' ke naye functions ----------------------------------------------------------------------------------------------
create or replace function public.caldav_feed_create(p_user uuid, p_org uuid, p_email text, p_label text, p_token_id text, p_hash text)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare v_id uuid; v_n integer;
begin
  if not public.caldav_member_ok(p_org, p_user) then return jsonb_build_object('error', 'forbidden'); end if;
  if char_length(btrim(coalesce(p_label, ''))) not between 1 and 40 then return jsonb_build_object('error', 'bad_label'); end if;
  if not public.caldav_token_id_ok(p_token_id) or not public.caldav_hash_ok(p_hash) then return jsonb_build_object('error', 'bad_secret'); end if;
  select count(*) into v_n from public.caldav_app_passwords where user_id = p_user and kind = 'feed' and revoked_at is null;
  if v_n >= 5 then return jsonb_build_object('error', 'too_many'); end if;
  begin
    insert into public.caldav_app_passwords (user_id, org_id, email, label, token_id, secret_hash, kind)
    values (p_user, p_org, lower(btrim(p_email)), btrim(p_label), p_token_id, p_hash, 'feed') returning id into v_id;
  exception when unique_violation then
    return jsonb_build_object('error', 'retry');
  end;
  return jsonb_build_object('id', v_id);
end $$;

create or replace function public.caldav_feed_list(p_user uuid)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', label, 'created_at', created_at, 'last_used_at', last_used_at) order by created_at desc), '[]'::jsonb)
  from public.caldav_app_passwords where user_id = p_user and kind = 'feed' and revoked_at is null $$;

-- feed ka lookup: sirf kind='feed'. Hash Rust compare karta hai (constant-time). Revoked/locked/non-member => null.
create or replace function public.caldav_feed_lookup(p_token_id text)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select jsonb_build_object('id', a.id, 'user_id', a.user_id, 'org_id', a.org_id, 'email', a.email, 'secret_hash', a.secret_hash)
  from public.caldav_app_passwords a
  where a.token_id = p_token_id and a.kind = 'feed' and a.revoked_at is null and (a.locked_until is null or a.locked_until <= now())
    and public.caldav_member_ok(a.org_id, a.user_id) $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.caldav_apppw_create(uuid,uuid,text,text,text,text)', 'public.caldav_apppw_list(uuid)', 'public.caldav_auth_lookup(text)',
    'public.caldav_feed_create(uuid,uuid,text,text,text,text)', 'public.caldav_feed_list(uuid)', 'public.caldav_feed_lookup(text)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
