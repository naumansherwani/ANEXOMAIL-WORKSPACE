
-- E69 — identity vault: local mirror feed + health report + payment sweep source + deny-after-signup flag
--   * identity_bans.changed_at + NOTIFY: Rust/Bun apni local copy (mirror) isi feed se rakhte hain; RPC down ho to bhi check chalta hai
--   * identity_ban_feed: sirf mazboot nishan, (changed_at,id) cursor, active + hataye hue dono (mirror se nikalne ke liye)
--   * identity_health: har process (bun/rust) apni halat likhta hai; founder overview mein ek line (alert)
--   * identity_payment_pending: polar_subscriptions se SIRF PADHTA hai (webhook ko haath nahi); cursor identity_cursors mein
--   * identity_register_raw: signup ke baad deny mile (outbox retry / payment) => founder queue mein 'suspicious'
-- Rule 38 (advanced), 42 (editor compat), 43 (RLS ON), 44 (server se). Idempotent.
set lock_timeout = '3s';
set statement_timeout = '60s';

-- ---- 1. changed_at + NOTIFY ----------------------------------------------------------------------------------------------------
alter table public.identity_bans add column if not exists changed_at timestamptz not null default now();
create index if not exists identity_bans_changed_idx on public.identity_bans (changed_at, id);

create or replace function public.identity_bans_touch()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  new.changed_at := clock_timestamp();
  return new;
end $$;

create or replace function public.identity_bans_notify()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  perform pg_notify('identity_ban', '');
  return null;
end $$;

drop trigger if exists identity_bans_touch_bi on public.identity_bans;
create trigger identity_bans_touch_bi before insert or update on public.identity_bans
  for each row execute function public.identity_bans_touch();
drop trigger if exists identity_bans_notify_ai on public.identity_bans;
create trigger identity_bans_notify_ai after insert or update or delete on public.identity_bans
  for each statement execute function public.identity_bans_notify();

-- ---- 2. feed (mirror ke liye) -----------------------------------------------------------------------------------------------------
-- p_since NULL => poora active set; warna (changed_at,id) ke baad ki har tabdeeli (hataye hue ban bhi, a=false)
create or replace function public.identity_ban_feed(p_since timestamptz default null, p_since_id bigint default 0, p_limit integer default 5000)
returns jsonb language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare lim integer := least(greatest(coalesce(p_limit, 5000), 1), 20000); rows_j jsonb; last_t timestamptz; last_id bigint; n integer;
begin
  with pick as (
    select b.id, b.kind, encode(b.hmac, 'hex') as h, b.changed_at,
           (b.lifted_at is null and (b.expires_at is null or b.expires_at > now())) as a,
           case when b.expires_at is null then null else extract(epoch from b.expires_at)::bigint end as e
      from public.identity_bans b
     where public.identity_kind_strong(b.kind)
       and ((p_since is null and b.lifted_at is null and (b.expires_at is null or b.expires_at > now()))
         or (p_since is not null and (b.changed_at, b.id) > (p_since, coalesce(p_since_id, 0))))
     order by b.changed_at, b.id
     limit lim + 1),
  numbered as (select p.*, row_number() over (order by p.changed_at, p.id) as rn from pick p),
  page as (select * from numbered where rn <= lim)
  select (select jsonb_agg(jsonb_build_object('k', kind, 'h', h, 'a', a, 'e', e) order by changed_at, id) from page),
         (select changed_at from page order by rn desc limit 1),
         (select id from page order by rn desc limit 1),
         (select count(*) from numbered)
    into rows_j, last_t, last_id, n;
  return jsonb_build_object('rows', coalesce(rows_j, '[]'::jsonb), 'cursor_t', last_t, 'cursor_id', coalesce(last_id, 0),
                            'more', n > lim, 'full', p_since is null, 'at', now());
end $$;

-- ---- 3. health ---------------------------------------------------------------------------------------------------------------------
create table if not exists public.identity_health (
  source       text primary key check (source in ('bun', 'rust')),
  reported_at  timestamptz not null default now(),
  outbox_pending integer not null default 0 check (outbox_pending >= 0),
  check_failures_1h integer not null default 0 check (check_failures_1h >= 0),
  mirror_size  integer not null default 0 check (mirror_size >= 0),
  mirror_age_s integer not null default 0 check (mirror_age_s >= 0),
  mode         text not null default 'mirror' check (mode in ('mirror', 'db_only', 'closed'))
);
alter table public.identity_health enable row level security;
revoke all on table public.identity_health from public, anon, authenticated;
grant select, insert, update, delete on table public.identity_health to service_role;
do $$
begin
  if not exists (select 1 from pg_policy p where p.polrelid = 'public.identity_health'::regclass and p.polname = 'ax_service_role_only') then
    create policy ax_service_role_only on public.identity_health for all to service_role using (true) with check (true);
  end if;
