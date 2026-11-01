-- E113 — FOUNDER SETTINGS S2 (master order step 6): TIME MACHINE + DRIFT + SCHEDULED CHANGES WITH AUTO-ROLLBACK + EXPLAIN / BLAST RADIUS.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), security definer RPCs (service_role only, search_path + statement_timeout pinned), on E102 (founder_audit chain),
--             E107 (Merkle ledger), E108 (founder_settings + append-only founder_settings_history). Rust (axum) calls these; the browser never does.
-- What this file adds (nothing here touches the awam user settings tables — FC18 / Rule 35):
--   1) TIME MACHINE   — founder_settings_history_list (every version, who/when/from/to, audit seq, reverted?, can_undo?)
--                       founder_setting_revert (one-click undo of any version; written through the same E108 door, so it is history + audit again; each version can be undone once)
--                       founder_settings_at / founder_settings_diff (point-in-time replay of the whole settings object, and what changed between two moments)
--                       founder_settings_replay_check (history replay must equal the live table — a tamper / drift detector for the history itself)
--                       founder_settings_timeline (one merged feed: changes, reverts, scheduled events)
--   2) DRIFT          — founder_settings_baseline (the recommended safe values, one table) + founder_settings_drift (score 0..100, aligned / loose / risky per item).
--                       Sources are REAL: founder settings that matter (name, home city) AND the live Merkle checkpoint policy + checkpoint lag from E107. No invented items.
--   3) SCHEDULE       — founder_settings_schedule (state machine guarded by trigger) + create / cancel / confirm / tick / list / preview.
--                       "Apply at T, roll back after N minutes unless I confirm" — the founder's dead-man switch. The tick (Rust, every minute) applies due changes and rolls back
--                       the ones that were not confirmed; if the founder changed the value again meanwhile the rollback steps aside (state superseded), it never overwrites a newer choice.
--   4) EXPLAIN/BLAST  — founder_settings_info (plain words, example, trade-off, surfaces touched) + founder_setting_explain + founder_setting_blast (real counts: approved devices,
--                       pending schedules, history size, last change).
--   5) PULSE          — founder_settings_pulse (24h/7d changes, reverts, pending schedules, drift score, replay check) for the Dashboard; live source registered.
--   6) selftest / selftest2 (rolled back, E104 standard) + crosscheck. CHECK_E113.sql has 14 checks.
-- Rules kept: every write = history + founder_audit in ONE transaction (through founder_setting_set / founder_audit_append); append-only logs; no mock data — a setting with
-- no stored value says "default". Polar :3400 NO-TOUCH. Safe to run again (create if not exists / create or replace / upsert of read-only registries).
-- Avatar note: personal.avatar history keeps only a SHA-256 (E108 design). It is shown in the Time machine as "photo changed" and cannot be reverted from history (re-upload instead).

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = pg_catalog, public, extensions;

-- ==============================================================================================================================
-- 0) prerequisites — fail loudly, never half-install
-- ==============================================================================================================================
do $$
begin
  if to_regclass('public.founder_accounts') is null or to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then
    raise exception 'E113: run E102 first (founder_accounts / founder_audit_append)';
  end if;
  if to_regclass('public.founder_settings') is null or to_regclass('public.founder_settings_history') is null
     or to_regprocedure('public.founder_setting_set(uuid,text,jsonb)') is null or to_regprocedure('public._founder_setting_valid(text,jsonb)') is null then
    raise exception 'E113: run E108 first (founder_settings / founder_settings_history / founder_setting_set)';
  end if;
  if to_regclass('public.founder_audit_merkle_policy') is null or to_regclass('public.founder_audit_checkpoints') is null then
    raise exception 'E113: run E107 first (Merkle policy + checkpoints) — drift reads the live checkpoint policy';
  end if;
  if to_regclass('public.founder_devices') is null or to_regclass('public.founder_live_sources') is null or to_regprocedure('public._fa_immutable()') is null then
    raise exception 'E113: run E102 / E109 first (founder_devices / founder_live_sources / _fa_immutable)';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_settings_s2:ddl', 0));
end $$;

-- ==============================================================================================================================
-- 1) tables
-- ==============================================================================================================================
-- 1a) which history version was undone, by which action. Append-only. One version can be undone once (unique target).
create table if not exists public.founder_settings_revert_log (
  id                bigint generated always as identity primary key,
  user_id           uuid   not null references public.founder_accounts(user_id) on delete cascade,
  key               text   not null,
  target_history_id bigint not null unique references public.founder_settings_history(id),
  result_history_id bigint references public.founder_settings_history(id),
  audit_seq         bigint not null,
  reason            text   not null check (length(btrim(reason)) between 8 and 300),
  created_at        timestamptz not null default now()
);
create index if not exists founder_settings_revert_log_idx on public.founder_settings_revert_log (user_id, created_at desc);
alter table public.founder_settings_revert_log enable row level security;
revoke all on public.founder_settings_revert_log from public, anon, authenticated;
grant select, insert on public.founder_settings_revert_log to service_role;

-- 1b) scheduled changes
create table if not exists public.founder_settings_schedule (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid   not null references public.founder_accounts(user_id) on delete cascade,
  key                text   not null check (key in ('personal.display_name','personal.home','appearance.graphics','appearance.sidebar_slim')),
  new_value          jsonb  not null,                                  -- JSON null = "back to default"
  apply_at           timestamptz not null,
  rollback_minutes   integer check (rollback_minutes between 5 and 10080),
  reason             text   not null check (length(btrim(reason)) between 8 and 300),
  state              text   not null default 'scheduled'
                     check (state in ('scheduled','applied','confirmed','rolled_back','cancelled','superseded','failed')),
  created_at         timestamptz not null default now(),
  applied_at         timestamptz,
  prev_value         jsonb,                                            -- value before the change; SQL null = it was the default
  applied_history_id bigint references public.founder_settings_history(id),
  rollback_due_at    timestamptz,
  finished_at        timestamptz,
  note               text check (note is null or length(note) <= 300),
  constraint founder_settings_schedule_octets check (octet_length(new_value::text) <= 4000),
  constraint founder_settings_schedule_window check (apply_at > created_at)
);
create index if not exists founder_settings_schedule_due_idx on public.founder_settings_schedule (apply_at) where state = 'scheduled';
create index if not exists founder_settings_schedule_rb_idx on public.founder_settings_schedule (rollback_due_at) where state = 'applied' and rollback_due_at is not null;
create index if not exists founder_settings_schedule_user_idx on public.founder_settings_schedule (user_id, created_at desc);
alter table public.founder_settings_schedule enable row level security;
revoke all on public.founder_settings_schedule from public, anon, authenticated;
grant select, insert, update on public.founder_settings_schedule to service_role;

-- 1c) read-only registries (upserted by this file; service_role can only read)
create table if not exists public.founder_settings_info (
  key         text primary key,
  label       text not null,
  plain       text not null,
  example     text not null,
  tradeoff    text,
  surfaces    text[] not null,
  severity    text not null check (severity in ('low','medium','high')),
  reversible  boolean not null default true,
  schedulable boolean not null default true
);
alter table public.founder_settings_info enable row level security;
revoke all on public.founder_settings_info from public, anon, authenticated;
grant select on public.founder_settings_info to service_role;

create table if not exists public.founder_settings_baseline (
  key         text primary key,
  source      text not null check (source in ('setting','policy')),
  rule        text not null check (rule in ('set','max')),
  recommended numeric,
  label       text not null,
  why         text not null,
  sort        integer not null default 100,
  constraint founder_settings_baseline_rule_ok check ((rule = 'set' and recommended is null) or (rule = 'max' and recommended is not null and recommended > 0))
);
alter table public.founder_settings_baseline enable row level security;
revoke all on public.founder_settings_baseline from public, anon, authenticated;
grant select on public.founder_settings_baseline to service_role;

comment on table public.founder_settings_revert_log is 'E113: which settings-history version was undone (append-only). One version can be undone once.';
comment on table public.founder_settings_schedule is 'E113: scheduled founder setting changes with optional auto-rollback. State machine guarded by trigger founder_settings_schedule_guard.';
comment on table public.founder_settings_info is 'E113: plain-language Explain / Blast-radius text per founder setting (read-only registry).';
comment on table public.founder_settings_baseline is 'E113: recommended safe values that Drift measures against (read-only registry). Policy rows read the live Merkle checkpoint policy of E107.';

-- ==============================================================================================================================
-- 2) guards: append-only logs + schedule state machine
-- ==============================================================================================================================
do $$
begin
  drop trigger if exists founder_settings_revert_log_no_upd on public.founder_settings_revert_log;
  create trigger founder_settings_revert_log_no_upd before update or delete on public.founder_settings_revert_log for each row execute function public._fa_immutable();
  drop trigger if exists founder_settings_revert_log_no_trunc on public.founder_settings_revert_log;
  create trigger founder_settings_revert_log_no_trunc before truncate on public.founder_settings_revert_log for each statement execute function public._fa_immutable();
  drop trigger if exists founder_settings_schedule_no_trunc on public.founder_settings_schedule;
  create trigger founder_settings_schedule_no_trunc before truncate on public.founder_settings_schedule for each statement execute function public._fa_immutable();
