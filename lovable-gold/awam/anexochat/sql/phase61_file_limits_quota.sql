-- ============================================================================
-- PHASE 61 — FILE LIMITS + MONTHLY BANDWIDTH QUOTA (founder 3 Nov 2026 13:09 / 13:17 PKT: "yeh wala chart ab reality hai")
-- ADVANCED SQL (founder 13:19): the chart lives in ONE immutable function, a trigger refuses any row that disagrees with it (so an old script re-run can never bring back 2/5/7 GB),
-- the quota numbers are GENERATED columns of the one dial (sends_per_month), the thresholds are a pure function, dedup is a database rule, and a selftest + CHECK file prove it.
--   Business          500 MB per file   50 GB per user per month   20 users  x 50 GB  = ~1 TB organisation pool
--   Business Pro      1.5 GB            150 GB                     570 users x 150 GB = 85.5 TB fair-use
--   Business Premium  4 GB              400 GB                     21,000 users CAP (founder 13:38: NOT unlimited; only the PRICE page shows the word 'Unlimited'), 21,000 x 400 GB = 8.4 PB fair-use
--   monthly quota = per file x sends_per_month (100, his dial); hour burst = per file x 10; warn at 80%, THROTTLE at 100%, NEVER block; inbound is never closed.
--   FREE (counted 0): sha256 dedup (same content already stored in the workspace), re-download (downloads are never written to the ledger), inbound receiving.
-- Needs phase13_15_file_engine.sql (edited the same day: its seed rows now carry the chart). Safe to run again. Selftest rolls back.
-- Honest limit: the byte-rate THROTTLE itself is applied by the Rust transfer engine from the 'rate_mode' this file returns; SQL only decides, never blocks.
-- ============================================================================
do $$ begin
  if to_regclass('public.file_plan_limits') is null or to_regclass('public.chat_transfer_ledger') is null then raise exception 'PHASE 61 needs phase13_15_file_engine.sql first'; end if;
end $$;

-- 1) THE CHART, in one place -------------------------------------------------------------------------------------------------------------------------------------------
-- (plan -> per-file bytes, user cap) ; every other number below is derived from these two facts.
create or replace function public.file_chart(p_plan text) returns table (max_file_bytes bigint, max_users integer)
language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select v.f, v.u from (values
    ('business',         524288000::bigint,  20),
    ('ai_pro',           524288000::bigint,  20),
    ('business_pro',     1610612736::bigint, 570),
    ('ai_business',      1610612736::bigint, 570),
    ('business_premium', 4294967296::bigint, 21000),
    ('enterprise',       4294967296::bigint, 21000),
    ('ai_executive',     4294967296::bigint, 21000)
  ) as v(p, f, u) where v.p = lower(coalesce(p_plan, ''))
$$;
comment on function public.file_chart(text) is 'PHASE 61: the founder chart (3 Nov 2026). 500 MB / 1.5 GB / 4 GB per file; 20 / 570 / 21,000 users (Premium; the price page alone says Unlimited). The only place these numbers are typed.';

-- 2) columns: the dial and everything derived from it ---------------------------------------------------------------------------------------------------------------------
alter table public.file_plan_limits add column if not exists sends_per_month integer not null default 100;
alter table public.file_plan_limits add column if not exists max_users integer;
alter table public.file_plan_limits add column if not exists throttle_never_block boolean not null default true;
alter table public.file_plan_limits add column if not exists per_user_monthly_bytes bigint generated always as (max_file_bytes * sends_per_month) stored;
alter table public.file_plan_limits add column if not exists burst_hour_bytes bigint generated always as (max_file_bytes * 10) stored;
alter table public.file_plan_limits add column if not exists org_pool_transfer_bytes bigint generated always as (case when max_users is null then null else max_file_bytes * sends_per_month * max_users end) stored;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'file_plan_limits_dial_sane') then
    alter table public.file_plan_limits add constraint file_plan_limits_dial_sane check (sends_per_month between 1 and 10000 and (max_users is null or max_users > 0));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'file_plan_limits_never_block') then
    alter table public.file_plan_limits add constraint file_plan_limits_never_block check (throttle_never_block);   -- the rule "throttle, never block" is a constraint, not a habit
  end if;
