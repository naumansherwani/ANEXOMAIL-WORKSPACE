-- ============================================================================
-- ANEXOMAIL — PHASE 48: INBOX STORAGE & QUOTA CONTROL (logical quota)
--
-- Supabase #4 SQL Editor mein poora block paste karo (idempotent + self-healing).
--
-- RULE: quota LOGICAL hai — koi disk pre-allocation nahi. 25GB mailbox ka
-- matlab 25GB reserve karna NAHI hai. Hum sirf 3 number rakhte hain:
--   quota_bytes · used_bytes · remaining_bytes
-- Business Pro = POOLED workspace storage (1TB), har mailbox ko 1TB nahi.
--
-- Storage abstraction: `storage_volumes` — mailbox kisi bhi volume par ho
-- sakta hai (local disk, object storage, storage box). Frontend ko kabhi
-- pata nahi chalta ke data kis server par hai.
--
-- Jimmy / LEO / AI / chat / billing ko yeh block chhoota bhi nahi.
-- ============================================================================

-- ── 0) legacy conflict guard ────────────────────────────────────────────────
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='mailbox_storage')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='mailbox_storage'
               and column_name='used_attachments_bytes') then
    execute 'alter table public.mailbox_storage rename to mailbox_storage_legacy';
  end if;
end $$;

-- ── 1) plan matrix (founder locked) ────────────────────────────────────────
create table if not exists public.storage_plans (
  plan_id            text primary key,
  per_mailbox_bytes  bigint,              -- null = pooled only
  mailbox_limit      int,                 -- null = unlimited
  pooled_bytes       bigint,              -- null = no pool (per-mailbox model)
  max_send_bytes     bigint not null default 26214400,
  updated_at         timestamptz not null default now()
);

insert into public.storage_plans (plan_id, per_mailbox_bytes, mailbox_limit, pooled_bytes, max_send_bytes) values
  ('trial',        1073741824,  1,    null, 26214400),
  ('basic',        5368709120,  3,    null, 26214400),
  ('pro',          10737418240, 5,    null, 26214400),
  ('business',     26843545600, 30,   null, 2147483648),
  ('business_pro', null,        null, 1099511627776, 5368709120)
on conflict (plan_id) do update set
  per_mailbox_bytes = excluded.per_mailbox_bytes,
  mailbox_limit     = excluded.mailbox_limit,
  pooled_bytes      = excluded.pooled_bytes,
  max_send_bytes    = excluded.max_send_bytes,
  updated_at        = now();

-- ── 2) storage abstraction: volumes ────────────────────────────────────────
-- Mailbox kis physical jagah par hai — yeh sirf backend jaanta hai. Nayi
-- capacity add karne ke liye naya row insert karo; quota/UI nahi badalta.
create table if not exists public.storage_volumes (
  id             uuid primary key default gen_random_uuid(),
  name           text not null unique,
  kind           text not null default 'local'
                 check (kind in ('local','storage_box','object','external')),
  endpoint       text,
  capacity_bytes bigint not null,
  used_bytes     bigint not null default 0,
  accepts_new    boolean not null default true,
  created_at     timestamptz not null default now()
);

insert into public.storage_volumes (name, kind, capacity_bytes, accepts_new)
values ('server2-local', 'local', 60000000000, true)
on conflict (name) do nothing;

-- ── 3) per mailbox logical ledger ──────────────────────────────────────────
create table if not exists public.mailbox_storage (
  id                       uuid primary key default gen_random_uuid(),
  workspace_id             uuid not null,
  mailbox                  text not null,
  volume_id                uuid references public.storage_volumes(id),
  -- null = plan default (per_mailbox_bytes). Sirf founder override karta hai.
  quota_override_bytes     bigint,
  used_emails_bytes        bigint not null default 0,
  used_attachments_bytes   bigint not null default 0,
  used_files_bytes         bigint not null default 0,
  reserved_bytes           bigint not null default 0,   -- in-flight uploads
  updated_at               timestamptz not null default now(),
  unique (workspace_id, mailbox)
);
create index if not exists mailbox_storage_ws_idx on public.mailbox_storage(workspace_id);

-- append-only truth trail (kabhi update/delete nahi — sirf insert)
create table if not exists public.storage_events (
  id           bigserial primary key,
  workspace_id uuid not null,
  mailbox      text not null,
  kind         text not null check (kind in ('email','attachment','file','reserve','release','purge')),
  delta_bytes  bigint not null,
  reason       text,
  created_at   timestamptz not null default now()
);
create index if not exists storage_events_mb_idx
  on public.storage_events(workspace_id, mailbox, created_at desc);

