-- E72 — Appeals: 20,000-character statement + evidence files (screenshots, PDFs, documents) — 23 Oct 2026
--
-- Founder order (23 Oct 01:17): appeal ka text 20,000 characters tak, aur attachments (Rust + tokio async par) wagera.
--
-- Kya badalta hai
--   1. Statement ki had: 20..20,000 characters — device appeal (device_appeal_open), logged-out sign-up appeal
--      (identity_signup_appeals) aur user ka apna appeal (account_integrity_appeal). Pehle sign-up appeal 2,000 par tha.
--   2. Evidence files: user appeal se PEHLE file upload karta hai (Rust stream: /file/appeal-evidence), phir appeal ke saath
--      file ids bhejta hai; appeal khulte hi files us se jud jati hain (appeal_evidence_links). Bytes sirf Rust ke disk par,
--      DB mein sirf metadata. Dedup SIRF usi user ke andar (sha256).
--   3. Reviewer sirf JUDI hui files dekh/utaar sakta hai, har download appeal_evidence_access mein likha jata hai.
--   4. Hadein (appeal_limits mein, badli ja sakti hain): 5 files, 10 MB har file, 25 MB kul, 20 uploads/din, 10 appeals/din.
--   5. Safai: be-appeal files 48 ghante baad, hataye hue 1 ghante baad, faisle ke 90 din baad, aur jis user ka account mit gaya.
--      Pehle file disk se hatti hai, phir row (purge_list -> script -> purge_done): beech mein crash ho to kuch bhatakta nahi.
--
-- Sab tables RLS ON, anon/authenticated ko koi haq nahi; functions SECURITY DEFINER, search_path pinned, sirf service_role.
-- PEHLE: phase23 (device_ban_appeals, device_bans, device_vault), E46, E68, E70. Dobara chalana safe. Kuch delete nahi karta.
set search_path = public, extensions;

do $$
begin
  if to_regclass('public.device_ban_appeals') is null or to_regclass('public.device_bans') is null
     or to_regclass('public.device_vault') is null or to_regclass('public.identity_signup_appeals') is null then
    raise exception 'E72: pehle phase23 + E68 chalayen (device_ban_appeals / device_bans / device_vault / identity_signup_appeals nahi mile)';
  end if;
end $$;

-- ---- 1. hadein (ek hi jagah; Rust aur SQL dono yahin se padhte hain) -----------------------------------------------------------
create table if not exists public.appeal_limits (
  key        text primary key,
  value      bigint not null check (value > 0),
  note       text,
  updated_at timestamptz not null default now()
);
alter table public.appeal_limits enable row level security;
revoke all on public.appeal_limits from public, anon, authenticated;
grant select, insert, update, delete on public.appeal_limits to service_role;
do $$ begin
  if not exists (select 1 from pg_policy where polrelid = 'public.appeal_limits'::regclass and polname = 'ax_service_role_only') then
    create policy ax_service_role_only on public.appeal_limits for all to service_role using (true) with check (true);
  end if;
end $$;
insert into public.appeal_limits (key, value, note) values
  ('statement_min_chars',      20,         'minimum characters in an appeal statement'),
  ('statement_max_chars',      20000,      'maximum characters in an appeal statement'),
  ('max_files',                5,          'evidence files per appeal'),
  ('max_file_bytes',           10000000,   'bytes per evidence file'),
  ('max_total_bytes',          25000000,   'bytes of evidence per appeal'),
  ('max_uploads_per_day',      20,         'evidence uploads one user may make in 24 hours'),
  ('max_appeals_per_day',      10,         'appeal rows one user may open in 24 hours'),
  ('staged_ttl_hours',         48,         'uploaded but never attached to an appeal: removed after this many hours'),
  ('keep_days_after_decision', 90,         'evidence is deleted this many days after the appeal is decided')
on conflict (key) do nothing;

