
-- E174 (QPERF-1, 15 Nov 2026): THE MAIL SPEED LEDGER. How fast is the founder's mail, per stage, p50 / p90 / p95 / p99 / p99.9, and is the speed promise (SLO) being kept?
-- Design + research: docs/claude/QPERF-PLAN-15NOV.md (Google SRE workbook multi-window multi-burn-rate; HDR-histogram style log-linear buckets).
-- TECHNOLOGY: SQL (PostgreSQL 16): day range partitions + BRIN, forced RLS, append-only triggers on every partition, a daily SHA-256 SEAL chain over the ordered samples (tamper evidence
-- without one hash per sample), a per-minute log-linear histogram (relative error below 0.8 percent, mergeable) for long windows, EXACT percentile_disc on raw samples for short windows,
-- the 3-tier multi-window burn rate, security-definer doors with a fixed search_path (service_role only). Privacy by design: only durations, outcome class and size bucket are stored.
-- Needs: E102 (_fa_lp length-prefix helper), pgcrypto (extensions.digest).
-- Stages: accept (RCPT to end of DATA), scan (ClamAV), seal (AES-256-GCM + ML-KEM wrap), commit (the SQL deliver door), total.
do $$ begin
  if to_regprocedure('public._fa_lp(text)') is null then raise exception 'E174: _fa_lp missing (run E102 first)'; end if;
  if to_regprocedure('extensions.digest(bytea,text)') is null then raise exception 'E174: pgcrypto digest missing'; end if;
end $$;

-- ===========================================================================================================================================
-- 1) THE SAMPLES (partitioned by day, append-only)
-- ===========================================================================================================================================
create table if not exists public.fmail_perf_sample (
  ts          timestamptz not null,
  stage       text   not null check (stage in ('accept', 'scan', 'seal', 'commit', 'total')),
  outcome     text   not null check (outcome in ('ok', 'quarantine', 'reject', 'error')),
  size_bucket text   not null check (size_bucket in ('xs', 's', 'm', 'l', 'xl')),
  dur_us      bigint not null check (dur_us >= 0 and dur_us <= 3600000000)
) partition by range (ts);
alter table public.fmail_perf_sample enable row level security;
alter table public.fmail_perf_sample force row level security;
revoke all on public.fmail_perf_sample from public, anon, authenticated;

create or replace function public._fp_immutable() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin raise exception 'E174: the mail speed ledger is append-only (% refused)', tg_op using errcode = '42501'; end $$;

-- 2) THE PARTITION MANAGER: yesterday .. today+2 exist; anything older than 35 days is DETACHED (kept as a table, never deleted silently).
create or replace function public.fmail_perf_partitions174() returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare d date; v_name text; v_made int := 0; v_detached int := 0; r record;
begin
  for d in select generate_series((now() at time zone 'utc')::date - 1, (now() at time zone 'utc')::date + 2, interval '1 day')::date loop
    v_name := 'fmail_perf_sample_y' || to_char(d, 'YYYYMMDD');
    if to_regclass('public.' || v_name) is null then
      execute format('create table public.%I partition of public.fmail_perf_sample for values from (%L) to (%L)', v_name, d::timestamptz, (d + 1)::timestamptz);
      execute format('create index %I on public.%I using brin (ts)', v_name || '_brin', v_name);
      execute format('alter table public.%I enable row level security', v_name);
      execute format('alter table public.%I force row level security', v_name);
      execute format('revoke all on public.%I from public, anon, authenticated', v_name);
      execute format('create policy "service_role_internal_access" on public.%I for all to service_role using (true) with check (true)', v_name);
      execute format('create trigger %I before update or delete on public.%I for each row execute function public._fp_immutable()', v_name || '_row', v_name);
      execute format('create trigger %I before truncate on public.%I for each statement execute function public._fp_immutable()', v_name || '_trunc', v_name);
      v_made := v_made + 1;
    end if;
  end loop;
  for r in select c.relname from pg_inherits i join pg_class c on c.oid = i.inhrelid join pg_class p on p.oid = i.inhparent
           where p.relname = 'fmail_perf_sample' and c.relname ~ '^fmail_perf_sample_y[0-9]{8}$'
             and to_date(substr(c.relname, 20, 8), 'YYYYMMDD') < (now() at time zone 'utc')::date - 35 loop
    execute format('alter table public.fmail_perf_sample detach partition public.%I', r.relname); v_detached := v_detached + 1;
  end loop;
  return jsonb_build_object('created', v_made, 'detached', v_detached);