end $$;

-- 3) the seed rows (idempotent, same values as the edited phase13_15) ----------------------------------------------------------------------------------------------------
insert into public.file_plan_limits (plan, max_file_bytes, pool_bytes, transfer_unlimited, monthly_transfer_bytes, max_concurrent, versions_kept, max_users)
select c.plan, f.max_file_bytes, c.pool, false, null, c.conc, c.ver, f.max_users
  from (values ('business', 274877906944::bigint, 3, 10), ('business_pro', 1099511627776::bigint, 6, 30), ('business_premium', 1099511627776::bigint, 8, 50), ('enterprise', 1099511627776::bigint, 8, 50),
               ('ai_pro', 274877906944::bigint, 4, 10), ('ai_business', 1099511627776::bigint, 6, 30), ('ai_executive', 2199023255552::bigint, 8, 50)) as c(plan, pool, conc, ver)
  cross join lateral public.file_chart(c.plan) f
on conflict (plan) do update set max_file_bytes = excluded.max_file_bytes, max_users = excluded.max_users, transfer_unlimited = false, monthly_transfer_bytes = null;
update public.file_plan_limits set max_file_bytes = 4294967296, transfer_unlimited = true, monthly_transfer_bytes = null where plan = 'founder';   -- founder: no quota (founder side is separate)

-- 4) the trigger that makes the chart unbreakable ---------------------------------------------------------------------------------------------------------------------------
create or replace function public._file_chart_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare c record;
begin
  select * into c from public.file_chart(new.plan);
  if found then
    if new.max_users is null and tg_op = 'INSERT' then new.max_users := c.max_users; end if;   -- the edited phase13_15 seed (no max_users column in its list) re-runs cleanly: the chart fills it in
    if new.max_file_bytes is distinct from c.max_file_bytes or new.max_users is distinct from c.max_users then
      raise exception 'file_plan_limits.%: the founder chart says max_file_bytes=% and max_users=%, not % / % (change file_chart(), not the row)', new.plan, c.max_file_bytes, c.max_users, new.max_file_bytes, new.max_users using errcode = 'check_violation';
    end if;
    if new.transfer_unlimited or new.monthly_transfer_bytes is not null then
      raise exception 'file_plan_limits.%: quota is per user (per_user_monthly_bytes); the old workspace-wide limit stays NULL and transfer_unlimited stays false', new.plan using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists file_plan_limits_chart on public.file_plan_limits;
create trigger file_plan_limits_chart before insert or update on public.file_plan_limits for each row execute function public._file_chart_guard();
update public.file_plan_limits set plan = plan;   -- run the guard over every existing row once: a row that disagrees with the chart stops this migration loudly

-- 5) thresholds as a pure function (the only place 80% / 100% live) ----------------------------------------------------------------------------------------------------------
create or replace function public.file_quota_level(p_used bigint, p_cap bigint) returns text language sql immutable parallel safe set search_path = pg_catalog as $$
  select case when p_cap is null or p_cap <= 0 then 'none'
              when p_used >= p_cap then 'throttle'      -- 100%: slow down, NEVER block
              when p_used::numeric >= p_cap * 0.8 then 'warn'   -- 80%: warn the user
              else 'ok' end
$$;