create or replace function public._ap_limit(_key text, _default bigint)
returns bigint language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce((select value from public.appeal_limits where key = _key), _default)
$$;

-- ---- 2. tables ----------------------------------------------------------------------------------------------------------------------
create table if not exists public.appeal_evidence (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null,                       -- FIR KEY NAHI: account mit jaye to bhi file ki safai purge se hoti hai
  sha256     text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  filename   text not null check (char_length(filename) between 1 and 200),
  mime       text not null default 'application/octet-stream' check (char_length(mime) <= 120),
  size_bytes bigint not null check (size_bytes > 0),
  rel_path   text not null check (rel_path ~ '^appeals/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{2}/[0-9a-f]{64}-[0-9a-f]{8}$'),
  scan       jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  removed_at timestamptz
);
create unique index if not exists appeal_evidence_user_sha_live on public.appeal_evidence (user_id, sha256) where removed_at is null;
create index if not exists appeal_evidence_user_created on public.appeal_evidence (user_id, created_at desc);
alter table public.appeal_evidence enable row level security;
revoke all on public.appeal_evidence from public, anon, authenticated;
grant select, insert, update, delete on public.appeal_evidence to service_role;

create table if not exists public.appeal_evidence_links (
  appeal_id   uuid not null references public.device_ban_appeals (id) on delete cascade,
  evidence_id uuid not null references public.appeal_evidence (id) on delete cascade,
  linked_at   timestamptz not null default now(),
  primary key (appeal_id, evidence_id)
);
create index if not exists appeal_evidence_links_ev on public.appeal_evidence_links (evidence_id);
alter table public.appeal_evidence_links enable row level security;
revoke all on public.appeal_evidence_links from public, anon, authenticated;
grant select, insert, update, delete on public.appeal_evidence_links to service_role;

create table if not exists public.appeal_evidence_access (
  id          bigserial primary key,
  evidence_id uuid not null,                      -- FIR KEY NAHI: file mit jaye to bhi "kisne dekhi" ka record rahe
  actor       uuid not null,
  kind        text not null check (kind in ('download')),
  at          timestamptz not null default now()
);
create index if not exists appeal_evidence_access_ev on public.appeal_evidence_access (evidence_id, at desc);
alter table public.appeal_evidence_access enable row level security;
revoke all on public.appeal_evidence_access from public, anon, authenticated;
grant select, insert, update, delete on public.appeal_evidence_access to service_role;
grant usage, select on sequence public.appeal_evidence_access_id_seq to service_role;

do $$
declare t text;
begin
  foreach t in array array['appeal_evidence', 'appeal_evidence_links', 'appeal_evidence_access'] loop
    if not exists (select 1 from pg_policy where polrelid = ('public.' || t)::regclass and polname = 'ax_service_role_only') then
      execute format('create policy ax_service_role_only on public.%I for all to service_role using (true) with check (true)', t);
    end if;
  end loop;
end $$;

-- ---- 3. statement ki had (table level) ----------------------------------------------------------------------------------------------
-- sign-up appeal: purani 20..2000 check hatao, 20..20000 lagao
do $$
declare c record;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.identity_signup_appeals'::regclass and contype = 'c'
              and pg_get_constraintdef(oid) like '%char_length(statement)%' and conname <> 'identity_signup_appeals_statement_20k'
  loop
    execute format('alter table public.identity_signup_appeals drop constraint %I', c.conname);
  end loop;
  if not exists (select 1 from pg_constraint where conrelid = 'public.identity_signup_appeals'::regclass and conname = 'identity_signup_appeals_statement_20k') then
    alter table public.identity_signup_appeals
      add constraint identity_signup_appeals_statement_20k check (char_length(statement) between 20 and 20000);
  end if;
  -- device appeal: naye rows par had (purane rows ko chhedna nahi)
  if not exists (select 1 from pg_constraint where conrelid = 'public.device_ban_appeals'::regclass and conname = 'device_ban_appeals_statement_20k') then
    alter table public.device_ban_appeals
      add constraint device_ban_appeals_statement_20k check (char_length(statement) <= 20000) not valid;
  end if;