end $$;
revoke all on function public.fmail_perf_partitions174() from public, anon, authenticated;
grant execute on function public.fmail_perf_partitions174() to service_role;
select public.fmail_perf_partitions174();

-- E65 law: every RLS-on table carries an explicit policy (service_role only; anon/authenticated have no grant and no policy). Idempotent; also covers partitions made before this fix.
do $$ declare r record; begin
  for r in select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p') and c.relrowsecurity
             and (c.relname in ('fmail_perf_sample', 'fmail_perf_seal', 'fmail_perf_hist', 'fmail_perf_state', 'fmail_perf_slo') or c.relname ~ '^fmail_perf_sample_y[0-9]{8}$') loop
    execute format('drop policy if exists "service_role_internal_access" on public.%I', r.relname);
    execute format('create policy "service_role_internal_access" on public.%I for all to service_role using (true) with check (true)', r.relname);
  end loop;
end $$;

-- ===========================================================================================================================================
-- 3) THE INGEST DOOR: the Rust batch writer sends up to 500 samples; every element is checked against the closed lists; nothing is guessed.
-- ===========================================================================================================================================
create or replace function public.fmail_perf_ingest174(p_batch jsonb) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n int; v_ok int; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  if p_batch is null or jsonb_typeof(p_batch) <> 'array' then raise exception 'E174: batch must be a JSON array' using errcode = '22023'; end if;
  v_n := jsonb_array_length(p_batch);
  if v_n > 500 then raise exception 'E174: at most 500 samples per batch' using errcode = '22023'; end if;
  perform public.fmail_perf_partitions174();
  with t as (
    select (e ->> 'ts_ms') as ts_ms, e ->> 'stage' as stage, e ->> 'outcome' as outcome, e ->> 'size' as sz, (e ->> 'dur_us') as dur
    from jsonb_array_elements(p_batch) e where jsonb_typeof(e) = 'object'),
  good as (
    select to_timestamp(ts_ms::bigint / 1000.0) as ts, stage, outcome, sz as size_bucket, dur::bigint as dur_us from t
    where ts_ms ~ '^[0-9]{10,14}$' and dur ~ '^[0-9]{1,10}$' and dur::bigint <= 3600000000
      and stage in ('accept', 'scan', 'seal', 'commit', 'total') and outcome in ('ok', 'quarantine', 'reject', 'error') and sz in ('xs', 's', 'm', 'l', 'xl')
      and ts_ms::bigint between v_now - 86400000 and v_now + 60000)
  insert into public.fmail_perf_sample (ts, stage, outcome, size_bucket, dur_us) select ts, stage, outcome, size_bucket, dur_us from good;
  get diagnostics v_ok = row_count;
  return jsonb_build_object('accepted', v_ok, 'rejected', v_n - v_ok);
end $$;
revoke all on function public.fmail_perf_ingest174(jsonb) from public, anon, authenticated;
grant execute on function public.fmail_perf_ingest174(jsonb) to service_role;

-- ===========================================================================================================================================
-- 4) THE DAILY SEAL CHAIN: one append-only row per closed UTC day = count + SHA-256 over the ordered samples + the previous seal.
-- ===========================================================================================================================================
create table if not exists public.fmail_perf_seal (
  day date primary key, n bigint not null check (n >= 0), digest text not null check (digest ~ '^[0-9a-f]{64}$'),
  prev text not null check (prev ~ '^[0-9a-f]{64}$'), seal text not null check (seal ~ '^[0-9a-f]{64}$'), sealed_at timestamptz not null default now());
