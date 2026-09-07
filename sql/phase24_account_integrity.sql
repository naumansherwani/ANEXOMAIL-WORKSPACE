-- ============================================================================
-- ANEXOMAIL / ANEXOChat — ACCOUNT INTEGRITY BATCH  (Supabase #4)
--
-- RUN: Supabase SQL editor mein poora file paste -> Run. Idempotent + self-healing.
--
-- LOCKED RULES (memory ke mutabiq):
--   1. One person, one account. Detection SIRF device shape par (device_vault
--      ka sha256 hash) — IP / network / WiFi kabhi nahi.
--   2. Ladder: clean -> suspicious (engine, deterministic) -> warned (INSAAN,
--      12+ char reason) -> blocked (INSAAN, warning ke baad hi).
--      Engine khud kisi ko block NAHI karti. Step skip mumkin nahi.
--   3. Block ke baad 72 ghante FULL EXPORT khula rehta hai; us window ke baad
--      hi data permanently delete hota hai (purge), pehle kabhi nahi.
--   4. Block ke saath device hash device_bans mein jata hai — appealable
--      (Phase 23 ka device_ban_appeals). Release bhi insaan karta hai, reason ke saath.
--   5. account_integrity_log append-only: update/delete namumkin.
--   6. No duplicate: device detection ka ghar device_vault/device_trust_events hai,
--      yeh layer uske OOPAR enforcement + evidence hai.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) self-healing: purani conflicting shape ko _legacy kar do
-- ---------------------------------------------------------------------------
do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='account_integrity')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='account_integrity' and column_name='state') then
    execute format('alter table public.account_integrity rename to account_integrity_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='account_integrity_log')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='account_integrity_log' and column_name='event') then
    execute format('alter table public.account_integrity_log rename to account_integrity_log_legacy_%s', ts);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) policy (published numbers — footer ki copy inhi se milti hai)
-- ---------------------------------------------------------------------------
create table if not exists public.account_integrity_policy (
  id                     int primary key default 1 check (id = 1),
  max_accounts_per_device int  not null default 3,
  signup_window_hours     int  not null default 24,
  max_signups_in_window   int  not null default 3,
  warning_required        boolean not null default true,
  export_window_hours     int  not null default 72,
  ban_scope               text not null default 'device_hash_only',
  note                    text not null default
    'Detection device shape par. IP ya network par ban kabhi nahi. Har block appealable.'
);
insert into public.account_integrity_policy (id) values (1) on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 2) per-account state
-- ---------------------------------------------------------------------------
create table if not exists public.account_integrity (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  state          text not null default 'clean'
                 check (state in ('clean','suspicious','warned','blocked','released','purged')),
  reason         text,
  evidence       jsonb not null default '{}'::jsonb,
  accounts_on_device int not null default 1,
  signups_in_window  int not null default 0,
  warned_at      timestamptz,
  warned_by      uuid references auth.users(id) on delete set null,
  blocked_at     timestamptz,
  blocked_by     uuid references auth.users(id) on delete set null,
  export_until   timestamptz,
  purge_after    timestamptz,
  purged_at      timestamptz,
  released_at    timestamptz,
  updated_at     timestamptz not null default now()
);
create index if not exists account_integrity_state_idx
  on public.account_integrity(state, updated_at desc);
create index if not exists account_integrity_purge_idx
  on public.account_integrity(purge_after) where purge_after is not null;

-- ---------------------------------------------------------------------------
-- 3) append-only ledger
-- ---------------------------------------------------------------------------
create table if not exists public.account_integrity_log (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  device_hash text,
  event       text not null check (event in
                ('evaluated','suspicious','warned','blocked','export_window_opened',
                 'exported','released','purged','appeal_linked')),
  actor       text not null default 'engine',
  actor_user  uuid references auth.users(id) on delete set null,
  reason      text,
  detail      jsonb not null default '{}'::jsonb,
  at          timestamptz not null default now()
);
create index if not exists account_integrity_log_idx
  on public.account_integrity_log(user_id, id desc);

create or replace function public.account_integrity_log_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'account_integrity_log is append-only';
end $$;