-- 6) dedup is a database rule: same bytes + same sha256 already READY in this workspace = counted once ------------------------------------------------------------------------
create or replace function public.file_is_dedup(p_version uuid, p_workspace uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public as $$
  select v.file_sha256 is not null and exists (
    select 1 from public.chat_file_versions o join public.chat_files f on f.id = o.file_id
     where f.workspace_id = p_workspace and f.deleted_at is null and o.state = 'ready' and o.id <> v.id and o.file_sha256 = v.file_sha256 and o.bytes = v.bytes)
  from public.chat_file_versions v where v.id = p_version
$$;

-- 7) the quota state (what the UI mirrors and the Rust engine enforces) -----------------------------------------------------------------------------------------------------------
create or replace function public.file_quota_state_for(p_lim public.file_plan_limits, p_user uuid, p_workspace uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_used bigint; v_hour bigint; v_org bigint; v_level text; v_month date := date_trunc('month', (now() at time zone 'utc'))::date;
begin
  if p_lim.max_file_bytes <= 0 then return jsonb_build_object('entitled', false, 'level', 'none', 'rate_mode', 'full'); end if;
  select coalesce(sum(bytes), 0) into v_used from public.chat_transfer_ledger where user_id = p_user and direction = 'upload' and day >= v_month;
  select coalesce(sum(bytes), 0) into v_hour from public.chat_transfer_ledger where user_id = p_user and direction = 'upload' and created_at > now() - interval '1 hour';
  select coalesce(sum(bytes), 0) into v_org  from public.chat_transfer_ledger where workspace_id = p_workspace and direction = 'upload' and day >= v_month;
  v_level := public.file_quota_level(v_used, p_lim.per_user_monthly_bytes);
  if p_lim.transfer_unlimited then v_level := 'none'; end if;
  return jsonb_build_object(
    'entitled', true, 'plan', p_lim.plan, 'sends_per_month', p_lim.sends_per_month,
    'per_file_bytes', p_lim.max_file_bytes, 'per_user_monthly_bytes', p_lim.per_user_monthly_bytes, 'used_month_bytes', v_used,
    'percent', case when p_lim.per_user_monthly_bytes > 0 then round(v_used::numeric * 100 / p_lim.per_user_monthly_bytes, 1) else 0 end,
    'level', v_level,
    'rate_mode', case when v_level = 'throttle' then 'slow' else 'full' end,        -- never 'blocked'
    'blocked', false,
    'burst_hour_bytes', p_lim.burst_hour_bytes, 'used_hour_bytes', v_hour, 'burst_left_bytes', greatest(p_lim.burst_hour_bytes - v_hour, 0),
    'org_month_bytes', v_org, 'org_pool_bytes', p_lim.org_pool_transfer_bytes, 'org_fair_use', true,
    'inbound', 'always_open', 'redownload', 'free', 'dedup', 'counted_once');
end $$;
create or replace function public.file_quota_state(p_user uuid, p_workspace uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$ select public.file_quota_state_for(public.file_plan_for(p_user), p_user, p_workspace) $$;

-- 8) the two engine functions re-issued with the chart (file_pool_state now carries the quota; file_chunk_ack counts dedup once) ---------------------------------------------------
create or replace function public.file_pool_state(_user uuid, _workspace uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
declare
  v_lim public.file_plan_limits;
  v_stored bigint;
  v_month bigint;
  v_active int;
begin
  v_lim := public.file_plan_for(_user);

  select coalesce(sum(v.bytes), 0) into v_stored
  from public.chat_file_versions v
  join public.chat_files f on f.id = v.file_id
  where f.workspace_id = _workspace and v.state = 'ready' and f.deleted_at is null;

  select coalesce(sum(bytes), 0) into v_month
  from public.chat_transfer_ledger
  where workspace_id = _workspace
    and day >= date_trunc('month', (now() at time zone 'utc'))::date;

  select count(*) into v_active
  from public.chat_transfers
  where workspace_id = _workspace and state = 'active';

  return jsonb_build_object(
    'plan', v_lim.plan,
    'entitled', v_lim.max_file_bytes > 0,
    'max_file_bytes', v_lim.max_file_bytes,
    'pool_bytes', v_lim.pool_bytes,
    'stored_bytes', v_stored,
    'remaining_bytes', greatest(v_lim.pool_bytes - v_stored, 0),
    'percent', case when v_lim.pool_bytes > 0
                    then round((v_stored::numeric / v_lim.pool_bytes) * 100, 1) else 0 end,
    'transfer_unlimited', v_lim.transfer_unlimited,
    'transfer_month_bytes', v_month,
    'transfer_month_limit', v_lim.monthly_transfer_bytes,
    'max_concurrent', v_lim.max_concurrent,
    'active_transfers', v_active,
    'versions_kept', v_lim.versions_kept,
    'quota', public.file_quota_state_for(v_lim, _user, _workspace)
  );
end $$;

create or replace function public.file_chunk_ack(
  _user uuid,
  _transfer uuid,
  _idx int,
  _bytes bigint,
  _sha256 text,
  _server_sha256 text
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_t public.chat_transfers;
  v_state text;
  v_done bigint;
begin
  select * into v_t from public.chat_transfers where id = _transfer and user_id = _user;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'transfer_not_found');
  end if;

  v_state := case
    when _server_sha256 is null or _sha256 is null then 'stored'
    when lower(_server_sha256) = lower(_sha256) then 'verified'
    else 'corrupt'
  end;

  update public.chat_file_chunks
     set bytes = coalesce(nullif(_bytes, 0), bytes),
         sha256 = coalesce(_sha256, sha256),
         state = v_state,
         attempts = attempts + 1,
         updated_at = now()
   where version_id = v_t.version_id and idx = _idx;

  update public.chat_transfers
     set last_seen_at = now(), state = case when state = 'paused' then 'active' else state end
   where id = _transfer;

  -- PHASE 61 (founder formula): a verified chunk counts against the user's monthly quota UNLESS the same content (sha256 + size) is already stored ready in this workspace = dedup, counted once
  if v_state = 'verified' and not public.file_is_dedup(v_t.version_id, v_t.workspace_id) then
    insert into public.chat_transfer_ledger (workspace_id, user_id, transfer_id, direction, bytes)
    values (v_t.workspace_id, _user, _transfer, 'upload', coalesce(_bytes, 0));
  end if;

  select coalesce(sum(bytes), 0) into v_done
    from public.chat_file_chunks where version_id = v_t.version_id and state = 'verified';

  return jsonb_build_object(
    'ok', v_state <> 'corrupt',
    'chunk_state', v_state,
    'bytes_done', v_done,
    'bytes_total', v_t.bytes_total,
    'percent', case when v_t.bytes_total > 0
                    then round((v_done::numeric / v_t.bytes_total) * 100, 2) else 0 end
  );
end $$;

-- 9) SELFTEST (rolls back) ---------------------------------------------------------------------------------------------------------------------------------------------------------------
create or replace function public.file_quota_phase61_selftest() returns text
language plpgsql security definer set search_path = public, extensions set statement_timeout = '60s' as $$
declare r text := ''; l public.file_plan_limits; u uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); w uuid := gen_random_uuid(); j jsonb; n int; b_led bigint;
        v1 uuid; v2 uuid; f1 uuid; f2 uuid; u_real uuid; sha text := repeat('ab', 32);