-- ── 4) grants (Data API) ───────────────────────────────────────────────────
grant select on public.storage_plans   to authenticated;
grant select on public.mailbox_storage to authenticated;
grant select on public.storage_events  to authenticated;
grant all on public.storage_plans, public.storage_volumes,
             public.mailbox_storage, public.storage_events to service_role;
grant usage, select on sequence public.storage_events_id_seq to service_role;

alter table public.storage_plans   enable row level security;
alter table public.storage_volumes enable row level security;
alter table public.mailbox_storage enable row level security;
alter table public.storage_events  enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public'
                 and tablename='storage_plans' and policyname='plans_read') then
    create policy plans_read on public.storage_plans for select to authenticated using (true);
  end if;
  -- workspace boundary = chat_members (asli membership table). Agar woh na ho
  -- to sirf service_role padhega (backend anyway RPC se aata hai).
  if to_regclass('public.chat_members') is not null
     and not exists (select 1 from pg_policies where schemaname='public'
                     and tablename='mailbox_storage' and policyname='ms_read_own_ws') then
    execute $p$
      create policy ms_read_own_ws on public.mailbox_storage for select to authenticated
        using (exists (
          select 1 from public.chat_members m
           where m.workspace_id = public.mailbox_storage.workspace_id
             and m.user_id = auth.uid()
        ))
    $p$;
  end if;
end $$;

-- ── 5) helpers ─────────────────────────────────────────────────────────────
-- entitlement_state ka key `user_id` hai (workspace_id NAHI). Is liye plan
-- workspace -> owner_user_id -> entitlement_state se resolve hota hai.
-- Founder hamesha business_pro (FOUNDER 100% ACCESS RULE).
create or replace function public.storage_plan_of(_workspace uuid)
returns text language plpgsql stable security definer set search_path = public as $$
declare _owner uuid; _plan text; _is_founder boolean := false;
begin
  if _workspace is null then return 'trial'; end if;

  if to_regclass('public.chat_workspaces') is not null then
    execute 'select owner_user_id from public.chat_workspaces where id = $1'
      into _owner using _workspace;
  end if;
  if _owner is null then return 'trial'; end if;

  if to_regclass('public.founder_accounts') is not null then
    execute 'select exists(select 1 from public.founder_accounts where user_id = $1)'
      into _is_founder using _owner;
    if _is_founder then return 'business_pro'; end if;
  end if;

  if to_regclass('public.entitlement_state') is not null then
    execute 'select plan from public.entitlement_state
              where user_id = $1
                and (active_until is null or active_until > now())
              limit 1'
      into _plan using _owner;
  end if;

  -- AI plans ko pooled (business_pro) storage milti hai.
  if coalesce(_plan,'') in ('ai_pro','ai_business','ai_executive') then
    return 'business_pro';
  end if;
  if _plan is not null and exists (select 1 from public.storage_plans where plan_id = _plan) then
    return _plan;
  end if;
  return 'trial';
end $$;

-- POOLED plan? (business_pro) → pool ka hisaab, warna per-mailbox.
create or replace function public.storage_state(_workspace uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  _plan text; _p record; _pool_used bigint; _out jsonb;
begin
  _plan := public.storage_plan_of(_workspace);
  select * into _p from public.storage_plans where plan_id = _plan;
  if _p is null then
    select * into _p from public.storage_plans where plan_id = 'trial';
  end if;

  select coalesce(sum(used_emails_bytes + used_attachments_bytes + used_files_bytes), 0)
    into _pool_used from public.mailbox_storage where workspace_id = _workspace;

  select jsonb_build_object(
    'plan', _plan,
    'model', case when _p.pooled_bytes is not null then 'pooled' else 'per_mailbox' end,
    'mailbox_limit', _p.mailbox_limit,
    'max_send_bytes', _p.max_send_bytes,
    'pool', case when _p.pooled_bytes is null then null else jsonb_build_object(
        'quota_bytes', _p.pooled_bytes,
        'used_bytes', _pool_used,
        'remaining_bytes', greatest(_p.pooled_bytes - _pool_used, 0),
        'percent', round((_pool_used::numeric / nullif(_p.pooled_bytes,0)) * 100, 1)
      ) end,
    'mailboxes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'mailbox', m.mailbox,
        'quota_bytes', q.quota,
        'used_bytes', q.used,
        'remaining_bytes', greatest(q.quota - q.used, 0),
        'percent', round((q.used::numeric / nullif(q.quota,0)) * 100, 1),
        'level', case
                   when q.used >= q.quota then 'full'
                   when q.used::numeric >= q.quota * 0.9 then 'critical'
                   when q.used::numeric >= q.quota * 0.8 then 'warning'
                   else 'ok' end,
        'breakdown', jsonb_build_object(
          'emails_bytes', m.used_emails_bytes,
          'attachments_bytes', m.used_attachments_bytes,
          'files_bytes', m.used_files_bytes),
        'reserved_bytes', m.reserved_bytes,
        'updated_at', m.updated_at
      ) order by q.used desc)
      from public.mailbox_storage m
      cross join lateral (
        select coalesce(m.quota_override_bytes, _p.per_mailbox_bytes, _p.pooled_bytes) as quota,
               m.used_emails_bytes + m.used_attachments_bytes + m.used_files_bytes as used
      ) q
      where m.workspace_id = _workspace
    ), '[]'::jsonb)
  ) into _out;

  return _out;