drop trigger if exists account_integrity_log_no_change on public.account_integrity_log;
create trigger account_integrity_log_no_change
  before update or delete on public.account_integrity_log
  for each row execute function public.account_integrity_log_immutable();

-- ---------------------------------------------------------------------------
-- 4) grants (RLS se PEHLE) + RLS
-- ---------------------------------------------------------------------------
grant select on public.account_integrity, public.account_integrity_log,
  public.account_integrity_policy to authenticated;
grant all on public.account_integrity, public.account_integrity_log,
  public.account_integrity_policy to service_role;
grant usage, select on sequence public.account_integrity_log_id_seq to service_role;

alter table public.account_integrity        enable row level security;
alter table public.account_integrity_log    enable row level security;
alter table public.account_integrity_policy enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='account_integrity' and policyname='own integrity read') then
    create policy "own integrity read" on public.account_integrity
      for select to authenticated
      using (user_id = auth.uid() or public.safety_can_review(auth.uid()));
  end if;
  if not exists (select 1 from pg_policies
                  where tablename='account_integrity_log' and policyname='own integrity log') then
    create policy "own integrity log" on public.account_integrity_log
      for select to authenticated
      using (user_id = auth.uid() or public.safety_can_review(auth.uid()));
  end if;
  if not exists (select 1 from pg_policies
                  where tablename='account_integrity_policy' and policyname='integrity policy readable') then
    create policy "integrity policy readable" on public.account_integrity_policy
      for select to authenticated using (true);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5) EVALUATE — deterministic, sirf marks suspicious. Block kabhi nahi.