end $$;

create or replace function public._fs_schedule_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'schedule rows are never deleted' using errcode = '42501'; end if;
  if new.id <> old.id or new.user_id <> old.user_id or new.key <> old.key or new.new_value <> old.new_value or new.apply_at <> old.apply_at
     or new.rollback_minutes is distinct from old.rollback_minutes or new.reason <> old.reason or new.created_at <> old.created_at then
    raise exception 'schedule row: the request itself is fixed once created' using errcode = '42501';
  end if;
  if old.state in ('confirmed','rolled_back','cancelled','superseded','failed') then
    raise exception 'schedule row is final (%)', old.state using errcode = '42501';
  end if;
  if new.state is distinct from old.state then
    if not ((old.state = 'scheduled' and new.state in ('applied','confirmed','cancelled','failed'))
         or (old.state = 'applied'   and new.state in ('confirmed','rolled_back','superseded','failed'))) then
      raise exception 'illegal schedule transition % -> %', old.state, new.state using errcode = '42501';
    end if;
    if new.finished_at is null and new.state not in ('applied') then new.finished_at := now(); end if;
  end if;
  return new;
end $$;
revoke all on function public._fs_schedule_guard() from public, anon, authenticated;
drop trigger if exists founder_settings_schedule_guard on public.founder_settings_schedule;
create trigger founder_settings_schedule_guard before update or delete on public.founder_settings_schedule for each row execute function public._fs_schedule_guard();

-- helper for the selftests: true when the statement raises (swallows the error). Not granted to anyone.
create or replace function public._fs_fails(p_sql text) returns boolean language plpgsql set search_path = pg_catalog, public, extensions as $$
begin execute p_sql; return false; exception when others then return true; end $$;
revoke all on function public._fs_fails(text) from public, anon, authenticated;

-- ==============================================================================================================================
-- 3) registries (real text, real recommended values)
-- ==============================================================================================================================
insert into public.founder_settings_info (key, label, plain, example, tradeoff, surfaces, severity, reversible, schedulable) values
 ('personal.display_name', 'Display name',
  'The name shown in your greeting, your account menu and the activity records.',
  'Set it to "Nauman" and the dashboard greets you as Nauman.',
  'Short names read better; the full legal name stays on your account.',
  array['Dashboard greeting','Account menu','Profile page'], 'low', true, true),
 ('personal.avatar', 'Profile photo',
  'Your profile photo, stored on your founder account only (not shared with the public site).',
  'Upload a square photo and it appears in the account menu on every approved device.',
  'Only a fingerprint of the photo is kept in history, so an old photo cannot be restored from the Time machine; upload it again instead.',
  array['Account menu','Profile page'], 'low', false, false),
 ('personal.home', 'Home city',
  'The city your greeting, clock and sunset-based day part follow. If it is not set, the city of the device is used.',
  'Home city Lahore: the evening greeting switches at Lahore sunset, not at the device''s sunset.',
  'Travelling? A fixed home city keeps the greeting steady; leave it unset to follow the device.',
  array['Dashboard greeting','World clock','Day-part theme'], 'low', true, true),
 ('appearance.graphics', 'Graphics',
  'Turns the aurora and 3D effects on or off for your account on every approved device.',
  'Off on a slow laptop: the dashboard keeps all data and loses only the animation.',
  'Off is lighter on battery; on is the full cinematic look.',
  array['Aurora background','3D scenes','Ambient edge'], 'low', true, true),
 ('appearance.sidebar_slim', 'Compact sidebar',
  'Starts the left sidebar in its slim, icons-only state.',
  'On: more room for the page; hover or click to open the full labels.',
  'Icons-only is tidy but hides the section names.',
  array['Sidebar'], 'low', true, true)
on conflict (key) do update set label = excluded.label, plain = excluded.plain, example = excluded.example, tradeoff = excluded.tradeoff,
  surfaces = excluded.surfaces, severity = excluded.severity, reversible = excluded.reversible, schedulable = excluded.schedulable;

insert into public.founder_settings_baseline (key, source, rule, recommended, label, why, sort) values
 ('personal.display_name', 'setting', 'set', null, 'Display name is set', 'Your name appears in the greeting and in who-did-what records; without it the account email is shown.', 10),
 ('personal.home',         'setting', 'set', null, 'Home city is set', 'Greeting, clock and sunset follow the home city; unset, they follow whichever device you open.', 20),
 ('audit.merkle.every_rows',    'policy', 'max', 50,   'Ledger seal interval (entries)', 'The ledger is sealed every N new entries. Above 50 the unsealed tail grows; above 500 a long stretch stays unproven.', 30),
 ('audit.merkle.warn_lag_rows', 'policy', 'max', 200,  'Ledger seal warning lag (entries)', 'You are warned when this many entries are unsealed. A higher value hides a growing unsealed tail.', 40),
 ('audit.merkle.fail_lag_rows', 'policy', 'max', 2000, 'Ledger seal failure lag (entries)', 'The ledger card turns red at this lag. A higher value lets a very long tail stay unsealed before anything shouts.', 50)
on conflict (key) do update set source = excluded.source, rule = excluded.rule, recommended = excluded.recommended, label = excluded.label, why = excluded.why, sort = excluded.sort;

-- ==============================================================================================================================
-- 4) shared helpers (pure / read-only)
-- ==============================================================================================================================
create or replace function public._fs_ms(p_ts timestamptz) returns bigint language sql immutable set search_path = pg_catalog as $$
  select (extract(epoch from p_ts) * 1000)::bigint
$$;

create or replace function public._fs_hash(p_v jsonb) returns text language sql immutable set search_path = pg_catalog, public, extensions as $$
  select case when p_v is null then null else encode(digest(p_v::text, 'sha256'), 'hex') end
$$;

create or replace function public._fs_assert_founder(p_uid uuid) returns void language plpgsql stable set search_path = pg_catalog, public as $$
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'not a founder' using errcode = '42501'; end if;
end $$;

-- drift score: aligned = 1 point, loose = half, risky = none; 100 when there is nothing to measure is never returned (always >= 1 item)
create or replace function public._fs_drift_score(p_aligned integer, p_loose integer, p_risky integer) returns integer language sql immutable set search_path = pg_catalog as $$
  select case when p_aligned + p_loose + p_risky <= 0 then 100
              else round(100.0 * (p_aligned + 0.5 * p_loose) / (p_aligned + p_loose + p_risky))::integer end
$$;

-- the live value of one founder setting (SQL null = default / not stored)
create or replace function public._fs_current(p_uid uuid, p_key text) returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select value from public.founder_settings where user_id = p_uid and key = p_key
$$;

-- newest history row id for (user, key) — used right after a write inside the same transaction
create or replace function public._fs_last_history_id(p_uid uuid, p_key text) returns bigint language sql stable set search_path = pg_catalog, public as $$
  select max(id) from public.founder_settings_history where user_id = p_uid and key = p_key
$$;

-- which audit row belongs to a history row: same actor/action/from/to, first one at or after the change, within 60s
create or replace function public._fs_audit_seq_for(p_uid uuid, p_key text, p_old_hash text, p_new_hash text, p_at timestamptz) returns bigint
language sql stable set search_path = pg_catalog, public as $$
  select a.seq from public.founder_audit a
   where a.actor = p_uid and a.action = 'settings.' || p_key
     and a.meta ->> 'from' is not distinct from left(coalesce(p_old_hash, 'default'), 12)
     and a.meta ->> 'to'   is not distinct from left(coalesce(p_new_hash, 'default'), 12)
     and a.ts_ms >= public._fs_ms(p_at) - 1000 and a.ts_ms <= public._fs_ms(p_at) + 60000
   order by a.ts_ms asc, a.seq asc limit 1
$$;

revoke all on function public._fs_ms(timestamptz), public._fs_hash(jsonb), public._fs_assert_founder(uuid), public._fs_drift_score(integer, integer, integer),
  public._fs_current(uuid, text), public._fs_last_history_id(uuid, text), public._fs_audit_seq_for(uuid, text, text, text, timestamptz) from public, anon, authenticated;

-- ==============================================================================================================================
-- 5) TIME MACHINE
-- ==============================================================================================================================
-- 5a) every version, newest first. keyset paging with before_id. Avatar values are never exposed (hash-only).
create or replace function public.founder_settings_history_list(p_uid uuid, p_key text default null, p_before_id bigint default null, p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 200); v_items jsonb; v_more boolean;
begin
  perform public._fs_assert_founder(p_uid);
  if p_key is not null and p_key not in ('personal.display_name','personal.avatar','personal.home','appearance.graphics','appearance.sidebar_slim') then
    raise exception 'unknown setting' using errcode = '22023';
  end if;
  with page as (
    select h.* from public.founder_settings_history h
     where h.user_id = p_uid and (p_key is null or h.key = p_key) and (p_before_id is null or h.id < p_before_id)
     order by h.id desc limit v_lim + 1
  ), shown as (select * from page order by id desc limit v_lim)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'key', s.key, 'at_ms', public._fs_ms(s.changed_at), 'at', to_char(s.changed_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'hash_only', s.key = 'personal.avatar',
           'from', s.old_value, 'to', s.new_value,
           'from_hash', left(s.old_hash, 12), 'to_hash', left(s.new_hash, 12),
           'was_default', s.old_hash is null, 'now_default', s.new_hash is null,
           'reverted', exists (select 1 from public.founder_settings_revert_log r where r.target_history_id = s.id),
           'can_undo', s.key <> 'personal.avatar'
                       and not exists (select 1 from public.founder_settings_revert_log r where r.target_history_id = s.id)
                       and public._fs_current(p_uid, s.key) is distinct from s.old_value,
           'audit_seq', public._fs_audit_seq_for(p_uid, s.key, s.old_hash, s.new_hash, s.changed_at)
         ) order by s.id desc), '[]'::jsonb),
         (select count(*) > v_lim from page)
    into v_items, v_more from shown s;
  return jsonb_build_object('items', v_items, 'more', v_more,
                            'next_before_id', case when v_more then (select min((e ->> 'id')::bigint) from jsonb_array_elements(v_items) e) else null end);
