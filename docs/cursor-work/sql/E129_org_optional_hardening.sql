-- =============================================================================
-- E129 — "Create your workspace": the ORGANISATION IS OPTIONAL, and the organisation layer is hardened (founder 2 Nov 2026 09:57:
--   "create your workspace main organization optional ... sql 600 lines super advance ... gaps aur loophole theek ker dai").
-- Idempotent. Every part is guarded (table / column exists) and skips with a NOTICE, so a schema difference never aborts the run.
-- NOTHING here changes how the live sign-up flow inserts rows: the Rust door inserts `organisations` first and `org_members` second in SEPARATE requests,
-- so there is deliberately NO trigger that demands an owner row at insert time (it would break that flow).
--
-- WHAT IT ADDS (gap -> fix)
--  A  helpers                         _o_tbl / _o_col: schema-tolerant existence checks.
--  B  new columns                     organisations: name_source, updated_at, domain_claimed_at, domain_verified_at, domain_grandfathered, deleted_at, delete_after.
--  C  normalisers                     org_norm_name / org_slugify / org_make_slug / org_default_name / org_norm_domain / org_domain_valid / org_domain_blocked.
--  D  guard trigger (BEFORE I/U)      on organisations AND account_organisations: blank name -> "<Name> workspace" (ORGANISATION OPTIONAL), slug made + checked,
--                                     domain normalised ('' -> NULL: gap = two empty strings broke UNIQUE; "HTTPS://WWW.Acme.com/x" -> acme.com), public mail providers and
--                                     anexomail.com refused (gap = anyone could claim gmail.com), domain change resets verification.
--  E  constraints + indexes           name 2..80, slug shape, storage >= 0 (NOT VALID: old rows are not rewritten); case-insensitive UNIQUE on domain
--                                     (gap = Acme.com vs acme.com), skipped with a NOTICE when old data already collides (CHECK shows it).
--  F  limits                          max 5 live organisations per owner, max 3 created per 24 h per owner (gap = unlimited org spam); bypass for service jobs:
--                                     set local anexo.org_bypass_limits = '1'.
--  G  org_events                      append-only SHA-256 hash chain per organisation (created / renamed / domain / owner / deleted / purged). No personal data in it
--                                     (ids, hashes, counters only). No FK, so an organisation delete never collides with the chain (lesson of E126).
--  H  last-owner protection           an org that still has other members cannot lose its last owner (gap = orphaned team).
--  I  domain ownership                org_domain_claims (DNS TXT challenge, only the SHA-256 of the token is stored), org_domain_claim_start / _confirm,
--                                     org_domain_release_stale (gap = squatting: an unverified claim older than 14 days is released; existing domains are grandfathered).
--  J  soft delete                     org_soft_delete / org_restore / org_purge_due (30 days). NOT wired into the listings yet: Rust must filter deleted_at (phase O2).
--  K  optional organisation           org_ensure_default(uid): the person who skips the form still gets exactly one working workspace; org_integrity_report() and
--                                     org_repair_owner_member() find / fix orgs whose owner has no member row.
--  L  privileges                      RLS on, anon / authenticated have nothing, functions pinned search_path, SECURITY DEFINER not executable by public.
-- Needs: nothing new. Check: CHECK_E129 (read-only). Rust wiring (default name, optional domain) is already live (wsx).
-- =============================================================================
set search_path = public, extensions;

-- ---- A) helpers -------------------------------------------------------------
create or replace function public._o_tbl(_t text) returns boolean
language sql stable set search_path = public, pg_temp as $$ select to_regclass('public.' || quote_ident(_t)) is not null $$;

create or replace function public._o_col(_t text, _c text) returns boolean
language sql stable set search_path = public, pg_temp as $$
  select exists (select 1 from pg_attribute a where a.attrelid = to_regclass('public.' || quote_ident(_t)) and a.attname = _c and a.attnum > 0 and not a.attisdropped)
$$;