end $$;

-- ── 6) enforcement: allow / reject with a human reason ─────────────────────
-- Backend har incoming mail aur har upload se PEHLE yeh call karta hai.
create or replace function public.storage_can_accept(
  _workspace uuid, _mailbox text, _bytes bigint, _kind text default 'attachment')
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  _plan text; _p record; _used bigint; _quota bigint; _pool_used bigint;
begin
  _plan := public.storage_plan_of(_workspace);
  select * into _p from public.storage_plans where plan_id = _plan;
  if _p is null then select * into _p from public.storage_plans where plan_id='trial'; end if;

  if _kind <> 'email' and _bytes > _p.max_send_bytes then
    return jsonb_build_object('allowed', false, 'code', 'file_too_large',
      'reason', 'This file is larger than your plan allows for a single transfer.',
      'limit_bytes', _p.max_send_bytes);
  end if;

  select coalesce(used_emails_bytes + used_attachments_bytes + used_files_bytes + reserved_bytes, 0),
         coalesce(quota_override_bytes, _p.per_mailbox_bytes, _p.pooled_bytes)
    into _used, _quota
  from public.mailbox_storage
  where workspace_id = _workspace and mailbox = _mailbox;

  if _used is null then _used := 0; end if;
  if _quota is null then _quota := coalesce(_p.per_mailbox_bytes, _p.pooled_bytes); end if;

  if _p.pooled_bytes is not null then
    select coalesce(sum(used_emails_bytes + used_attachments_bytes + used_files_bytes + reserved_bytes), 0)
      into _pool_used from public.mailbox_storage where workspace_id = _workspace;
    if _pool_used + _bytes > _p.pooled_bytes then
      return jsonb_build_object('allowed', false, 'code', 'pool_full',
        'reason', 'Your workspace storage pool is full. Free up space or add capacity.',
        'used_bytes', _pool_used, 'quota_bytes', _p.pooled_bytes);
    end if;
    return jsonb_build_object('allowed', true, 'code', 'ok',
      'used_bytes', _pool_used, 'quota_bytes', _p.pooled_bytes);
  end if;

  if _used + _bytes > _quota then
    return jsonb_build_object('allowed', false, 'code', 'mailbox_full',
      'reason', format('Mailbox %s is full (%s of %s used). Existing email stays readable; new items are held until space is freed.',
                       _mailbox, pg_size_pretty(_used), pg_size_pretty(_quota)),
      'used_bytes', _used, 'quota_bytes', _quota,
      'remaining_bytes', greatest(_quota - _used, 0));
  end if;

  return jsonb_build_object('allowed', true, 'code', 'ok',
    'used_bytes', _used, 'quota_bytes', _quota,
    'remaining_bytes', greatest(_quota - _used - _bytes, 0));
end $$;

-- reserve (upload shuru) → commit (upload complete) → release (fail/cancel)
create or replace function public.storage_reserve(
  _workspace uuid, _mailbox text, _bytes bigint, _kind text default 'attachment')
