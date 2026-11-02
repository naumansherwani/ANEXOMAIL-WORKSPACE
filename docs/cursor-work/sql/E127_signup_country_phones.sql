-- =============================================================================
-- E127 — PX2a (founder 2 Nov 2026 09:02 + 09:07): sign-up/create-account gets COUNTRY and MOBILE NUMBERS.
-- Founder rules: a person may have MANY numbers ("user multiple number use kar sakta hai", no unfair "already used" wall); the same number may exist on more than one account;
--                no phone login by SMS yet (no SMS provider chosen); numbers are stored UNVERIFIED until a verification channel exists. NO mock data.
-- Adds (idempotent):
--   1) account_profiles.country_iso2  text, ISO 3166-1 alpha-2, upper case (NULL for old accounts until they add it; a NULL never blocks sign-in).
--   2) public.account_phones          one row per number: e164 (+ and 7-15 digits), country_iso2, label, is_primary, verified_at (NULL = unverified), created_at.
--        * UNIQUE (user_id, e164) only: the same number twice on ONE account is refused; across accounts it is allowed.
--        * at most 5 numbers per account (trigger), at most one primary (partial unique index).
--        * RLS on, anon/authenticated have no privileges (the Rust/Bun doors use service_role, like the other account tables).
-- Not here: server doors (PX2b), UI (PX2c), SMS verification (needs a provider decision), email/handle availability (existing identity/check + PX2b).
-- =============================================================================
set search_path = public, extensions;

alter table public.account_profiles add column if not exists country_iso2 text;
do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.account_profiles'::regclass and conname = 'account_profiles_country_iso2_chk') then
    alter table public.account_profiles add constraint account_profiles_country_iso2_chk check (country_iso2 is null or country_iso2 ~ '^[A-Z]{2}$');
  end if;
end $$;

create table if not exists public.account_phones (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  e164        text not null check (e164 ~ '^\+[1-9][0-9]{6,14}$'),
  country_iso2 text not null check (country_iso2 ~ '^[A-Z]{2}$'),
  label       text check (label is null or char_length(label) <= 40),
  is_primary  boolean not null default false,
  verified_at timestamptz,
  created_at  timestamptz not null default now(),
  unique (user_id, e164)
);
create index if not exists account_phones_user_idx on public.account_phones (user_id);
create unique index if not exists account_phones_one_primary_uq on public.account_phones (user_id) where is_primary;

create or replace function public.account_phones_limit() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if (select count(*) from public.account_phones where user_id = new.user_id) >= 5 then
    raise exception 'account_phones_limit: at most 5 numbers per account';
  end if;
  return new;
end $$;
drop trigger if exists account_phones_limit_trg on public.account_phones;
create trigger account_phones_limit_trg before insert on public.account_phones for each row execute function public.account_phones_limit();
revoke all on function public.account_phones_limit() from public, anon, authenticated;

alter table public.account_phones enable row level security;
revoke all on public.account_phones from anon, authenticated;
grant all on public.account_phones to service_role;
