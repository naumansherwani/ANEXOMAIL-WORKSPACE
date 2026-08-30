-- ANEXOMAIL — Phase 25: Admin Center (Supabase #4)
-- 6 advance features:
--   1. Self-healing health (check -> auto-remedy -> proof)
--   2. Storage forecast (days-until-full + reclaimable bytes)
--   3. Incident timeline (blame-free replay + postmortem)
--   4. Delivery watchtower (queue / defer / bounce reasons, live)
--   5. Log lens (request trace + plain-English translation)
--   6. Diagnostics proof pack (DNS/DKIM/SPF/DMARC/TLS/SMTP/IMAP, signed export)
-- Locked rules: idempotent + self-healing (legacy rename), grants pehle phir RLS.
begin;

-- self-healing: purani conflicting tables ko _legacy_<ts> bana do -----------
do $$
declare t text; ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  foreach t in array array[
    'admin_health_checks','admin_health_runs','admin_incidents','admin_incident_events',
    'admin_storage_snapshots','admin_logs','admin_reports','admin_diagnostic_runs',
    'admin_diagnostic_probes','admin_delivery_events'
  ] loop
    if exists (
      select 1 from information_schema.tables
      where table_schema = 'public' and table_name = t
    ) and not exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = t and column_name = 'user_id'
    ) then
      execute format('alter table public.%I rename to %I', t, t || '_legacy_' || ts);
    end if;
  end loop;
end $$;

-- 1) Self-healing health ----------------------------------------------------
create table if not exists public.admin_health_checks (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  key           text not null,
  label         text not null,
  category      text not null default 'system'
                check (category in ('mail','dns','system','storage','security','ai')),
  status        text not null default 'unknown'
                check (status in ('ok','warn','fail','unknown')),
  detail        text,
  can_self_heal boolean not null default false,
  remedy        text,
  heals_24h     integer not null default 0,
  last_healed_at timestamptz,
  checked_at    timestamptz not null default now(),
  unique (user_id, key)
);
grant select, insert, update, delete on public.admin_health_checks to authenticated;
grant all on public.admin_health_checks to service_role;
alter table public.admin_health_checks enable row level security;
drop policy if exists admin_health_checks_own on public.admin_health_checks;
create policy admin_health_checks_own on public.admin_health_checks for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.admin_health_runs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  key         text not null,
  action      text not null check (action in ('check','heal')),
  outcome     text not null check (outcome in ('ok','failed','skipped')),
  before_state text,
  after_state  text,
  proof       jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists admin_health_runs_idx on public.admin_health_runs(user_id, created_at desc);