returns jsonb language plpgsql security definer set search_path = public as $$
declare _check jsonb; _vol uuid;
begin
  _check := public.storage_can_accept(_workspace, _mailbox, _bytes, _kind);
  if not (_check->>'allowed')::boolean then return _check; end if;

  select id into _vol from public.storage_volumes
   where accepts_new and capacity_bytes - used_bytes > _bytes
   order by capacity_bytes - used_bytes desc limit 1;

  insert into public.mailbox_storage (workspace_id, mailbox, volume_id, reserved_bytes)
  values (_workspace, _mailbox, _vol, _bytes)
  on conflict (workspace_id, mailbox) do update
    set reserved_bytes = public.mailbox_storage.reserved_bytes + _bytes,
        volume_id = coalesce(public.mailbox_storage.volume_id, _vol),
        updated_at = now();

  insert into public.storage_events (workspace_id, mailbox, kind, delta_bytes, reason)
  values (_workspace, _mailbox, 'reserve', _bytes, _kind);

  return jsonb_build_object('allowed', true, 'code', 'reserved', 'bytes', _bytes);
end $$;

create or replace function public.storage_commit(
  _workspace uuid, _mailbox text, _bytes bigint, _kind text,
  _was_reserved boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  insert into public.mailbox_storage (workspace_id, mailbox) values (_workspace, _mailbox)
  on conflict (workspace_id, mailbox) do nothing;

  update public.mailbox_storage set
    used_emails_bytes      = used_emails_bytes      + case when _kind='email' then _bytes else 0 end,
    used_attachments_bytes = used_attachments_bytes + case when _kind='attachment' then _bytes else 0 end,
    used_files_bytes       = used_files_bytes       + case when _kind='file' then _bytes else 0 end,
    reserved_bytes = greatest(reserved_bytes - case when _was_reserved then _bytes else 0 end, 0),
    updated_at = now()
  where workspace_id = _workspace and mailbox = _mailbox;

  update public.storage_volumes v set used_bytes = v.used_bytes + _bytes
   where v.id = (select volume_id from public.mailbox_storage
                  where workspace_id=_workspace and mailbox=_mailbox);

  insert into public.storage_events (workspace_id, mailbox, kind, delta_bytes, reason)
  values (_workspace, _mailbox, _kind, _bytes, 'commit');

  return public.storage_can_accept(_workspace, _mailbox, 0, _kind);
end $$;

create or replace function public.storage_release(
  _workspace uuid, _mailbox text, _bytes bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.mailbox_storage
     set reserved_bytes = greatest(reserved_bytes - _bytes, 0), updated_at = now()
   where workspace_id = _workspace and mailbox = _mailbox;
  insert into public.storage_events (workspace_id, mailbox, kind, delta_bytes, reason)
  values (_workspace, _mailbox, 'release', -_bytes, 'cancelled');
end $$;

-- delete/purge → space wapas
create or replace function public.storage_purge(
  _workspace uuid, _mailbox text, _bytes bigint, _kind text default 'attachment')
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.mailbox_storage set
    used_emails_bytes      = greatest(used_emails_bytes      - case when _kind='email' then _bytes else 0 end, 0),
    used_attachments_bytes = greatest(used_attachments_bytes - case when _kind='attachment' then _bytes else 0 end, 0),
    used_files_bytes       = greatest(used_files_bytes       - case when _kind='file' then _bytes else 0 end, 0),
    updated_at = now()
  where workspace_id = _workspace and mailbox = _mailbox;

  insert into public.storage_events (workspace_id, mailbox, kind, delta_bytes, reason)
  values (_workspace, _mailbox, 'purge', -_bytes, _kind);

  return public.storage_can_accept(_workspace, _mailbox, 0, _kind);
end $$;

grant execute on function public.storage_state(uuid),
  public.storage_can_accept(uuid, text, bigint, text) to authenticated;
grant execute on function public.storage_state(uuid),
  public.storage_can_accept(uuid, text, bigint, text),
  public.storage_reserve(uuid, text, bigint, text),
  public.storage_commit(uuid, text, bigint, text, boolean),
  public.storage_release(uuid, text, bigint),
  public.storage_purge(uuid, text, bigint, text),
  public.storage_plan_of(uuid) to service_role;

-- ── 7) verify ──────────────────────────────────────────────────────────────
select plan_id, pg_size_pretty(per_mailbox_bytes) per_mailbox, mailbox_limit,
       pg_size_pretty(pooled_bytes) pool, pg_size_pretty(max_send_bytes) max_send
from public.storage_plans order by coalesce(per_mailbox_bytes, pooled_bytes);
