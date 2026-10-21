-- E57 — calendar ki display pasand ACCOUNT mein save: clock 12h/24h/auto + layout classic/expanded (22 Oct 2026)
-- Pehle sirf us device ke localStorage mein thi; ab user kisi bhi device par login kare to wahi pasand milti hai.
--   * ek row per user (primary key), sirf service_role (Rust /rpc/locale.uipref*) — anon/authenticated ko kuch nahi
--   * galat value table mein ja hi nahi sakti (CHECK), aur account delete hote hi row saaf (FK ... ON DELETE CASCADE)
--   * `extra` jsonb: agli pasandein (working hours, default view, week start …) bina nayi migration ke; sirf object, <= 4 KB
--   * updated_at hamesha DB khud lagata hai (trigger), client par bharosa nahi
-- Dobara chalana safe. Koi table DROP nahi. Fail ho to USI file ko theek karo (naya naam nahi).
create table if not exists public.awam_ui_pref (
  user_id    uuid primary key,
  clock      text not null default 'auto',
  cal_layout text not null default 'classic',
  extra      jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.awam_ui_pref add column if not exists clock text not null default 'auto';
alter table public.awam_ui_pref add column if not exists cal_layout text not null default 'classic';
alter table public.awam_ui_pref add column if not exists extra jsonb not null default '{}'::jsonb;
alter table public.awam_ui_pref add column if not exists updated_at timestamptz not null default now();

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'awam_ui_pref_clock_ck') then
    alter table public.awam_ui_pref add constraint awam_ui_pref_clock_ck check (clock in ('auto', '12', '24'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'awam_ui_pref_layout_ck') then
    alter table public.awam_ui_pref add constraint awam_ui_pref_layout_ck check (cal_layout in ('classic', 'expanded'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'awam_ui_pref_extra_ck') then
    alter table public.awam_ui_pref add constraint awam_ui_pref_extra_ck
      check (jsonb_typeof(extra) = 'object' and pg_column_size(extra) <= 4096);
  end if;
  -- account delete => row bhi jaye (privacy). auth.users na ho (test DB) to FK chhod do.
  if to_regclass('auth.users') is not null and not exists (select 1 from pg_constraint where conname = 'awam_ui_pref_user_fk') then
    alter table public.awam_ui_pref
      add constraint awam_ui_pref_user_fk foreign key (user_id) references auth.users (id) on delete cascade not valid;
    alter table public.awam_ui_pref validate constraint awam_ui_pref_user_fk;
  end if;
end $$;

create or replace function public.awam_ui_pref_touch()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists awam_ui_pref_touch on public.awam_ui_pref;
create trigger awam_ui_pref_touch before insert or update on public.awam_ui_pref
  for each row execute function public.awam_ui_pref_touch();

alter table public.awam_ui_pref enable row level security;
revoke all on public.awam_ui_pref from anon, authenticated;
revoke all on function public.awam_ui_pref_touch() from public, anon, authenticated;
grant select, insert, update on public.awam_ui_pref to service_role;

comment on table public.awam_ui_pref is 'Per-account calendar display preference (clock format, layout). Written only by the Rust engine (service_role).';