end $$;

-- 5b) one-click undo of one version: put the key back to what it was BEFORE that change
create or replace function public.founder_setting_revert(p_uid uuid, p_history_id bigint, p_reason text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare h public.founder_settings_history%rowtype; v_cur jsonb; v_target jsonb; res jsonb; v_res_hist bigint; a jsonb;
begin
  perform public._fs_assert_founder(p_uid);
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'reason needs at least 8 characters' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_settings:' || p_uid::text, 0));
  select * into h from public.founder_settings_history where id = p_history_id and user_id = p_uid;
  if not found then raise exception 'no such version' using errcode = '22023'; end if;
  if h.key = 'personal.avatar' then raise exception 'the photo itself is not kept in history; upload it again' using errcode = '22023'; end if;
  if exists (select 1 from public.founder_settings_revert_log where target_history_id = h.id) then raise exception 'this version was already undone' using errcode = '22023'; end if;
  v_cur := public._fs_current(p_uid, h.key);
  v_target := h.old_value;                                    -- SQL null means "it was the default"
  if v_cur is not distinct from v_target then raise exception 'the setting already has that value' using errcode = '22023'; end if;
  res := public.founder_setting_set(p_uid, h.key, coalesce(v_target, 'null'::jsonb));
  if (res ->> 'changed')::boolean is not true then raise exception 'nothing changed' using errcode = '22023'; end if;
  v_res_hist := public._fs_last_history_id(p_uid, h.key);
  a := public.founder_audit_append(p_uid, 'settings.revert', h.key, btrim(p_reason), jsonb_build_object('history_id', h.id, 'result_history_id', v_res_hist));
  insert into public.founder_settings_revert_log (user_id, key, target_history_id, result_history_id, audit_seq, reason)
    values (p_uid, h.key, h.id, v_res_hist, (a ->> 'seq')::bigint, btrim(p_reason));
  return jsonb_build_object('changed', true, 'key', h.key, 'history_id', h.id, 'result_history_id', v_res_hist, 'audit_seq', (a ->> 'seq')::bigint,
                            'now_default', v_target is null);
end $$;

-- 5c) the whole settings object as it was at a moment (replay of the append-only history). Avatar is listed as hash only.
create or replace function public.founder_settings_at(p_uid uuid, p_ts timestamptz)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_obj jsonb; v_hash jsonb;
begin
  perform public._fs_assert_founder(p_uid);
  if p_ts is null then raise exception 'time needed' using errcode = '22023'; end if;
  with last as (
    select distinct on (key) key, new_value, new_hash from public.founder_settings_history
     where user_id = p_uid and changed_at <= p_ts order by key, id desc
  )
  select coalesce(jsonb_object_agg(key, new_value) filter (where new_value is not null), '{}'::jsonb),
         coalesce(jsonb_object_agg(key, left(new_hash, 12)) filter (where new_value is null and new_hash is not null), '{}'::jsonb)
    into v_obj, v_hash from last;
  return jsonb_build_object('at_ms', public._fs_ms(p_ts), 'settings', v_obj, 'hash_only', v_hash);
end $$;

-- 5d) what changed between two moments
create or replace function public.founder_settings_diff(p_uid uuid, p_from timestamptz, p_to timestamptz)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare a jsonb; b jsonb; ha jsonb; hb jsonb; v_items jsonb;
begin
  perform public._fs_assert_founder(p_uid);
  if p_from is null or p_to is null or p_from > p_to then raise exception 'from must be before to' using errcode = '22023'; end if;
  a := public.founder_settings_at(p_uid, p_from); b := public.founder_settings_at(p_uid, p_to);
  select coalesce(jsonb_agg(jsonb_build_object('key', k, 'before', a -> 'settings' -> k, 'after', b -> 'settings' -> k,
                                               'before_hash', a -> 'hash_only' -> k, 'after_hash', b -> 'hash_only' -> k) order by k), '[]'::jsonb)
    into v_items
    from (select k from (select jsonb_object_keys(a -> 'settings') k union select jsonb_object_keys(b -> 'settings') union
                         select jsonb_object_keys(a -> 'hash_only') union select jsonb_object_keys(b -> 'hash_only')) u
           where (a -> 'settings' -> k) is distinct from (b -> 'settings' -> k) or (a -> 'hash_only' -> k) is distinct from (b -> 'hash_only' -> k)) d;
  return jsonb_build_object('from_ms', public._fs_ms(p_from), 'to_ms', public._fs_ms(p_to), 'changes', v_items);
end $$;

-- 5e) history replay must equal the live table. null = consistent; otherwise a plain sentence naming the first mismatch.
create or replace function public.founder_settings_replay_check(p_uid uuid)
returns text language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare r jsonb; k text; live jsonb; v_live_keys text[]; v_rep_keys text[];
begin
  perform public._fs_assert_founder(p_uid);
  r := public.founder_settings_at(p_uid, clock_timestamp() + interval '1 second');
  for k in select key from public.founder_settings where user_id = p_uid order by key loop
    live := public._fs_current(p_uid, k);
    if k = 'personal.avatar' then
      if (r -> 'hash_only' ->> k) is distinct from left(public._fs_hash(live), 12) then return 'history disagrees with the stored photo'; end if;
    elsif (r -> 'settings' -> k) is distinct from live then
      return 'history disagrees with the stored value of ' || k;
    end if;
  end loop;
  select array_agg(x order by x) into v_rep_keys from (select jsonb_object_keys(r -> 'settings') x union select jsonb_object_keys(r -> 'hash_only')) u;
  select array_agg(key order by key) into v_live_keys from public.founder_settings where user_id = p_uid;
  if coalesce(v_rep_keys, '{}'::text[]) is distinct from coalesce(v_live_keys, '{}'::text[]) then
    return 'history and the stored settings list different keys';
  end if;
  return null;
end $$;