end $$;

-- ---- 4. kaun appeal kar sakta hai (storage ka galat istemal rokne ke liye) ------------------------------------------------------------
create or replace function public._appeal_eligible(_user uuid)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select _user is not null and (
    exists (select 1 from public.account_integrity i where i.user_id = _user and i.state in ('blocked', 'warned', 'purged'))
    or exists (select 1 from public.device_vault v join public.device_bans b on b.device_hash = v.device_hash and b.appealable
                where v.user_id = _user)
  )
$$;

-- ---- 5. evidence: ctx / register / remove --------------------------------------------------------------------------------------------
create or replace function public.appeal_evidence_ctx(_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
begin
  if _user is null then return jsonb_build_object('ok', false, 'error', 'unauthorized'); end if;
  return jsonb_build_object(
    'ok', true,
    'eligible', public._appeal_eligible(_user),
    'statement_min', public._ap_limit('statement_min_chars', 20),
    'statement_max', public._ap_limit('statement_max_chars', 20000),
    'max_files', public._ap_limit('max_files', 5),
    'max_file_bytes', public._ap_limit('max_file_bytes', 10000000),
    'max_total_bytes', public._ap_limit('max_total_bytes', 25000000),
    'staged_files', (select count(*) from public.appeal_evidence e
                      where e.user_id = _user and e.removed_at is null
                        and not exists (select 1 from public.appeal_evidence_links l where l.evidence_id = e.id)),
    'staged_bytes', coalesce((select sum(e.size_bytes) from public.appeal_evidence e
                      where e.user_id = _user and e.removed_at is null
                        and not exists (select 1 from public.appeal_evidence_links l where l.evidence_id = e.id)), 0),
    'uploads_today', (select count(*) from public.appeal_evidence e where e.user_id = _user and e.created_at > now() - interval '24 hours'));
end $$;

create or replace function public.appeal_evidence_register(
  _user uuid, _sha256 text, _size bigint, _filename text, _mime text, _rel_path text, _scan jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public, extensions set statement_timeout = '8s' as $$
declare
  v_name   text := left(btrim(coalesce(_filename, '')), 200);
  v_max    bigint := public._ap_limit('max_file_bytes', 10000000);
  v_files  bigint; v_bytes bigint; v_id uuid; v_old public.appeal_evidence;
begin
  if _user is null or not exists (select 1 from auth.users where id = _user) then
    return jsonb_build_object('ok', false, 'error', 'unauthorized');
  end if;
  if not public._appeal_eligible(_user) then
    return jsonb_build_object('ok', false, 'error', 'nothing_to_appeal');
  end if;
  if _sha256 is null or _sha256 !~ '^[0-9a-f]{64}$' or coalesce(_size, 0) <= 0 or v_name = '' then
    return jsonb_build_object('ok', false, 'error', 'bad_file');
  end if;
  if _size > v_max then
    return jsonb_build_object('ok', false, 'error', 'file_too_large', 'limit_bytes', v_max);
  end if;

  perform pg_advisory_xact_lock(hashtextextended('appeal_evidence:' || _user::text, 72));

  -- usi user ki wahi file pehle se hai => nayi byte nahi (dedup sirf user ke andar)
  select * into v_old from public.appeal_evidence where user_id = _user and sha256 = _sha256 and removed_at is null;
  if found then
    return jsonb_build_object('ok', true, 'id', v_old.id, 'filename', v_old.filename, 'deduped', true);
  end if;

  if (select count(*) from public.appeal_evidence e where e.user_id = _user and e.created_at > now() - interval '24 hours')
       >= public._ap_limit('max_uploads_per_day', 20) then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  select count(*), coalesce(sum(e.size_bytes), 0) into v_files, v_bytes
    from public.appeal_evidence e
   where e.user_id = _user and e.removed_at is null
     and not exists (select 1 from public.appeal_evidence_links l where l.evidence_id = e.id);
  if v_files >= public._ap_limit('max_files', 5) then
    return jsonb_build_object('ok', false, 'error', 'too_many_files', 'limit', public._ap_limit('max_files', 5));
  end if;
  if v_bytes + _size > public._ap_limit('max_total_bytes', 25000000) then
    return jsonb_build_object('ok', false, 'error', 'total_too_large', 'limit_bytes', public._ap_limit('max_total_bytes', 25000000), 'used_bytes', v_bytes);
  end if;

  insert into public.appeal_evidence (user_id, sha256, filename, mime, size_bytes, rel_path, scan)
  values (_user, _sha256, v_name, left(coalesce(nullif(btrim(_mime), ''), 'application/octet-stream'), 120), _size, _rel_path, coalesce(_scan, '{}'::jsonb))
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'filename', v_name, 'deduped', false);
end $$;

create or replace function public.appeal_evidence_remove(_user uuid, _id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public, extensions as $$
declare v public.appeal_evidence;
begin
  if _user is null then return jsonb_build_object('ok', false, 'error', 'unauthorized'); end if;
  select * into v from public.appeal_evidence where id = _id and user_id = _user and removed_at is null for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  -- appeal mein lag chuki file wapas nahi li ja sakti (reviewer ke saamne saboot badal nahi sakta)
  if exists (select 1 from public.appeal_evidence_links l where l.evidence_id = _id) then
    return jsonb_build_object('ok', false, 'error', 'file_in_appeal');
  end if;
  update public.appeal_evidence set removed_at = now() where id = _id;
  return jsonb_build_object('ok', true);
end $$;

-- ---- 6. appeal kholna (ab 20,000 characters + evidence ke saath, ek hi transaction mein) -------------------------------------------------
create or replace function public.appeal_evidence_attach(_user uuid, _appeal uuid, _ids uuid[])
returns jsonb language plpgsql volatile security definer set search_path = public, extensions as $$
declare v_ids uuid[]; v_ok int; v_bytes bigint;
begin
  select coalesce(array_agg(distinct x), '{}') into v_ids from unnest(coalesce(_ids, '{}')) x;
  if cardinality(v_ids) = 0 then return jsonb_build_object('ok', true, 'linked', 0); end if;
  if cardinality(v_ids) > public._ap_limit('max_files', 5) then
    return jsonb_build_object('ok', false, 'error', 'too_many_files', 'limit', public._ap_limit('max_files', 5));
  end if;
  select count(*), coalesce(sum(e.size_bytes), 0) into v_ok, v_bytes
    from public.appeal_evidence e where e.id = any (v_ids) and e.user_id = _user and e.removed_at is null;
  if v_ok <> cardinality(v_ids) then return jsonb_build_object('ok', false, 'error', 'evidence_invalid'); end if;
  if v_bytes > public._ap_limit('max_total_bytes', 25000000) then
    return jsonb_build_object('ok', false, 'error', 'total_too_large', 'limit_bytes', public._ap_limit('max_total_bytes', 25000000));
  end if;
  insert into public.appeal_evidence_links (appeal_id, evidence_id) select _appeal, x from unnest(v_ids) x on conflict do nothing;
  return jsonb_build_object('ok', true, 'linked', cardinality(v_ids));
end $$;

create or replace function public.device_appeal_open_v2(_user uuid, _device_hash text, _statement text, _evidence uuid[] default '{}')
returns jsonb language plpgsql volatile security definer set search_path = public, extensions as $$
declare
  v_id uuid; v_txt text := btrim(coalesce(_statement, ''));
  v_min int := public._ap_limit('statement_min_chars', 20); v_max int := public._ap_limit('statement_max_chars', 20000);
  v_att jsonb;
begin
  if _user is null or coalesce(_device_hash, '') = '' then raise exception 'user_device_required'; end if;
  if char_length(v_txt) < v_min then
    return jsonb_build_object('ok', false, 'error', 'statement_required',
      'message', format('Tell us in at least %s characters why this block is wrong.', v_min));
  end if;
  if char_length(v_txt) > v_max then
    return jsonb_build_object('ok', false, 'error', 'statement_too_long', 'limit', v_max,
      'message', format('An appeal can be up to %s characters.', to_char(v_max, 'FM999,999')));
  end if;
  if not exists (select 1 from public.device_bans b where b.device_hash = _device_hash and b.appealable) then
    return jsonb_build_object('ok', false, 'error', 'no_appealable_ban');
  end if;
  if exists (select 1 from public.device_ban_appeals a
              where a.device_hash = _device_hash and a.user_id = _user and a.state in ('new', 'reviewing')) then
    return jsonb_build_object('ok', false, 'error', 'appeal_already_open');
  end if;
  if (select count(*) from public.device_ban_appeals a where a.user_id = _user and a.created_at > now() - interval '24 hours')
       >= public._ap_limit('max_appeals_per_day', 10) then
    return jsonb_build_object('ok', false, 'error', 'rate_limited', 'message', 'Too many appeals today. A person is already reading the earlier ones.');
  end if;

  insert into public.device_ban_appeals (device_hash, user_id, statement)
  values (_device_hash, _user, v_txt) returning id into v_id;

  v_att := public.appeal_evidence_attach(_user, v_id, _evidence);
  if not coalesce((v_att ->> 'ok')::boolean, false) then
    -- evidence ghalat => poora appeal wapas (adhoora appeal nahi chhodte)
    raise exception 'evidence_rejected:%', coalesce(v_att ->> 'error', 'evidence_invalid') using errcode = 'P0001';
  end if;

  insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
  values (_user, _device_hash, 'appealed', 'user', jsonb_build_object('appeal_id', v_id, 'evidence', coalesce((v_att ->> 'linked')::int, 0)));

  return jsonb_build_object('ok', true, 'appeal_id', v_id, 'state', 'new', 'evidence', coalesce((v_att ->> 'linked')::int, 0));
exception when sqlstate 'P0001' then
  if sqlerrm like 'evidence_rejected:%' then
    return jsonb_build_object('ok', false, 'error', substr(sqlerrm, char_length('evidence_rejected:') + 1),
      'message', 'One of the attached files could not be used. Remove it and try again.');
  end if;
  raise;
end $$;

-- purana naam (Rust/Brain/E46 ki purani calls) wahi chalta hai — ab 20,000 ki had aur rate limit ke saath
create or replace function public.device_appeal_open(_user uuid, _device_hash text, _statement text)
returns jsonb language sql volatile security definer set search_path = public, extensions as $$
  select public.device_appeal_open_v2(_user, _device_hash, _statement, '{}'::uuid[])
$$;

create or replace function public.account_integrity_appeal_v2(_user uuid, _statement text, _evidence uuid[] default '{}')
returns jsonb language plpgsql volatile security definer set search_path = public, extensions as $$
declare h text; res jsonb; opened int := 0; last_err text; first_id uuid;
begin
  if _user is null then raise exception 'user_required'; end if;
  if not exists (select 1 from public.account_integrity where user_id = _user and state in ('blocked', 'warned', 'purged')) then
    return jsonb_build_object('ok', false, 'error', 'nothing_to_appeal');
  end if;
  for h in select distinct v.device_hash from public.device_vault v
             join public.device_bans b on b.device_hash = v.device_hash and b.appealable
            where v.user_id = _user
  loop
    res := public.device_appeal_open_v2(_user, h, _statement, _evidence);
    if coalesce((res ->> 'ok')::boolean, false) then
      opened := opened + 1; first_id := coalesce(first_id, (res ->> 'appeal_id')::uuid);
    else
      last_err := res ->> 'error';
      if last_err in ('statement_required', 'statement_too_long', 'rate_limited') or last_err in ('too_many_files', 'total_too_large', 'evidence_invalid') then
        return res;
      end if;
    end if;
  end loop;
  if opened = 0 then
    return jsonb_build_object('ok', false, 'error', coalesce(last_err, 'no_appealable_ban'),
      'message', case when last_err = 'appeal_already_open' then 'Your appeal is already with a reviewer.'
                      else 'No appealable device block found on this account.' end);
  end if;
  return jsonb_build_object('ok', true, 'appeal_id', first_id, 'devices', opened);
end $$;

create or replace function public.account_integrity_appeal(_user uuid, _statement text)
returns jsonb language sql volatile security definer set search_path = public, extensions as $$
  select public.account_integrity_appeal_v2(_user, _statement, '{}'::uuid[])
$$;

-- ---- 7. reviewer / owner: list, resolve, queue ---------------------------------------------------------------------------------------
create or replace function public.appeal_evidence_list(_actor uuid, _appeal uuid)
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
declare v_owner uuid;
begin
  select user_id into v_owner from public.device_ban_appeals where id = _appeal;
  if v_owner is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not (public.safety_can_review(_actor) or v_owner = _actor) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  return jsonb_build_object('ok', true, 'files', coalesce((
    select jsonb_agg(jsonb_build_object('id', e.id, 'filename', e.filename, 'mime', e.mime, 'size_bytes', e.size_bytes,
                                        'scanned', coalesce((e.scan ->> 'scanned')::boolean, false), 'created_at', e.created_at)
                     order by e.created_at)
      from public.appeal_evidence_links l join public.appeal_evidence e on e.id = l.evidence_id
     where l.appeal_id = _appeal and e.removed_at is null), '[]'::jsonb));
end $$;

create or replace function public.appeal_evidence_resolve(_actor uuid, _id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public, extensions as $$
declare e public.appeal_evidence; v_linked boolean; v_reviewer boolean;
begin
  if _actor is null then return jsonb_build_object('ok', false, 'error', 'unauthorized'); end if;
  select * into e from public.appeal_evidence where id = _id and removed_at is null;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  v_linked := exists (select 1 from public.appeal_evidence_links l where l.evidence_id = _id);
  v_reviewer := public.safety_can_review(_actor);
  -- reviewer: sirf appeal se JUDI file. Malik: apni file (judi ya nahi).
  if not ((v_reviewer and v_linked) or e.user_id = _actor) then
    return jsonb_build_object('ok', false, 'error', 'not_found');   -- wajah nahi batate: file ka wajood bhi nahi
  end if;
  if e.user_id <> _actor then
    insert into public.appeal_evidence_access (evidence_id, actor, kind) values (_id, _actor, 'download');
  end if;
  return jsonb_build_object('ok', true, 'rel_path', e.rel_path, 'filename', e.filename, 'mime', e.mime, 'size_bytes', e.size_bytes);
end $$;

-- device_appeal_queue: ab pura statement + judi files ki ginti (signature wahi)
create or replace function public.device_appeal_queue(_actor uuid, _state text default null)
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
begin
  if not public.safety_can_review(_actor) then
    return jsonb_build_object('allowed', false, 'appeals', '[]'::jsonb);
  end if;
  return jsonb_build_object('allowed', true, 'appeals', coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', a.id, 'device_hash', left(a.device_hash, 12) || '…', 'user_id', a.user_id,
        'statement', a.statement, 'state', a.state, 'created_at', a.created_at,
        'decision_reason', a.decision_reason, 'decided_at', a.decided_at,
        'evidence', (select count(*) from public.appeal_evidence_links l join public.appeal_evidence e on e.id = l.evidence_id
                      where l.appeal_id = a.id and e.removed_at is null))
      order by a.created_at desc)
      from public.device_ban_appeals a
     where _state is null or a.state = _state), '[]'::jsonb));
