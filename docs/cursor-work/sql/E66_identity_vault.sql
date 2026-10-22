
-- E66 — IDENTITY VAULT: "ek insaan, ek account" (22 Oct 2026, founder: wrong activity => blacklist, dobara account nahi banega — Gmail jaisa; yahan bhi).
-- Privacy ke mutabiq: koi raw cheez nahi — sirf ek-tarfa HMAC-SHA256 (HASHING.md; key server env, DB mein kabhi nahi) ke 32 byte. Biometric kuch nahi.
-- Dobara chalana safe. Koi DROP TABLE/COLUMN nahi. Rule 38 (advance) + 42 (editor-compat) + 43 (RLS on).
-- DESIGN (docs/cursor-work/AUTH-MIGRATION-PLAN.md "Identity Vault"):
--   * MAZBOOT nishaniyan (akeli ban ke liye kaafi): device_key (browser ka non-extractable WebCrypto key — Rust ne challenge-proof se tasdeeq ki), email, recovery, payment.
--   * KAMZOR nishaniyan (akeli kabhi ban nahi; sirf "review"): device_shape (paanch moti nishaniyan — bahut log ek jaise hote hain, isliye ban ke liye nahi), network (IP /24 ya /48, 30 din).
--   * Faisla (identity_signup_check): koi bhi mazboot nishani active ban se mile => deny; kamzor milan >= threshold, ya ek device_key 3+ accounts par => review; warna allow.
--   * Jawab mein kabhi hash ya "kis account se mila" nahi jata (andaza lagane ka raasta band).
--   * Account delete (bina ban) => FK CASCADE se uske sab signals khud mit jate hain. Ban wale hash identity_bans mein alag rehte hain (expires_at: 2 saal default, severe = hamesha, appeal par lift).
--   * Retention policy table mein (identity_vault_policy) — Privacy page ke wade ka ek jagah ka sach.
--   * Hashing/encryption Rust mein; SQL sirf 32-byte hash dekhta hai, kabhi key nahi.
--   * WAPAS LENA (haath se): drop function public.identity_signup_check(jsonb), public.identity_register(uuid,jsonb), public.identity_ban_account(uuid,text,boolean,uuid), public.identity_ban_lift(uuid,uuid), public.identity_vault_purge(), public.identity_signals_ok(jsonb), public.identity_kind_strong(text); tables identity_* ko data bachane ke liye rehne do.
set lock_timeout = '3s';
set statement_timeout = '60s';

-- ---- 1. policy (ek hi row) ----------------------------------------------------------------------------------------------------
create table if not exists public.identity_vault_policy (
  id                    smallint primary key default 1 check (id = 1),
  ban_retain_days       integer  not null default 730 check (ban_retain_days between 30 and 3650),
  signal_retain_days    integer  not null default 180 check (signal_retain_days between 30 and 730),
  network_retain_days   integer  not null default 30  check (network_retain_days between 1 and 90),
  weak_review_threshold smallint not null default 2   check (weak_review_threshold between 1 and 5),
  shared_device_limit   smallint not null default 3   check (shared_device_limit between 2 and 20),
  key_id                smallint not null default 1   check (key_id > 0),
  updated_at            timestamptz not null default now()
);
insert into public.identity_vault_policy (id) values (1) on conflict (id) do nothing;