-- 5f) one merged feed: changes, reverts and scheduled events, newest first
create or replace function public.founder_settings_timeline(p_uid uuid, p_limit integer default 60)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 60), 1), 200);
begin
  perform public._fs_assert_founder(p_uid);
  return coalesce((
    select jsonb_agg(jsonb_build_object('at_ms', at_ms, 'kind', kind, 'key', key, 'text', txt, 'ref', ref) order by at_ms desc, kind)
      from (
        select public._fs_ms(h.changed_at) at_ms, 'change' kind, h.key,
               case when h.key = 'personal.avatar' then 'Profile photo changed'
                    when h.new_hash is null then i.label || ' went back to the default'
                    when h.old_hash is null then i.label || ' was set'
                    else i.label || ' was changed' end txt, h.id::text ref
          from public.founder_settings_history h join public.founder_settings_info i on i.key = h.key where h.user_id = p_uid
        union all
        select public._fs_ms(r.created_at), 'revert', r.key, i.label || ' was undone: ' || r.reason, r.target_history_id::text
          from public.founder_settings_revert_log r join public.founder_settings_info i on i.key = r.key where r.user_id = p_uid
        union all
        select public._fs_ms(s.created_at), 'scheduled', s.key, i.label || ' change scheduled for ' || to_char(s.apply_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI "UTC"'), s.id::text
          from public.founder_settings_schedule s join public.founder_settings_info i on i.key = s.key where s.user_id = p_uid
        union all
        select public._fs_ms(s.finished_at), s.state, s.key,
               i.label || case s.state when 'rolled_back' then ' scheduled change was rolled back' when 'confirmed' then ' scheduled change was kept'
                                      when 'cancelled' then ' scheduled change was cancelled' when 'superseded' then ' scheduled change was overtaken by a newer change'
                                      else ' scheduled change failed' end, s.id::text
          from public.founder_settings_schedule s join public.founder_settings_info i on i.key = s.key where s.user_id = p_uid and s.finished_at is not null
        order by 1 desc limit v_lim
      ) t), '[]'::jsonb);
end $$;

-- ==============================================================================================================================
-- 6) DRIFT
-- ==============================================================================================================================
create or replace function public.founder_settings_drift(p_uid uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare b record; pol public.founder_audit_merkle_policy%rowtype; v_cur jsonb; v_num numeric; v_state text; v_items jsonb := '[]'::jsonb;
        na integer := 0; nl integer := 0; nr integer := 0; v_rows bigint; v_last bigint; v_lag bigint;
begin
  perform public._fs_assert_founder(p_uid);
  select * into pol from public.founder_audit_merkle_policy where id;
  for b in select * from public.founder_settings_baseline order by sort, key loop
    v_state := 'aligned'; v_cur := null;
    if b.rule = 'set' then
      v_cur := public._fs_current(p_uid, b.key);
      if v_cur is null then v_state := 'loose'; end if;
    else
      v_num := case b.key when 'audit.merkle.every_rows' then pol.every_rows when 'audit.merkle.warn_lag_rows' then pol.warn_lag_rows
                          when 'audit.merkle.fail_lag_rows' then pol.fail_lag_rows else null end;
      if v_num is null then continue; end if;
      v_cur := to_jsonb(v_num);
      if v_num > b.recommended * 10 then v_state := 'risky'; elsif v_num > b.recommended then v_state := 'loose'; end if;
    end if;
    if v_state = 'aligned' then na := na + 1; elsif v_state = 'loose' then nl := nl + 1; else nr := nr + 1; end if;
    v_items := v_items || jsonb_build_object('key', b.key, 'label', b.label, 'state', v_state, 'current', v_cur,
                                             'recommended', case when b.rule = 'set' then to_jsonb('set'::text) else to_jsonb(b.recommended) end, 'why', b.why);
  end loop;
  -- runtime item: how many ledger entries are currently unsealed, against the policy the founder has chosen
  select coalesce(max(seq), 0) into v_rows from public.founder_audit;
  select coalesce(max(upto_seq), 0) into v_last from public.founder_audit_checkpoints;
  v_lag := greatest(v_rows - v_last, 0);
  v_state := case when v_lag > pol.fail_lag_rows then 'risky' when v_lag > pol.warn_lag_rows then 'loose' else 'aligned' end;
  if v_state = 'aligned' then na := na + 1; elsif v_state = 'loose' then nl := nl + 1; else nr := nr + 1; end if;
  v_items := v_items || jsonb_build_object('key', 'audit.merkle.lag', 'label', 'Unsealed ledger entries right now', 'state', v_state, 'current', to_jsonb(v_lag),
                                           'recommended', to_jsonb(pol.warn_lag_rows), 'why', 'Entries since the last seal. Above the warning lag the tail is no longer provably covered by a seal.');
  return jsonb_build_object('score', public._fs_drift_score(na, nl, nr), 'aligned', na, 'loose', nl, 'risky', nr, 'items', v_items,
                            'at_ms', public._fs_ms(clock_timestamp()));
end $$;

-- ==============================================================================================================================
-- 7) EXPLAIN / BLAST RADIUS
-- ==============================================================================================================================
create or replace function public.founder_setting_explain(p_key text)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare i public.founder_settings_info%rowtype; b public.founder_settings_baseline%rowtype;
begin
  select * into i from public.founder_settings_info where key = p_key;
  if not found then raise exception 'unknown setting' using errcode = '22023'; end if;
  select * into b from public.founder_settings_baseline where key = p_key;
  return jsonb_build_object('key', i.key, 'label', i.label, 'plain', i.plain, 'example', i.example, 'tradeoff', i.tradeoff, 'source', 'server',
                            'recommended', case when b.key is null then null when b.rule = 'set' then to_jsonb('set'::text) else to_jsonb(b.recommended) end,
                            'why_recommended', b.why);
end $$;

create or replace function public.founder_setting_blast(p_uid uuid, p_key text)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare i public.founder_settings_info%rowtype; v_dev integer; v_pend integer; v_hist integer; v_last timestamptz;
begin
  perform public._fs_assert_founder(p_uid);
  select * into i from public.founder_settings_info where key = p_key;
  if not found then raise exception 'unknown setting' using errcode = '22023'; end if;
  select count(*) into v_dev from public.founder_devices where user_id = p_uid and approved_at is not null and revoked_at is null;
  select count(*) into v_pend from public.founder_settings_schedule where user_id = p_uid and key = p_key and state in ('scheduled','applied');
  select count(*), max(changed_at) into v_hist, v_last from public.founder_settings_history where user_id = p_uid and key = p_key;
  return jsonb_build_object('key', i.key, 'severity', i.severity, 'reversible', i.reversible, 'schedulable', i.schedulable,
                            'devices_affected', v_dev, 'surfaces', to_jsonb(i.surfaces), 'pending_schedules', v_pend, 'versions', v_hist,
                            'last_change_ms', case when v_last is null then null else public._fs_ms(v_last) end,
                            'breaks', '[]'::jsonb);
end $$;

-- ==============================================================================================================================
-- 8) SCHEDULED CHANGES WITH AUTO-ROLLBACK
-- ==============================================================================================================================
create or replace function public.founder_settings_schedule_create(p_uid uuid, p_key text, p_value jsonb, p_apply_at timestamptz, p_rollback_minutes integer, p_reason text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_val jsonb := coalesce(p_value, 'null'::jsonb); v_id uuid; v_open integer; a jsonb; i public.founder_settings_info%rowtype;
begin
  perform public._fs_assert_founder(p_uid);
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'reason needs at least 8 characters' using errcode = '22023'; end if;
  select * into i from public.founder_settings_info where key = p_key;
  if not found then raise exception 'unknown setting' using errcode = '22023'; end if;
  if not i.schedulable then raise exception '% cannot be scheduled', i.label using errcode = '22023'; end if;
  if jsonb_typeof(v_val) <> 'null' and not public._founder_setting_valid(p_key, v_val) then raise exception 'invalid value for %', p_key using errcode = '22023'; end if;
  if p_apply_at is null or p_apply_at < now() + interval '1 minute' then raise exception 'apply time must be at least 1 minute from now' using errcode = '22023'; end if;
  if p_apply_at > now() + interval '90 days' then raise exception 'apply time must be within 90 days' using errcode = '22023'; end if;
  if p_rollback_minutes is not null and p_rollback_minutes not between 5 and 10080 then raise exception 'auto-rollback must be 5 minutes to 7 days' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_settings_schedule:' || p_uid::text, 0));
  select count(*) into v_open from public.founder_settings_schedule where user_id = p_uid and state in ('scheduled','applied') and (state = 'scheduled' or rollback_due_at is not null);
  if v_open >= 20 then raise exception 'too many open scheduled changes (20)' using errcode = '53400'; end if;
  insert into public.founder_settings_schedule (user_id, key, new_value, apply_at, rollback_minutes, reason)
    values (p_uid, p_key, v_val, p_apply_at, p_rollback_minutes, btrim(p_reason)) returning id into v_id;
  a := public.founder_audit_append(p_uid, 'settings.schedule.create', p_key, btrim(p_reason),
                                   jsonb_build_object('id', v_id, 'apply_at_ms', public._fs_ms(p_apply_at), 'rollback_minutes', p_rollback_minutes));
  return jsonb_build_object('id', v_id, 'key', p_key, 'state', 'scheduled', 'apply_at_ms', public._fs_ms(p_apply_at), 'rollback_minutes', p_rollback_minutes,
                            'audit_seq', (a ->> 'seq')::bigint);
end $$;

create or replace function public.founder_settings_schedule_cancel(p_uid uuid, p_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare s public.founder_settings_schedule%rowtype; a jsonb;
begin
  perform public._fs_assert_founder(p_uid);
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'reason needs at least 8 characters' using errcode = '22023'; end if;
  select * into s from public.founder_settings_schedule where id = p_id and user_id = p_uid for update;
  if not found then raise exception 'no such scheduled change' using errcode = '22023'; end if;
  if s.state <> 'scheduled' then raise exception 'only a change that has not run yet can be cancelled (now %)', s.state using errcode = '22023'; end if;
  update public.founder_settings_schedule set state = 'cancelled', note = 'cancelled by the founder' where id = s.id;
  a := public.founder_audit_append(p_uid, 'settings.schedule.cancel', s.key, btrim(p_reason), jsonb_build_object('id', s.id));
  return jsonb_build_object('id', s.id, 'state', 'cancelled', 'audit_seq', (a ->> 'seq')::bigint);
end $$;

-- keep a change that was applied with an auto-rollback timer
create or replace function public.founder_settings_schedule_confirm(p_uid uuid, p_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare s public.founder_settings_schedule%rowtype; a jsonb;
begin
  perform public._fs_assert_founder(p_uid);
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'reason needs at least 8 characters' using errcode = '22023'; end if;
  select * into s from public.founder_settings_schedule where id = p_id and user_id = p_uid for update;
  if not found then raise exception 'no such scheduled change' using errcode = '22023'; end if;
  if s.state <> 'applied' or s.rollback_due_at is null then raise exception 'nothing to confirm (state %)', s.state using errcode = '22023'; end if;
  update public.founder_settings_schedule set state = 'confirmed', note = 'kept by the founder' where id = s.id;
  a := public.founder_audit_append(p_uid, 'settings.schedule.confirm', s.key, btrim(p_reason), jsonb_build_object('id', s.id));
  return jsonb_build_object('id', s.id, 'state', 'confirmed', 'audit_seq', (a ->> 'seq')::bigint);
end $$;

-- the tick: Rust calls it every minute. 1) applies due changes, 2) rolls back unconfirmed ones. p_now exists so tests can move the clock.
create or replace function public.founder_settings_schedule_tick(p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r public.founder_settings_schedule%rowtype; v_prev jsonb; v_cur jsonb; res jsonb; v_hid bigint; v_target jsonb;
        n_applied integer := 0; n_noop integer := 0; n_back integer := 0; n_super integer := 0; n_fail integer := 0;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('founder_settings_schedule:tick', 0)) then return jsonb_build_object('skipped', true); end if;
  -- 1) apply
  for r in select * from public.founder_settings_schedule where state = 'scheduled' and apply_at <= p_now order by apply_at, created_at for update skip locked limit 100 loop
    begin
      v_prev := public._fs_current(r.user_id, r.key);
      res := public.founder_setting_set(r.user_id, r.key, r.new_value);
      if (res ->> 'changed')::boolean is not true then
        update public.founder_settings_schedule set state = 'confirmed', applied_at = p_now, note = 'already had that value' where id = r.id;
        n_noop := n_noop + 1;
      else
        v_hid := public._fs_last_history_id(r.user_id, r.key);
        update public.founder_settings_schedule
           set state = 'applied', applied_at = p_now, prev_value = v_prev, applied_history_id = v_hid,
               rollback_due_at = case when r.rollback_minutes is null then null else p_now + make_interval(mins => r.rollback_minutes) end,
               note = case when r.rollback_minutes is null then 'applied (permanent)' else 'applied; rolls back unless confirmed' end
         where id = r.id;
        perform public.founder_audit_append(r.user_id, 'settings.schedule.apply', r.key, 'scheduled change applied automatically', jsonb_build_object('id', r.id));
        n_applied := n_applied + 1;
      end if;
    exception when others then
      update public.founder_settings_schedule set state = 'failed', note = left('apply failed: ' || sqlerrm, 300) where id = r.id;
      n_fail := n_fail + 1;
    end;
  end loop;
  -- 2) roll back what was not confirmed in time — only if the value is still the one this schedule wrote
  for r in select * from public.founder_settings_schedule where state = 'applied' and rollback_due_at is not null and rollback_due_at <= p_now order by rollback_due_at for update skip locked limit 100 loop
    begin
      v_cur := public._fs_current(r.user_id, r.key);
      v_target := case when jsonb_typeof(r.new_value) = 'null' then null else r.new_value end;
      if v_cur is not distinct from v_target then
        perform public.founder_setting_set(r.user_id, r.key, coalesce(r.prev_value, 'null'::jsonb));
        update public.founder_settings_schedule set state = 'rolled_back', note = 'rolled back automatically (not confirmed in time)' where id = r.id;
        perform public.founder_audit_append(r.user_id, 'settings.schedule.rollback', r.key, 'scheduled change rolled back automatically', jsonb_build_object('id', r.id));
        n_back := n_back + 1;
      else
        update public.founder_settings_schedule set state = 'superseded', note = 'a newer change replaced it; nothing rolled back' where id = r.id;
        n_super := n_super + 1;
      end if;
    exception when others then
      update public.founder_settings_schedule set state = 'failed', note = left('rollback failed: ' || sqlerrm, 300) where id = r.id;
      n_fail := n_fail + 1;
    end;
  end loop;
  return jsonb_build_object('skipped', false, 'applied', n_applied, 'already_set', n_noop, 'rolled_back', n_back, 'superseded', n_super, 'failed', n_fail);
