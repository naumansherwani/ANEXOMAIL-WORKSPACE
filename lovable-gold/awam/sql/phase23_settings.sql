-- ANEXOMAIL — Phase 23: Settings Center (Supabase #4)
-- Locked rules: idempotent + self-healing, grants pehle phir RLS.
-- 6 advance features: Time Machine · Explain (Leo) · Blast radius · Drift baseline
--                     · Scheduled change + auto-rollback · Dry-run simulate
begin;

-- 1) Setting catalog (server-owned definition, not user data) -----------------
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='setting_defs')
     and not exists (select 1 from information_schema.columns
                     where table_schema='public' and table_name='setting_defs' and column_name='scope') then
    execute format('alter table public.setting_defs rename to setting_defs_legacy_%s', to_char(now(),'YYYYMMDDHH24MISS'));
  end if;
end $$;

create table if not exists public.setting_defs (
  key            text primary key,
  scope          text not null check (scope in ('personal','workspace','appearance','notifications','privacy','ai')),
  label          text not null,
  help           text not null default '',
  kind           text not null default 'toggle' check (kind in ('toggle','choice','number','text')),
  default_value  text,
  options        jsonb,
  -- baseline for drift: recommended safe value
  recommended    text,
  risk_if_off    text,
  -- blast radius inputs
  affects        text[] not null default '{}',
  reversible     boolean not null default true,
  created_at     timestamptz not null default now()
);

grant select on public.setting_defs to authenticated;
grant select on public.setting_defs to anon;
grant all on public.setting_defs to service_role;
alter table public.setting_defs enable row level security;
drop policy if exists setting_defs_read on public.setting_defs;
create policy setting_defs_read on public.setting_defs for select to authenticated, anon using (true);

-- 2) Actual values -----------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='setting_values')
     and not exists (select 1 from information_schema.columns
                     where table_schema='public' and table_name='setting_values' and column_name='user_id') then
    execute format('alter table public.setting_values rename to setting_values_legacy_%s', to_char(now(),'YYYYMMDDHH24MISS'));
  end if;
end $$;

create table if not exists public.setting_values (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  tenant      text,
  key         text not null,
  value       text,
  updated_at  timestamptz not null default now(),
  updated_by  text,
  unique (user_id, key)
);
create index if not exists setting_values_user_idx on public.setting_values(user_id);

grant select, insert, update, delete on public.setting_values to authenticated;
grant all on public.setting_values to service_role;
alter table public.setting_values enable row level security;
drop policy if exists setting_values_own on public.setting_values;
create policy setting_values_own on public.setting_values for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 3) Time Machine: every change, revertible --------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='setting_versions')
     and not exists (select 1 from information_schema.columns
                     where table_schema='public' and table_name='setting_versions' and column_name='user_id') then
    execute format('alter table public.setting_versions rename to setting_versions_legacy_%s', to_char(now(),'YYYYMMDDHH24MISS'));
  end if;
end $$;

create table if not exists public.setting_versions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  key         text not null,
  from_value  text,
  to_value    text,
  changed_by  text not null default 'self',
  changed_at  timestamptz not null default now(),
  reason      text,
  reverted    boolean not null default false,
  -- blast radius snapshot at the moment of change (audit-grade)
  blast       jsonb
);
create index if not exists setting_versions_user_idx on public.setting_versions(user_id, changed_at desc);

grant select, insert, update on public.setting_versions to authenticated;
grant all on public.setting_versions to service_role;
alter table public.setting_versions enable row level security;
drop policy if exists setting_versions_own on public.setting_versions;
create policy setting_versions_own on public.setting_versions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 4) Scheduled change + auto-rollback ---------------------------------------
create table if not exists public.setting_schedules (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references auth.users(id) on delete cascade,
  key                    text not null,
  to_value               text not null,
  apply_at               timestamptz not null,
  auto_rollback_minutes  integer,
  state                  text not null default 'scheduled'
                         check (state in ('scheduled','applied','rolled_back','cancelled')),
  requested_by           text not null default 'self',
  applied_at             timestamptz,
  rolled_back_at         timestamptz,
  rollback_reason        text,
  created_at             timestamptz not null default now()
);
create index if not exists setting_schedules_due_idx on public.setting_schedules(state, apply_at);