begin
  select count(*) into b_led from public.chat_transfer_ledger;
  -- 1) the chart IS the table
  for l in select * from public.file_plan_limits where plan in ('business','business_pro','business_premium','enterprise') loop
    if l.plan = 'business' and (l.max_file_bytes <> 500::bigint*1024*1024 or l.per_user_monthly_bytes <> 500::bigint*1024*1024*100 or l.burst_hour_bytes <> 500::bigint*1024*1024*10 or l.org_pool_transfer_bytes <> 500::bigint*1024*1024*100*20) then raise exception 'business chart wrong: %', row_to_json(l); end if;
    if l.plan = 'business_pro' and (l.max_file_bytes <> 1536::bigint*1024*1024 or l.per_user_monthly_bytes <> 150::bigint*1024*1024*1024 or l.org_pool_transfer_bytes <> 150::bigint*1024*1024*1024*570) then raise exception 'business_pro chart wrong: %', row_to_json(l); end if;
    if l.plan in ('business_premium','enterprise') and (l.max_file_bytes <> 4::bigint*1024*1024*1024 or l.per_user_monthly_bytes <> 400::bigint*1024*1024*1024 or l.org_pool_transfer_bytes <> 400::bigint*1024*1024*1024*21000 or l.max_users <> 21000) then raise exception 'premium chart wrong: %', row_to_json(l); end if;
    if l.transfer_unlimited or l.monthly_transfer_bytes is not null or not l.throttle_never_block then raise exception '% still carries the old workspace-wide quota', l.plan; end if;
  end loop;
  if exists (select 1 from public.file_plan_limits where max_file_bytes in (2147483648, 5368709120, 7516192768)) then raise exception 'an old 2/5/7 GB gate is still in the table'; end if;
  r := r || 'chart is the table (500 MB / 1.5 GB / 4 GB, 50 / 150 / 400 GB, 20 x 50 GB, 570 x 150 GB, Premium 21,000 users x 400 GB), no 2/5/7 GB left OK; ';
  -- 2) the guard refuses drift
  begin update public.file_plan_limits set max_file_bytes = 5368709120 where plan = 'business_pro'; raise exception 'guard let the old 5 GB back in'; exception when check_violation then null; end;
  begin update public.file_plan_limits set transfer_unlimited = true where plan = 'business'; raise exception 'guard let unlimited transfer back in'; exception when check_violation then null; end;
  begin update public.file_plan_limits set throttle_never_block = false where plan = 'business'; raise exception 'blocking was allowed'; exception when check_violation then null; end;
  begin update public.file_plan_limits set sends_per_month = 0 where plan = 'business'; raise exception 'dial 0 allowed'; exception when check_violation then null; end;
  r := r || 'guard refuses 5 GB, unlimited, blocking and a zero dial OK; ';
  -- 3) thresholds: 80% warn, 100% throttle, never block
  if public.file_quota_level(0, 100) <> 'ok' or public.file_quota_level(79, 100) <> 'ok' or public.file_quota_level(80, 100) <> 'warn' or public.file_quota_level(99, 100) <> 'warn' or public.file_quota_level(100, 100) <> 'throttle' or public.file_quota_level(10000, 100) <> 'throttle' or public.file_quota_level(5, 0) <> 'none' then raise exception 'threshold function wrong'; end if;
  r := r || 'thresholds 80% warn / 100% throttle OK; ';
  -- 4) quota state from real ledger rows: dedup + never blocked
  select * into l from public.file_plan_limits where plan = 'business';
  insert into public.chat_transfer_ledger (workspace_id, user_id, direction, bytes) values (w, u, 'upload', (l.per_user_monthly_bytes * 0.85)::bigint);
  j := public.file_quota_state_for(l, u, w);
  if j ->> 'level' <> 'warn' or j ->> 'rate_mode' <> 'full' or (j ->> 'blocked')::boolean then raise exception 'at 85%% expected warn/full: %', j; end if;
  insert into public.chat_transfer_ledger (workspace_id, user_id, direction, bytes) values (w, u, 'upload', l.per_user_monthly_bytes);
  j := public.file_quota_state_for(l, u, w);
  if j ->> 'level' <> 'throttle' or j ->> 'rate_mode' <> 'slow' or (j ->> 'blocked')::boolean or j ->> 'inbound' <> 'always_open' then raise exception 'at 100%% expected throttle/slow and never blocked: %', j; end if;
  j := public.file_quota_state_for(l, u2, w);
  if j ->> 'level' <> 'ok' or (j ->> 'org_month_bytes')::bigint <= 0 then raise exception 'another user must start at ok while the org pool shows the use: %', j; end if;
  r := r || 'warn at 85%, throttle at 100% (slow, blocked=false, inbound open), per user, org pool visible OK; ';
  -- 5) dedup: same bytes + sha already ready in the workspace is counted once (needs one real account for the foreign keys; without one this part says SKIP)
  select id into u_real from auth.users limit 1;
  if u_real is null then r := r || 'dedup SKIP (no account in auth.users); ';
  else
  begin
  insert into public.chat_files (workspace_id, owner_id, name, content_type) values (w, u_real, 'a.pdf', 'application/pdf') returning id into f1;
  insert into public.chat_file_versions (file_id, version, bytes, content_type, file_sha256, chunk_size, chunk_count, storage_prefix, created_by, state) values (f1, 1, 1000, 'application/pdf', sha, 1048576, 1, w || '/' || f1 || '/v1', u_real, 'ready') returning id into v1;
  insert into public.chat_files (workspace_id, owner_id, name, content_type) values (w, u_real, 'same.pdf', 'application/pdf') returning id into f2;
  insert into public.chat_file_versions (file_id, version, bytes, content_type, file_sha256, chunk_size, chunk_count, storage_prefix, created_by, state) values (f2, 1, 1000, 'application/pdf', sha, 1048576, 1, w || '/' || f2 || '/v1', u_real, 'transferring') returning id into v2;
  if not public.file_is_dedup(v2, w) then raise exception 'the same file was not seen as a duplicate'; end if;
  if public.file_is_dedup(v1, w) then raise exception 'the first copy must not count as its own duplicate'; end if;
  update public.chat_file_versions set file_sha256 = repeat('cd', 32) where id = v2;
  if public.file_is_dedup(v2, w) then raise exception 'a different file was treated as a duplicate'; end if;
  r := r || 'dedup: same sha + size counted once, different file counted OK; ';
  exception when foreign_key_violation then
    -- an older schema whose foreign keys point somewhere else (e.g. a renamed _legacy table): say so plainly, do not fake a pass. phase13_15 now repairs those keys.
    r := r || 'dedup SKIP (foreign keys of chat_files/chat_file_versions point to another table: run phase13_15_file_engine.sql again, it repairs them; ' || sqlerrm || '); ';
  end;
  end if;
  -- 6) pool state carries the quota
  if public.file_pool_state(u, w) ? 'quota' is not true then raise exception 'file_pool_state lost the quota key'; end if;
  r := r || 'file_pool_state carries the quota OK; ';
  raise exception 'ROLLBACK_SELFTEST';
