
-- E80 — CalDAV (#6) neev: phone/desktop calendar app ke liye "app password" + events par etag/ctag. 23 Oct 2026. E79 ke baad. Dobara chalana safe. Koi DROP nahi.
-- Kyun: iPhone/DAVx5/Thunderbird web login (passkey) nahi karte; woh HTTP Basic maangte hain. Isliye alag, sirf-calendar wali, kabhi bhi wapas li ja sakne wali chaabi.
-- Qaida (Rust dav_core ka mirror, DB kabhi Rust se sakht nahi):
--   * chaabi ka asli matn DB mein KABHI nahi: sirf token_id (10 chhote akshar/ank, lookup ke liye) + secret_hash (sha256 hex, Rust pepper ke saath banata hai). Asli chaabi sirf ek baar user ko dikhti hai.
--   * har user ki zyada se zyada 10 chalu chaabiyan; label 1..40; revoke = revoked_at (history rahti hai, auth band).
--   * brute-force: 8 ghalat koshish -> 15 minute lock (fail_count, locked_until); sahi koshish par fail_count 0.
--   * revoked/removed member ki chaabi usi pal band: caldav_auth_lookup har baar org_members.status='active' dekhta hai (G29 ka sabaq).
--   * events par `dav_rev` (har badlav par +1) aur `dav_updated_at` => asli etag; org ki `caldav_org_state.ctag` har insert/update/delete par +1 => asli ctag. Pehle koi updated_at tha hi nahi.
-- Advance: lock_timeout/statement_timeout, NOT VALID -> VALIDATE constraints, IMMUTABLE shape-function (pinned search_path), RLS on + service_role policy, revoke from public/anon/authenticated, partial indexes,
--   FK ON DELETE CASCADE (account delete = chaabiyan saaf), trigger function par bhi revoke, comments.
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.calendar_events') is null then
    raise exception 'E80 PREFLIGHT: calendar_events maujood nahi — pehle E31 chalayen' using errcode = 'AX080';
  end if;
  if to_regclass('public.org_members') is null then
    raise exception 'E80 PREFLIGHT: org_members maujood nahi' using errcode = 'AX080';
  end if;
end $$;

-- 1. shape (CHECK ke andar chalne wali, immutable) -------------------------------------------------------------------
create or replace function public.caldav_token_id_ok(t text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as
$$ select t is not null and t ~ '^[a-z2-7]{10}$' $$;

create or replace function public.caldav_hash_ok(h text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as
$$ select h is not null and h ~ '^[0-9a-f]{64}$' $$;

-- 2. app passwords ----------------------------------------------------------------------------------------------------
create table if not exists public.caldav_app_passwords (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  org_id       uuid not null,
  email        text not null,
  label        text not null,
  token_id     text not null,
  secret_hash  text not null,
  created_at   timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at   timestamptz,
  fail_count   integer not null default 0,
  locked_until timestamptz
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'caldav_app_passwords_shape') then
    alter table public.caldav_app_passwords add constraint caldav_app_passwords_shape check (
      char_length(btrim(label)) between 1 and 40
      and char_length(email) between 3 and 254
      and public.caldav_token_id_ok(token_id)
      and public.caldav_hash_ok(secret_hash)
      and fail_count >= 0
    ) not valid;
  end if;
end $$;
alter table public.caldav_app_passwords validate constraint caldav_app_passwords_shape;

create unique index if not exists caldav_app_passwords_token_uidx on public.caldav_app_passwords (token_id);
create index if not exists caldav_app_passwords_user_live_idx on public.caldav_app_passwords (user_id, created_at desc) where revoked_at is null;

alter table public.caldav_app_passwords enable row level security;
revoke all on public.caldav_app_passwords from public, anon, authenticated;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'caldav_app_passwords' and policyname = 'caldav_app_passwords_service') then
    create policy caldav_app_passwords_service on public.caldav_app_passwords for all to service_role using (true) with check (true);
  end if;
end $$;
comment on table public.caldav_app_passwords is 'CalDAV app passwords (E80). Matn kabhi nahi, sirf sha256 hash. Sirf service_role (Rust dav module).';

-- 3. events par etag + org ka ctag -----------------------------------------------------------------------------------
alter table public.calendar_events add column if not exists dav_rev        bigint      not null default 1;
alter table public.calendar_events add column if not exists dav_updated_at timestamptz not null default now();

create table if not exists public.caldav_org_state (
  org_id uuid primary key,
  ctag   bigint not null default 1
);
alter table public.caldav_org_state enable row level security;
revoke all on public.caldav_org_state from public, anon, authenticated;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'caldav_org_state' and policyname = 'caldav_org_state_service') then
    create policy caldav_org_state_service on public.caldav_org_state for all to service_role using (true) with check (true);
  end if;
end $$;

create or replace function public.calendar_dav_touch()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'UPDATE' then
    new.dav_rev := coalesce(old.dav_rev, 0) + 1;
    new.dav_updated_at := now();
  end if;
  insert into public.caldav_org_state as s (org_id, ctag)
  values (case when tg_op = 'DELETE' then old.org_id else new.org_id end, 2)
  on conflict (org_id) do update set ctag = s.ctag + 1;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
revoke all on function public.calendar_dav_touch() from public, anon, authenticated;

-- BEFORE UPDATE + AFTER INSERT/DELETE alag trigger (BEFORE se hi NEW badal sakte hain)
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'calendar_dav_touch_upd' and tgrelid = 'public.calendar_events'::regclass) then
    create trigger calendar_dav_touch_upd before update on public.calendar_events for each row execute function public.calendar_dav_touch();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'calendar_dav_touch_insdel' and tgrelid = 'public.calendar_events'::regclass) then
    create trigger calendar_dav_touch_insdel after insert or delete on public.calendar_events for each row execute function public.calendar_dav_touch();
  end if;