-- ---- 2. kind ki ek definition (mazboot / kamzor) -----------------------------------------------------------------------------
create or replace function public.identity_kind_strong(k text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select case k when 'device_key' then true when 'email' then true when 'recovery' then true when 'payment' then true
               when 'device_shape' then false when 'network' then false else null end
$$;

-- ---- 3. tables ----------------------------------------------------------------------------------------------------------------
create table if not exists public.identity_signals (
  id           bigint generated always as identity primary key,
  account_id   uuid        not null references auth.users (id) on delete cascade,
  kind         text        not null check (public.identity_kind_strong(kind) is not null),
  hmac         bytea       not null check (octet_length(hmac) = 32),
  key_id       smallint    not null default 1 check (key_id > 0),
  first_seen   timestamptz not null default now(),
  last_seen    timestamptz not null default now(),
  seen_count   integer     not null default 1 check (seen_count >= 1),
  retain_until timestamptz,
  -- email/recovery/payment account ke saath jeete hain (retain_until NULL); baqi sab (device_key, device_shape, network) finite retention par
  constraint identity_signals_retain_ck check ((kind in ('email', 'recovery', 'payment')) = (retain_until is null))
);
create unique index if not exists identity_signals_uq on public.identity_signals (account_id, kind, hmac);
create index if not exists identity_signals_lookup_idx on public.identity_signals (kind, hmac);
create index if not exists identity_signals_expiry_idx on public.identity_signals (retain_until) where retain_until is not null;

create table if not exists public.identity_bans (
  id          bigint generated always as identity primary key,
  kind        text        not null check (public.identity_kind_strong(kind) is not null),
  hmac        bytea       not null check (octet_length(hmac) = 32),
  key_id      smallint    not null default 1 check (key_id > 0),
  reason      text        not null check (reason in ('abuse', 'spam', 'fraud', 'severe_pattern', 'policy_violation')),
  source_ref  uuid,                                   -- sirf andar ka hawala (FK nahi: account mit jata hai); kabhi bahar nahi jata
  banned_at   timestamptz not null default now(),
  expires_at  timestamptz,                            -- NULL = hamesha (severe)
  appealable  boolean     not null default true,
  lifted_at   timestamptz,
  lifted_by   uuid,
  constraint identity_bans_lift_ck check (lifted_by is null or lifted_at is not null)
);
create unique index if not exists identity_bans_active_uq on public.identity_bans (kind, hmac) where lifted_at is null;
create index if not exists identity_bans_source_idx on public.identity_bans (source_ref) where source_ref is not null;

create table if not exists public.identity_vault_audit (
  id         bigint generated always as identity primary key,
  at         timestamptz not null default now(),
  event      text        not null check (event in ('register', 'deny', 'review', 'ban', 'lift', 'purge')),
  account_id uuid,
  detail     jsonb       not null default '{}'::jsonb check (pg_column_size(detail) <= 2048)   -- hash kabhi nahi, sirf ginti / kind
);
create index if not exists identity_vault_audit_at_idx on public.identity_vault_audit (at desc);

-- ---- 4. RLS ON + band (Rule 43) ------------------------------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['identity_vault_policy', 'identity_signals', 'identity_bans', 'identity_vault_audit'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant select, insert, update, delete on table public.%I to service_role', t);
    if not exists (select 1 from pg_policy p where p.polrelid = format('public.%I', t)::regclass and p.polname = 'ax_service_role_only') then
      execute format('create policy ax_service_role_only on public.%I for all to service_role using (true) with check (true)', t);
    end if;
  end loop;
end $$;

-- ---- 5. signals ka shape (ek jagah) -------------------------------------------------------------------------------------------
-- [{"kind":"device_key","hmac":"<64 hex>"}, ...] — <= 12, har kind maujood, hmac 64 chhote hex
create or replace function public.identity_signals_ok(p jsonb)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select p is not null and jsonb_typeof(p) = 'array' and jsonb_array_length(p) between 1 and 12
     and not exists (
       select 1 from jsonb_array_elements(p) e
        where jsonb_typeof(e) <> 'object'
           or public.identity_kind_strong(e ->> 'kind') is null
           or coalesce(e ->> 'hmac', '') !~ '^[0-9a-f]{64}$')
$$;

create or replace function public.identity_parse_signals(p jsonb)
returns table (kind text, hmac bytea) language plpgsql immutable parallel safe set search_path = pg_catalog, public as $$
begin
  if not public.identity_signals_ok(p) then raise exception 'bad_signals' using errcode = '22023'; end if;
  return query select distinct e ->> 'kind', decode(e ->> 'hmac', 'hex') from jsonb_array_elements(p) e;
end $$;

-- ---- 6. signup check: allow | review | deny --------------------------------------------------------------------------------
create or replace function public.identity_signup_check(p_signals jsonb)
returns jsonb language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare
  pol      public.identity_vault_policy;
  v_deny   text[];
  v_weak   integer;
  v_shared boolean;
  v_appeal boolean;
  v_reason text;
begin
  select * into pol from public.identity_vault_policy where id = 1;
  select array_agg(distinct s.kind order by s.kind), bool_and(b.appealable), (array_agg(b.reason order by b.banned_at desc))[1]
    into v_deny, v_appeal, v_reason
    from public.identity_parse_signals(p_signals) s
    join public.identity_bans b on b.kind = s.kind and b.hmac = s.hmac and b.lifted_at is null and (b.expires_at is null or b.expires_at > now())
   where public.identity_kind_strong(s.kind);
  if v_deny is not null then
    return jsonb_build_object('decision', 'deny', 'matched', to_jsonb(v_deny), 'appealable', coalesce(v_appeal, true), 'reason', v_reason);
  end if;

  select count(*) into v_weak
    from public.identity_parse_signals(p_signals) s
    join public.identity_bans b on b.kind = s.kind and b.hmac = s.hmac and b.lifted_at is null and (b.expires_at is null or b.expires_at > now())
   where not public.identity_kind_strong(s.kind);

  select exists (
    select 1 from public.identity_parse_signals(p_signals) s
     where s.kind = 'device_key'
       and (select count(distinct x.account_id) from public.identity_signals x where x.kind = 'device_key' and x.hmac = s.hmac) >= pol.shared_device_limit
  ) into v_shared;

  if v_weak >= pol.weak_review_threshold or v_shared then
    return jsonb_build_object('decision', 'review', 'matched', '[]'::jsonb, 'appealable', true, 'reason', case when v_shared then 'shared_device' else 'weak_match' end);
  end if;
  return jsonb_build_object('decision', 'allow', 'matched', '[]'::jsonb, 'appealable', true, 'reason', null);
end $$;

-- ---- 7. register: account ki nishaniyan likho (pehle phir se check — dohra darwaza) -------------------------------------------------
create or replace function public.identity_register(p_account uuid, p_signals jsonb)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare
  pol  public.identity_vault_policy;
  chk  jsonb;
  n    integer := 0;
begin
  if p_account is null then raise exception 'account_required' using errcode = '22023'; end if;
  chk := public.identity_signup_check(p_signals);
  if chk ->> 'decision' = 'deny' then
    insert into public.identity_vault_audit (event, account_id, detail) values ('deny', p_account, jsonb_build_object('matched', chk -> 'matched'));
    return chk;
  end if;
  select * into pol from public.identity_vault_policy where id = 1;
  insert into public.identity_signals (account_id, kind, hmac, key_id, retain_until)
  select p_account, s.kind, s.hmac, pol.key_id,
         case s.kind when 'device_key'   then now() + make_interval(days => pol.signal_retain_days)
                     when 'device_shape' then now() + make_interval(days => pol.signal_retain_days)
                     when 'network'      then now() + make_interval(days => pol.network_retain_days)
                     else null end
    from public.identity_parse_signals(p_signals) s
  on conflict (account_id, kind, hmac) do update
     set last_seen = now(), seen_count = public.identity_signals.seen_count + 1,
         retain_until = case when public.identity_signals.retain_until is null then null else excluded.retain_until end;
  get diagnostics n = row_count;
  insert into public.identity_vault_audit (event, account_id, detail)
  values (case when chk ->> 'decision' = 'review' then 'review' else 'register' end, p_account, jsonb_build_object('signals', n, 'reason', chk -> 'reason'));
  return chk || jsonb_build_object('registered', n);
end $$;

-- ---- 8. ban: account ke sab nishan blacklist mein (account delete hone par bhi bache rehte hain) ----------------------------------------
create or replace function public.identity_ban_account(p_account uuid, p_reason text, p_permanent boolean default false, p_by uuid default null)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare
  pol public.identity_vault_policy;
  n   integer;
begin
  if p_account is null then raise exception 'account_required' using errcode = '22023'; end if;
  if p_reason is null or p_reason not in ('abuse', 'spam', 'fraud', 'severe_pattern', 'policy_violation') then
    raise exception 'bad_reason' using errcode = '22023';
  end if;
  select * into pol from public.identity_vault_policy where id = 1;
  insert into public.identity_bans (kind, hmac, key_id, reason, source_ref, expires_at, appealable)
  select distinct on (s.kind, s.hmac) s.kind, s.hmac, s.key_id, p_reason, p_account,
         case when p_permanent or p_reason in ('fraud', 'severe_pattern') then null else now() + make_interval(days => pol.ban_retain_days) end,
         not (p_permanent or p_reason = 'severe_pattern')
    from public.identity_signals s where s.account_id = p_account
  on conflict (kind, hmac) where lifted_at is null do update
     set reason = excluded.reason, banned_at = now(),
         expires_at = case when public.identity_bans.expires_at is null or excluded.expires_at is null then null
                           else greatest(public.identity_bans.expires_at, excluded.expires_at) end,
         appealable = public.identity_bans.appealable and excluded.appealable;
  get diagnostics n = row_count;
  insert into public.identity_vault_audit (event, account_id, detail) values ('ban', p_account, jsonb_build_object('signals', n, 'reason', p_reason, 'by_human', p_by is not null));
  return jsonb_build_object('banned', n);
end $$;

-- appeal manzoor: us account ke sab ban hat jate hain
create or replace function public.identity_ban_lift(p_account uuid, p_by uuid)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare n integer;
begin
  if p_account is null or p_by is null then raise exception 'account_and_actor_required' using errcode = '22023'; end if;
  update public.identity_bans set lifted_at = now(), lifted_by = p_by
   where source_ref = p_account and lifted_at is null and appealable;
  get diagnostics n = row_count;
  insert into public.identity_vault_audit (event, account_id, detail) values ('lift', p_account, jsonb_build_object('lifted', n));
  return jsonb_build_object('lifted', n);
end $$;

-- ---- 9. purge (cron/timer se): expiry guzri nishaniyan + purane ban + purana audit saaf ---------------------------------------------------
create or replace function public.identity_vault_purge()
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '30s' as $$
declare a integer; b integer; c integer;
begin
  delete from public.identity_signals where retain_until is not null and retain_until < now();
  get diagnostics a = row_count;
  delete from public.identity_bans where (expires_at is not null and expires_at < now() - interval '30 days') or (lifted_at is not null and lifted_at < now() - interval '30 days');
  get diagnostics b = row_count;
  delete from public.identity_vault_audit where at < now() - interval '2 years';
  get diagnostics c = row_count;
  insert into public.identity_vault_audit (event, detail) values ('purge', jsonb_build_object('signals', a, 'bans', b, 'audit', c));
  return jsonb_build_object('signals', a, 'bans', b, 'audit', c);
end $$;

-- ---- 10. function privileges: sirf service_role ---------------------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'public.identity_kind_strong(text)', 'public.identity_signals_ok(jsonb)', 'public.identity_parse_signals(jsonb)',
    'public.identity_signup_check(jsonb)', 'public.identity_register(uuid,jsonb)', 'public.identity_ban_account(uuid,text,boolean,uuid)',
    'public.identity_ban_lift(uuid,uuid)', 'public.identity_vault_purge()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on table public.identity_signals is 'One-way HMAC identity signals per account (E66). Cascade-deleted with the account. Never holds raw data.';
comment on table public.identity_bans is 'Blacklist of one-way HMAC signals of blocked accounts (E66). Survives account deletion; expires per identity_vault_policy; appealable unless severe.';
comment on function public.identity_signup_check(jsonb) is 'allow | review | deny for a set of HMAC signals. Never returns hashes or source accounts.';

-- ---- 11. POST-CONDITION -----------------------------------------------------------------------------------------------------------------
do $$
begin
  if (select count(*) from pg_class c where c.oid in ('public.identity_vault_policy'::regclass, 'public.identity_signals'::regclass, 'public.identity_bans'::regclass, 'public.identity_vault_audit'::regclass) and c.relrowsecurity) <> 4 then
    raise exception 'E66 POST-CONDITION: RLS chaaron tables par ON nahi' using errcode = 'AX066';
  end if;
  if not public.identity_signals_ok('[{"kind":"email","hmac":"0000000000000000000000000000000000000000000000000000000000000000"}]'::jsonb)
     or public.identity_signals_ok('[{"kind":"email","hmac":"xyz"}]'::jsonb) then
    raise exception 'E66 POST-CONDITION: identity_signals_ok galat jawab deta hai' using errcode = 'AX066';
  end if;
end $$;

notify pgrst, 'reload schema';
