
-- E76 v2 — ACCOUNT CLASS WALL: asli buyer / founder / family / test accounts kabhi mix nahi. 23 Oct 2026. Dobara chalana safe. Koi DROP nahi.
-- Founder hukm (Rule 49): "real buyers test accounts se ek word bhi mix nahi hoga". Teen deewarein:
--   1) EK CLASS: ek email sirf ek class mein (founder_accounts | family_accounts | test_accounts | warna real). Teeno table par trigger: doosri class mein hai to INSERT/UPDATE band.
--   2) ASLI SIGNUP KA RASTA: trial_accounts par trigger (claim ka chokepoint) — asli user ko test-naam wala handle (x.test) ya kisi special account ka pata (address) nahi milta.
--   3) CHHOOT FAIL-CLOSED: passkey gate ki chhoot sirf registry (test_accounts) se, naam-pattern akela kaafi nahi; rpc na mile to chhoot nahi.
-- Naya test account (naam kuch bhi, jaise pro.buyer): pehle register_test_account(email, note), phir claim (E28/E36 yehi karte hain). Sirf service_role/SQL; asli signup ka koi rasta nahi. Audit: account_mix_report() — khali = saaf.
-- Advance: lock_timeout, RLS ON + service_role only, security definer + pinned search_path, triggers sirf naye writes par (purani rows nahi chhedta),
--   registry mojooda auth.users (pattern wale) se ek baar bhari jati hai aur NOTICE mein naam dikhate hain taake founder dekh sake.
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$
begin
  if to_regclass('public.trial_accounts') is null or to_regclass('auth.users') is null then
    raise exception 'PREFLIGHT: trial_accounts / auth.users nahi mile — pehle purani migrations chalayen';
  end if;
end $$;

-- ---------------------------------------------------------------- registry
create table if not exists public.test_accounts (
  email      text primary key check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+$'),
  note       text,
  created_at timestamptz not null default now()
);
alter table public.test_accounts enable row level security;
revoke all on public.test_accounts from public, anon, authenticated;
grant select, insert, delete on public.test_accounts to service_role;
comment on table public.test_accounts is 'Founder test accounts only (E76). Passkey exemption needs name pattern AND a row here. Real signups never land here.';