alter table public.fmail_perf_seal enable row level security;
alter table public.fmail_perf_seal force row level security;
revoke all on public.fmail_perf_seal from public, anon, authenticated;
drop trigger if exists fmail_perf_seal_ro on public.fmail_perf_seal;
create trigger fmail_perf_seal_ro before update or delete on public.fmail_perf_seal for each row execute function public._fp_immutable();
drop trigger if exists fmail_perf_seal_tr on public.fmail_perf_seal;
create trigger fmail_perf_seal_tr before truncate on public.fmail_perf_seal for each statement execute function public._fp_immutable();

create or replace function public._fp_digest(p_day date) returns table (n bigint, digest text)
language sql stable set search_path = pg_catalog, public, extensions as $$
  select count(*), encode(extensions.digest(convert_to(coalesce(string_agg(s.ts::text || ':' || s.stage || ':' || s.outcome || ':' || s.size_bucket || ':' || s.dur_us::text, E'\n' order by s.ts, s.stage, s.dur_us, s.outcome, s.size_bucket), ''), 'UTF8'), 'sha256'), 'hex')
  from public.fmail_perf_sample s where s.ts >= p_day::timestamptz and s.ts < (p_day + 1)::timestamptz
$$;
create or replace function public._fp_seal_hash(p_prev text, p_day date, p_n bigint, p_digest text) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(public._fa_lp(p_prev) || public._fa_lp(p_day::text) || public._fa_lp(p_n::text) || public._fa_lp(p_digest), 'sha256'), 'hex')
$$;

create or replace function public.fmail_perf_seal174(p_day date) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_prev text; v_last date; v_n bigint; v_dig text; v_seal text;
begin
  if p_day is null or p_day >= (now() at time zone 'utc')::date then raise exception 'E174: only a closed UTC day can be sealed' using errcode = '22023'; end if;
  if exists (select 1 from public.fmail_perf_seal where day = p_day) then return jsonb_build_object('ok', true, 'already', true); end if;
  select day, seal into v_last, v_prev from public.fmail_perf_seal order by day desc limit 1;
  if v_last is not null and p_day < v_last then raise exception 'E174: days are sealed in order (last sealed %)', v_last using errcode = '22023'; end if;
  v_prev := coalesce(v_prev, repeat('0', 64));
  select n, digest into v_n, v_dig from public._fp_digest(p_day);
  v_seal := public._fp_seal_hash(v_prev, p_day, v_n, v_dig);
  insert into public.fmail_perf_seal (day, n, digest, prev, seal) values (p_day, v_n, v_dig, v_prev, v_seal);
  return jsonb_build_object('ok', true, 'day', p_day, 'n', v_n);
end $$;
revoke all on function public.fmail_perf_seal174(date) from public, anon, authenticated;
grant execute on function public.fmail_perf_seal174(date) to service_role;

-- verify: the chain links, every seal re-hashes, and every sealed day whose partition is still attached still hashes to its digest. Returns the number of seals; raises on the first problem.
create or replace function public.fmail_perf_seal_verify174() returns int
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare r record; v_prev text := repeat('0', 64); v_cnt int := 0; v_n bigint; v_dig text;
begin
  for r in select * from public.fmail_perf_seal order by day loop
    if r.prev <> v_prev then raise exception 'E174: seal chain broken at %', r.day; end if;
    if public._fp_seal_hash(r.prev, r.day, r.n, r.digest) <> r.seal then raise exception 'E174: seal % does not re-hash', r.day; end if;
    if to_regclass('public.fmail_perf_sample_y' || to_char(r.day, 'YYYYMMDD')) is not null then
      select n, digest into v_n, v_dig from public._fp_digest(r.day);
      if v_n <> r.n or v_dig <> r.digest then raise exception 'E174: the samples of % changed after sealing', r.day; end if;
    end if;
    v_prev := r.seal; v_cnt := v_cnt + 1;
  end loop;
  return v_cnt;
end $$;
revoke all on function public.fmail_perf_seal_verify174() from public, anon, authenticated;
grant execute on function public.fmail_perf_seal_verify174() to service_role;