-- ---------------------------------------------------------------------------
create or replace function public.account_integrity_evaluate(_user uuid, _device_hash text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_pol    public.account_integrity_policy;
  v_hash   text := nullif(btrim(coalesce(_device_hash,'')), '');
  v_users  int := 1;
  v_signup int := 0;
  v_row    public.account_integrity;
  v_ev     jsonb := '[]'::jsonb;
  v_state  text;
begin
  if _user is null then return jsonb_build_object('ok', false, 'error', 'user_required'); end if;
  select * into v_pol from public.account_integrity_policy where id = 1;

  if v_hash is null then
    select device_hash into v_hash from public.device_vault
     where user_id = _user order by last_seen_at desc limit 1;
  end if;

  if v_hash is not null then
    select count(distinct user_id) into v_users
      from public.device_vault where device_hash = v_hash;
    select count(*) into v_signup
      from public.device_trust_events
     where device_hash = v_hash and event = 'registered'
       and at > now() - make_interval(hours => v_pol.signup_window_hours);
  end if;

  if v_users >= v_pol.max_accounts_per_device then
    v_ev := v_ev || jsonb_build_array(
      format('is device shape par %s accounts mile (had %s)', v_users, v_pol.max_accounts_per_device));
  end if;
  if v_signup >= v_pol.max_signups_in_window then
    v_ev := v_ev || jsonb_build_array(
      format('%s ghante mein %s naye signup isi device se', v_pol.signup_window_hours, v_signup));
  end if;

  insert into public.account_integrity (user_id, accounts_on_device, signups_in_window)
  values (_user, greatest(v_users,1), v_signup)
  on conflict (user_id) do update
    set accounts_on_device = greatest(excluded.accounts_on_device,1),
        signups_in_window  = excluded.signups_in_window,
        updated_at = now()
  returning * into v_row;

  -- ladder aage badh chuki ho to engine peeche nahi le jaati
  if v_row.state in ('clean','suspicious') then
    v_state := case when jsonb_array_length(v_ev) > 0 then 'suspicious' else 'clean' end;
    update public.account_integrity
       set state = v_state,
           evidence = jsonb_build_object('signals', v_ev, 'device_hash_prefix',
                        case when v_hash is null then null else left(v_hash,12) || '…' end),
           reason = case when v_state = 'suspicious'
                        then 'engine ne dohra account pattern dekha' else null end,
           updated_at = now()
     where user_id = _user
     returning * into v_row;
  end if;

  insert into public.account_integrity_log (user_id, device_hash, event, actor, detail)
  values (_user, v_hash,
    case when v_row.state = 'suspicious' then 'suspicious' else 'evaluated' end,
    'engine',
    jsonb_build_object('accounts_on_device', v_users, 'signups_in_window', v_signup,
                       'signals', v_ev));

  return jsonb_build_object('ok', true, 'state', v_row.state,
    'accounts_on_device', v_users, 'signups_in_window', v_signup,
    'signals', v_ev, 'engine_can_block', false);
end $$;

-- ---------------------------------------------------------------------------
-- 6) STATE — user ko sach dikhana (export window ka baqi waqt bhi)
-- ---------------------------------------------------------------------------
create or replace function public.account_integrity_state(_user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_row public.account_integrity; v_pol public.account_integrity_policy;
begin
  select * into v_pol from public.account_integrity_policy where id = 1;
  select * into v_row from public.account_integrity where user_id = _user;
  return jsonb_build_object(
    'policy', jsonb_build_object(
      'max_accounts_per_device', v_pol.max_accounts_per_device,
      'signup_window_hours', v_pol.signup_window_hours,
      'max_signups_in_window', v_pol.max_signups_in_window,
      'export_window_hours', v_pol.export_window_hours,
      'ban_scope', v_pol.ban_scope,
      'warning_required', v_pol.warning_required),
    'state', coalesce(v_row.state, 'clean'),
    'reason', v_row.reason,
    'evidence', coalesce(v_row.evidence, '{}'::jsonb),
    'accounts_on_device', coalesce(v_row.accounts_on_device, 1),
    'signups_in_window', coalesce(v_row.signups_in_window, 0),
    'warned_at', v_row.warned_at,
    'blocked_at', v_row.blocked_at,
    'export_until', v_row.export_until,
    'export_hours_left', case when v_row.export_until is null then null
      else greatest(0, round(extract(epoch from (v_row.export_until - now())) / 3600.0, 1)) end,
    'purge_after', v_row.purge_after,
    'purged_at', v_row.purged_at,
    'appeal', coalesce((
      select jsonb_build_object('id', a.id, 'state', a.state, 'created_at', a.created_at,
                                'decision_reason', a.decision_reason)
        from public.device_ban_appeals a
       where a.user_id = _user order by a.created_at desc limit 1), 'null'::jsonb),
    'timeline', coalesce((
      select jsonb_agg(jsonb_build_object('event', l.event, 'actor', l.actor,
               'reason', l.reason, 'detail', l.detail, 'at', l.at) order by l.id desc)
        from public.account_integrity_log l where l.user_id = _user limit 50), '[]'::jsonb),
    'append_only', true);
end $$;

-- ---------------------------------------------------------------------------
-- 7) REVIEW QUEUE (sirf reviewer)
-- ---------------------------------------------------------------------------
create or replace function public.account_integrity_queue(_actor uuid, _state text default null)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
begin
  if not public.safety_can_review(_actor) then
    return jsonb_build_object('allowed', false, 'accounts', '[]'::jsonb);
  end if;
  return jsonb_build_object('allowed', true, 'accounts', coalesce((
    select jsonb_agg(jsonb_build_object(
        'user_id', i.user_id, 'state', i.state, 'reason', i.reason,
        'evidence', i.evidence, 'accounts_on_device', i.accounts_on_device,
        'signups_in_window', i.signups_in_window,
        'warned_at', i.warned_at, 'blocked_at', i.blocked_at,
        'export_until', i.export_until, 'purge_after', i.purge_after,
        'updated_at', i.updated_at) order by i.updated_at desc)
      from public.account_integrity i
     where (_state is null and i.state <> 'clean') or i.state = _state), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------
-- 8) WARN — sirf insaan, 12+ char reason, ek hi final warning
-- ---------------------------------------------------------------------------
create or replace function public.account_integrity_warn(_actor uuid, _user uuid, _reason text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_reason text := btrim(coalesce(_reason,'')); v_row public.account_integrity;
begin
  if not public.safety_can_review(_actor) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if length(v_reason) < 12 then
    return jsonb_build_object('ok', false, 'error', 'reason_required',
      'message', 'Warning ke liye kam az kam 12 character ki wajah likhni hogi.');
  end if;
  select * into v_row from public.account_integrity where user_id = _user;
  if v_row.user_id is null then
    perform public.account_integrity_evaluate(_user, null);
    select * into v_row from public.account_integrity where user_id = _user;
  end if;
  if v_row.state = 'warned' then
    return jsonb_build_object('ok', false, 'error', 'already_warned',
      'message', 'Final warning pehle se mojood hai — dobara warning nahi, agla qadam block hai.');
  end if;
  if v_row.state in ('blocked','purged') then
    return jsonb_build_object('ok', false, 'error', 'already_blocked');
  end if;

  update public.account_integrity
     set state = 'warned', reason = v_reason, warned_at = now(), warned_by = _actor,
         released_at = null, updated_at = now()
   where user_id = _user;

  insert into public.account_integrity_log (user_id, event, actor, actor_user, reason)
  values (_user, 'warned', 'human', _actor, v_reason);

  return jsonb_build_object('ok', true, 'state', 'warned', 'next_step', 'block');
end $$;

-- ---------------------------------------------------------------------------
-- 9) BLOCK — warning ke BAAD hi; 72h export window kholta hai; device ban only
-- ---------------------------------------------------------------------------
create or replace function public.account_integrity_block(_actor uuid, _user uuid, _reason text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_reason text := btrim(coalesce(_reason,''));
  v_row public.account_integrity;
  v_pol public.account_integrity_policy;
  v_until timestamptz;
  v_bans int := 0;
  v_hash text;
begin
  if not public.safety_can_review(_actor) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if length(v_reason) < 12 then
    return jsonb_build_object('ok', false, 'error', 'reason_required',
      'message', 'Block ke liye kam az kam 12 character ki wajah likhni hogi.');
  end if;
  select * into v_pol from public.account_integrity_policy where id = 1;
  select * into v_row from public.account_integrity where user_id = _user;
  if v_row.user_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_record');
  end if;
  if v_pol.warning_required and v_row.state <> 'warned' then
    return jsonb_build_object('ok', false, 'error', 'warning_required_first',
      'message', 'Ladder ka qadam skip nahi hota: pehle ek likhi hui final warning.');
  end if;

  v_until := now() + make_interval(hours => v_pol.export_window_hours);

  update public.account_integrity
     set state = 'blocked', reason = v_reason, blocked_at = now(), blocked_by = _actor,
         export_until = v_until, purge_after = v_until, updated_at = now()
   where user_id = _user;

  -- ban SIRF device hash par (IP / network kabhi nahi), aur appealable
  for v_hash in select distinct device_hash from public.device_vault where user_id = _user loop
    insert into public.device_bans (device_hash, reason, banned_by, appealable)
    values (v_hash, 'account integrity: ' || v_reason, _actor, true)
    on conflict (device_hash) do update
      set reason = excluded.reason, banned_by = excluded.banned_by, appealable = true;
    v_bans := v_bans + 1;
    insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
    values (_user, v_hash, 'banned', 'human', jsonb_build_object('reason', v_reason));
  end loop;

  update public.device_vault set state = 'banned', last_seen_at = last_seen_at
   where user_id = _user;

  insert into public.account_integrity_log (user_id, event, actor, actor_user, reason, detail)
  values (_user, 'blocked', 'human', _actor, v_reason,
          jsonb_build_object('devices_banned', v_bans, 'ban_scope', v_pol.ban_scope));
  insert into public.account_integrity_log (user_id, event, actor, actor_user, detail)
  values (_user, 'export_window_opened', 'engine', _actor,
          jsonb_build_object('export_until', v_until, 'hours', v_pol.export_window_hours));

  return jsonb_build_object('ok', true, 'state', 'blocked', 'devices_banned', v_bans,
    'export_until', v_until, 'export_hours', v_pol.export_window_hours,
    'appealable', true);
end $$;

-- ---------------------------------------------------------------------------
-- 10) EXPORT — blocked account 72h tak apna sab kuch le ja sakta hai
-- ---------------------------------------------------------------------------
create or replace function public.account_integrity_export_ready(_user uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_row public.account_integrity;
begin
  select * into v_row from public.account_integrity where user_id = _user;
  if v_row.user_id is null or v_row.state <> 'blocked' then
    return jsonb_build_object('ok', true, 'blocked', false, 'export_open', true);
  end if;
  if v_row.export_until is not null and v_row.export_until < now() then
    return jsonb_build_object('ok', false, 'blocked', true, 'export_open', false,
      'error', 'export_window_closed', 'export_until', v_row.export_until);
  end if;
  insert into public.account_integrity_log (user_id, event, actor, detail)
  values (_user, 'exported', 'user', jsonb_build_object('at', now()));
  return jsonb_build_object('ok', true, 'blocked', true, 'export_open', true,
    'export_until', v_row.export_until,
    'hours_left', greatest(0, round(extract(epoch from (v_row.export_until - now())) / 3600.0, 1)));
end $$;

-- ---------------------------------------------------------------------------
-- 11) RELEASE — appeal granted / ghalat block. Insaan + reason. Device ban hatta hai.
-- ---------------------------------------------------------------------------
create or replace function public.account_integrity_release(_actor uuid, _user uuid, _reason text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_reason text := btrim(coalesce(_reason,'')); v_row public.account_integrity;
begin
  if not public.safety_can_review(_actor) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if length(v_reason) < 12 then
    return jsonb_build_object('ok', false, 'error', 'reason_required');
  end if;
  select * into v_row from public.account_integrity where user_id = _user;
  if v_row.user_id is null then return jsonb_build_object('ok', false, 'error', 'no_record'); end if;
  if v_row.purged_at is not null then
    return jsonb_build_object('ok', false, 'error', 'already_purged',
      'message', 'Data purge ho chuka — release se wapas nahi aata.');
  end if;

  delete from public.device_bans
   where device_hash in (select device_hash from public.device_vault where user_id = _user);
  update public.device_vault set state = 'pending' where user_id = _user and state = 'banned';

  update public.account_integrity
     set state = 'released', reason = v_reason, released_at = now(),
         blocked_at = null, export_until = null, purge_after = null, warned_at = null,
         updated_at = now()
   where user_id = _user;

  insert into public.account_integrity_log (user_id, event, actor, actor_user, reason)
  values (_user, 'released', 'human', _actor, v_reason);

  return jsonb_build_object('ok', true, 'state', 'released');
end $$;

-- ---------------------------------------------------------------------------
-- 12) PURGE — sirf export window guzarne ke baad; service_role/cron
-- ---------------------------------------------------------------------------
create or replace function public.account_integrity_purge_due()
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_user uuid; v_done int := 0;
begin
  for v_user in
    select user_id from public.account_integrity
     where state = 'blocked' and purge_after is not null
       and purge_after < now() and purged_at is null
  loop
    -- sirf is user ka data. Ledger + integrity record subooot ke liye zinda.
    delete from public.chat_messages where sender_id = v_user;
    delete from public.chat_work_items where owner_user_id = v_user or created_by = v_user;
    delete from public.device_vault where user_id = v_user;

    update public.account_integrity
       set state = 'purged', purged_at = now(), updated_at = now()
     where user_id = v_user;

    insert into public.account_integrity_log (user_id, event, actor, detail)
    values (v_user, 'purged', 'engine',
            jsonb_build_object('after_export_window', true, 'at', now()));
    v_done := v_done + 1;
  end loop;
  return jsonb_build_object('ok', true, 'purged', v_done);
end $$;

-- ---------------------------------------------------------------------------
-- 13) execute grants
-- ---------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'public.account_integrity_evaluate(uuid,text)',
    'public.account_integrity_state(uuid)',
    'public.account_integrity_queue(uuid,text)',
    'public.account_integrity_warn(uuid,uuid,text)',
    'public.account_integrity_block(uuid,uuid,text)',
    'public.account_integrity_export_ready(uuid)',
    'public.account_integrity_release(uuid,uuid,text)',
    'public.account_integrity_purge_due()'
  ]
  loop
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ============================================================================
-- GREEN CHECK (Supabase editor mein last query):
--   select public.account_integrity_evaluate(auth.uid(), null);
--   select public.account_integrity_state(auth.uid());
--   select public.account_integrity_queue(auth.uid());
-- ============================================================================