-- ---------------------------------------------------------------- helpers
create or replace function public._is_test_name(_email text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select lower(coalesce(_email, '')) ~ '(^|[._-])test@' or lower(coalesce(_email, '')) ~ '^[^@]*(^|[._-])test$';
$$;

-- email kis class ka hai: founder | family | test | real (case-insensitive; null/khali => real)
create or replace function public.account_class(_email text)
returns text language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare e text := lower(btrim(coalesce(_email, '')));
begin
  if e = '' then return 'real'; end if;
  if to_regclass('public.founder_accounts') is not null
     and exists (select 1 from public.founder_accounts f where lower(f.email) = e) then return 'founder'; end if;
  if to_regclass('public.family_accounts') is not null
     and exists (select 1 from public.family_accounts f where lower(f.email) = e) then return 'family'; end if;
  if exists (select 1 from public.test_accounts t where t.email = e) then return 'test'; end if;
  return 'real';
end $$;

create or replace function public.is_registered_test_account(_email text)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select public.account_class(_email) = 'test';
$$;

create or replace function public.register_test_account(_email text, _note text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare e text := lower(btrim(coalesce(_email, '')));
begin
  if e !~ '^[^@\s]+@[^@\s]+$' then return jsonb_build_object('ok', false, 'error', 'bad_email'); end if;
  if public.account_class(e) not in ('real', 'test') then
    return jsonb_build_object('ok', false, 'error', 'belongs_to_' || public.account_class(e));
  end if;
  insert into public.test_accounts (email, note) values (e, left(_note, 200)) on conflict do nothing;
  return jsonb_build_object('ok', true, 'email', e);
end $$;

-- ---------------------------------------------------------------- wall 1: ek email, ek class
create or replace function public._acct_one_class()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare e text := lower(btrim(coalesce(new.email, ''))); mine text := tg_argv[0]; other text;
begin
  other := public.account_class(e);
  if other not in ('real', mine) then
    raise exception 'account_class_clash: % pehle se % hai, % nahi ban sakta', e, other, mine using errcode = '23514';
  end if;
  return new;
end $$;

drop trigger if exists ax_one_class on public.test_accounts;
create trigger ax_one_class before insert or update of email on public.test_accounts
  for each row execute function public._acct_one_class('test');
do $$
begin
  if to_regclass('public.founder_accounts') is not null then
    drop trigger if exists ax_one_class on public.founder_accounts;
    create trigger ax_one_class before insert or update of email on public.founder_accounts
      for each row execute function public._acct_one_class('founder');
  end if;
  if to_regclass('public.family_accounts') is not null then
    drop trigger if exists ax_one_class on public.family_accounts;
    create trigger ax_one_class before insert or update of email on public.family_accounts
      for each row execute function public._acct_one_class('family');
  end if;
end $$;

-- ---------------------------------------------------------------- wall 2: asli signup ka claim chokepoint
create or replace function public._trial_handle_wall()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare addr text; cls text; login text;
begin
  if new.anexomail_handle is null or btrim(new.anexomail_handle) = '' then return new; end if;
  addr := lower(btrim(new.anexomail_handle)) || '@anexomail.com';
  cls  := public.account_class(addr);
  select lower(u.email) into login from auth.users u where u.id = new.user_id;
  if cls <> 'real' and login is distinct from addr then
    raise exception 'handle_reserved: % % account ka pata hai', addr, cls using errcode = '23514';
  end if;
  if public._is_test_name(addr) and cls = 'real' then
    raise exception 'handle_reserved: x.test jaise naam sirf founder ke test accounts ke liye hain' using errcode = '23514';
  end if;
  return new;
end $$;

drop trigger if exists ax_trial_handle_wall on public.trial_accounts;
create trigger ax_trial_handle_wall before insert or update of anexomail_handle, anexomail_address on public.trial_accounts
  for each row execute function public._trial_handle_wall();

-- ---------------------------------------------------------------- seed: mojooda test accounts (pattern par) registry mein
do $$
declare r record;
begin
  for r in select lower(u.email) as e from auth.users u where public._is_test_name(u.email) and u.deleted_at is null loop
    if public.account_class(r.e) = 'real' then
      insert into public.test_accounts (email, note) values (r.e, 'E76 seed: pattern par mojood tha') on conflict do nothing;
      raise notice 'E76 registry: %', r.e;
    else
      raise notice 'E76 chhoda (pehle se %): %', public.account_class(r.e), r.e;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------- audit: khali = saaf
create or replace function public.account_mix_report()
returns table(problem text, email text) language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  return query
    select 'test-naam par asli (registry mein nahi)'::text, lower(u.email)
      from auth.users u where public._is_test_name(u.email) and u.deleted_at is null
       and public.account_class(u.email) = 'real';
  if to_regclass('public.founder_accounts') is not null then
    return query select 'founder aur test dono'::text, lower(f.email) from public.founder_accounts f join public.test_accounts t on t.email = lower(f.email);
  end if;
  if to_regclass('public.family_accounts') is not null then
    return query select 'family aur test dono'::text, lower(f.email) from public.family_accounts f join public.test_accounts t on t.email = lower(f.email);
  end if;
  if to_regclass('public.founder_accounts') is not null and to_regclass('public.family_accounts') is not null then
    return query select 'founder aur family dono'::text, lower(a.email) from public.founder_accounts a join public.family_accounts b on lower(b.email) = lower(a.email);
  end if;
end $$;

revoke all on function public._is_test_name(text), public.account_class(text), public.is_registered_test_account(text),
  public.register_test_account(text, text), public._acct_one_class(), public._trial_handle_wall(), public.account_mix_report() from public, anon, authenticated;
grant execute on function public.account_class(text), public.is_registered_test_account(text), public.register_test_account(text, text),
  public.account_mix_report() to service_role;
