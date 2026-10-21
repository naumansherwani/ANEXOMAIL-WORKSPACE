-- E58 — calendar ki display pasand (clock 12h/24h/auto + layout classic/expanded) ACCOUNT mein save (22 Oct 2026)
-- Pehle sirf us device ke localStorage mein thi; ab user kisi bhi device par login kare to wahi pasand milti hai.
-- Sirf service_role (Rust /rpc/locale.uipref*). Dobara chalana safe. Koi table DROP nahi.
create table if not exists public.awam_ui_pref (
  user_id    uuid primary key,
  clock      text not null default 'auto',
  cal_layout text not null default 'classic',
  updated_at timestamptz not null default now()
);
alter table public.awam_ui_pref add column if not exists clock text not null default 'auto';
alter table public.awam_ui_pref add column if not exists cal_layout text not null default 'classic';
alter table public.awam_ui_pref add column if not exists updated_at timestamptz not null default now();

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'awam_ui_pref_clock_ck') then
    alter table public.awam_ui_pref add constraint awam_ui_pref_clock_ck check (clock in ('auto', '12', '24'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'awam_ui_pref_layout_ck') then
    alter table public.awam_ui_pref add constraint awam_ui_pref_layout_ck check (cal_layout in ('classic', 'expanded'));
  end if;
end $$;

alter table public.awam_ui_pref enable row level security;
revoke all on public.awam_ui_pref from anon, authenticated;
grant select, insert, update on public.awam_ui_pref to service_role;