-- ---- B) columns ---------------------------------------------------------------
do $$
begin
  if not public._o_tbl('organisations') then
    raise notice 'E129: organisations not found, nothing to harden';
    return;
  end if;
  alter table public.organisations add column if not exists name_source text not null default 'user';
  alter table public.organisations add column if not exists updated_at timestamptz not null default now();
  alter table public.organisations add column if not exists domain_claimed_at timestamptz;
  alter table public.organisations add column if not exists domain_verified_at timestamptz;
  alter table public.organisations add column if not exists domain_grandfathered boolean not null default false;
  alter table public.organisations add column if not exists deleted_at timestamptz;
  alter table public.organisations add column if not exists delete_after timestamptz;
  if not exists (select 1 from pg_constraint where conrelid = 'public.organisations'::regclass and conname = 'organisations_name_source_chk') then
    alter table public.organisations add constraint organisations_name_source_chk check (name_source in ('user', 'default'));
  end if;
  -- every domain that exists TODAY is grandfathered and counts as verified: the live sign-ups and test buyers keep working untouched
  update public.organisations set domain_grandfathered = true, domain_verified_at = coalesce(domain_verified_at, now()), domain_claimed_at = coalesce(domain_claimed_at, now())
   where domain is not null and domain <> '' and domain_grandfathered = false and domain_verified_at is null and domain_claimed_at is null;
  -- an empty string is not a domain
  update public.organisations set domain = null where domain is not null and btrim(domain) = '';
end $$;

-- ---- C) normalisers (pure, immutable) -------------------------------------------
create or replace function public.org_norm_name(_n text) returns text
language sql immutable set search_path = public, pg_temp as $$
  select nullif(btrim(regexp_replace(regexp_replace(coalesce(_n, ''), '[[:cntrl:]]', ' ', 'g'), '\s+', ' ', 'g')), '')
$$;

create or replace function public.org_slugify(_n text) returns text
language sql immutable set search_path = public, pg_temp as $$
  select coalesce(nullif(left(btrim(regexp_replace(lower(coalesce(_n, '')), '[^a-z0-9]+', '-', 'g'), '-'), 40), ''), 'workspace')
$$;

create or replace function public.org_slug_reserved(_s text) returns boolean
language sql immutable set search_path = public, pg_temp as $$
  select lower(coalesce(_s, '')) = any (array['admin','api','app','www','mail','support','billing','founder','founderworkspace','root','system','status','docs','auth',
    'storage','cdn','ai','settings','login','signup','trust','security','anexomail','anexochat','anexovideocall','polar','null','undefined'])
$$;

create or replace function public.org_make_slug(_name text, _id uuid) returns text
language sql immutable set search_path = public, pg_temp as $$
  select public.org_slugify(_name) || '-' || left(replace(coalesce(_id, gen_random_uuid())::text, '-', ''), 8)
$$;

-- "ali.khan@anexomail.com" -> "Ali Khan workspace" (same pattern as the Rust door and the family workspaces)
create or replace function public.org_default_name(_email text) returns text
language plpgsql immutable set search_path = public, pg_temp as $$
declare w text; base text := '';
begin
  for w in select x from regexp_split_to_table(split_part(coalesce(_email, ''), '@', 1), '[^[:alnum:]]+') as x where x <> '' limit 4 loop
    base := btrim(base || ' ' || initcap(lower(w)));
  end loop;
  if char_length(base) < 2 then return 'My workspace'; end if;
  return base || ' workspace';
end $$;

create or replace function public.org_norm_domain(_d text) returns text
language plpgsql immutable set search_path = public, pg_temp as $$
declare s text := lower(btrim(coalesce(_d, '')));
begin
  s := regexp_replace(s, '^[a-z][a-z0-9+.-]*://', '');
  s := regexp_replace(s, '[/?#].*$', '');
  s := regexp_replace(s, '^[^@]*@', '');
  s := regexp_replace(s, ':[0-9]+$', '');
  s := regexp_replace(s, '^www\.', '');
  s := regexp_replace(s, '\.+$', '');
  if s = '' then return null; end if;
  return s;
end $$;

create or replace function public.org_domain_valid(_d text) returns boolean
language sql immutable set search_path = public, pg_temp as $$
  select _d is not null and char_length(_d) <= 253 and _d ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$'
$$;

-- public mail providers and our own domain can never be an organisation domain
create or replace function public.org_domain_blocked(_d text) returns boolean
language sql immutable set search_path = public, pg_temp as $$
  select _d = 'anexomail.com' or _d like '%.anexomail.com'
      or _d = any (array['gmail.com','googlemail.com','outlook.com','hotmail.com','live.com','msn.com','yahoo.com','ymail.com','icloud.com','me.com','mac.com','aol.com',
         'proton.me','protonmail.com','gmx.com','gmx.net','mail.com','zoho.com','yandex.com','yandex.ru','qq.com','163.com','example.com','example.org','localhost'])