end $$;

-- what the next tick would do (read-only)
create or replace function public.founder_settings_schedule_preview(p_now timestamptz default now())
returns jsonb language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select jsonb_build_object('due_to_apply', (select count(*) from public.founder_settings_schedule where state = 'scheduled' and apply_at <= p_now),
                            'due_to_rollback', (select count(*) from public.founder_settings_schedule where state = 'applied' and rollback_due_at is not null and rollback_due_at <= p_now),
                            'next_apply_ms', (select public._fs_ms(min(apply_at)) from public.founder_settings_schedule where state = 'scheduled'),
                            'next_rollback_ms', (select public._fs_ms(min(rollback_due_at)) from public.founder_settings_schedule where state = 'applied' and rollback_due_at is not null))
$$;

create or replace function public.founder_settings_schedule_list(p_uid uuid, p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  perform public._fs_assert_founder(p_uid);
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', s.id, 'key', s.key, 'label', i.label, 'to', s.new_value, 'apply_at_ms', public._fs_ms(s.apply_at), 'rollback_minutes', s.rollback_minutes,
      'state', s.state, 'reason', s.reason, 'created_ms', public._fs_ms(s.created_at),
      'applied_ms', case when s.applied_at is null then null else public._fs_ms(s.applied_at) end,
      'rollback_due_ms', case when s.rollback_due_at is null then null else public._fs_ms(s.rollback_due_at) end,
      'can_cancel', s.state = 'scheduled', 'can_confirm', s.state = 'applied' and s.rollback_due_at is not null, 'note', s.note) order by s.apply_at desc)
    from (select * from public.founder_settings_schedule where user_id = p_uid order by apply_at desc limit v_lim) s
    join public.founder_settings_info i on i.key = s.key), '[]'::jsonb);
end $$;

-- ==============================================================================================================================
-- 9) PULSE for the Dashboard + live source
-- ==============================================================================================================================
create or replace function public.founder_settings_pulse(p_uid uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare d jsonb; v_replay text; v_last timestamptz;
begin
  perform public._fs_assert_founder(p_uid);
  d := public.founder_settings_drift(p_uid);
  v_replay := public.founder_settings_replay_check(p_uid);
  select max(changed_at) into v_last from public.founder_settings_history where user_id = p_uid;
  return jsonb_build_object(
    'versions_total', (select count(*) from public.founder_settings_history where user_id = p_uid),
    'changes_24h', (select count(*) from public.founder_settings_history where user_id = p_uid and changed_at > now() - interval '24 hours'),
    'changes_7d', (select count(*) from public.founder_settings_history where user_id = p_uid and changed_at > now() - interval '7 days'),
    'reverts_7d', (select count(*) from public.founder_settings_revert_log where user_id = p_uid and created_at > now() - interval '7 days'),
    'pending_scheduled', (select count(*) from public.founder_settings_schedule where user_id = p_uid and state = 'scheduled'),
    'awaiting_confirm', (select count(*) from public.founder_settings_schedule where user_id = p_uid and state = 'applied' and rollback_due_at is not null),
    'rolled_back_30d', (select count(*) from public.founder_settings_schedule where user_id = p_uid and state = 'rolled_back' and finished_at > now() - interval '30 days'),
    'drift_score', d -> 'score', 'drift_loose', d -> 'loose', 'drift_risky', d -> 'risky',
    'replay_ok', v_replay is null, 'replay_note', v_replay,
    'last_change_ms', case when v_last is null then null else public._fs_ms(v_last) end);
end $$;

do $$
begin
  insert into public.founder_live_sources (key, label, relation, ts_candidates, ts_unit, owner, expect_max_age_secs, sort)
    values ('settings_history', 'Settings history', 'public.founder_settings_history', array['changed_at'], 'timestamptz', 'founder', null, 150)
  on conflict (key) do nothing;
end $$;

-- ==============================================================================================================================
-- 10) cross-check: replay must also agree with a second, independent derivation (latest history row per key via window function).
--     p_uid null = every founder account (diagnostic on real data); p_uid given = just that founder (what the selftest uses).
--     The comparison is scoped to ONE founder at a time: another founder's rows must never count against this one.
-- ==============================================================================================================================
drop function if exists public.founder_settings_crosscheck();
create or replace function public.founder_settings_crosscheck(p_uid uuid default null) returns text language plpgsql stable security definer
set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare u uuid; n integer := 0; v_bad text; v_msg text := '';
begin
  for u in select user_id from public.founder_accounts where p_uid is null or user_id = p_uid order by user_id loop
    n := n + 1;
    with w as (select key, new_value, new_hash, row_number() over (partition by key order by id desc) rn from public.founder_settings_history where user_id = u),
         latest as (select key, new_value, new_hash from w where rn = 1 and new_hash is not null),
         live as (select key, value from public.founder_settings where user_id = u)
    select string_agg(coalesce(l.key, s.key), ',' order by coalesce(l.key, s.key)) into v_bad
      from latest l full join live s on s.key = l.key
     where (l.key is null) or (s.key is null) or (l.key <> 'personal.avatar' and l.new_value is distinct from s.value)
        or (l.key = 'personal.avatar' and l.new_hash is distinct from public._fs_hash(s.value));
    if v_bad is not null then v_msg := v_msg || left(u::text, 8) || ': ' || v_bad || '; '; end if;
  end loop;
  if v_msg <> '' then return 'E113 crosscheck FAIL: ' || v_msg; end if;
  return 'E113 crosscheck OK (' || n || ' founder account(s))';
end $$;

-- ==============================================================================================================================
-- 11) selftest (everything rolled back)
-- ==============================================================================================================================
create or replace function public.founder_settings_s2_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare
  u uuid; r text := ''; j jsonb; j2 jsonb; hid bigint; hid2 bigint; sid uuid; sid2 uuid; sid3 uuid; sid4 uuid; v_n integer; t0 timestamptz := now();
  b_set bigint; b_hist bigint; b_audit bigint; b_rev bigint; b_sch bigint; b_pol public.founder_audit_merkle_policy%rowtype;