end $$;

create or replace function public.identity_health_report(p_source text, p_outbox integer, p_failures integer, p_mirror_size integer, p_mirror_age integer, p_mode text)
returns void language sql volatile set search_path = pg_catalog, public as $$
  insert into public.identity_health (source, reported_at, outbox_pending, check_failures_1h, mirror_size, mirror_age_s, mode)
  values (p_source, now(), greatest(coalesce(p_outbox, 0), 0), greatest(coalesce(p_failures, 0), 0), greatest(coalesce(p_mirror_size, 0), 0),
          greatest(coalesce(p_mirror_age, 0), 0), coalesce(p_mode, 'mirror'))
  on conflict (source) do update set reported_at = now(), outbox_pending = excluded.outbox_pending, check_failures_1h = excluded.check_failures_1h,
    mirror_size = excluded.mirror_size, mirror_age_s = excluded.mirror_age_s, mode = excluded.mode
$$;

-- ---- 4. payment sweep source (sirf padhta hai) + cursor ----------------------------------------------------------------------------
create table if not exists public.identity_cursors (
  name text primary key,
  ts   timestamptz not null default 'epoch',
  id   bigint not null default 0
);
alter table public.identity_cursors enable row level security;
revoke all on table public.identity_cursors from public, anon, authenticated;
grant select, insert, update, delete on table public.identity_cursors to service_role;
do $$
begin
  if not exists (select 1 from pg_policy p where p.polrelid = 'public.identity_cursors'::regclass and p.polname = 'ax_service_role_only') then
    create policy ax_service_role_only on public.identity_cursors for all to service_role using (true) with check (true);
  end if;
end $$;

create or replace function public.identity_cursor_get(p_name text)
returns timestamptz language sql stable set search_path = pg_catalog, public as $$
  select coalesce((select ts from public.identity_cursors where name = p_name), 'epoch'::timestamptz)
$$;
create or replace function public.identity_cursor_set(p_name text, p_ts timestamptz)
returns void language sql volatile set search_path = pg_catalog, public as $$
  insert into public.identity_cursors (name, ts) values (p_name, p_ts)
  on conflict (name) do update set ts = greatest(public.identity_cursors.ts, excluded.ts)
$$;

create or replace function public.identity_payment_pending(p_after timestamptz default 'epoch', p_limit integer default 200)
returns table (user_id uuid, ref text, at timestamptz)
language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '10s' as $$
begin
  if to_regclass('public.polar_subscriptions') is null then return; end if;
  return query execute
    'select s.user_id, s.polar_customer_id, s.updated_at from public.polar_subscriptions s
      where s.user_id is not null and s.polar_customer_id is not null and s.updated_at > $1
        and exists (select 1 from auth.users u where u.id = s.user_id)
      order by s.updated_at limit $2'
    using coalesce(p_after, 'epoch'::timestamptz), least(greatest(coalesce(p_limit, 200), 1), 1000);
end $$;

-- ---- 5. register: signup ke baad deny/review => founder queue (hash wala raasta, outbox retry bhi isi se) -----------------------------
create or replace function public.identity_register_signals(p_account uuid, p_signals jsonb)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare r jsonb; why text;
begin
  r := public.identity_register(p_account, p_signals);
  if r ->> 'decision' in ('review', 'deny') and to_regclass('public.account_integrity') is not null then
    why := case when r ->> 'decision' = 'deny' then 'matched a blocked identity after sign-up' else coalesce(r ->> 'reason', 'review') end;
    insert into public.account_integrity (user_id, state, reason, evidence)
    values (p_account, 'suspicious', 'identity vault: ' || why, jsonb_build_object('source', 'identity_vault', 'decision', r ->> 'decision', 'reason', why))
    on conflict (user_id) do update
      set state = case when public.account_integrity.state = 'clean' then 'suspicious' else public.account_integrity.state end,
          reason = case when public.account_integrity.state = 'clean' then excluded.reason else public.account_integrity.reason end,
          evidence = case when public.account_integrity.state = 'clean' then excluded.evidence else public.account_integrity.evidence end,
          updated_at = now();
  end if;
  return r;