$$;

-- ---- D) guard trigger: organisation optional, clean data ---------------------------
create or replace function public.org_guard_biu() returns trigger
language plpgsql set search_path = public, pg_temp as $$
declare
  v jsonb := to_jsonb(new); o jsonb := case when TG_OP = 'UPDATE' then to_jsonb(old) else '{}'::jsonb end;
  patch jsonb := '{}'::jsonb; n text; sl text; d text; uid uuid; em text; used_default boolean := false;
begin
  -- name: optional. Blank -> "<Name> workspace" from the owner's e-mail.
  if TG_OP = 'INSERT' or (v->>'name') is distinct from (o->>'name') then
    n := public.org_norm_name(v->>'name');
    if n is null or char_length(n) < 2 then
      begin uid := coalesce(nullif(v->>'owner_id', ''), nullif(v->>'created_by', ''))::uuid; exception when others then uid := null; end;
      if uid is not null then select u.email into em from auth.users u where u.id = uid; end if;
      n := public.org_default_name(em);
      used_default := true;
    end if;
    if char_length(n) > 80 then n := left(n, 80); end if;
    patch := patch || jsonb_build_object('name', n);
    if v ? 'name_source' then patch := patch || jsonb_build_object('name_source', case when used_default then 'default' else 'user' end); end if;
  end if;

  -- slug: made when blank, checked when set / changed
  sl := nullif(btrim(coalesce(v->>'slug', '')), '');
  if sl is null then
    sl := public.org_make_slug(coalesce(patch->>'name', v->>'name'), nullif(v->>'id', '')::uuid);
    patch := patch || jsonb_build_object('slug', sl);
  elsif TG_OP = 'INSERT' or sl is distinct from (o->>'slug') then
    if sl !~ '^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$' then raise exception 'org_slug_invalid' using errcode = '22023'; end if;
    if public.org_slug_reserved(sl) then raise exception 'org_slug_reserved' using errcode = '22023'; end if;
  end if;

  -- domain: optional. '' -> NULL; normalised; public providers refused; a changed domain must be proved again
  if TG_OP = 'INSERT' or (v->>'domain') is distinct from (o->>'domain') then
    d := public.org_norm_domain(v->>'domain');
    if d is not null then
      if not public.org_domain_valid(d) then raise exception 'org_domain_invalid' using errcode = '22023'; end if;
      if public.org_domain_blocked(d) then raise exception 'org_domain_not_allowed' using errcode = '22023'; end if;
    end if;
    patch := patch || jsonb_build_object('domain', d);
    if v ? 'domain_claimed_at' and d is distinct from public.org_norm_domain(o->>'domain') then
      patch := patch || jsonb_build_object('domain_claimed_at', case when d is null then null else now() end, 'domain_verified_at', null, 'domain_grandfathered', false);
    end if;
  end if;

  if v ? 'updated_at' then patch := patch || jsonb_build_object('updated_at', now()); end if;
  new := jsonb_populate_record(new, patch);
  return new;
end $$;