begin
  select user_id into u from public.founder_accounts limit 1;
  if u is null then return 'E113 selftest SKIP — no founder account'; end if;
  select count(*) into b_set from public.founder_settings; select count(*) into b_hist from public.founder_settings_history; select count(*) into b_audit from public.founder_audit;
  select count(*) into b_rev from public.founder_settings_revert_log; select count(*) into b_sch from public.founder_settings_schedule;
  begin
    delete from public.founder_settings where user_id = u;                      -- rolled back below

    -- registries
    if (select count(*) from public.founder_settings_info) < 5 then raise exception 'info registry incomplete'; end if;
    if (select count(*) from public.founder_settings_baseline) < 5 then raise exception 'baseline registry incomplete'; end if;
    j := public.founder_setting_explain('personal.home');
    if j ->> 'label' <> 'Home city' or j ->> 'recommended' <> 'set' then raise exception 'explain wrong: %', j; end if;
    if not public._fs_fails($q$select public.founder_setting_explain('nope.key')$q$) then raise exception 'explain accepted an unknown key'; end if;
    r := r || 'registries+explain OK; ';

    -- blast radius: real counts
    j := public.founder_setting_blast(u, 'appearance.graphics');
    if (j ->> 'devices_affected')::integer <> (select count(*) from public.founder_devices where user_id = u and approved_at is not null and revoked_at is null) then raise exception 'blast device count wrong'; end if;
    if jsonb_array_length(j -> 'surfaces') < 1 or j ->> 'severity' <> 'low' then raise exception 'blast shape wrong: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_setting_blast(%L, 'appearance.graphics')$q$, gen_random_uuid())) then raise exception 'blast for a non-founder'; end if;
    r := r || 'blast OK; ';

    -- drift: nothing set -> two loose
    j := public.founder_settings_drift(u);
    if (select count(*) from jsonb_array_elements(j -> 'items') e where e ->> 'key' in ('personal.display_name','personal.home') and e ->> 'state' = 'loose') <> 2 then raise exception 'drift: unset name/home must be loose: %', j; end if;
    if (j ->> 'score')::integer not between 0 and 100 then raise exception 'drift score range'; end if;
    perform public.founder_setting_set(u, 'personal.display_name', to_jsonb('Drift Tester'::text));
    perform public.founder_setting_set(u, 'personal.home', jsonb_build_object('city','Lahore','country','Pakistan','iana','Asia/Karachi','lat',31.52,'lon',74.36));
    j2 := public.founder_settings_drift(u);
    if (select count(*) from jsonb_array_elements(j2 -> 'items') e where e ->> 'key' in ('personal.display_name','personal.home') and e ->> 'state' = 'aligned') <> 2 then raise exception 'drift: set name/home must be aligned'; end if;
    if (j2 ->> 'score')::integer <= (j ->> 'score')::integer then raise exception 'drift score must improve after setting name and home'; end if;
    r := r || 'drift settings OK; ';

    -- drift: ledger policy (read from E107)
    select * into b_pol from public.founder_audit_merkle_policy where id;
    perform public.founder_audit_merkle_policy_set(u, 600, 700, 2500, 'drift selftest policy change');
    j := public.founder_settings_drift(u);
    if (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = 'audit.merkle.every_rows') <> 'risky' then raise exception 'every_rows 600 must be risky'; end if;
    if (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = 'audit.merkle.warn_lag_rows') <> 'loose' then raise exception 'warn 700 must be loose'; end if;
    if (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = 'audit.merkle.fail_lag_rows') <> 'loose' then raise exception 'fail 2500 must be loose'; end if;
    perform public.founder_audit_merkle_policy_set(u, b_pol.every_rows, b_pol.warn_lag_rows, b_pol.fail_lag_rows, 'drift selftest policy restore');
    j := public.founder_settings_drift(u);
    if (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = 'audit.merkle.every_rows') <> 'aligned' then raise exception 'policy restore must be aligned again'; end if;
    if public._fs_drift_score(2, 2, 0) <> 75 or public._fs_drift_score(0, 0, 3) <> 0 or public._fs_drift_score(4, 0, 0) <> 100 then raise exception 'drift score maths'; end if;
    r := r || 'drift policy+score OK; ';

    -- time machine: versions + undo
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(true));
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(false));
    hid := public._fs_last_history_id(u, 'appearance.graphics');
    j := public.founder_settings_history_list(u, 'appearance.graphics', null, 10);
    if jsonb_array_length(j -> 'items') <> 2 or (j -> 'items' -> 0 ->> 'id')::bigint <> hid then raise exception 'history list wrong: %', j; end if;
    if (j -> 'items' -> 0 ->> 'can_undo')::boolean is not true or (j -> 'items' -> 0 ->> 'reverted')::boolean then raise exception 'newest version must be undoable'; end if;
    if (j -> 'items' -> 0 ->> 'audit_seq') is null then raise exception 'history item has no audit seq'; end if;
    if public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'short')$q$, u, hid)) is not true then raise exception 'revert accepted a 5-char reason'; end if;
    j := public.founder_setting_revert(u, hid, 'selftest undo graphics');
    if (j ->> 'changed')::boolean is not true or (public._fs_current(u, 'appearance.graphics')) <> to_jsonb(true) then raise exception 'undo did not restore true: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest undo twice')$q$, u, hid)) then raise exception 'a version was undone twice'; end if;
    j := public.founder_settings_history_list(u, 'appearance.graphics', null, 10);
    if (select count(*) from jsonb_array_elements(j -> 'items') e where (e ->> 'reverted')::boolean) <> 1 then raise exception 'reverted flag not shown'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, 999999999, 'selftest unknown version')$q$, u)) then raise exception 'unknown version undone'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest wrong founder')$q$, gen_random_uuid(), hid)) then raise exception 'non-founder undid a version'; end if;
    r := r || 'undo OK; ';

    -- undo back to default (first ever change of a key)
    perform public.founder_setting_set(u, 'appearance.sidebar_slim', to_jsonb(true));
    hid2 := public._fs_last_history_id(u, 'appearance.sidebar_slim');
    j := public.founder_setting_revert(u, hid2, 'selftest back to default');
    if (j ->> 'now_default')::boolean is not true or public.founder_settings_get(u) ? 'appearance.sidebar_slim' then raise exception 'undo to default failed'; end if;
    -- undoing the undo is a legitimate new version: it brings the earlier value back, and is itself undoable once
    j := public.founder_setting_revert(u, public._fs_last_history_id(u, 'appearance.sidebar_slim'), 'selftest undo of the undo');
    if (j ->> 'now_default')::boolean or public._fs_current(u, 'appearance.sidebar_slim') <> to_jsonb(true) then raise exception 'undo of the undo did not bring true back'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest first version twice')$q$, u, hid2)) then raise exception 'the first version was undone twice'; end if;
    r := r || 'undo-to-default OK; ';

    -- avatar can never be reverted from history
    perform public.founder_setting_set(u, 'personal.avatar', to_jsonb('data:image/png;base64,iVBORw0KGgo='::text));
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest avatar revert')$q$, u, public._fs_last_history_id(u, 'personal.avatar'))) then raise exception 'avatar was reverted'; end if;
    j := public.founder_settings_history_list(u, 'personal.avatar', null, 5);
    if (j -> 'items' -> 0 ->> 'hash_only')::boolean is not true or j -> 'items' -> 0 -> 'to' <> 'null'::jsonb or (j -> 'items' -> 0 ->> 'can_undo')::boolean then raise exception 'avatar history must be hash-only and not undoable'; end if;
    r := r || 'avatar guard OK; ';

    -- replay must equal live; tamper must be caught
    if public.founder_settings_replay_check(u) is not null then raise exception 'replay check dirty: %', public.founder_settings_replay_check(u); end if;
    if public.founder_settings_crosscheck(u) not like 'E113 crosscheck OK%' then raise exception 'crosscheck: %', public.founder_settings_crosscheck(u); end if;
    update public.founder_settings set value = to_jsonb(false) where user_id = u and key = 'appearance.graphics';   -- bypasses the door on purpose
    if public.founder_settings_replay_check(u) is null then raise exception 'replay check missed a tampered value'; end if;
    update public.founder_settings set value = to_jsonb(true) where user_id = u and key = 'appearance.graphics';
    if public.founder_settings_replay_check(u) is not null then raise exception 'replay check still dirty after fixing'; end if;
    r := r || 'replay+tamper OK; ';

    -- point in time (backdated rows are inserted directly; history allows insert, never update)
    insert into public.founder_settings_history (user_id, key, old_hash, new_hash, old_value, new_value, changed_at)
      values (u, 'appearance.sidebar_slim', null, public._fs_hash(to_jsonb(true)), null, to_jsonb(true), t0 - interval '3 days');
    insert into public.founder_settings_history (user_id, key, old_hash, new_hash, old_value, new_value, changed_at)
      values (u, 'appearance.sidebar_slim', public._fs_hash(to_jsonb(true)), null, to_jsonb(true), null, t0 - interval '1 day');
    j := public.founder_settings_at(u, t0 - interval '2 days');
    if j -> 'settings' -> 'appearance.sidebar_slim' <> to_jsonb(true) then raise exception 'time travel: 2 days ago sidebar_slim must be true: %', j; end if;
    j := public.founder_settings_at(u, t0 - interval '4 days');
    if j -> 'settings' ? 'appearance.sidebar_slim' then raise exception 'time travel: 4 days ago nothing was set'; end if;
    j := public.founder_settings_at(u, t0 - interval '12 hours');
    if j -> 'settings' ? 'appearance.sidebar_slim' then raise exception 'time travel: after the reset the key is back to default'; end if;
    j := public.founder_settings_diff(u, t0 - interval '4 days', t0 - interval '2 days');
    if jsonb_array_length(j -> 'changes') <> 1 or j -> 'changes' -> 0 ->> 'key' <> 'appearance.sidebar_slim' then raise exception 'diff wrong: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_settings_diff(%L, now(), now() - interval '1 day')$q$, u)) then raise exception 'diff accepted a reversed range'; end if;
    r := r || 'point-in-time+diff OK; ';

    -- timeline carries all kinds
    j := public.founder_settings_timeline(u, 100);
    if jsonb_array_length(j) < 6 or not exists (select 1 from jsonb_array_elements(j) e where e ->> 'kind' = 'revert') then raise exception 'timeline incomplete'; end if;
    r := r || 'timeline OK; ';

    -- scheduling: validation
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '30 seconds', null, 'selftest too soon')$q$, u)) then raise exception 'schedule accepted <1 min'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '91 days', null, 'selftest too far')$q$, u)) then raise exception 'schedule accepted >90 days'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', '"x"'::jsonb, now() + interval '5 minutes', null, 'selftest bad value')$q$, u)) then raise exception 'schedule accepted a bad value'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'personal.avatar', '"https://x.y/a.png"'::jsonb, now() + interval '5 minutes', null, 'selftest avatar')$q$, u)) then raise exception 'schedule accepted the avatar'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'nope.key', 'true'::jsonb, now() + interval '5 minutes', null, 'selftest unknown')$q$, u)) then raise exception 'schedule accepted an unknown key'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '5 minutes', 3, 'selftest short rollback')$q$, u)) then raise exception 'schedule accepted a 3-minute rollback'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '5 minutes', null, 'short')$q$, u)) then raise exception 'schedule accepted a short reason'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '5 minutes', null, 'selftest non founder')$q$, gen_random_uuid())) then raise exception 'non-founder scheduled'; end if;
    r := r || 'schedule validation OK; ';

    -- schedule: cancel path
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'false'::jsonb, now() + interval '5 minutes', null, 'selftest cancel path');
    sid := (j ->> 'id')::uuid;
    j := public.founder_settings_schedule_cancel(u, sid, 'selftest cancel it');
    if j ->> 'state' <> 'cancelled' then raise exception 'cancel failed'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_cancel(%L, %L, 'selftest cancel twice')$q$, u, sid)) then raise exception 'cancelled twice'; end if;
    if public._fs_fails(format($q$update public.founder_settings_schedule set state = 'scheduled' where id = %L$q$, sid)) is not true then raise exception 'a cancelled row went back to scheduled'; end if;
    r := r || 'cancel OK; ';

    -- schedule: apply then auto-rollback (value true -> false -> back to true)
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'false'::jsonb, now() + interval '2 minutes', 10, 'selftest rollback path');
    sid := (j ->> 'id')::uuid;
    j := public.founder_settings_schedule_preview(now() + interval '3 minutes');
    if (j ->> 'due_to_apply')::integer <> 1 then raise exception 'preview must see 1 due: %', j; end if;
    j := public.founder_settings_schedule_tick(now() + interval '1 minute');
    if (j ->> 'applied')::integer <> 0 then raise exception 'tick applied too early: %', j; end if;
    j := public.founder_settings_schedule_tick(now() + interval '3 minutes');
    if (j ->> 'applied')::integer <> 1 or public._fs_current(u, 'appearance.graphics') <> to_jsonb(false) then raise exception 'tick did not apply: %', j; end if;
    if (select state from public.founder_settings_schedule where id = sid) <> 'applied' then raise exception 'state should be applied'; end if;
    j := public.founder_settings_schedule_tick(now() + interval '5 minutes');
    if (j ->> 'rolled_back')::integer <> 0 then raise exception 'rolled back before the timer'; end if;
    j := public.founder_settings_schedule_tick(now() + interval '20 minutes');
    if (j ->> 'rolled_back')::integer <> 1 or public._fs_current(u, 'appearance.graphics') <> to_jsonb(true) then raise exception 'auto-rollback did not restore true: %', j; end if;
    if (select state from public.founder_settings_schedule where id = sid) <> 'rolled_back' then raise exception 'state should be rolled_back'; end if;
    j := public.founder_settings_schedule_tick(now() + interval '40 minutes');
    if (j ->> 'rolled_back')::integer <> 0 or (j ->> 'applied')::integer <> 0 then raise exception 'tick is not idempotent: %', j; end if;
    r := r || 'apply+auto-rollback OK; ';

    -- schedule: confirm keeps the change
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'false'::jsonb, now() + interval '2 minutes', 10, 'selftest confirm path');
    sid2 := (j ->> 'id')::uuid;
    perform public.founder_settings_schedule_tick(now() + interval '3 minutes');
    j := public.founder_settings_schedule_confirm(u, sid2, 'selftest keep this one');
    if j ->> 'state' <> 'confirmed' then raise exception 'confirm failed'; end if;
    j := public.founder_settings_schedule_tick(now() + interval '60 minutes');
    if public._fs_current(u, 'appearance.graphics') <> to_jsonb(false) then raise exception 'confirmed change was rolled back'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_confirm(%L, %L, 'selftest confirm again')$q$, u, sid2)) then raise exception 'confirmed twice'; end if;
    r := r || 'confirm OK; ';

    -- schedule: a newer manual change wins (superseded, never overwritten)
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(true));
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'false'::jsonb, now() + interval '2 minutes', 10, 'selftest superseded path');
    sid3 := (j ->> 'id')::uuid;
    perform public.founder_settings_schedule_tick(now() + interval '3 minutes');
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(true));                 -- founder changes it again before the timer
    j := public.founder_settings_schedule_tick(now() + interval '30 minutes');
    if (j ->> 'superseded')::integer <> 1 or public._fs_current(u, 'appearance.graphics') <> to_jsonb(true) then raise exception 'rollback overwrote a newer value: %', j; end if;
    r := r || 'superseded OK; ';

    -- schedule: no-op and permanent
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'true'::jsonb, now() + interval '2 minutes', 10, 'selftest already set');
    sid4 := (j ->> 'id')::uuid;
    j := public.founder_settings_schedule_tick(now() + interval '3 minutes');
    if (j ->> 'already_set')::integer <> 1 or (select state from public.founder_settings_schedule where id = sid4) <> 'confirmed' then raise exception 'no-op schedule wrong: %', j; end if;
    j := public.founder_settings_schedule_create(u, 'appearance.sidebar_slim', 'false'::jsonb, now() + interval '2 minutes', null, 'selftest permanent path');
    sid4 := (j ->> 'id')::uuid;
    perform public.founder_settings_schedule_tick(now() + interval '3 minutes');
    perform public.founder_settings_schedule_tick(now() + interval '9 days');
    if public._fs_current(u, 'appearance.sidebar_slim') <> to_jsonb(false) or (select state from public.founder_settings_schedule where id = sid4) <> 'applied' then raise exception 'permanent schedule changed after the tick'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_confirm(%L, %L, 'selftest nothing to confirm')$q$, u, sid4)) then raise exception 'confirmed a permanent change'; end if;
    r := r || 'no-op+permanent OK; ';

    -- schedule: list + guards
    j := public.founder_settings_schedule_list(u, 50);
    if jsonb_array_length(j) < 6 then raise exception 'schedule list short: %', jsonb_array_length(j); end if;
    if public._fs_fails(format($q$delete from public.founder_settings_schedule where id = %L$q$, sid)) is not true then raise exception 'schedule row deleted'; end if;
    if public._fs_fails(format($q$update public.founder_settings_schedule set new_value = 'true'::jsonb where id = %L$q$, sid3)) is not true then raise exception 'request edited after creation'; end if;
    if public._fs_fails('truncate public.founder_settings_schedule') is not true then raise exception 'schedule truncated'; end if;
    if public._fs_fails('truncate public.founder_settings_revert_log') is not true then raise exception 'revert log truncated'; end if;
    if public._fs_fails('update public.founder_settings_revert_log set reason = ''xxxxxxxxxx''') is not true then raise exception 'revert log updated'; end if;
    -- open-schedule limit
    for v_n in 1..20 loop
      perform public.founder_settings_schedule_create(u, 'appearance.sidebar_slim', 'false'::jsonb, now() + interval '5 days', null, 'selftest limit ' || v_n);
    end loop;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.sidebar_slim', 'false'::jsonb, now() + interval '5 days', null, 'selftest limit over')$q$, u)) then raise exception 'open schedule limit not enforced'; end if;
    r := r || 'list+guards+limit OK; ';

    -- pulse
    j := public.founder_settings_pulse(u);
    if (j ->> 'versions_total')::integer < 8 or (j ->> 'pending_scheduled')::integer < 20 or (j ->> 'reverts_7d')::integer < 2 then raise exception 'pulse counts wrong: %', j; end if;
    if (j ->> 'drift_score')::integer not between 0 and 100 then raise exception 'pulse drift'; end if;
    r := r || 'pulse OK; ';

    -- audit chain still clean, new action names present
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain broken'; end if;
    if (select count(distinct action) from public.founder_audit where action in ('settings.revert','settings.schedule.create','settings.schedule.apply','settings.schedule.rollback','settings.schedule.confirm','settings.schedule.cancel')) <> 6 then
      raise exception 'expected 6 new audit actions, got %', (select count(distinct action) from public.founder_audit where action like 'settings.%');
    end if;
    r := r || 'audit chain+actions OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E113 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_settings) <> b_set or (select count(*) from public.founder_settings_history) <> b_hist or (select count(*) from public.founder_audit) <> b_audit
     or (select count(*) from public.founder_settings_revert_log) <> b_rev or (select count(*) from public.founder_settings_schedule) <> b_sch then
    raise exception 'E113 selftest left rows behind';
  end if;
  return 'E113 selftest OK — ' || r || 'rollback clean';