end $$;

-- ---- 8. safai (file pehle, row baad mein) -----------------------------------------------------------------------------------------------
create or replace function public.appeal_evidence_purge_list(_limit int default 500)
returns jsonb language sql stable security definer set search_path = public, extensions as $$
  select jsonb_build_object('files', coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'rel_path', x.rel_path)), '[]'::jsonb))
    from (
      select e.id, e.rel_path
        from public.appeal_evidence e
       where
         -- (a) hataya hua, 1 ghanta guzar gaya
         (e.removed_at is not null and e.removed_at < now() - interval '1 hour')
         -- (b) kabhi appeal se nahi juda, TTL guzar gayi
         or (e.removed_at is null and e.created_at < now() - make_interval(hours => public._ap_limit('staged_ttl_hours', 48)::int)
             and not exists (select 1 from public.appeal_evidence_links l where l.evidence_id = e.id))
         -- (c) saare judey appeals ka faisla ho chuka aur retention guzar gayi
         or (exists (select 1 from public.appeal_evidence_links l where l.evidence_id = e.id)
             and not exists (select 1 from public.appeal_evidence_links l join public.device_ban_appeals a on a.id = l.appeal_id
                              where l.evidence_id = e.id
                                and (a.decided_at is null or a.decided_at >= now() - make_interval(days => public._ap_limit('keep_days_after_decision', 90)::int))))
         -- (d) account mit gaya
         or not exists (select 1 from auth.users u where u.id = e.user_id)
       order by e.created_at
       limit greatest(1, least(coalesce(_limit, 500), 2000))
    ) x