-- ===========================================================================================================================================
-- 5) THE LOG-LINEAR BUCKET (HDR-histogram idea): values below 256 us are exact; above, 128 sub-buckets per power of two = relative error below 1/128 (0.78 percent).
-- ===========================================================================================================================================
create or replace function public._fp_bucket(p_us bigint) returns int
language plpgsql immutable set search_path = pg_catalog, public as $$
declare e int; sub bigint;
begin
  if p_us < 256 then return p_us::int; end if;
  e := floor(log(2::numeric, p_us::numeric))::int;
  while (1::bigint << (e + 1)) <= p_us loop e := e + 1; end loop;
  while (1::bigint << e) > p_us loop e := e - 1; end loop;
  sub := p_us >> (e - 7);
  return (256 + (e - 8) * 128 + (sub - 128))::int;
end $$;
-- the largest value that falls in a bucket (what a percentile reports: never below the truth, at most 0.78 percent above)
create or replace function public._fp_bucket_hi(p_idx int) returns bigint
language plpgsql immutable set search_path = pg_catalog, public as $$
declare k int; e int; sub bigint;
begin
  if p_idx < 256 then return p_idx; end if;
  k := p_idx - 256; e := 8 + k / 128; sub := 128 + k % 128;
  return ((sub + 1) << (e - 7)) - 1;
end $$;

create table if not exists public.fmail_perf_hist (
  minute timestamptz not null, stage text not null check (stage in ('accept', 'scan', 'seal', 'commit', 'total')),
  outcome text not null check (outcome in ('ok', 'quarantine', 'reject', 'error')), bucket int not null check (bucket >= 0), n bigint not null check (n > 0),
  primary key (minute, stage, outcome, bucket));
alter table public.fmail_perf_hist enable row level security;
alter table public.fmail_perf_hist force row level security;
revoke all on public.fmail_perf_hist from public, anon, authenticated;
create table if not exists public.fmail_perf_state (id boolean primary key default true check (id), rolled_to timestamptz not null);
alter table public.fmail_perf_state enable row level security;
alter table public.fmail_perf_state force row level security;
revoke all on public.fmail_perf_state from public, anon, authenticated;
insert into public.fmail_perf_state (rolled_to) values (date_trunc('minute', now()) - interval '1 minute') on conflict do nothing;

-- rollup: closed minutes only, from the watermark; idempotent (the watermark moves in the same transaction as the insert)
create or replace function public.fmail_perf_rollup174() returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_from timestamptz; v_to timestamptz := date_trunc('minute', now()); v_rows int;
begin
  perform pg_advisory_xact_lock(hashtext('fmail_perf_rollup'));
  select rolled_to into v_from from public.fmail_perf_state;
  if v_to <= v_from then return jsonb_build_object('rolled', 0); end if;
  insert into public.fmail_perf_hist (minute, stage, outcome, bucket, n)
    select date_trunc('minute', s.ts), s.stage, s.outcome, public._fp_bucket(s.dur_us), count(*) from public.fmail_perf_sample s
    where s.ts >= v_from and s.ts < v_to group by 1, 2, 3, 4
    on conflict (minute, stage, outcome, bucket) do update set n = public.fmail_perf_hist.n + excluded.n;
  get diagnostics v_rows = row_count;
  update public.fmail_perf_state set rolled_to = v_to;
  return jsonb_build_object('rolled', v_rows, 'to', v_to);
end $$;
revoke all on function public.fmail_perf_rollup174() from public, anon, authenticated;
grant execute on function public.fmail_perf_rollup174() to service_role;

