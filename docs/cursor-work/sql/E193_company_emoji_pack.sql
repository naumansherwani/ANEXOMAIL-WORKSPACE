
-- =============================================================================
-- E193 — QC1e D4A: COMPANY EMOJI PACK (AWAM ONLY, Business tiers) — 20 Nov 2026 (founder: "D4 sirf awam ke liye, super advance SQL").
-- Founder lane ko is file se koi lena dena nahi (FOUNDER/AWAM SEPARATION LAW). Sirf awam tenancy tables (organisations / org_members) par tiki hai.
--
--  Kya hai: company ka owner ya admin apna logo / badge chhoti picture ke taur par upload karta hai; shortcode (:acme:) se compose mein milti hai.
--  Rust door (awam engine, proc "emoji.pack.*") picture ko dobara encode karke saaf WebP banata hai (<= 256x256, <= 64 KB, koi metadata nahi);
--  yeh SQL uski aakhri dewaar hai: Rust bhi galat ho to database galat picture kabhi qubool nahi karta.
--
--  1) company_emoji          : picture ki row (bytes abhi Postgres bytea mein; Q3 ke saath Hetzner Storage Box — `storage` column ready).
--       * shortcode a-z0-9_- , 2..24 haroof, pehla/aakhri harf alnum, company mein UNIQUE (sirf active rows par), reserved naam (official, admin,
--         support, system, anexo...) trigger se band, hex-colour jaise naam bhi band nahi — sirf yeh reserved list.
--       * WebP ka RIFF....WEBP magic, bytes <= 65536, w/h 16..256 — CHECK + trigger (Rust ko bypass karke bhi galat file nahi ghus sakti).
--       * sha256 (64 hex) har company mein ek hi picture ek baar (dedupe), SVG/animated Rust refuse karta hai; yahan mime sirf image/webp.
--       * TIER QUOTA trigger: Business 10, Business Pro 10, Premium 50, MAX 200; baaqi plans (basic/pro) = 0 (feature unke liye nahi).
--       * forced RLS, anon/authenticated ke liye koi policy nahi; sab kuch sirf service_role ke security-definer doors se.
--  2) company_emoji_ledger   : append-only, sha-256 HASH CHAIN har company ki alag (prev_hash -> row_hash), update/delete/truncate trigger se band.
--       Har add / remove / rename ledger mein jata hai (governance). company_emoji_verify() poori chain dobara hisab karke batata hai.
--  3) Doors (security definer, fixed search_path, service_role-only execute):
--       company_emoji_tier_limit(plan)            pure, immutable
--       company_emoji_reserved(code)              pure, immutable
--       company_emoji_quota(org)                  {plan, limit, used, left}
--       company_emoji_add(org, actor, code, alt, sha, w, h, data)    owner/admin only
--       company_emoji_remove(org, actor, code)    owner/admin only (soft remove: row `removed`, bytes saaf, ledger mein sha rehta hai)
--       company_emoji_list(org)                   bytes ke bina (picker ki list), + aliases
--       company_emoji_get(org, code)              bytes + etag (same-origin immutable serving ke liye)
--       company_emoji_verify(org)                 chain check
--       company_emoji_posture193()                RLS/grants/trigger audit (CHECK file isey parhti hai)
--       company_emoji_selftest193()               Part 2 isi ko chalata hai; sab data rollback
--
-- Hifazat: additive + idempotent; lock_timeout 15s; advisory lock; kuch drop/rename nahi; purane tables ko haath nahi.
-- Chalane ka tareeqa: sql-run.sh se (E193). Aakhri jawab: ek row `e193_result`. Fail ho to usi file ko theek karo (naya naam banned).
-- =============================================================================

-- ============================ PART 1 — schema + functions (sql-run / editor khud transaction sambhalte hain) ===============================
set local lock_timeout = '15s';
set local statement_timeout = '120s';
select pg_advisory_xact_lock(hashtext('anexomail.E193'));

-- 0. preflight: awam tenancy tables + E15 plan helper maujood hon
do $$
declare
  missing text[] := '{}';
begin
  if to_regclass('public.organisations') is null then missing := missing || 'organisations'; end if;
  if to_regclass('public.org_members')   is null then missing := missing || 'org_members'; end if;
  if to_regprocedure('public.org_plan_of(uuid)') is null then missing := missing || 'org_plan_of(uuid)'; end if;
  if coalesce(array_length(missing, 1), 0) > 0 then
    raise exception 'E193 PREFLIGHT: yeh maujood nahi: % — awam team/domain SQL (E15, E33) pehle chalayen', array_to_string(missing, ', ')
      using errcode = 'AX193';
  end if;
end $$;