end $$;

-- ==============================================================================================================================
-- 12) selftest2 — structure, privileges, hygiene
-- ==============================================================================================================================
create or replace function public.founder_settings_s2_selftest2() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r text := ''; t text; f text; v_n integer;
begin
  foreach t in array array['public.founder_settings_revert_log','public.founder_settings_schedule','public.founder_settings_info','public.founder_settings_baseline'] loop
    if to_regclass(t) is null then raise exception 'table missing: %', t; end if;
    if not (select relrowsecurity from pg_class where oid = to_regclass(t)) then raise exception 'RLS off on %', t; end if;
    if has_table_privilege('anon', t, 'select') or has_table_privilege('authenticated', t, 'select') or has_table_privilege('anon', t, 'insert') or has_table_privilege('authenticated', t, 'insert') then raise exception 'anon/authenticated can reach %', t; end if;
  end loop;
  if has_table_privilege('service_role', 'public.founder_settings_info', 'insert') or has_table_privilege('service_role', 'public.founder_settings_baseline', 'update') then raise exception 'registries must be read-only for service_role'; end if;
  if has_table_privilege('service_role', 'public.founder_settings_revert_log', 'update') or has_table_privilege('service_role', 'public.founder_settings_revert_log', 'delete') then raise exception 'revert log must be append-only for service_role'; end if;
  if has_table_privilege('service_role', 'public.founder_settings_schedule', 'delete') then raise exception 'service_role must not delete schedule rows'; end if;
  r := r || 'tables+RLS+grants OK; ';
  foreach f in array array[
      'public.founder_settings_history_list(uuid,text,bigint,integer)','public.founder_setting_revert(uuid,bigint,text)','public.founder_settings_at(uuid,timestamptz)',
      'public.founder_settings_diff(uuid,timestamptz,timestamptz)','public.founder_settings_replay_check(uuid)','public.founder_settings_timeline(uuid,integer)',
      'public.founder_settings_drift(uuid)','public.founder_setting_explain(text)','public.founder_setting_blast(uuid,text)',
      'public.founder_settings_schedule_create(uuid,text,jsonb,timestamptz,integer,text)','public.founder_settings_schedule_cancel(uuid,uuid,text)',
      'public.founder_settings_schedule_confirm(uuid,uuid,text)','public.founder_settings_schedule_tick(timestamptz)','public.founder_settings_schedule_preview(timestamptz)',
      'public.founder_settings_schedule_list(uuid,integer)','public.founder_settings_pulse(uuid)','public.founder_settings_crosscheck(uuid)'] loop
    if to_regprocedure(f) is null then raise exception 'rpc missing: %', f; end if;
    if has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute') or has_function_privilege('public', f, 'execute') then raise exception 'rpc open to the public: %', f; end if;
    if not has_function_privilege('service_role', f, 'execute') then raise exception 'service_role cannot run %', f; end if;
  end loop;
  r := r || 'rpc grants OK; ';
  select count(*) into v_n from pg_proc p where p.oid = any (array[to_regprocedure('public.founder_setting_revert(uuid,bigint,text)'), to_regprocedure('public.founder_settings_schedule_tick(timestamptz)'),
        to_regprocedure('public.founder_settings_schedule_create(uuid,text,jsonb,timestamptz,integer,text)'), to_regprocedure('public.founder_settings_drift(uuid)'),
        to_regprocedure('public.founder_settings_history_list(uuid,text,bigint,integer)')])
     and p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(p.proconfig) c where c like 'statement_timeout=%');
  if v_n <> 5 then raise exception 'security definer functions must pin search_path and statement_timeout (%/5)', v_n; end if;
  r := r || 'definer hygiene OK; ';
  if (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_settings_schedule') and tgname in ('founder_settings_schedule_guard','founder_settings_schedule_no_trunc')) <> 2 then raise exception 'schedule triggers missing'; end if;
  if (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_settings_revert_log') and tgname in ('founder_settings_revert_log_no_upd','founder_settings_revert_log_no_trunc')) <> 2 then raise exception 'revert log triggers missing'; end if;
  r := r || 'triggers OK; ';
  if exists (select 1 from public.founder_settings_info i where not exists (select 1 from unnest(array['personal.display_name','personal.avatar','personal.home','appearance.graphics','appearance.sidebar_slim']) k where k = i.key)) then raise exception 'info has a key outside the E108 registry'; end if;
  if (select count(*) from public.founder_settings_info) <> 5 then raise exception 'every E108 key needs an info row'; end if;
  r := r || 'registry coverage OK; ';
  if not exists (select 1 from public.founder_live_sources where key = 'settings_history') then raise exception 'live source missing'; end if;
  r := r || 'live source OK; ';
  return 'E113 selftest2 OK — ' || r || 'done';
end $$;

-- ==============================================================================================================================
-- 13) grants (service_role only)
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array[
      'public.founder_settings_history_list(uuid,text,bigint,integer)','public.founder_setting_revert(uuid,bigint,text)','public.founder_settings_at(uuid,timestamptz)',
      'public.founder_settings_diff(uuid,timestamptz,timestamptz)','public.founder_settings_replay_check(uuid)','public.founder_settings_timeline(uuid,integer)',
      'public.founder_settings_drift(uuid)','public.founder_setting_explain(text)','public.founder_setting_blast(uuid,text)',
      'public.founder_settings_schedule_create(uuid,text,jsonb,timestamptz,integer,text)','public.founder_settings_schedule_cancel(uuid,uuid,text)',
      'public.founder_settings_schedule_confirm(uuid,uuid,text)','public.founder_settings_schedule_tick(timestamptz)','public.founder_settings_schedule_preview(timestamptz)',
      'public.founder_settings_schedule_list(uuid,integer)','public.founder_settings_pulse(uuid)','public.founder_settings_crosscheck(uuid)',
      'public.founder_settings_s2_selftest()','public.founder_settings_s2_selftest2()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on function public.founder_setting_revert(uuid, bigint, text) is 'E113: one-click undo of one settings version. Goes through founder_setting_set (history + audit) and logs the undo. Each version once; the photo cannot be undone (hash-only history).';
comment on function public.founder_settings_schedule_tick(timestamptz) is 'E113: Rust calls this every minute. Applies due changes, rolls back unconfirmed ones. Never overwrites a newer value (state superseded). Idempotent.';
comment on function public.founder_settings_drift(uuid) is 'E113: score 0..100 from baseline rows plus the live ledger-seal policy and lag. aligned=1, loose=0.5, risky=0.';
comment on function public.founder_settings_replay_check(uuid) is 'E113: null when replaying the append-only history gives exactly the live settings; otherwise a plain sentence. Detects edits that bypassed the door.';

-- ==============================================================================================================================
-- 14) run the selftests now (output shows in sql-run.sh)
-- ==============================================================================================================================
do $$ begin
  raise notice '%', public.founder_settings_s2_selftest();
  raise notice '%', public.founder_settings_s2_selftest2();
  raise notice '%', public.founder_settings_crosscheck();
end $$;

-- ==============================================================================================================================
-- RUNBOOK (comments only)
-- ==============================================================================================================================
-- Run:        bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E113_founder_settings_timemachine CHECK_E113   (after the usual fetch)
-- Order:      E102 -> E107 -> E108 -> E109 -> E113. Running E113 again is safe: tables are create-if-not-exists, functions are create-or-replace, registries are upserted.
-- Rust:       settings_s2.rs calls (all signed, service_role): history_list, revert, at, diff, timeline, drift, explain, blast, schedule_create/cancel/confirm/list, pulse;
--             the live tick calls founder_settings_schedule_tick() once a minute.
-- Undo plan:  drop the E113 functions and the three new tables; E108 settings + history are untouched. Nothing here edits an existing table apart from registering one live source.
-- Not here:   notifications of a rollback (S4 push), passkey-gated revert for high-danger keys (F2d). Today every founder setting is low severity, so G2 (two-tap + reason) is enough.