exception when others then
  if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'PHASE 61 selftest FAIL: %', sqlerrm; end if;
  if (select count(*) from public.chat_transfer_ledger) <> b_led then raise exception 'PHASE 61 selftest left ledger rows behind'; end if;
  return 'PHASE 61 selftest OK — ' || r || 'rollback clean';
end $$;

do $$ declare f text; begin
  foreach f in array array['public.file_chart(text)', 'public._file_chart_guard()', 'public.file_quota_level(bigint,bigint)', 'public.file_is_dedup(uuid,uuid)',
                           'public.file_quota_state_for(public.file_plan_limits,uuid,uuid)', 'public.file_quota_state(uuid,uuid)', 'public.file_quota_phase61_selftest()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
  grant execute on function public.file_quota_state(uuid, uuid) to authenticated;   -- the user may read only their own state (file_plan_for resolves by the id passed; Rust passes the token's id)
end $$;
revoke execute on function public.file_quota_state(uuid, uuid) from authenticated;   -- keep it Rust-only: the id must come from the verified token, never from the browser
do $$ begin raise notice '%', public.file_quota_phase61_selftest(); end $$;

-- RUNBOOK: after phase13_15_file_engine.sql. Undo: drop trigger file_plan_limits_chart on public.file_plan_limits; drop the functions above; the added columns are harmless.