-- ---- E) constraints + indexes -----------------------------------------------------
do $$
declare t text; v_dups integer;
begin
  foreach t in array array['organisations', 'account_organisations'] loop
    if not public._o_tbl(t) then continue; end if;
    execute format('drop trigger if exists %I on public.%I', t || '_guard_biu', t);
    execute format('create trigger %I before insert or update on public.%I for each row execute function public.org_guard_biu()', t || '_guard_biu', t);
    if public._o_col(t, 'name') and not exists (select 1 from pg_constraint where conrelid = to_regclass('public.' || t) and conname = t || '_name_len_chk') then
      execute format('alter table public.%I add constraint %I check (char_length(btrim(name)) between 2 and 80) not valid', t, t || '_name_len_chk');
    end if;
    if public._o_col(t, 'slug') and not exists (select 1 from pg_constraint where conrelid = to_regclass('public.' || t) and conname = t || '_slug_shape_chk') then
      execute format('alter table public.%I add constraint %I check (slug ~ ''^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$'') not valid', t, t || '_slug_shape_chk');
    end if;
  end loop;

  if public._o_tbl('organisations') then
    if public._o_col('organisations', 'storage_limit_bytes') and not exists (select 1 from pg_constraint where conrelid = 'public.organisations'::regclass and conname = 'organisations_storage_nonneg_chk') then
      alter table public.organisations add constraint organisations_storage_nonneg_chk check (storage_limit_bytes is null or storage_limit_bytes >= 0) not valid;
    end if;
    -- case-insensitive uniqueness of live domains (Acme.com vs acme.com)
    select count(*) into v_dups from (select lower(domain) from public.organisations where domain is not null and deleted_at is null group by 1 having count(*) > 1) x;
    if v_dups = 0 then
      create unique index if not exists organisations_domain_ci_uq on public.organisations (lower(domain)) where domain is not null and deleted_at is null;
    else
      raise notice 'E129: % domain(s) already collide case-insensitively: unique index skipped, see CHECK_E129', v_dups;
    end if;
    create index if not exists organisations_owner_idx on public.organisations (owner_id) where deleted_at is null;
    create index if not exists organisations_delete_after_idx on public.organisations (delete_after) where deleted_at is not null;
  end if;
end $$;

-- ---- F) limits ---------------------------------------------------------------------
create or replace function public.org_limits_bi() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if coalesce(current_setting('anexo.org_bypass_limits', true), '') = '1' or new.owner_id is null then return new; end if;
  if (select count(*) from public.organisations o where o.owner_id = new.owner_id and o.deleted_at is null) >= 5 then
    raise exception 'org_limit_owned' using errcode = '53400', hint = 'At most 5 organisations per owner.';
  end if;
  if (select count(*) from public.organisations o where o.owner_id = new.owner_id and o.created_at > now() - interval '24 hours') >= 3 then
    raise exception 'org_limit_rate' using errcode = '53400', hint = 'At most 3 organisations per owner per 24 hours.';
  end if;
  return new;
end $$;

do $$
begin
  if public._o_tbl('organisations') and public._o_col('organisations', 'owner_id') then
    drop trigger if exists organisations_limits_bi on public.organisations;
    create trigger organisations_limits_bi before insert on public.organisations for each row execute function public.org_limits_bi();
  end if;
end $$;

-- ---- G) org_events: tamper-evident history per organisation --------------------------
create table if not exists public.org_events (
  id          bigint generated always as identity primary key,
  org_id      uuid not null,                      -- NO foreign key on purpose (an organisation delete must never collide with this chain)
  seq         integer not null check (seq >= 1),
  event_type  text not null check (event_type in ('created', 'renamed', 'slug_changed', 'domain_set', 'domain_cleared', 'domain_verified', 'owner_added', 'owner_removed',
                                                  'soft_deleted', 'restored', 'purged', 'default_created')),
  actor       uuid,
  detail      jsonb not null default '{}'::jsonb, -- ids, counters and SHA-256 hashes only; never a name, e-mail or plain domain
  prev_hash   text not null,
  hash        text not null,
  created_at  timestamptz not null default now(),
  unique (org_id, seq)
);
create index if not exists org_events_org_idx on public.org_events (org_id, seq);

create or replace function public.org_events_immutable() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if coalesce(current_setting('anexo.org_events_purge', true), '') = '1' then
    return case when TG_OP = 'DELETE' then old else new end;
  end if;
  raise exception 'org_events is append-only (tamper-evident history)' using errcode = '42501';
end $$;

drop trigger if exists org_events_no_change on public.org_events;
create trigger org_events_no_change before update or delete on public.org_events for each row execute function public.org_events_immutable();

create or replace function public.org_event_append(_org uuid, _type text, _actor uuid, _detail jsonb) returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_prev text; v_seq integer; v_hash text; v_at timestamptz := now();
begin
  perform pg_advisory_xact_lock(hashtextextended('org_events:' || _org::text, 0));
  select e.hash, e.seq into v_prev, v_seq from public.org_events e where e.org_id = _org order by e.seq desc limit 1;
  v_seq := coalesce(v_seq, 0) + 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  v_hash := encode(sha256(convert_to(v_prev || '|' || _org::text || '|' || v_seq::text || '|' || _type || '|' || coalesce(_actor::text, '-') || '|' || coalesce(_detail, '{}'::jsonb)::text || '|' || v_at::text, 'UTF8')), 'hex');
  insert into public.org_events (org_id, seq, event_type, actor, detail, prev_hash, hash, created_at) values (_org, v_seq, _type, _actor, coalesce(_detail, '{}'::jsonb), v_prev, v_hash, v_at);
  return v_seq;