-- ===========================================================================================================================================
-- 6) PERCENTILES: exact (nearest-rank, a value that really happened) from raw samples up to 24 h, from the merged histogram beyond. Too few samples = null + the reason, never a guess:
--    p50 needs 1, p90 needs 10, p95 needs 20, p99 needs 100, p99.9 needs 1000 samples.
-- ===========================================================================================================================================
create or replace function public.fmail_perf_pct174(p_stage text, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare v_n bigint; v_src text; v_p double precision[] := array[0.5, 0.9, 0.95, 0.99, 0.999]; v_need int[] := array[1, 10, 20, 100, 1000]; v_names text[] := array['p50', 'p90', 'p95', 'p99', 'p999'];
        v_val double precision[]; v_out jsonb := '{}'::jsonb; i int; r record; v_cum bigint; v_target bigint;
begin
  if p_stage not in ('accept', 'scan', 'seal', 'commit', 'total') then raise exception 'E174: unknown stage' using errcode = '22023'; end if;
  if p_to - p_from <= interval '24 hours' then
    v_src := 'raw';
    select count(*), percentile_disc(v_p) within group (order by dur_us) into v_n, v_val from public.fmail_perf_sample where stage = p_stage and ts >= p_from and ts < p_to;
  else
    v_src := 'histogram';
    select coalesce(sum(n), 0) into v_n from public.fmail_perf_hist where stage = p_stage and minute >= p_from and minute < p_to;
    v_val := array[null, null, null, null, null]::double precision[];
    for i in 1 .. 5 loop
      continue when v_n = 0;
      v_target := ceil(v_p[i] * v_n)::bigint; v_cum := 0;
      for r in select bucket, sum(n) as n from public.fmail_perf_hist where stage = p_stage and minute >= p_from and minute < p_to group by bucket order by bucket loop
        v_cum := v_cum + r.n;
        if v_cum >= v_target then v_val[i] := public._fp_bucket_hi(r.bucket); exit; end if;
      end loop;
    end loop;
  end if;
  for i in 1 .. 5 loop
    v_out := v_out || jsonb_build_object(v_names[i], case when v_n >= v_need[i] and v_val[i] is not null then to_jsonb(round((v_val[i] / 1000.0)::numeric, 3)) else null end);
  end loop;
  return v_out || jsonb_build_object('n', v_n, 'unit', 'ms', 'source', v_src, 'needs', to_jsonb(v_need));
end $$;
revoke all on function public.fmail_perf_pct174(text, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.fmail_perf_pct174(text, timestamptz, timestamptz) to service_role;

-- ===========================================================================================================================================
-- 7) THE SLO + THE BURN RATE (Google SRE workbook): burn = (bad fraction) / (1 - target). Tiers: page at 14.4 on 1h AND 5m, page at 6 on 6h AND 30m, ticket at 1 on 3d AND 6h.
--    A window with fewer than 20 samples cannot raise an alert (state too_few): a quiet founder mailbox must not page on three mails.
-- ===========================================================================================================================================
create table if not exists public.fmail_perf_slo (
  stage text primary key check (stage in ('accept', 'scan', 'seal', 'commit', 'total')), threshold_ms int not null check (threshold_ms between 1 and 3600000),
  target numeric not null check (target > 0.5 and target < 1), note text not null);
alter table public.fmail_perf_slo enable row level security;
alter table public.fmail_perf_slo force row level security;
revoke all on public.fmail_perf_slo from public, anon, authenticated;
insert into public.fmail_perf_slo (stage, threshold_ms, target, note) values
  ('total',  5000,  0.99,  '99 percent of mails are scanned, sealed and committed within 5 s'),
  ('scan',   10000, 0.99,  '99 percent of ClamAV scans finish within 10 s'),
  ('seal',   500,   0.999, '99.9 percent of seals (AES-256-GCM + ML-KEM) finish within 0.5 s'),
  ('commit', 1000,  0.999, '99.9 percent of database commits finish within 1 s'),
  ('accept', 5000,  0.99,  '99 percent of mails are received within 5 s')
on conflict (stage) do nothing;

create or replace function public._fp_burn(p_stage text, p_window interval, p_now timestamptz) returns jsonb
language sql stable set search_path = pg_catalog, public as $$
  select jsonb_build_object('n', count(*), 'bad', count(*) filter (where s.dur_us > o.threshold_ms * 1000 or s.outcome = 'error'),
    'burn', case when count(*) = 0 then null else round(((count(*) filter (where s.dur_us > o.threshold_ms * 1000 or s.outcome = 'error'))::numeric / count(*)) / (1 - o.target), 3) end)
  from public.fmail_perf_slo o left join public.fmail_perf_sample s on s.stage = o.stage and s.ts > p_now - p_window and s.ts <= p_now
  where o.stage = p_stage group by o.threshold_ms, o.target
$$;

create or replace function public.fmail_perf_burn174(p_stage text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare v_now timestamptz := now(); w jsonb := '{}'::jsonb; v_state text := 'ok'; v_o public.fmail_perf_slo%rowtype;
  b1h jsonb; b5m jsonb; b6h jsonb; b30m jsonb; b3d jsonb;
begin
  select * into v_o from public.fmail_perf_slo where stage = p_stage;
  if not found then raise exception 'E174: no SLO for this stage' using errcode = '22023'; end if;
  b1h := public._fp_burn(p_stage, interval '1 hour', v_now); b5m := public._fp_burn(p_stage, interval '5 minutes', v_now);
  b6h := public._fp_burn(p_stage, interval '6 hours', v_now); b30m := public._fp_burn(p_stage, interval '30 minutes', v_now);
  b3d := public._fp_burn(p_stage, interval '3 days', v_now);
  if (b3d ->> 'n')::int < 20 then v_state := 'too_few'; end if;
  if (b3d ->> 'n')::int >= 20 and coalesce((b3d ->> 'burn')::numeric, 0) >= 1 and coalesce((b6h ->> 'burn')::numeric, 0) >= 1 and (b6h ->> 'n')::int >= 20 then v_state := 'ticket'; end if;
  if (b6h ->> 'n')::int >= 20 and coalesce((b6h ->> 'burn')::numeric, 0) >= 6 and coalesce((b30m ->> 'burn')::numeric, 0) >= 6 and (b30m ->> 'n')::int >= 20 then v_state := 'page'; end if;
  if (b1h ->> 'n')::int >= 20 and coalesce((b1h ->> 'burn')::numeric, 0) >= 14.4 and coalesce((b5m ->> 'burn')::numeric, 0) >= 14.4 and (b5m ->> 'n')::int >= 20 then v_state := 'page'; end if;
  return jsonb_build_object('stage', p_stage, 'threshold_ms', v_o.threshold_ms, 'target', v_o.target, 'note', v_o.note, 'state', v_state,
    'windows', jsonb_build_object('1h', b1h, '5m', b5m, '6h', b6h, '30m', b30m, '3d', b3d));
end $$;
revoke all on function public.fmail_perf_burn174(text) from public, anon, authenticated;
grant execute on function public.fmail_perf_burn174(text) to service_role;

-- ===========================================================================================================================================
-- 8) THE READ DOOR for the Bridge card "Mail speed" (signed by the Rust door, read by the kernel over WebTransport)
-- ===========================================================================================================================================
create or replace function public.fmail_perf_door174(p_window text default '1h') returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare v_w interval; v_st jsonb := '{}'::jsonb; v_slo jsonb := '[]'::jsonb; s text; v_seal record;
begin
  v_w := case p_window when '1h' then interval '1 hour' when '6h' then interval '6 hours' when '24h' then interval '24 hours' when '7d' then interval '7 days' end;
  if v_w is null then raise exception 'E174: window must be 1h, 6h, 24h or 7d' using errcode = '22023'; end if;
  foreach s in array array['accept', 'scan', 'seal', 'commit', 'total'] loop
    v_st := v_st || jsonb_build_object(s, public.fmail_perf_pct174(s, now() - v_w, now() + interval '1 minute'));
    v_slo := v_slo || jsonb_build_array(public.fmail_perf_burn174(s));
  end loop;
  select count(*) as seals, max(day) as head into v_seal from public.fmail_perf_seal;
  return jsonb_build_object('v', 'fmail-perf-v1', 'window', p_window, 'stages', v_st, 'slo', v_slo, 'seals', jsonb_build_object('count', v_seal.seals, 'head_day', v_seal.head));
end $$;
revoke all on function public.fmail_perf_door174(text) from public, anon, authenticated;
grant execute on function public.fmail_perf_door174(text) to service_role;

-- ===========================================================================================================================================
-- 9) THE SELFTEST (rolls everything back): 12 cases. Returns 'E174 selftest: 12 ok, 0 failed' or the first failure.
-- ===========================================================================================================================================
create or replace function public.fmail_perf_selftest174() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_ok int := 0; v_bad text := ''; v_j jsonb; v_x bigint; v_err numeric; v_worst numeric := 0; i int; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  begin
    perform public.fmail_perf_partitions174();
    -- 1 bucket roundtrip: the bucket top is never below the value and at most 0.8 percent above (checked on 2000 values across 9 decades)
    for i in 0 .. 1999 loop
      v_x := (10 ^ (i / 222.0))::bigint + i; v_err := (public._fp_bucket_hi(public._fp_bucket(v_x)) - v_x)::numeric / greatest(v_x, 1);
      if public._fp_bucket_hi(public._fp_bucket(v_x)) < v_x then v_bad := v_bad || ' bucket-below'; end if;
      v_worst := greatest(v_worst, v_err);
    end loop;
    if v_worst <= 0.0079 and v_bad = '' then v_ok := v_ok + 1; else v_bad := v_bad || ' bucket-error ' || v_worst; end if;
    -- 2 ingest accepts good rows, rejects bad ones (unknown stage, negative, a row from last year)
    v_j := public.fmail_perf_ingest174(jsonb_build_array(
      jsonb_build_object('ts_ms', v_now, 'stage', 'total', 'outcome', 'ok', 'size', 's', 'dur_us', 1000),
      jsonb_build_object('ts_ms', v_now, 'stage', 'nope', 'outcome', 'ok', 'size', 's', 'dur_us', 1000),
      jsonb_build_object('ts_ms', v_now, 'stage', 'total', 'outcome', 'ok', 'size', 's', 'dur_us', -5),
      jsonb_build_object('ts_ms', 1600000000000, 'stage', 'total', 'outcome', 'ok', 'size', 's', 'dur_us', 10)));
    if (v_j ->> 'accepted')::int = 1 and (v_j ->> 'rejected')::int = 3 then v_ok := v_ok + 1; else v_bad := v_bad || ' ingest ' || v_j::text; end if;
    -- 3 a known set: 1..1000 ms, p50 = 500, p90 = 900, p95 = 950, p99 = 990, p999 = 999 (nearest rank), exact
    insert into public.fmail_perf_sample (ts, stage, outcome, size_bucket, dur_us) select now() - interval '10 minutes' + g * interval '1 millisecond', 'commit', 'ok', 'm', g * 1000 from generate_series(1, 1000) g;
    v_j := public.fmail_perf_pct174('commit', now() - interval '1 hour', now() + interval '1 minute');
    if (v_j ->> 'p50')::numeric = 500 and (v_j ->> 'p90')::numeric = 900 and (v_j ->> 'p95')::numeric = 950 and (v_j ->> 'p99')::numeric = 990 and (v_j ->> 'p999')::numeric = 999 and (v_j ->> 'n')::int = 1000 then v_ok := v_ok + 1; else v_bad := v_bad || ' pct ' || v_j::text; end if;
    -- 4 too few samples: p99.9 of 5 samples is null, never a guess
    v_j := public.fmail_perf_pct174('accept', now() - interval '1 hour', now() + interval '1 minute');
    insert into public.fmail_perf_sample (ts, stage, outcome, size_bucket, dur_us) select now(), 'accept', 'ok', 'xs', 1000 * g from generate_series(1, 5) g;
    v_j := public.fmail_perf_pct174('accept', now() - interval '1 hour', now() + interval '1 minute');
    if (v_j ->> 'n')::int = 5 and v_j -> 'p999' = 'null'::jsonb and v_j -> 'p99' = 'null'::jsonb and (v_j ->> 'p50')::numeric > 0 then v_ok := v_ok + 1; else v_bad := v_bad || ' toofew ' || v_j::text; end if;
    -- 5 append-only: UPDATE and DELETE on a sample are refused
    begin update public.fmail_perf_sample set dur_us = 1 where stage = 'accept'; v_bad := v_bad || ' update-allowed'; exception when insufficient_privilege then v_ok := v_ok + 1; end;
    begin delete from public.fmail_perf_sample where stage = 'accept'; v_bad := v_bad || ' delete-allowed'; exception when insufficient_privilege then v_ok := v_ok + 1; end;
    -- 6 the rollup puts the samples into the histogram and the long-window percentile is within 0.8 percent of the exact one
    update public.fmail_perf_state set rolled_to = now() - interval '2 hours';
    perform public.fmail_perf_rollup174();
    v_j := public.fmail_perf_pct174('commit', now() - interval '48 hours', now() + interval '1 minute');
    if v_j ->> 'source' = 'histogram' and (v_j ->> 'p99')::numeric between 990 and 990 * 1.0079 then v_ok := v_ok + 1; else v_bad := v_bad || ' hist ' || v_j::text; end if;
    -- 7 burn: 1000 commits, 300 of them over 1 s (target 99.9 percent) = a page; the window with 5 samples says too_few
    insert into public.fmail_perf_sample (ts, stage, outcome, size_bucket, dur_us) select now() - interval '5 minutes' + g * interval '1 millisecond', 'commit', 'ok', 'm', 2000000 from generate_series(1, 300) g;
    v_j := public.fmail_perf_burn174('commit');
    if v_j ->> 'state' = 'page' then v_ok := v_ok + 1; else v_bad := v_bad || ' burn-page ' || v_j::text; end if;
    v_j := public.fmail_perf_burn174('accept');
    if v_j ->> 'state' = 'too_few' then v_ok := v_ok + 1; else v_bad := v_bad || ' burn-toofew ' || v_j::text; end if;
    -- 8 the seal: today cannot be sealed; a closed day with samples seals, and the chain verifies; a second seal of the same day is a no-op
    begin perform public.fmail_perf_seal174((now() at time zone 'utc')::date); v_bad := v_bad || ' sealed-today'; exception when others then v_ok := v_ok + 1; end;
    insert into public.fmail_perf_sample (ts, stage, outcome, size_bucket, dur_us) values (((now() at time zone 'utc')::date - 1)::timestamptz + interval '3 hours', 'total', 'ok', 'm', 2500);
    v_j := public.fmail_perf_seal174((now() at time zone 'utc')::date - 1);
    if (v_j ->> 'ok')::boolean and public.fmail_perf_seal_verify174() >= 1 and coalesce((public.fmail_perf_seal174((now() at time zone 'utc')::date - 1) ->> 'already')::boolean, false) then v_ok := v_ok + 1; else v_bad := v_bad || ' seal ' || v_j::text; end if;
    -- 9 the door answers with the five stages and the five SLOs
    v_j := public.fmail_perf_door174('1h');
    if jsonb_array_length(v_j -> 'slo') = 5 and (select count(*) from jsonb_object_keys(v_j -> 'stages')) = 5 then v_ok := v_ok + 1; else v_bad := v_bad || ' door'; end if;
    raise exception 'E174_SELFTEST_ROLLBACK';
  exception when others then
    if sqlerrm <> 'E174_SELFTEST_ROLLBACK' then v_bad := v_bad || ' crash: ' || sqlerrm; end if;
  end;
  if v_bad = '' and v_ok = 12 then return 'E174 selftest: 12 ok, 0 failed'; end if;
  return 'E174 selftest FAILED: ' || v_ok || ' ok;' || v_bad;
end $$;
revoke all on function public.fmail_perf_selftest174() from public, anon, authenticated;
grant execute on function public.fmail_perf_selftest174() to service_role;

-- the tables created after the first backfill (seal, hist, state, slo) get their policy here (same E65 law)
do $$ declare r record; begin
  for r in select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p') and c.relrowsecurity
             and (c.relname in ('fmail_perf_sample', 'fmail_perf_seal', 'fmail_perf_hist', 'fmail_perf_state', 'fmail_perf_slo') or c.relname ~ '^fmail_perf_sample_y[0-9]{8}$') loop
    execute format('drop policy if exists "service_role_internal_access" on public.%I', r.relname);
    execute format('create policy "service_role_internal_access" on public.%I for all to service_role using (true) with check (true)', r.relname);
  end loop;
end $$;