grant select, insert, update, delete on public.setting_schedules to authenticated;
grant all on public.setting_schedules to service_role;
alter table public.setting_schedules enable row level security;
drop policy if exists setting_schedules_own on public.setting_schedules;
create policy setting_schedules_own on public.setting_schedules for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 5) Explain this setting (Leo cache — plain language + real example) --------
create table if not exists public.setting_explanations (
  key         text primary key,
  plain       text not null,
  example     text not null,
  tradeoff    text,
  source      text not null default 'leo' check (source in ('leo','server')),
  model       text,
  updated_at  timestamptz not null default now()
);

grant select on public.setting_explanations to authenticated;
grant all on public.setting_explanations to service_role;
alter table public.setting_explanations enable row level security;
drop policy if exists setting_explanations_read on public.setting_explanations;
create policy setting_explanations_read on public.setting_explanations for select to authenticated using (true);

-- 6) Seed the catalog (real settings, no dummy) -----------------------------
insert into public.setting_defs (key, scope, label, help, kind, default_value, recommended, affects, reversible, options) values
  ('personal.display_name','personal','Display name','The name recipients see next to your address.','text',null,null,'{}',true,null),
  ('personal.undo_send_seconds','personal','Undo send window','How long a sent mail is held before it really leaves.','choice','30','30','{outbox}',true,'[{"value":"0","label":"Off"},{"value":"10","label":"10 seconds"},{"value":"30","label":"30 seconds"}]'),
  ('personal.send_confidence','personal','Send confidence check','Warn before sending when tone, recipients or attachments look wrong.','toggle','true','true','{compose}',true,null),
  ('workspace.enforce_mfa','workspace','Require two-factor for everyone','Members without a second factor cannot sign in.','toggle','true','true','{members,sessions}',true,null),
  ('workspace.external_warning','workspace','Flag external recipients','Show a clear warning when a thread leaves the company.','toggle','true','true','{compose,members}',true,null),
  ('workspace.retention_days','workspace','Retention window','How long mail is kept before permanent deletion.','number','0','0','{mailboxes}',false,null),
  ('appearance.density','appearance','Density','How tight the three-panel layout packs information.','choice','comfortable','comfortable','{}',true,'[{"value":"compact","label":"Compact"},{"value":"comfortable","label":"Comfortable"}]'),
  ('appearance.reduce_motion','appearance','Reduce motion','Honour the system setting and drop all non-essential animation.','toggle','false','false','{}',true,null),
  ('notifications.quiet_hours','notifications','Quiet hours','Silence everything outside working hours, except escalations.','toggle','true','true','{notifications}',true,null),
  ('notifications.vip_only','notifications','Only VIPs interrupt','Everything else waits for the next inbox check.','toggle','false','false','{notifications}',true,null),
  ('privacy.read_receipts','privacy','Read receipts','Tell senders when you opened their mail.','toggle','false','false','{privacy}',true,null),
  ('privacy.link_tracking','privacy','Block tracking pixels','Strip trackers from incoming mail before it renders.','toggle','true','true','{privacy}',true,null),
  ('ai.leo_enabled','ai','Leo assistance','Let Leo draft, triage and summarise inside this workspace.','toggle','false','false','{ai}',true,null),
  ('ai.leo_autoreply','ai','Leo auto-reply','Leo may answer routine mail without you approving each one.','toggle','false','false','{ai,outbox}',true,null)
on conflict (key) do update
  set scope = excluded.scope, label = excluded.label, help = excluded.help,
      kind = excluded.kind, default_value = excluded.default_value,
      recommended = excluded.recommended, affects = excluded.affects,
      reversible = excluded.reversible, options = excluded.options;

commit;