end $$;

-- recomputes the chain of one organisation: true = intact
create or replace function public.org_events_verify(_org uuid) returns boolean
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare r record; v_prev text := repeat('0', 64); v_seq integer := 0;
begin
  for r in select * from public.org_events where org_id = _org order by seq loop
    v_seq := v_seq + 1;
    if r.seq <> v_seq or r.prev_hash <> v_prev then return false; end if;
    if r.hash <> encode(sha256(convert_to(v_prev || '|' || _org::text || '|' || r.seq::text || '|' || r.event_type || '|' || coalesce(r.actor::text, '-') || '|' || r.detail::text || '|' || r.created_at::text, 'UTF8')), 'hex') then return false; end if;
    v_prev := r.hash;
  end loop;
  return true;
end $$;

create or replace function public.org_events_trg() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_actor uuid; v_role_new text; v_role_old text;
begin
  if TG_TABLE_NAME = 'organisations' then
    v_actor := nullif(current_setting('anexo.actor', true), '')::uuid;
    if TG_OP = 'INSERT' then
      perform public.org_event_append(new.id, 'created', coalesce(v_actor, new.owner_id), jsonb_build_object('name_source', to_jsonb(new)->>'name_source', 'has_domain', new.domain is not null));
    elsif TG_OP = 'DELETE' then
      perform public.org_event_append(old.id, 'purged', v_actor, '{}'::jsonb);
    else
      if new.name is distinct from old.name then perform public.org_event_append(new.id, 'renamed', v_actor, jsonb_build_object('name_sha256', encode(sha256(convert_to(new.name, 'UTF8')), 'hex'))); end if;
      if new.slug is distinct from old.slug then perform public.org_event_append(new.id, 'slug_changed', v_actor, '{}'::jsonb); end if;
      if new.domain is distinct from old.domain then
        perform public.org_event_append(new.id, case when new.domain is null then 'domain_cleared' else 'domain_set' end, v_actor,
          jsonb_build_object('domain_sha256', encode(sha256(convert_to(coalesce(new.domain, ''), 'UTF8')), 'hex')));
      end if;
      if new.domain_verified_at is not null and old.domain_verified_at is null and new.domain is not distinct from old.domain then perform public.org_event_append(new.id, 'domain_verified', v_actor, '{}'::jsonb); end if;
      if new.deleted_at is not null and old.deleted_at is null then perform public.org_event_append(new.id, 'soft_deleted', v_actor, jsonb_build_object('delete_after', new.delete_after)); end if;
      if new.deleted_at is null and old.deleted_at is not null then perform public.org_event_append(new.id, 'restored', v_actor, '{}'::jsonb); end if;
    end if;
    return case when TG_OP = 'DELETE' then old else new end;
  end if;
  -- org_members: only owner changes are history
  v_role_new := case when TG_OP = 'DELETE' then null else new.role::text end;
  v_role_old := case when TG_OP = 'INSERT' then null else old.role::text end;
  if v_role_new = 'owner' and v_role_old is distinct from 'owner' then
    perform public.org_event_append(new.org_id, 'owner_added', nullif(current_setting('anexo.actor', true), '')::uuid, jsonb_build_object('user_sha256', encode(sha256(convert_to(new.user_id::text, 'UTF8')), 'hex')));
  elsif v_role_old = 'owner' and v_role_new is distinct from 'owner' then
    -- the organisation may be gone (cascade): the chain still records it, it has no foreign key
    perform public.org_event_append(old.org_id, 'owner_removed', nullif(current_setting('anexo.actor', true), '')::uuid, jsonb_build_object('user_sha256', encode(sha256(convert_to(old.user_id::text, 'UTF8')), 'hex')));
  end if;
  return case when TG_OP = 'DELETE' then old else new end;
end $$;