end $$;

create or replace function public.identity_register_raw(p_account uuid, p_email text, p_recovery text, p_device_key text, p_shape text, p_network text, p_key text)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare s jsonb := public.identity_signals_raw(p_email, p_recovery, p_device_key, p_shape, p_network, p_key);
begin
  if jsonb_array_length(s) = 0 then return jsonb_build_object('decision', 'allow', 'registered', 0); end if;
  return public.identity_register_signals(p_account, s);
end $$;

-- ---- 6. overview: health + alert ----------------------------------------------------------------------------------------------------
create or replace function public.identity_admin_overview(p_actor uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare h jsonb; alert boolean;
begin
  if not public.safety_can_review(p_actor) then return jsonb_build_object('allowed', false); end if;
  select coalesce(jsonb_agg(jsonb_build_object('source', source, 'age_s', extract(epoch from now() - reported_at)::int, 'outbox_pending', outbox_pending,
                  'check_failures_1h', check_failures_1h, 'mirror_size', mirror_size, 'mirror_age_s', mirror_age_s, 'mode', mode)), '[]'::jsonb),
         coalesce(bool_or(outbox_pending > 0 or check_failures_1h >= 5 or mode <> 'mirror' or mirror_age_s > 900 or reported_at < now() - interval '30 minutes'), false)
    into h, alert from public.identity_health;
  return jsonb_build_object(
    'allowed', true,
    'bans_active', (select count(*) from public.identity_bans where lifted_at is null and (expires_at is null or expires_at > now())),
    'bans_by_reason', coalesce((select jsonb_object_agg(reason, c) from (select reason, count(*) c from public.identity_bans where lifted_at is null and (expires_at is null or expires_at > now()) group by reason) x), '{}'::jsonb),
    'bans_permanent', (select count(*) from public.identity_bans where lifted_at is null and expires_at is null),
    'bans_expiring_30d', (select count(*) from public.identity_bans where lifted_at is null and expires_at between now() and now() + interval '30 days'),
    'signups_denied_30d', (select count(*) from public.identity_vault_audit where event = 'deny' and at > now() - interval '30 days' and detail ? 'matched'),
    'signups_review_30d', (select count(*) from public.identity_vault_audit where event = 'review' and at > now() - interval '30 days'),
    'signals_total', (select count(*) from public.identity_signals),
    'health', h, 'health_alert', alert,
    'appeals', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'created_at', a.created_at, 'contact', a.contact, 'statement', a.statement) order by a.created_at)
                           from public.identity_signup_appeals a where a.state = 'new'), '[]'::jsonb),
    'appeals_open', (select count(*) from public.identity_signup_appeals where state = 'new'));
end $$;

-- ---- 7. privileges (Rule 43) -------------------------------------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'public.identity_bans_touch()', 'public.identity_bans_notify()', 'public.identity_ban_feed(timestamptz,bigint,integer)',
    'public.identity_health_report(text,integer,integer,integer,integer,text)', 'public.identity_cursor_get(text)', 'public.identity_cursor_set(text,timestamptz)',
    'public.identity_payment_pending(timestamptz,integer)', 'public.identity_register_raw(uuid,text,text,text,text,text,text)', 'public.identity_register_signals(uuid,jsonb)',
    'public.identity_admin_overview(uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on function public.identity_ban_feed(timestamptz,bigint,integer) is 'Change feed of strong-signal blocks for the Rust/Bun local mirror (E69). Hashes only, service_role only.';
comment on table public.identity_health is 'One row per process (bun/rust): outbox size, check failures, mirror size/age (E69). Drives the founder overview alert.';

do $$
begin
  if (select count(*) from pg_class where oid in ('public.identity_health'::regclass, 'public.identity_cursors'::regclass) and relrowsecurity) <> 2 then
    raise exception 'E69 POST-CONDITION: RLS ON nahi' using errcode = 'AX069';
  end if;
  if has_function_privilege('authenticated', 'public.identity_ban_feed(timestamptz,bigint,integer)', 'execute') then
    raise exception 'E69 POST-CONDITION: authenticated ko feed execute mil gaya' using errcode = 'AX069';
  end if;
end $$;