$$;

create or replace function public.appeal_evidence_purge_done(_ids uuid[])
returns jsonb language plpgsql volatile security definer set search_path = public, extensions as $$
declare n int;
begin
  delete from public.appeal_evidence where id = any (coalesce(_ids, '{}'));
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'deleted', n);
end $$;

-- ---- 9. haq: sirf service_role ------------------------------------------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    '_ap_limit(text,bigint)', '_appeal_eligible(uuid)', 'appeal_evidence_ctx(uuid)',
    'appeal_evidence_register(uuid,text,bigint,text,text,text,jsonb)', 'appeal_evidence_remove(uuid,uuid)',
    'appeal_evidence_attach(uuid,uuid,uuid[])', 'device_appeal_open_v2(uuid,text,text,uuid[])', 'device_appeal_open(uuid,text,text)',
    'account_integrity_appeal_v2(uuid,text,uuid[])', 'account_integrity_appeal(uuid,text)', 'appeal_evidence_list(uuid,uuid)',
    'appeal_evidence_resolve(uuid,uuid)', 'device_appeal_queue(uuid,text)', 'appeal_evidence_purge_list(int)', 'appeal_evidence_purge_done(uuid[])']
  loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;

-- ---- 10. post-conditions -----------------------------------------------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['appeal_limits', 'appeal_evidence', 'appeal_evidence_links', 'appeal_evidence_access'] loop
    if not (select c.relrowsecurity from pg_class c where c.oid = ('public.' || t)::regclass) then
      raise exception 'E72: RLS band hai: %', t;
    end if;
    if has_table_privilege('anon', ('public.' || t)::regclass, 'select') or has_table_privilege('authenticated', ('public.' || t)::regclass, 'select') then
      raise exception 'E72: anon/authenticated ko haq mila hua hai: %', t;
    end if;
  end loop;
  if has_function_privilege('authenticated', 'public.appeal_evidence_resolve(uuid,uuid)', 'execute')
     or has_function_privilege('anon', 'public.device_appeal_open_v2(uuid,text,text,uuid[])', 'execute') then
    raise exception 'E72: function par anon/authenticated ka EXECUTE khula hai';
  end if;
end $$;
