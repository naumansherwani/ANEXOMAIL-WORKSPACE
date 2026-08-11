-- ANEXOMAIL — Phase 28: Cross-Platform Experience (device handoff)
-- Supabase #4 SQL editor mein poora block chalao. Idempotent + self-healing.
--
-- Ye phase READ-offline + PWA + handoff hai. Send queue (outbox) Phase 30 mein.

-- ---------- self-heal: purani conflicting table ko legacy kar do ----------
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema = 'public' and table_name = 'device_handoff')
     and not exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'device_handoff'
               and column_name = 'cursor_position') then
    execute 'alter table public.device_handoff rename to device_handoff_legacy';
  end if;
end $$;

-- ---------- devices: har device ki pehchaan (trust Phase 26 mein) ----------
create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_label text not null default 'Unknown device',
  platform text,
  installed boolean not null default false,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, device_id)
);

-- ---------- handoff drafts: ek draft, cursor ke saath ----------
create table if not exists public.device_handoff (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_label text not null default 'Unknown device',
  thread_id text,
  to_address text,
  subject text,
  body text,
  cursor_position integer not null default 0,
  claimed_by text,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.device_handoff add column if not exists cursor_position integer not null default 0;
alter table public.device_handoff add column if not exists claimed_by text;
alter table public.device_handoff add column if not exists device_label text not null default 'Unknown device';

create index if not exists device_handoff_user_idx on public.device_handoff (user_id, updated_at desc);
create unique index if not exists device_handoff_slot_idx
  on public.device_handoff (user_id, device_id, coalesce(thread_id, 'new'));
create index if not exists user_devices_user_idx on public.user_devices (user_id, last_seen desc);

-- ---------- grants (Data API access) ----------
grant select, insert, update, delete on public.device_handoff to authenticated;
grant all on public.device_handoff to service_role;
grant select, insert, update, delete on public.user_devices to authenticated;
grant all on public.user_devices to service_role;

-- ---------- RLS: sirf apna data ----------
alter table public.device_handoff enable row level security;
alter table public.user_devices enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public'
                 and tablename='device_handoff' and policyname='handoff_own') then
    create policy handoff_own on public.device_handoff
      for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public'
                 and tablename='user_devices' and policyname='devices_own') then
    create policy devices_own on public.user_devices
      for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
end $$;

-- ---------- housekeeping: 30 din se purane handoff drafts hata do ----------
delete from public.device_handoff where updated_at < now() - interval '30 days';