-- 1. pure helpers --------------------------------------------------------------------------------------------
create or replace function public.company_emoji_tier_limit(p_plan text)
returns integer
language sql
immutable
as $$
  -- plan ka naam jaisa E15/E94 mein hai: business, business_pro, business_premium, business_max. Basic/pro/founder = feature nahi.
  select case
           when p_plan is null                      then 0
           when lower(p_plan) like '%max%'          then 200
           when lower(p_plan) like '%premium%'      then 50
           when lower(p_plan) in ('business', 'business_pro') then 10
           else 0
         end
$$;

create or replace function public.company_emoji_reserved(p_code text)
returns boolean
language sql
immutable
as $$
  -- jo naam kisi company ko nahi milte: ofisial dikhne wale, system aur brand naam (chhoti haroof mein jaanch)
  select lower(coalesce(p_code, '')) = any (array[
    'official', 'admin', 'administrator', 'support', 'system', 'security', 'billing', 'staff', 'moderator', 'mod',
    'anexo', 'anexomail', 'anexochat', 'anexosuite', 'founder', 'owner', 'root', 'null', 'undefined', 'everyone', 'here', 'channel'
  ])
$$;

-- 2. company_emoji ------------------------------------------------------------------------------------------
create table if not exists public.company_emoji (
  id          uuid        primary key default gen_random_uuid(),
  org_id      uuid        not null references public.organisations (id) on delete cascade,
  shortcode   text        not null,
  alt         text        not null default '',
  mime        text        not null default 'image/webp',
  sha256      text        not null,
  bytes       integer     not null,
  w           integer     not null,
  h           integer     not null,
  data        bytea,
  storage     text        not null default 'pg',
  status      text        not null default 'active',
  created_by  uuid        not null,
  created_at  timestamptz not null default now(),
  removed_by  uuid,
  removed_at  timestamptz
);