grant select, insert on public.admin_health_runs to authenticated;
grant all on public.admin_health_runs to service_role;
alter table public.admin_health_runs enable row level security;
drop policy if exists admin_health_runs_own on public.admin_health_runs;
create policy admin_health_runs_own on public.admin_health_runs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 2) Storage forecast -------------------------------------------------------
create table if not exists public.admin_storage_snapshots (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  day              date not null default current_date,
  mailbox          text not null,
  used_bytes       bigint not null default 0,
  quota_bytes      bigint not null default 5368709120,
  attachment_bytes bigint not null default 0,
  trash_bytes      bigint not null default 0,
  duplicate_bytes  bigint not null default 0,
  created_at       timestamptz not null default now(),
  unique (user_id, day, mailbox)
);
create index if not exists admin_storage_idx on public.admin_storage_snapshots(user_id, day desc);
grant select, insert, update on public.admin_storage_snapshots to authenticated;
grant all on public.admin_storage_snapshots to service_role;
alter table public.admin_storage_snapshots enable row level security;
drop policy if exists admin_storage_own on public.admin_storage_snapshots;
create policy admin_storage_own on public.admin_storage_snapshots for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 3) Incident timeline ------------------------------------------------------
create table if not exists public.admin_incidents (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  title        text not null,
  severity     text not null default 'minor' check (severity in ('minor','major','critical')),
  status       text not null default 'open' check (status in ('open','mitigated','resolved')),
  surface      text not null default 'mail',
  started_at   timestamptz not null default now(),
  resolved_at  timestamptz,
  impact       text,
  cause        text,
  fix          text,
  prevention   text,
  auto_detected boolean not null default true
);
create index if not exists admin_incidents_idx on public.admin_incidents(user_id, started_at desc);
grant select, insert, update on public.admin_incidents to authenticated;
grant all on public.admin_incidents to service_role;
alter table public.admin_incidents enable row level security;
drop policy if exists admin_incidents_own on public.admin_incidents;
create policy admin_incidents_own on public.admin_incidents for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.admin_incident_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  incident_id uuid not null references public.admin_incidents(id) on delete cascade,
  at          timestamptz not null default now(),
  actor       text not null default 'system',
  kind        text not null default 'note'
              check (kind in ('detected','note','action','recovered','postmortem')),
  message     text not null
);
create index if not exists admin_incident_events_idx on public.admin_incident_events(incident_id, at);
grant select, insert on public.admin_incident_events to authenticated;
grant all on public.admin_incident_events to service_role;
alter table public.admin_incident_events enable row level security;
drop policy if exists admin_incident_events_own on public.admin_incident_events;
create policy admin_incident_events_own on public.admin_incident_events for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 4) Delivery watchtower ----------------------------------------------------
create table if not exists public.admin_delivery_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  at          timestamptz not null default now(),
  direction   text not null default 'out' check (direction in ('in','out')),
  address     text,
  remote      text,
  state       text not null check (state in ('queued','sent','deferred','bounced','rejected')),
  reason      text,
  reason_code text,
  human_reason text,
  fixable     boolean not null default false
);
create index if not exists admin_delivery_idx on public.admin_delivery_events(user_id, at desc);
grant select, insert on public.admin_delivery_events to authenticated;
grant all on public.admin_delivery_events to service_role;
alter table public.admin_delivery_events enable row level security;
drop policy if exists admin_delivery_own on public.admin_delivery_events;
create policy admin_delivery_own on public.admin_delivery_events for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 5) Log lens ---------------------------------------------------------------
create table if not exists public.admin_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  at          timestamptz not null default now(),
  level       text not null default 'info' check (level in ('debug','info','warn','error')),
  source      text not null default 'api',
  trace_id    text,
  route       text,
  status      integer,
  duration_ms integer,
  message     text not null,
  plain       text,
  meta        jsonb not null default '{}'::jsonb
);
create index if not exists admin_logs_idx on public.admin_logs(user_id, at desc);
create index if not exists admin_logs_trace_idx on public.admin_logs(trace_id);
create index if not exists admin_logs_msg_trgm on public.admin_logs using gin (message gin_trgm_ops);
grant select, insert on public.admin_logs to authenticated;
grant all on public.admin_logs to service_role;
alter table public.admin_logs enable row level security;
drop policy if exists admin_logs_own on public.admin_logs;
create policy admin_logs_own on public.admin_logs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 6a) Organization reports --------------------------------------------------
create table if not exists public.admin_reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  period      text not null,
  title       text not null,
  status      text not null default 'ready' check (status in ('building','ready','failed')),
  numbers     jsonb not null default '{}'::jsonb,
  highlights  jsonb not null default '[]'::jsonb,
  format      text not null default 'json' check (format in ('json','csv','pdf')),
  created_at  timestamptz not null default now(),
  unique (user_id, period, title)
);
create index if not exists admin_reports_idx on public.admin_reports(user_id, created_at desc);
grant select, insert, update, delete on public.admin_reports to authenticated;
grant all on public.admin_reports to service_role;
alter table public.admin_reports enable row level security;
drop policy if exists admin_reports_own on public.admin_reports;
create policy admin_reports_own on public.admin_reports for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 6b) Diagnostics proof pack ------------------------------------------------
create table if not exists public.admin_diagnostic_runs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  scope        text not null default 'all',
  passed       integer not null default 0,
  failed       integer not null default 0,
  proof_hash   text,
  export_ready boolean not null default false
);
create index if not exists admin_diag_runs_idx on public.admin_diagnostic_runs(user_id, started_at desc);
grant select, insert, update on public.admin_diagnostic_runs to authenticated;
grant all on public.admin_diagnostic_runs to service_role;
alter table public.admin_diagnostic_runs enable row level security;
drop policy if exists admin_diag_runs_own on public.admin_diagnostic_runs;
create policy admin_diag_runs_own on public.admin_diagnostic_runs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.admin_diagnostic_probes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  run_id     uuid not null references public.admin_diagnostic_runs(id) on delete cascade,
  probe      text not null,
  target     text,
  result     text not null default 'unknown' check (result in ('pass','fail','skip','unknown')),
  observed   text,
  expected   text,
  fix        text,
  ms         integer not null default 0
);
create index if not exists admin_diag_probes_idx on public.admin_diagnostic_probes(run_id);
grant select, insert on public.admin_diagnostic_probes to authenticated;
grant all on public.admin_diagnostic_probes to service_role;
alter table public.admin_diagnostic_probes enable row level security;
drop policy if exists admin_diag_probes_own on public.admin_diagnostic_probes;
create policy admin_diag_probes_own on public.admin_diagnostic_probes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Founder view ----------------------------------------------------------
create or replace function public.founder_admin_overview()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'tenants', (select count(distinct user_id) from public.admin_health_checks),
    'failing_checks', coalesce((select count(*) from public.admin_health_checks where status = 'fail'), 0),
    'self_heals_24h', coalesce((select sum(heals_24h) from public.admin_health_checks), 0),
    'open_incidents', coalesce((select count(*) from public.admin_incidents where status <> 'resolved'), 0),
    'deferred_1h', coalesce((
      select count(*) from public.admin_delivery_events
      where state in ('deferred','bounced','rejected') and at > now() - interval '1 hour'
    ), 0),
    'errors_1h', coalesce((
      select count(*) from public.admin_logs where level = 'error' and at > now() - interval '1 hour'
    ), 0),
    'storage_used_bytes', coalesce((
      select sum(used_bytes) from public.admin_storage_snapshots
      where day = (select max(day) from public.admin_storage_snapshots)
    ), 0),
    'worst_tenants', coalesce((
      select jsonb_agg(x) from (
        select user_id::text as tenant,
               count(*) filter (where status = 'fail') as failing,
               count(*) as checks
        from public.admin_health_checks
        group by user_id
        order by failing desc limit 10
      ) x
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.founder_admin_overview() from public;
grant execute on function public.founder_admin_overview() to service_role;

commit;