do $$
begin
  if public._o_tbl('organisations') then
    drop trigger if exists organisations_events_trg on public.organisations;
    create trigger organisations_events_trg after insert or delete or update of name, slug, domain, domain_verified_at, deleted_at on public.organisations for each row execute function public.org_events_trg();
  end if;
  if public._o_tbl('org_members') and public._o_col('org_members', 'role') then
    drop trigger if exists org_members_events_trg on public.org_members;
    create trigger org_members_events_trg after insert or delete or update of role on public.org_members for each row execute function public.org_events_trg();
  end if;
end $$;

-- ---- H) last-owner protection ---------------------------------------------------------
create or replace function public.org_last_owner_guard() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if old.role::text <> 'owner' then return case when TG_OP = 'DELETE' then old else new end; end if;
  if TG_OP = 'UPDATE' and new.role::text = 'owner' then return new; end if;
  -- the organisation itself is being removed (cascade) or is already gone: nothing to protect
  if not exists (select 1 from public.organisations o where o.id = old.org_id) then return case when TG_OP = 'DELETE' then old else new end; end if;
  -- only an organisation that still has OTHER members needs an owner (a one-person org may be emptied by an account purge)
  if exists (select 1 from public.org_members m where m.org_id = old.org_id and m.user_id <> old.user_id)
     and not exists (select 1 from public.org_members m where m.org_id = old.org_id and m.user_id <> old.user_id and m.role::text = 'owner') then
    raise exception 'org_last_owner' using errcode = '23514', hint = 'Make another member the owner first.';
  end if;
  return case when TG_OP = 'DELETE' then old else new end;
end $$;

do $$
begin
  if public._o_tbl('org_members') and public._o_col('org_members', 'role') and public._o_tbl('organisations') then
    drop trigger if exists org_members_last_owner on public.org_members;
    create trigger org_members_last_owner before delete or update of role on public.org_members for each row execute function public.org_last_owner_guard();
  end if;
end $$;

-- ---- I) domain ownership proof (anti-squatting) ----------------------------------------
create table if not exists public.org_domain_claims (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  domain      text not null check (domain ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$'),
  token_hash  text not null check (token_hash ~ '^[0-9a-f]{64}$'),       -- SHA-256 of the random token; the token itself is shown once and never stored
  status      text not null default 'pending' check (status in ('pending', 'verified', 'expired', 'revoked')),
  attempts    integer not null default 0 check (attempts >= 0),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '14 days',
  verified_at timestamptz
);
create unique index if not exists org_domain_claims_one_pending_uq on public.org_domain_claims (org_id, domain) where status = 'pending';
create index if not exists org_domain_claims_org_idx on public.org_domain_claims (org_id);

-- Frees every UNVERIFIED, non-grandfathered domain claimed more than 14 days ago. Returns how many were released.
create or replace function public.org_domain_release_stale() returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare n integer := 0;
begin
  if not public._o_tbl('organisations') then return 0; end if;
  update public.organisations set domain = null
   where domain is not null and domain_verified_at is null and domain_grandfathered = false and domain_claimed_at < now() - interval '14 days';
  get diagnostics n = row_count;
  update public.org_domain_claims set status = 'expired' where status = 'pending' and expires_at < now();
  return n;
end $$;

-- Step 1: the owner asks for a challenge. Returns the TXT value to publish at _anexomail.<domain>. Shown ONCE.
create or replace function public.org_domain_claim_start(_org uuid, _actor uuid) returns text
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_domain text; v_token text; v_ok boolean;
begin
  perform public.org_domain_release_stale();
  select o.domain into v_domain from public.organisations o where o.id = _org and o.deleted_at is null;
  if v_domain is null then raise exception 'org_no_domain' using errcode = '22023'; end if;
  select exists (select 1 from public.org_members m where m.org_id = _org and m.user_id = _actor and m.role::text = 'owner') into v_ok;
  if not v_ok then raise exception 'org_not_owner' using errcode = '42501'; end if;
  update public.org_domain_claims set status = 'revoked' where org_id = _org and status = 'pending';
  v_token := left(replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''), 48);
  insert into public.org_domain_claims (org_id, domain, token_hash) values (_org, v_domain, encode(sha256(convert_to(v_token, 'UTF8')), 'hex'));
  return 'anexomail-verify=' || v_token;
end $$;