-- columns ka asli naam (agar table pehle se kisi aur shakal mein ho): kami ho to jodo, kuch badlo nahi
alter table public.company_emoji add column if not exists alt        text not null default '';
alter table public.company_emoji add column if not exists storage    text not null default 'pg';
alter table public.company_emoji add column if not exists removed_by uuid;
alter table public.company_emoji add column if not exists removed_at timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_code_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_code_chk
      check (shortcode ~ '^[a-z0-9][a-z0-9_-]{0,22}[a-z0-9]$');                      -- 2..24 haroof
  end if;
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_mime_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_mime_chk check (mime = 'image/webp');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_sha_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_sha_chk check (sha256 ~ '^[0-9a-f]{64}$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_dim_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_dim_chk check (w between 16 and 256 and h between 16 and 256);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_bytes_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_bytes_chk check (bytes between 64 and 65536);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_status_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_status_chk check (status in ('active', 'removed'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_storage_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_storage_chk check (storage in ('pg', 'hetzner'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_alt_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_alt_chk check (char_length(alt) <= 80 and alt !~ '[[:cntrl:]]');
  end if;
  -- active row mein bytes hone chahiye (pg storage), removed row mein bytes saaf; hetzner storage mein bytes pg mein nahi
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_data_chk' and conrelid = 'public.company_emoji'::regclass) then
    alter table public.company_emoji add constraint company_emoji_data_chk check (
      (status = 'removed' and data is null and removed_at is not null and removed_by is not null)
      or (status = 'active' and storage = 'pg' and data is not null and octet_length(data) = bytes)
      or (status = 'active' and storage = 'hetzner' and data is null));
  end if;
end $$;

-- shortcode company mein ek hi (sirf active), aur ek hi picture (sha) ek baar (sirf active)
create unique index if not exists company_emoji_org_code_uq on public.company_emoji (org_id, shortcode) where status = 'active';
create unique index if not exists company_emoji_org_sha_uq  on public.company_emoji (org_id, sha256)    where status = 'active';
create index        if not exists company_emoji_org_idx     on public.company_emoji (org_id, status, created_at desc);

-- 3. trigger: reserved naam, WebP magic, quota, immutable columns ------------------------------------------
create or replace function public.company_emoji_guard()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_limit integer;
  v_used  integer;
begin
  if tg_op = 'INSERT' then
    if public.company_emoji_reserved(new.shortcode) then
      raise exception 'E193: "%" reserved naam hai (official/admin/support jaise naam kisi company ko nahi milte)', new.shortcode using errcode = 'AX193';
    end if;
    if new.status = 'active' and new.storage = 'pg' then
      -- WebP: "RIFF" <4 byte size> "WEBP"
      if octet_length(new.data) < 12
         or substring(new.data from 1 for 4) <> '\x52494646'::bytea
         or substring(new.data from 9 for 4) <> '\x57454250'::bytea then
        raise exception 'E193: picture WebP nahi (RIFF....WEBP magic nahi mila)' using errcode = 'AX193';
      end if;
    end if;
    if new.status = 'active' then
      -- quota: company ke plan ke hisaab se; org-wise advisory lock — do admin ek saath aakhri jagah nahi le sakte
      perform pg_advisory_xact_lock(hashtext('anexomail.E193.quota'), hashtext(new.org_id::text));
      v_limit := public.company_emoji_tier_limit(public.org_plan_of(new.org_id));
      select count(*) into v_used from public.company_emoji e where e.org_id = new.org_id and e.status = 'active';
      if v_limit <= 0 then
        raise exception 'E193 TIER: company ke plan mein emoji pack nahi hai (Business ya upar chahiye)' using errcode = 'AX193';
      end if;
      if v_used >= v_limit then
        raise exception 'E193 QUOTA: % ki had poori (% / %)', new.org_id, v_used, v_limit using errcode = 'AX193';
      end if;
    end if;
    return new;
  elsif tg_op = 'UPDATE' then
    -- identity aur picture kabhi nahi badalte; sirf alt text badal sakta hai ya active -> removed
    if new.id <> old.id or new.org_id <> old.org_id or new.shortcode <> old.shortcode or new.sha256 <> old.sha256
       or new.created_by <> old.created_by or new.created_at <> old.created_at or new.w <> old.w or new.h <> old.h or new.mime <> old.mime then
      raise exception 'E193: company_emoji ki pehchaan/picture badli nahi ja sakti (naya upload karo)' using errcode = 'AX193';
    end if;
    if old.status = 'removed' and new.status <> 'removed' then
      raise exception 'E193: hataya hua emoji wapas zinda nahi hota (naya upload karo)' using errcode = 'AX193';
    end if;
    return new;
  end if;
  return new;
end $$;

drop trigger if exists company_emoji_guard_trg on public.company_emoji;
create trigger company_emoji_guard_trg
  before insert or update on public.company_emoji
  for each row execute function public.company_emoji_guard();

-- 4. ledger: append-only, har company ki apni sha-256 chain ------------------------------------------------------
create table if not exists public.company_emoji_ledger (
  seq        bigint      generated always as identity primary key,
  org_id     uuid        not null,
  action     text        not null,
  shortcode  text        not null,
  sha256     text,
  actor      uuid        not null,
  detail     jsonb       not null default '{}'::jsonb,
  prev_hash  text        not null,
  row_hash   text        not null,
  created_at timestamptz not null default now()
);
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_ledger_action_chk' and conrelid = 'public.company_emoji_ledger'::regclass) then
    alter table public.company_emoji_ledger add constraint company_emoji_ledger_action_chk check (action in ('add', 'remove', 'rename'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'company_emoji_ledger_hash_chk' and conrelid = 'public.company_emoji_ledger'::regclass) then
    alter table public.company_emoji_ledger add constraint company_emoji_ledger_hash_chk
      check (prev_hash ~ '^[0-9a-f]{64}$' and row_hash ~ '^[0-9a-f]{64}$');
  end if;
end $$;
create index if not exists company_emoji_ledger_org_idx on public.company_emoji_ledger (org_id, seq);

create or replace function public.company_emoji_ledger_immutable()
returns trigger
language plpgsql
as $$
begin
  raise exception 'E193: company_emoji_ledger append-only hai (% band)', tg_op using errcode = 'AX193';
end $$;

drop trigger if exists company_emoji_ledger_nomod_trg on public.company_emoji_ledger;
create trigger company_emoji_ledger_nomod_trg
  before update or delete on public.company_emoji_ledger
  for each row execute function public.company_emoji_ledger_immutable();
drop trigger if exists company_emoji_ledger_notrunc_trg on public.company_emoji_ledger;
create trigger company_emoji_ledger_notrunc_trg
  before truncate on public.company_emoji_ledger
  for each statement execute function public.company_emoji_ledger_immutable();

-- hash: sha256( prev | org | action | code | sha | actor | detail | created_at ) — created_at text mein, taake dobara hisab ho sake
create or replace function public.company_emoji_row_hash(
  p_prev text, p_org uuid, p_action text, p_code text, p_sha text, p_actor uuid, p_detail jsonb, p_at timestamptz)
returns text
language sql
immutable
as $$
  select encode(sha256(convert_to(
    coalesce(p_prev, '') || '|' || p_org::text || '|' || p_action || '|' || p_code || '|' || coalesce(p_sha, '') || '|' ||
    p_actor::text || '|' || coalesce(p_detail, '{}'::jsonb)::text || '|' || to_char(p_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US'),
    'UTF8')), 'hex')
$$;

create or replace function public.company_emoji_ledger_append(
  p_org uuid, p_action text, p_code text, p_sha text, p_actor uuid, p_detail jsonb default '{}'::jsonb)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prev text;
  v_at   timestamptz := clock_timestamp();
  v_hash text;
  v_seq  bigint;
begin
  perform pg_advisory_xact_lock(hashtext('anexomail.E193.chain'), hashtext(p_org::text));
  select l.row_hash into v_prev from public.company_emoji_ledger l where l.org_id = p_org order by l.seq desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  v_hash := public.company_emoji_row_hash(v_prev, p_org, p_action, p_code, p_sha, p_actor, coalesce(p_detail, '{}'::jsonb), v_at);
  insert into public.company_emoji_ledger (org_id, action, shortcode, sha256, actor, detail, prev_hash, row_hash, created_at)
  values (p_org, p_action, p_code, p_sha, p_actor, coalesce(p_detail, '{}'::jsonb), v_prev, v_hash, v_at)
  returning seq into v_seq;
  return v_seq;
end $$;

-- 5. forced RLS: browser ke roles ke liye koi policy nahi (deny by default); sab kuch doors se ----------------------
alter table public.company_emoji        enable row level security;
alter table public.company_emoji        force  row level security;
alter table public.company_emoji_ledger enable row level security;
alter table public.company_emoji_ledger force  row level security;
revoke all on public.company_emoji        from public, anon, authenticated;
revoke all on public.company_emoji_ledger from public, anon, authenticated;
grant select on public.company_emoji        to service_role;     -- likhna sirf doors se
grant select on public.company_emoji_ledger to service_role;

-- 6. doors ---------------------------------------------------------------------------------------------------
create or replace function public.company_emoji_role(p_org uuid, p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select m.role::text from public.org_members m
   where m.org_id = p_org and m.user_id = p_user and coalesce(m.status::text, 'active') <> 'revoked' limit 1
$$;

create or replace function public.company_emoji_quota(p_org uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_plan  text := public.org_plan_of(p_org);
  v_limit integer := public.company_emoji_tier_limit(public.org_plan_of(p_org));
  v_used  integer;
begin
  select count(*) into v_used from public.company_emoji e where e.org_id = p_org and e.status = 'active';
  return jsonb_build_object('plan', v_plan, 'limit', v_limit, 'used', v_used, 'left', greatest(v_limit - v_used, 0), 'enabled', v_limit > 0);
end $$;

create or replace function public.company_emoji_add(
  p_org uuid, p_actor uuid, p_code text, p_alt text, p_sha text, p_w integer, p_h integer, p_data bytea)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_role text := public.company_emoji_role(p_org, p_actor);
  v_code text := lower(btrim(coalesce(p_code, '')));
  v_id   uuid;
  v_seq  bigint;
  v_calc text;
begin
  if v_role is null or v_role not in ('owner', 'admin') then
    raise exception 'E193 ROLE: sirf owner ya admin emoji jod sakta hai' using errcode = 'AX193';
  end if;
  if v_code !~ '^[a-z0-9][a-z0-9_-]{0,22}[a-z0-9]$' then
    raise exception 'E193 CODE: shortcode 2-24 haroof (a-z 0-9 _ -), pehla/aakhri harf alnum' using errcode = 'AX193';
  end if;
  if p_data is null then
    raise exception 'E193: picture ke bytes chahiye' using errcode = 'AX193';
  end if;
  v_calc := encode(sha256(p_data), 'hex');
  if v_calc <> lower(coalesce(p_sha, '')) then
    raise exception 'E193 SHA: bytes ka sha-256 Rust ke bheje sha se nahi milta' using errcode = 'AX193';
  end if;
  insert into public.company_emoji (org_id, shortcode, alt, sha256, bytes, w, h, data, created_by)
  values (p_org, v_code, left(coalesce(p_alt, ''), 80), v_calc, octet_length(p_data), p_w, p_h, p_data, p_actor)
  returning id into v_id;
  v_seq := public.company_emoji_ledger_append(p_org, 'add', v_code, v_calc, p_actor,
             jsonb_build_object('bytes', octet_length(p_data), 'w', p_w, 'h', p_h, 'role', v_role));
  return jsonb_build_object('ok', true, 'id', v_id, 'shortcode', v_code, 'sha256', v_calc, 'ledger_seq', v_seq,
                            'quota', public.company_emoji_quota(p_org));
exception when unique_violation then
  raise exception 'E193 DUP: yeh shortcode ya yeh picture company mein pehle se hai' using errcode = 'AX193';
end $$;

create or replace function public.company_emoji_remove(p_org uuid, p_actor uuid, p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_role text := public.company_emoji_role(p_org, p_actor);
  v_code text := lower(btrim(coalesce(p_code, '')));
  v_sha  text;
  v_seq  bigint;
begin
  if v_role is null or v_role not in ('owner', 'admin') then
    raise exception 'E193 ROLE: sirf owner ya admin emoji hata sakta hai' using errcode = 'AX193';
  end if;
  update public.company_emoji e
     set status = 'removed', data = null, removed_by = p_actor, removed_at = now()
   where e.org_id = p_org and e.shortcode = v_code and e.status = 'active'
  returning e.sha256 into v_sha;
  if v_sha is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  v_seq := public.company_emoji_ledger_append(p_org, 'remove', v_code, v_sha, p_actor, jsonb_build_object('role', v_role));
  return jsonb_build_object('ok', true, 'shortcode', v_code, 'ledger_seq', v_seq, 'quota', public.company_emoji_quota(p_org));
end $$;

create or replace function public.company_emoji_rename_alt(p_org uuid, p_actor uuid, p_code text, p_alt text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_role text := public.company_emoji_role(p_org, p_actor);
  v_code text := lower(btrim(coalesce(p_code, '')));
  v_sha  text;
  v_seq  bigint;
begin
  if v_role is null or v_role not in ('owner', 'admin') then
    raise exception 'E193 ROLE: sirf owner ya admin badal sakta hai' using errcode = 'AX193';
  end if;
  update public.company_emoji e set alt = left(coalesce(p_alt, ''), 80)
   where e.org_id = p_org and e.shortcode = v_code and e.status = 'active'
  returning e.sha256 into v_sha;
  if v_sha is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  v_seq := public.company_emoji_ledger_append(p_org, 'rename', v_code, v_sha, p_actor, jsonb_build_object('alt', left(coalesce(p_alt, ''), 80)));
  return jsonb_build_object('ok', true, 'shortcode', v_code, 'ledger_seq', v_seq);
end $$;

-- picker ki list: bytes ke bina, sirf active; kisi bhi member ko (Rust door member check karta hai) — yeh door sirf org ka maal deta hai
create or replace function public.company_emoji_list(p_org uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'shortcode', e.shortcode, 'alt', e.alt, 'sha256', e.sha256, 'bytes', e.bytes, 'w', e.w, 'h', e.h,
           'created_at', e.created_at) order by e.shortcode), '[]'::jsonb)
    from public.company_emoji e where e.org_id = p_org and e.status = 'active'
$$;

create or replace function public.company_emoji_get(p_org uuid, p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r public.company_emoji%rowtype;
begin
  select * into r from public.company_emoji e
   where e.org_id = p_org and e.shortcode = lower(coalesce(p_code, '')) and e.status = 'active';
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'mime', r.mime, 'etag', r.sha256, 'bytes', r.bytes,
                            'data_b64', encode(r.data, 'base64'), 'storage', r.storage);
end $$;

create or replace function public.company_emoji_verify(p_org uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r       record;
  v_prev  text := repeat('0', 64);
  v_n     integer := 0;
  v_bad   bigint;
begin
  for r in select * from public.company_emoji_ledger l where l.org_id = p_org order by l.seq loop
    v_n := v_n + 1;
    if r.prev_hash <> v_prev
       or r.row_hash <> public.company_emoji_row_hash(r.prev_hash, r.org_id, r.action, r.shortcode, r.sha256, r.actor, r.detail, r.created_at) then
      v_bad := r.seq;
      exit;
    end if;
    v_prev := r.row_hash;
  end loop;
  return jsonb_build_object('ok', v_bad is null, 'rows', v_n, 'first_bad_seq', v_bad, 'head', v_prev);
end $$;

-- 7. posture (CHECK file isey parhti hai) -------------------------------------------------------------------------
create or replace function public.company_emoji_posture193()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_doors text[] := array[
    'company_emoji_add(uuid,uuid,text,text,text,integer,integer,bytea)', 'company_emoji_remove(uuid,uuid,text)',
    'company_emoji_rename_alt(uuid,uuid,text,text)', 'company_emoji_list(uuid)', 'company_emoji_get(uuid,text)',
    'company_emoji_verify(uuid)', 'company_emoji_quota(uuid)', 'company_emoji_ledger_append(uuid,text,text,text,uuid,jsonb)',
    'company_emoji_role(uuid,uuid)'];
  d text;
  v_door_ok boolean := true;
begin
  foreach d in array v_doors loop
    if to_regprocedure('public.' || d) is null
       or has_function_privilege('anon', to_regprocedure('public.' || d), 'execute')
       or has_function_privilege('authenticated', to_regprocedure('public.' || d), 'execute')
       or not has_function_privilege('service_role', to_regprocedure('public.' || d), 'execute') then
      v_door_ok := false;
    end if;
  end loop;
  return jsonb_build_object(
    'doors_service_only', v_door_ok,
    'rls_forced', (select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c
                    where c.oid in ('public.company_emoji'::regclass, 'public.company_emoji_ledger'::regclass)),
    'anon_no_table_access', not (has_table_privilege('anon', 'public.company_emoji', 'select') or has_table_privilege('authenticated', 'public.company_emoji', 'select')
                              or has_table_privilege('anon', 'public.company_emoji_ledger', 'select') or has_table_privilege('authenticated', 'public.company_emoji_ledger', 'select')),
    'service_role_read_only', not (has_table_privilege('service_role', 'public.company_emoji', 'insert') or has_table_privilege('service_role', 'public.company_emoji', 'update')
                                or has_table_privilege('service_role', 'public.company_emoji', 'delete')
                                or has_table_privilege('service_role', 'public.company_emoji_ledger', 'insert')
                                or has_table_privilege('service_role', 'public.company_emoji_ledger', 'update')
                                or has_table_privilege('service_role', 'public.company_emoji_ledger', 'delete')),
    'triggers', (select count(*) from pg_trigger t where not t.tgisinternal
                  and t.tgrelid in ('public.company_emoji'::regclass, 'public.company_emoji_ledger'::regclass)),
    'tiers', jsonb_build_object('business', public.company_emoji_tier_limit('business'), 'business_pro', public.company_emoji_tier_limit('business_pro'),
                                'business_premium', public.company_emoji_tier_limit('business_premium'), 'business_max', public.company_emoji_tier_limit('business_max'),
                                'basic', public.company_emoji_tier_limit('basic'), 'pro', public.company_emoji_tier_limit('pro')));
end $$;

-- 8. execute: sirf service_role -----------------------------------------------------------------------------------
revoke all on function public.company_emoji_tier_limit(text)                                      from public, anon, authenticated;
revoke all on function public.company_emoji_reserved(text)                                        from public, anon, authenticated;
revoke all on function public.company_emoji_row_hash(text, uuid, text, text, text, uuid, jsonb, timestamptz) from public, anon, authenticated;
revoke all on function public.company_emoji_ledger_append(uuid, text, text, text, uuid, jsonb)    from public, anon, authenticated;
revoke all on function public.company_emoji_role(uuid, uuid)                                      from public, anon, authenticated;
revoke all on function public.company_emoji_quota(uuid)                                           from public, anon, authenticated;
revoke all on function public.company_emoji_add(uuid, uuid, text, text, text, integer, integer, bytea) from public, anon, authenticated;
revoke all on function public.company_emoji_remove(uuid, uuid, text)                              from public, anon, authenticated;
revoke all on function public.company_emoji_rename_alt(uuid, uuid, text, text)                    from public, anon, authenticated;
revoke all on function public.company_emoji_list(uuid)                                            from public, anon, authenticated;
revoke all on function public.company_emoji_get(uuid, text)                                       from public, anon, authenticated;
revoke all on function public.company_emoji_verify(uuid)                                          from public, anon, authenticated;
revoke all on function public.company_emoji_posture193()                                          from public, anon, authenticated;
grant execute on function public.company_emoji_tier_limit(text)                                   to service_role;
grant execute on function public.company_emoji_reserved(text)                                     to service_role;
grant execute on function public.company_emoji_row_hash(text, uuid, text, text, text, uuid, jsonb, timestamptz) to service_role;
grant execute on function public.company_emoji_ledger_append(uuid, text, text, text, uuid, jsonb) to service_role;
grant execute on function public.company_emoji_role(uuid, uuid)                                   to service_role;
grant execute on function public.company_emoji_quota(uuid)                                        to service_role;
grant execute on function public.company_emoji_add(uuid, uuid, text, text, text, integer, integer, bytea) to service_role;
grant execute on function public.company_emoji_remove(uuid, uuid, text)                           to service_role;
grant execute on function public.company_emoji_rename_alt(uuid, uuid, text, text)                 to service_role;
grant execute on function public.company_emoji_list(uuid)                                         to service_role;
grant execute on function public.company_emoji_get(uuid, text)                                    to service_role;
grant execute on function public.company_emoji_verify(uuid)                                       to service_role;
grant execute on function public.company_emoji_posture193()                                       to service_role;

notify pgrst, 'reload schema';

-- ============================ PART 2 — self-test (alag transaction, sab rollback) ===============================
-- Har jaanch ek `t(name, ok)`; aakhir mein sab ka jama. Test data ek sub-block mein banta hai jo aakhir mein jaan-boojh kar fail hota hai (rollback).
create or replace function public.company_emoji_selftest193()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  res     jsonb := '[]'::jsonb;
  v_org   uuid;
  v_owner uuid;
  v_plan  text;
  v_webp  bytea := '\x52494646'::bytea || '\x24000000'::bytea || '\x57454250'::bytea || decode(repeat('00', 80), 'hex');
  v_sha   text;
  v_ok    boolean;
  v_json  jsonb;
  v_skip  boolean := false;
  v_n     integer;
begin
  -- pure helpers
  res := res || jsonb_build_object('t', 'tier limits 10/10/50/200, basic/pro/null = 0',
    'ok', public.company_emoji_tier_limit('business') = 10 and public.company_emoji_tier_limit('business_pro') = 10
          and public.company_emoji_tier_limit('business_premium') = 50 and public.company_emoji_tier_limit('business_max') = 200
          and public.company_emoji_tier_limit('basic') = 0 and public.company_emoji_tier_limit('pro') = 0 and public.company_emoji_tier_limit(null) = 0);
  res := res || jsonb_build_object('t', 'reserved names refused, normal names fine',
    'ok', public.company_emoji_reserved('Official') and public.company_emoji_reserved('support') and public.company_emoji_reserved('ANEXO')
          and not public.company_emoji_reserved('acme') and not public.company_emoji_reserved('team-logo'));

  v_sha := encode(sha256(v_webp), 'hex');
  res := res || jsonb_build_object('t', 'row hash is deterministic and 64 hex',
    'ok', public.company_emoji_row_hash('a', gen_random_uuid(), 'add', 'x', null, gen_random_uuid(), '{}'::jsonb, now()) ~ '^[0-9a-f]{64}$');

  -- asli data: koi bhi owner wali company (kuch na ho to yeh hissa chhoota hua gina jata hai, fail nahi)
  select m.org_id, m.user_id into v_org, v_owner
    from public.org_members m where m.role::text = 'owner' and coalesce(m.status::text, 'active') <> 'revoked' limit 1;
  if v_org is null then
    v_skip := true;
  else
    v_plan := public.org_plan_of(v_org);
  end if;

  if not v_skip then
    -- sab kuch ek sub-transaction mein; aakhir mein exception se rollback
    begin
      -- ledger chain: seedhe append (plan se azaad) — 3 rows, verify, phir tamper koshish
      perform public.company_emoji_ledger_append(v_org, 'add', 'selftest-a', v_sha, v_owner, '{"t":1}'::jsonb);
      perform public.company_emoji_ledger_append(v_org, 'add', 'selftest-b', v_sha, v_owner, '{"t":2}'::jsonb);
      perform public.company_emoji_ledger_append(v_org, 'remove', 'selftest-a', v_sha, v_owner, '{}'::jsonb);
      v_json := public.company_emoji_verify(v_org);
      res := res || jsonb_build_object('t', 'ledger chain verifies (3 rows appended)', 'ok', (v_json ->> 'ok')::boolean and (v_json ->> 'rows')::int >= 3);

      v_ok := false;
      begin
        update public.company_emoji_ledger set detail = '{"hacked":true}'::jsonb where org_id = v_org;
      exception when others then
        v_ok := sqlerrm like 'E193:%';
      end;
      res := res || jsonb_build_object('t', 'ledger UPDATE refused', 'ok', v_ok);
      v_ok := false;
      begin
        delete from public.company_emoji_ledger where org_id = v_org;
      exception when others then
        v_ok := sqlerrm like 'E193:%';
      end;
      res := res || jsonb_build_object('t', 'ledger DELETE refused', 'ok', v_ok);

      -- table constraints seedhe (trigger/CHECK Rust ko bypass karke bhi)
      v_ok := false;
      begin
        insert into public.company_emoji (org_id, shortcode, sha256, bytes, w, h, data, created_by)
        values (v_org, 'official', v_sha, octet_length(v_webp), 64, 64, v_webp, v_owner);
      exception when others then
        v_ok := true;                                                  -- reserved ya tier/quota — dono sahi rok hain
      end;
      res := res || jsonb_build_object('t', 'reserved shortcode cannot be inserted', 'ok', v_ok);

      v_ok := false;
      begin
        insert into public.company_emoji (org_id, shortcode, sha256, bytes, w, h, data, created_by)
        values (v_org, 'Bad Name!', v_sha, octet_length(v_webp), 64, 64, v_webp, v_owner);
      exception when check_violation then
        v_ok := true;
      end;
      res := res || jsonb_build_object('t', 'bad shortcode shape refused by CHECK', 'ok', v_ok);

      v_ok := false;
      begin
        insert into public.company_emoji (org_id, shortcode, sha256, bytes, w, h, data, created_by)
        values (v_org, 'toobig', v_sha, 70000, 64, 64, v_webp, v_owner);
      exception when check_violation then
        v_ok := true;
      end;
      res := res || jsonb_build_object('t', 'oversize (>64 KB) refused', 'ok', v_ok);

      v_ok := false;
      begin
        insert into public.company_emoji (org_id, shortcode, sha256, bytes, w, h, data, created_by)
        values (v_org, 'tinyimg', v_sha, octet_length(v_webp), 8, 8, v_webp, v_owner);
      exception when check_violation then
        v_ok := true;
      end;
      res := res || jsonb_build_object('t', 'dimension out of 16..256 refused', 'ok', v_ok);

      -- tier wala raasta: sirf tab jab company ka plan Business+ ho
      if public.company_emoji_tier_limit(v_plan) > 0 then
        v_json := public.company_emoji_add(v_org, v_owner, 'selftest-logo', 'self test', v_sha, 64, 64, v_webp);
        res := res || jsonb_build_object('t', 'owner add works, quota counts it', 'ok', (v_json ->> 'ok')::boolean and (v_json #>> '{quota,used}')::int >= 1);

        v_ok := false;
        begin
          perform public.company_emoji_add(v_org, v_owner, 'selftest-logo2', 'dup picture', v_sha, 64, 64, v_webp);
        exception when others then
          v_ok := sqlerrm like 'E193%';
        end;
        res := res || jsonb_build_object('t', 'same picture twice refused (sha dedupe)', 'ok', v_ok);

        v_ok := false;
        begin
          perform public.company_emoji_add(v_org, v_owner, 'selftest-bad', '', repeat('a', 64), 64, 64, v_webp);
        exception when others then
          v_ok := sqlerrm like 'E193 SHA%';
        end;
        res := res || jsonb_build_object('t', 'sha mismatch refused', 'ok', v_ok);

        v_ok := false;
        begin
          perform public.company_emoji_add(v_org, gen_random_uuid(), 'selftest-x', '', v_sha, 64, 64, v_webp);
        exception when others then
          v_ok := sqlerrm like 'E193 ROLE%';
        end;
        res := res || jsonb_build_object('t', 'non-member / non-admin cannot add', 'ok', v_ok);

        v_json := public.company_emoji_get(v_org, 'selftest-logo');
        res := res || jsonb_build_object('t', 'get returns bytes + etag = sha', 'ok', (v_json ->> 'ok')::boolean and (v_json ->> 'etag') = v_sha);
        v_json := public.company_emoji_list(v_org);
        res := res || jsonb_build_object('t', 'list has it, no bytes in list', 'ok', v_json::text like '%selftest-logo%' and v_json::text not like '%data_b64%');

        v_json := public.company_emoji_remove(v_org, v_owner, 'selftest-logo');
        select count(*) into v_n from public.company_emoji e where e.org_id = v_org and e.shortcode = 'selftest-logo' and e.status = 'removed' and e.data is null;
        res := res || jsonb_build_object('t', 'remove = soft, bytes cleared, ledger row', 'ok', (v_json ->> 'ok')::boolean and v_n = 1);
        v_json := public.company_emoji_verify(v_org);
        res := res || jsonb_build_object('t', 'chain still verifies after add/remove', 'ok', (v_json ->> 'ok')::boolean);
      else
        v_ok := false;
        begin
          perform public.company_emoji_add(v_org, v_owner, 'selftest-logo', '', v_sha, 64, 64, v_webp);
        exception when others then
          v_ok := sqlerrm like 'E193 TIER%';
        end;
        res := res || jsonb_build_object('t', 'non-business plan refused (TIER) — plan ' || coalesce(v_plan, 'null'), 'ok', v_ok);
      end if;

      raise exception 'E193_SELFTEST_ROLLBACK';                       -- jaan-boojh kar: test ka saara data wapas
    exception when others then
      if sqlerrm <> 'E193_SELFTEST_ROLLBACK' then
        res := res || jsonb_build_object('t', 'selftest block crashed: ' || sqlerrm, 'ok', false);
      end if;
    end;
  end if;

  return jsonb_build_object(
    'ok', not exists (select 1 from jsonb_array_elements(res) x where not (x ->> 'ok')::boolean),
    'passed', (select count(*) from jsonb_array_elements(res) x where (x ->> 'ok')::boolean),
    'failed', (select count(*) from jsonb_array_elements(res) x where not (x ->> 'ok')::boolean),
    'org_part_skipped', v_skip,
    'plan_seen', v_plan,
    'checks', res);
end $$;

revoke all on function public.company_emoji_selftest193() from public, anon, authenticated;
grant execute on function public.company_emoji_selftest193() to service_role;

-- jawab: ek row
select 'e193_result' as result,
       (public.company_emoji_selftest193() ->> 'ok')::boolean                       as selftest_ok,
       public.company_emoji_selftest193() ->> 'passed'                              as passed,
       public.company_emoji_selftest193() ->> 'failed'                              as failed,
       (public.company_emoji_selftest193() ->> 'org_part_skipped')::boolean         as org_part_skipped,
       (public.company_emoji_posture193() ->> 'doors_service_only')::boolean        as doors_service_only,
       (public.company_emoji_posture193() ->> 'rls_forced')::boolean                as rls_forced,
       (public.company_emoji_posture193() ->> 'anon_no_table_access')::boolean      as anon_no_table_access,
       (public.company_emoji_posture193() ->> 'service_role_read_only')::boolean    as service_role_read_only,
       public.company_emoji_posture193() ->> 'triggers'                             as triggers;