end $$;

-- 4. proc-level functions (sirf service_role) ------------------------------------------------------------------------
create or replace function public.caldav_member_ok(p_org uuid, p_user uuid)
returns boolean language sql stable set search_path = pg_catalog, public as
$$ select p_org is not null and p_user is not null and exists (
     select 1 from public.org_members m where m.org_id = p_org and m.user_id = p_user and m.status = 'active') $$;

create or replace function public.caldav_apppw_create(p_user uuid, p_org uuid, p_email text, p_label text, p_token_id text, p_hash text)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare v_id uuid; v_n integer;
begin
  if not public.caldav_member_ok(p_org, p_user) then return jsonb_build_object('error', 'forbidden'); end if;
  if char_length(btrim(coalesce(p_label, ''))) not between 1 and 40 then return jsonb_build_object('error', 'bad_label'); end if;
  if not public.caldav_token_id_ok(p_token_id) or not public.caldav_hash_ok(p_hash) then return jsonb_build_object('error', 'bad_secret'); end if;
  select count(*) into v_n from public.caldav_app_passwords where user_id = p_user and revoked_at is null;
  if v_n >= 10 then return jsonb_build_object('error', 'too_many'); end if;
  begin
    insert into public.caldav_app_passwords (user_id, org_id, email, label, token_id, secret_hash)
    values (p_user, p_org, lower(btrim(p_email)), btrim(p_label), p_token_id, p_hash) returning id into v_id;
  exception when unique_violation then
    return jsonb_build_object('error', 'retry');
  end;
  return jsonb_build_object('id', v_id);
end $$;

create or replace function public.caldav_apppw_list(p_user uuid)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', label, 'created_at', created_at, 'last_used_at', last_used_at) order by created_at desc), '[]'::jsonb)
  from public.caldav_app_passwords where user_id = p_user and revoked_at is null $$;

create or replace function public.caldav_apppw_revoke(p_user uuid, p_id uuid)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare v_n integer;
begin
  update public.caldav_app_passwords set revoked_at = now() where id = p_id and user_id = p_user and revoked_at is null;
  get diagnostics v_n = row_count;
  return jsonb_build_object('revoked', v_n);
end $$;

-- auth: sirf lookup (hash Rust compare karta hai, constant-time). Revoked/locked/non-member => null.
create or replace function public.caldav_auth_lookup(p_token_id text)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select jsonb_build_object('id', a.id, 'user_id', a.user_id, 'org_id', a.org_id, 'email', a.email, 'secret_hash', a.secret_hash)
  from public.caldav_app_passwords a
  where a.token_id = p_token_id and a.revoked_at is null and (a.locked_until is null or a.locked_until <= now())
    and public.caldav_member_ok(a.org_id, a.user_id) $$;

create or replace function public.caldav_auth_result(p_id uuid, p_ok boolean)
returns void language plpgsql set search_path = pg_catalog, public as $$
begin
  if p_ok then
    update public.caldav_app_passwords set last_used_at = now(), fail_count = 0, locked_until = null where id = p_id;
  else
    update public.caldav_app_passwords
       set fail_count = fail_count + 1,
           locked_until = case when fail_count + 1 >= 8 then now() + interval '15 minutes' else locked_until end
     where id = p_id;
  end if;
end $$;

create or replace function public.caldav_ctag(p_org uuid)
returns bigint language sql stable set search_path = pg_catalog, public as
$$ select coalesce((select ctag from public.caldav_org_state where org_id = p_org), 1) $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.caldav_member_ok(uuid,uuid)', 'public.caldav_apppw_create(uuid,uuid,text,text,text,text)', 'public.caldav_apppw_list(uuid)',
    'public.caldav_apppw_revoke(uuid,uuid)', 'public.caldav_auth_lookup(text)', 'public.caldav_auth_result(uuid,boolean)', 'public.caldav_ctag(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on column public.calendar_events.dav_rev is 'E80: har badlav par +1 — CalDAV etag ka hissa (id + dav_rev).';
comment on column public.calendar_events.dav_updated_at is 'E80: aakhri badlav ka waqt — CalDAV getlastmodified.';
comment on table public.caldav_org_state is 'E80: org ka CalDAV ctag — calendar_events par har insert/update/delete par +1.';