-- Step 2: Rust looked up the TXT records of _anexomail.<domain> and passes them here. Verified when one of them carries the token. 10 tries per claim.
create or replace function public.org_domain_claim_confirm(_org uuid, _txt text[]) returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare c public.org_domain_claims; t text; h text;
begin
  select * into c from public.org_domain_claims where org_id = _org and status = 'pending' and expires_at > now() order by created_at desc limit 1 for update;
  if c.id is null then return false; end if;
  if c.attempts >= 10 then update public.org_domain_claims set status = 'expired' where id = c.id; return false; end if;
  update public.org_domain_claims set attempts = attempts + 1 where id = c.id;
  foreach t in array coalesce(_txt, '{}') loop
    if t like 'anexomail-verify=%' then
      h := encode(sha256(convert_to(substr(t, char_length('anexomail-verify=') + 1), 'UTF8')), 'hex');
      if h = c.token_hash then
        update public.org_domain_claims set status = 'verified', verified_at = now() where id = c.id;
        update public.organisations set domain_verified_at = now() where id = _org and domain = c.domain;
        return true;
      end if;
    end if;
  end loop;
  return false;
end $$;

-- ---- J) soft delete (30 days) -------------------------------------------------------------
create or replace function public.org_soft_delete(_org uuid, _actor uuid) returns timestamptz
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_after timestamptz := now() + interval '30 days';
begin
  if not exists (select 1 from public.org_members m where m.org_id = _org and m.user_id = _actor and m.role::text = 'owner') then raise exception 'org_not_owner' using errcode = '42501'; end if;
  perform set_config('anexo.actor', _actor::text, true);
  update public.organisations set deleted_at = now(), delete_after = v_after, domain = null where id = _org and deleted_at is null;
  return v_after;
end $$;

create or replace function public.org_restore(_org uuid, _actor uuid) returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not exists (select 1 from public.org_members m where m.org_id = _org and m.user_id = _actor and m.role::text = 'owner') then raise exception 'org_not_owner' using errcode = '42501'; end if;
  perform set_config('anexo.actor', _actor::text, true);
  update public.organisations set deleted_at = null, delete_after = null where id = _org and deleted_at is not null and delete_after > now();
  return found;
end $$;

-- Hard-deletes organisations whose 30 days are over. One bad organisation never stops the rest (its error is counted, not raised).
create or replace function public.org_purge_due(_limit integer default 50) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare r record; v_ok integer := 0; v_fail integer := 0;
begin
  for r in select id from public.organisations where deleted_at is not null and delete_after < now() order by delete_after limit greatest(_limit, 1) loop
    begin
      delete from public.organisations where id = r.id;
      v_ok := v_ok + 1;
    exception when others then
      v_fail := v_fail + 1;
    end;
  end loop;
  return jsonb_build_object('purged', v_ok, 'failed', v_fail);
end $$;

-- ---- K) optional organisation: nobody is left without a workspace ----------------------------
-- Returns the person's first live organisation, creating "<Name> workspace" (no domain) when they have none. Safe to call on every sign-in.
create or replace function public.org_ensure_default(_uid uuid) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_org uuid; v_email text; v_name text;
begin
  select m.org_id into v_org from public.org_members m join public.organisations o on o.id = m.org_id
   where m.user_id = _uid and o.deleted_at is null order by m.created_at nulls last limit 1;
  if v_org is not null then return v_org; end if;
  select u.email into v_email from auth.users u where u.id = _uid;
  if v_email is null then raise exception 'org_user_not_found' using errcode = '22023'; end if;
  v_name := public.org_default_name(v_email);
  perform pg_advisory_xact_lock(hashtextextended('org_ensure_default:' || _uid::text, 0));
  select m.org_id into v_org from public.org_members m join public.organisations o on o.id = m.org_id where m.user_id = _uid and o.deleted_at is null limit 1;
  if v_org is not null then return v_org; end if;
  perform set_config('anexo.org_bypass_limits', '1', true);
  perform set_config('anexo.actor', _uid::text, true);
  insert into public.organisations (name, slug, owner_id) values ('', public.org_make_slug(v_name, gen_random_uuid()), _uid) returning id into v_org; -- blank name: the guard trigger writes the default name and marks name_source = default
  insert into public.org_members (org_id, user_id, role, email, status) values (v_org, _uid, 'owner', v_email, 'active') on conflict (org_id, user_id) do nothing;
  perform public.org_event_append(v_org, 'default_created', _uid, '{}'::jsonb);
  return v_org;
end $$;

-- Every integrity problem the data can have, one row each (read-only). CHECK_E129 and the founder dashboard read this.
create or replace function public.org_integrity_report() returns table (problem text, org_id uuid, detail text)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return query select 'owner_without_member_row'::text, o.id, 'owner_id has no org_members row' from public.organisations o
    where o.owner_id is not null and o.deleted_at is null and not exists (select 1 from public.org_members m where m.org_id = o.id and m.user_id = o.owner_id);
  return query select 'org_without_any_owner'::text, o.id, 'no member with role owner' from public.organisations o
    where o.deleted_at is null and exists (select 1 from public.org_members m where m.org_id = o.id)
      and not exists (select 1 from public.org_members m where m.org_id = o.id and m.role::text = 'owner');
  return query select 'domain_collides_case_insensitive'::text, (array_agg(o.id))[1], lower(o.domain) from public.organisations o
    where o.domain is not null and o.deleted_at is null group by lower(o.domain) having count(*) > 1;
  return query select 'domain_not_clean'::text, o.id, o.domain from public.organisations o
    where o.domain is not null and (o.domain <> public.org_norm_domain(o.domain) or not public.org_domain_valid(o.domain) or public.org_domain_blocked(o.domain));
  return query select 'slug_not_clean'::text, o.id, o.slug from public.organisations o
    where o.slug is null or o.slug !~ '^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$';
  return query select 'name_not_clean'::text, o.id, left(coalesce(o.name, ''), 40) from public.organisations o
    where o.name is null or char_length(btrim(o.name)) not between 2 and 80;
  return query select 'event_chain_broken'::text, e.org_id, 'hash chain does not verify' from (select distinct ev.org_id from public.org_events ev) e where not public.org_events_verify(e.org_id);
  return query select 'user_without_organisation'::text, null::uuid, u.email from auth.users u
    where not exists (select 1 from public.org_members m where m.user_id = u.id);
end $$;

-- Repairs the first problem only: an owner_id that has no member row gets one (role owner). Returns how many rows it added.
create or replace function public.org_repair_owner_member() returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare r record; n integer := 0;
begin
  for r in select o.id, o.owner_id, u.email from public.organisations o join auth.users u on u.id = o.owner_id
           where o.deleted_at is null and not exists (select 1 from public.org_members m where m.org_id = o.id and m.user_id = o.owner_id) loop
    insert into public.org_members (org_id, user_id, role, email, status) values (r.id, r.owner_id, 'owner', r.email, 'active') on conflict (org_id, user_id) do nothing;
    n := n + 1;
  end loop;
  return n;
end $$;

-- ---- L) privileges / RLS ------------------------------------------------------------------------
alter table public.org_events enable row level security;
alter table public.org_domain_claims enable row level security;
revoke all on public.org_events, public.org_domain_claims from anon, authenticated;
grant all on public.org_events, public.org_domain_claims to service_role;

do $$
declare f text;
begin
  foreach f in array array[
    'org_guard_biu()', 'org_limits_bi()', 'org_events_immutable()', 'org_events_trg()', 'org_last_owner_guard()',
    'org_event_append(uuid,text,uuid,jsonb)', 'org_events_verify(uuid)', 'org_domain_release_stale()', 'org_domain_claim_start(uuid,uuid)',
    'org_domain_claim_confirm(uuid,text[])', 'org_soft_delete(uuid,uuid)', 'org_restore(uuid,uuid)', 'org_purge_due(integer)',
    'org_ensure_default(uuid)', 'org_integrity_report()', 'org_repair_owner_member()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;

comment on table public.org_events is 'E129: append-only SHA-256 hash chain per organisation. No personal data. No foreign key.';
comment on table public.org_domain_claims is 'E129: DNS TXT proof of domain ownership; only the SHA-256 of the token is stored.';

-- ---- M) one-time repair of legacy rows: an owner_id without an org_members row gets the missing owner row (idempotent) ------
do $$
declare n integer;
begin
  if public._o_tbl('organisations') and public._o_tbl('org_members') and public._o_col('org_members', 'role') then
    n := public.org_repair_owner_member();
    raise notice 'E129: % legacy organisation(s) got their missing owner member row', n;
  end if;
end $$;
