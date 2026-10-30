-- E109 — FOUNDER LIVE (L-phase): har number asli, har badlav page par khud aaye. Zero mock data (Rule 69). 10/10 (FC27).
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), security definer RPC (service_role only, search_path pinned, statement_timeout pinned), RLS on, append-only feed.
-- Founder order 30 Oct 22:17 (verbatim in docs/cursor-work/founder/founder-commands.md): "data live ... ek bhi mock data hua to goli maron ga ...
--   sab kuch live latest technology pe, page pe auto updates aaye, live real aaye ... is ki sql bana do advance level".
-- NOTE: E107 F2c Merkle ke liye RESERVED hai; isliye yeh file E109 hai (E108 settings ke baad).
--
-- ASAL MASLA JO YEH HAL KARTI HAI
--   (a) Aaj bridge handler 4-5 alag REST sawal chalata hai (revenue_accounts, revenue_targets, mail_outbox, revenue_leads, polar_pulse...). Har sawal
--       ~0.5-0.7 s (Supabase round trip) => page ~1.8 s. Yahan EK RPC `founder_live_snapshot()` sab kuch ek jawab mein deta hai.
--   (b) Page "15 s polling" par chalta hai, yani badlav 15 s late nazar aata. Yahan ek chhota "change feed" hai: Rust har ~2 s mein SIRF
--       `founder_live_tick()` poochta hai (ek arzaan call), badlav ho to feed mein event aata hai, Rust SSE/WebTransport se browser ko push karta hai,
--       browser kernel se verify karke dikhata hai. Koi mock nahi: event tabhi bante hain jab asli table ka fingerprint badle.
--   (c) Koi bhi "kab se chalta hai / kab se purana hai" andaza nahi: har source ka freshness SLO (age vs expected) asli waqt se naapa jata hai.
--
-- DESIGN FAISLA: awam tables par TRIGGER NAHI (Polar engine/WAL NO-TOUCH Rule B6a; user side ko haath nahi FC18). Badlav ki pehchan "fingerprint"
--   se hoti hai: har source ka (row count, sab se naya timestamp). Fingerprint padhna sirf SELECT hai, awam table ko koi lock/index/trigger nahi.
--   Trade-off (imandari se): ek badlav jo count aur max-timestamp dono na badle (jaise purani row ki value edit, bina updated_at) fingerprint se nahi
--   pakda jata; snapshot har dafa taza asli value padhta hai, isliye number kabhi jhoota nahi hota, sirf "push" late ho sakta hai (max ek poll).
--
-- SECTIONS
--   0) Preflight          — E102 maujood hai? warna saaf SKIP.
--   1) founder_live_sources — registry: kaun si table, kaunsa timestamp column, kitni der purani ho to "stale" (SLO). Sab guarded.
--   2) founder_live_state + founder_live_events — fingerprint ki yaad + append-only change feed (id = version).
--   3) fingerprint + tick  — founder_live_fp(), founder_live_tick(): badlav pakadta, stale/recover events, metrics likhta.
--   4) metrics            — founder_metric_points (1-minute buckets, compress), founder_metric_hourly view, retention.
--   5) snapshot           — founder_live_snapshot(): money, customers, mail, polar, audit, gates, devices, slo, trouble — ek jsonb.
--   6) feed + anomaly     — founder_live_since() (Last-Event-ID catch-up), founder_live_anomalies() (EWMA/z-score, deterministic, explains itself).
--   7) retention          — founder_live_prune().
--   8) grants + selftest + CHECK_E109.
-- Dobara chalana safe (create ... if not exists / create or replace). Awam tables ko KUCH nahi badalta.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = pg_catalog, public, extensions;

do $$
begin
  if to_regclass('public.founder_accounts') is null or to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then
    raise exception 'E109: pehle E102 (founder_accounts / founder_audit_append) chalayein' using errcode = '55000';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_live:ddl', 0));

  -- ==========================================================================================================================
  -- 1) REGISTRY — kaun se sources "live" hain
  -- ==========================================================================================================================
  create table if not exists public.founder_live_sources (
    key              text primary key check (key ~ '^[a-z][a-z0-9_]{1,40}$'),
    label            text not null check (length(label) between 2 and 60),
    relation         text not null check (relation ~ '^public\.[a-z_][a-z0-9_]{0,62}$'),
    -- pehla maujood column istemal hota hai (har deployment ka schema thora alag ho sakta hai: updated_at / created_at / received_at ...)
    ts_candidates    text[] not null default array['updated_at','created_at']::text[],
    ts_unit          text not null default 'timestamptz' check (ts_unit in ('timestamptz', 'epoch_ms')),
    owner            text not null default 'awam' check (owner in ('awam', 'founder')),
    -- kitni der se naya row na aaye to "stale" (null = koi umeed nahi, sirf jab data aaye tab dikhao)
    expect_max_age_secs integer check (expect_max_age_secs is null or expect_max_age_secs between 10 and 31536000),
    enabled          boolean not null default true,
    sort             smallint not null default 100,
    created_at       timestamptz not null default now(),
    constraint founder_live_sources_cols check (
      cardinality(ts_candidates) between 1 and 6
      and array_to_string(ts_candidates, ',') ~ '^[a-z_][a-z0-9_]{0,62}(,[a-z_][a-z0-9_]{0,62}){0,5}$'
    )
  );
  alter table public.founder_live_sources enable row level security;
  revoke all on public.founder_live_sources from public, anon, authenticated;
  grant select, insert, update on public.founder_live_sources to service_role;

  insert into public.founder_live_sources (key, label, relation, ts_candidates, ts_unit, owner, expect_max_age_secs, sort) values
    ('revenue_accounts',   'Revenue accounts',        'public.revenue_accounts',      array['updated_at','created_at'],             'timestamptz', 'awam',    null,  10),
    ('revenue_targets',    'Revenue target',          'public.revenue_targets',       array['updated_at','created_at','month'],     'timestamptz', 'awam',    null,  20),
    ('revenue_leads',      'Customer leads',          'public.revenue_leads',         array['updated_at','created_at'],             'timestamptz', 'awam',    null,  30),
    ('mail_outbox',        'Mail outbox',             'public.mail_outbox',           array['updated_at','created_at','queued_at'], 'timestamptz', 'awam',    null,  40),
    ('polar_webhook_inbox','Polar webhook events',    'public.polar_webhook_inbox',   array['received_at','created_at'],            'timestamptz', 'awam',    null,  50),
    ('polar_subscriptions','Polar subscriptions',     'public.polar_subscriptions',   array['updated_at','created_at'],             'timestamptz', 'awam',    null,  60),
    ('polar_alerts',       'Polar payment alerts',    'public.polar_payment_alerts',  array['created_at','updated_at'],             'timestamptz', 'awam',    null,  70),
    ('polar_rejects',      'Polar signature rejects', 'public.polar_signature_rejects', array['received_at','created_at'],        'timestamptz', 'awam',    null,  80),
    ('founder_audit',      'Founder audit ledger',    'public.founder_audit',         array['ts_ms'],                               'epoch_ms',    'founder', null,  90),
    ('founder_devices',    'Approved devices',        'public.founder_devices',       array['last_seen_at','approved_at','created_at'], 'timestamptz', 'founder', null, 100),
    ('founder_actions',    'Action registry',         'public.founder_actions',       array['created_at'],                          'timestamptz', 'founder', null, 110),
    ('founder_settings',   'Founder settings',        'public.founder_settings',      array['updated_at','created_at'],             'timestamptz', 'founder', null, 120)
  on conflict (key) do nothing;

  -- ==========================================================================================================================
  -- 2) STATE + FEED
  -- ==========================================================================================================================
  create table if not exists public.founder_live_state (
    source       text primary key references public.founder_live_sources(key) on delete cascade,
    present      boolean not null default false,   -- table maujood hai?
    n            bigint,                           -- row count (null = table nahi / timeout)
    max_ts       timestamptz,                      -- sab se naya row ka waqt
    ts_column    text,                             -- jo column istemal hua
    fp           text not null default '',         -- chhota fingerprint (present|n|max_ts)
    stale        boolean not null default false,
    changed_at   timestamptz,
    checked_at   timestamptz not null default now()
  );
  alter table public.founder_live_state enable row level security;
  revoke all on public.founder_live_state from public, anon, authenticated;
  grant select, insert, update on public.founder_live_state to service_role;

  create table if not exists public.founder_live_events (
    id      bigint generated always as identity primary key,   -- yehi "version" hai: browser Last-Event-ID se catch-up karta hai
    ts      timestamptz not null default now(),
    source  text not null references public.founder_live_sources(key) on delete cascade,
    kind    text not null check (kind in ('appear', 'vanish', 'change', 'stale', 'recover')),
    detail  jsonb not null default '{}'::jsonb,
    constraint founder_live_events_detail_size check (pg_column_size(detail) <= 2000),
    -- PRIVACY: sirf ginti, waqt, naam; email / id / payload kabhi nahi
    constraint founder_live_events_no_pii check (detail::text !~* '(@|bearer|password|secret|token|authorization)')
  );
  create index if not exists founder_live_events_source_idx on public.founder_live_events (source, id desc);
  create index if not exists founder_live_events_ts_idx     on public.founder_live_events (ts desc);
  alter table public.founder_live_events enable row level security;
  revoke all on public.founder_live_events from public, anon, authenticated;
  grant select, insert on public.founder_live_events to service_role;
  -- UPDATE/DELETE/TRUNCATE service_role se bhi hata do; delete sirf founder_live_prune() ke zariye (trigger neeche)
  revoke update, truncate, references, trigger on public.founder_live_events from service_role;
end $$;

-- Append-only: update/truncate hamesha band; delete sirf prune function ke andar (founder.live_prune = on, transaction-local).
create or replace function public._founder_live_events_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' and coalesce(current_setting('founder.live_prune', true), '') = 'on' then
    return old;
  end if;
  raise exception 'founder_live_events append-only: % not allowed', tg_op using errcode = '42501';
end $$;

do $$
begin
  if to_regclass('public.founder_live_events') is null then return; end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_live_events'::regclass and tgname = 'founder_live_events_no_upd_del') then
    create trigger founder_live_events_no_upd_del before update or delete on public.founder_live_events
      for each row execute function public._founder_live_events_guard();
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_live_events'::regclass and tgname = 'founder_live_events_no_trunc') then
    create trigger founder_live_events_no_trunc before truncate on public.founder_live_events
      for each statement execute function public._founder_live_events_guard();
  end if;
end $$;

-- ==============================================================================================================================
-- 3) HELPERS — har sawal "table/column na ho to NULL (= not connected)", kabhi jhoota 0 nahi (Rule 69)
-- ==============================================================================================================================
-- Sirf is file ke andar ke FIXED strings ke saath chalte hain (user input kabhi nahi) — isliye dynamic SQL safe hai; phir bhi relation regex se check.
create or replace function public._fl_count(p_rel text, p_where text default 'true') returns bigint
language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '4s' as $$
declare v bigint;
begin
  if p_rel !~ '^public\.[a-z_][a-z0-9_]{0,62}$' or to_regclass(p_rel) is null then return null; end if;
  execute format('select count(*) from %s where %s', p_rel::regclass, p_where) into v;
  return v;
exception when undefined_column or undefined_table or query_canceled or invalid_text_representation or datatype_mismatch or undefined_function then
  return null;
end $$;

create or replace function public._fl_num(p_sql text) returns numeric
language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '4s' as $$
declare v numeric;
begin
  execute p_sql into v;
  return v;
exception when undefined_column or undefined_table or query_canceled or invalid_text_representation or datatype_mismatch or undefined_function then
  return null;
end $$;

-- Ek table ka pehla maujood timestamp-jaisa column (candidates ki tarteeb se).
create or replace function public._fl_tscol(p_rel text, p_cands text[]) returns text
language sql stable set search_path = pg_catalog, public as $$
  select c.cand
    from unnest(p_cands) with ordinality as c(cand, ord)
    join pg_attribute a on a.attrelid = to_regclass(p_rel) and a.attname = c.cand and a.attnum > 0 and not a.attisdropped
   where to_regclass(p_rel) is not null
   order by c.ord limit 1
$$;

-- Ek source ka fingerprint: maujood? kitni rows? sab se naya waqt? (SELECT only)
create or replace function public.founder_live_fp(p_key text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare s public.founder_live_sources%rowtype; col text; v_n bigint; v_max timestamptz; reg regclass;
begin
  select * into s from public.founder_live_sources where key = p_key;
  if not found then return jsonb_build_object('present', false, 'note', 'unknown source'); end if;
  reg := to_regclass(s.relation);
  if reg is null then return jsonb_build_object('present', false); end if;
  col := public._fl_tscol(s.relation, s.ts_candidates);
  begin
    if col is null then
      execute format('select count(*), null::timestamptz from %s', reg) into v_n, v_max;
    elsif s.ts_unit = 'epoch_ms' then
      execute format('select count(*), to_timestamp(max(%I)::double precision / 1000.0) from %s', col, reg) into v_n, v_max;
    else
      execute format('select count(*), max(%I)::timestamptz from %s', col, reg) into v_n, v_max;
    end if;
  exception when query_canceled then
    -- bohat bari table: poori ginti nahi ho saki, andaza (reltuples) — saaf "approx" likha jata hai
    select greatest(reltuples, 0)::bigint into v_n from pg_class where oid = reg;
    return jsonb_build_object('present', true, 'n', v_n, 'approx', true, 'ts_column', col);
  end;
  return jsonb_build_object('present', true, 'n', v_n, 'max_ts', v_max, 'ts_column', col);
end $$;

-- Sab metrics ek saath (ek jagah): snapshot bhi yahi padhta hai, tick yahi record karta hai => dono hamesha ek jaise.
create or replace function public._founder_live_values() returns jsonb
language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare r jsonb := '{}'::jsonb; v numeric;
begin
  -- MRR: revenue_accounts.mrr_gbp (number ya "105.00" jaisi string dono) sirf active accounts ka (bridge.rs jaisa hi hisab)
  v := public._fl_num($q$select sum(case when mrr_gbp::text ~ '^-?[0-9]+(\.[0-9]+)?$' then mrr_gbp::text::numeric else 0 end)
                         from public.revenue_accounts where status = 'active'$q$);
  if v is not null or to_regclass('public.revenue_accounts') is not null then r := r || jsonb_build_object('mrr_gbp', coalesce(v, 0)); end if;
  v := public._fl_count('public.revenue_accounts', $q$status = 'active'$q$);       if v is not null then r := r || jsonb_build_object('active_accounts', v); end if;
  v := public._fl_count('public.polar_subscriptions', $q$status = 'active'$q$);    if v is not null then r := r || jsonb_build_object('active_subs', v); end if;
  v := public._fl_count('public.polar_subscriptions', $q$status = 'past_due'$q$);  if v is not null then r := r || jsonb_build_object('past_due', v); end if;
  v := public._fl_count('public.revenue_leads', $q$stage = 'new'$q$);              if v is not null then r := r || jsonb_build_object('new_leads', v); end if;
  v := public._fl_count('public.mail_outbox', $q$state in ('queued','failed')$q$); if v is not null then r := r || jsonb_build_object('mail_queue', v); end if;
  v := public._fl_count('public.polar_webhook_inbox', $q$received_at > now() - interval '1 hour'$q$);
  if v is not null then r := r || jsonb_build_object('webhook_events_1h', v); end if;
  v := public._fl_count('public.polar_signature_rejects', $q$received_at > now() - interval '24 hours'$q$);
  if v is not null then r := r || jsonb_build_object('sig_rejects_24h', v); end if;
  v := public._fl_count('public.founder_audit', 'true');                            if v is not null then r := r || jsonb_build_object('audit_entries', v); end if;
  return r;
end $$;

-- ==============================================================================================================================
-- 4) METRICS — asli time series (1-minute buckets). Badal na ho to nayi row nahi (compress), warna har 10 minute ek "dil ki dhadkan" point.
-- ==============================================================================================================================
do $$
begin
  if to_regclass('public.founder_live_sources') is null then return; end if;
  create table if not exists public.founder_metric_points (
    metric  text not null check (metric in ('mrr_gbp','active_accounts','active_subs','past_due','new_leads','mail_queue','webhook_events_1h','sig_rejects_24h','audit_entries')),
    bucket  timestamptz not null,                  -- date_trunc('minute', now())
    value   numeric not null,
    primary key (metric, bucket)
  );
  create index if not exists founder_metric_points_bucket_idx on public.founder_metric_points (bucket desc);
  alter table public.founder_metric_points enable row level security;
  revoke all on public.founder_metric_points from public, anon, authenticated;
  grant select, insert, update, delete on public.founder_metric_points to service_role;
end $$;

-- Hourly rollup (view: koi alag table/cron nahi, hamesha asli points se). security_invoker => RLS ka ehtram.
do $$
begin
  if to_regclass('public.founder_metric_points') is null then return; end if;
  execute $v$create or replace view public.founder_metric_hourly with (security_invoker = true) as
    select metric, date_trunc('hour', bucket) as hour,
           min(value) as lo, max(value) as hi, round(avg(value), 4) as mean,
           (array_agg(value order by bucket desc))[1] as last, count(*) as points
      from public.founder_metric_points group by metric, date_trunc('hour', bucket)$v$;
  revoke all on public.founder_metric_hourly from public, anon, authenticated;
  grant select on public.founder_metric_hourly to service_role;
end $$;

create or replace function public._founder_live_record(p_values jsonb) returns integer
language plpgsql security definer set search_path = pg_catalog, public as $$
declare k text; v numeric; last_v numeric; last_b timestamptz; n int := 0; b timestamptz := date_trunc('minute', now());
begin
  for k, v in select key, (value)::numeric from jsonb_each_text(p_values) loop
    select value, bucket into last_v, last_b from public.founder_metric_points where metric = k order by bucket desc limit 1;
    -- badla nahi aur 10 minute se kam purana point hai => naya point nahi (jagah bachao, sachchai wahi)
    if found and last_v = v and last_b > now() - interval '10 minutes' then continue; end if;
    insert into public.founder_metric_points (metric, bucket, value) values (k, b, v)
      on conflict (metric, bucket) do update set value = excluded.value;
    n := n + 1;
  end loop;
  return n;
end $$;

-- ==============================================================================================================================
-- 3b) TICK — Rust har ~2 s yeh poochta hai. Sasta: har source par ek count+max. Badlav ho to event bantey hain.
-- ==============================================================================================================================
create or replace function public.founder_live_tick(p_record boolean default true) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '15s' as $$
declare
  s public.founder_live_sources%rowtype; st public.founder_live_state%rowtype; fpj jsonb;
  v_fp text; v_present boolean; v_n bigint; v_max timestamptz; v_stale boolean; v_age bigint;
  changed text[] := '{}'; v_ver bigint; recorded int := 0;
begin
  -- ek hi waqt mein ek tick (Rust ke do instance bhi ho to doosra seedha version de kar nikal jaye)
  if not pg_try_advisory_xact_lock(hashtextextended('founder_live:tick', 0)) then
    select coalesce(max(id), 0) into v_ver from public.founder_live_events;
    return jsonb_build_object('version', v_ver, 'changed', '[]'::jsonb, 'skipped', true);
  end if;

  for s in select * from public.founder_live_sources where enabled order by sort, key loop
    fpj := public.founder_live_fp(s.key);
    v_present := coalesce((fpj ->> 'present')::boolean, false);
    v_n := nullif(fpj ->> 'n', '')::bigint;
    v_max := nullif(fpj ->> 'max_ts', '')::timestamptz;
    v_fp := concat_ws('|', v_present::text, coalesce(v_n::text, '-'), coalesce(extract(epoch from v_max)::text, '-'));
    v_age := case when v_max is null then null else greatest(0, extract(epoch from (now() - v_max))::bigint) end;
    v_stale := v_present and s.expect_max_age_secs is not null and (v_age is null or v_age > s.expect_max_age_secs);

    select * into st from public.founder_live_state where source = s.key;
    if not found then
      -- pehli dafa dekha: baseline likho, shor nahi (feed "asli badlav" ka hai, "shuru hua" ka nahi)
      insert into public.founder_live_state (source, present, n, max_ts, ts_column, fp, stale, changed_at, checked_at)
        values (s.key, v_present, v_n, v_max, fpj ->> 'ts_column', v_fp, v_stale, null, now());
      continue;
    end if;

    if st.fp is distinct from v_fp then
      insert into public.founder_live_events (source, kind, detail) values (
        s.key,
        case when not st.present and v_present then 'appear' when st.present and not v_present then 'vanish' else 'change' end,
        jsonb_strip_nulls(jsonb_build_object('n_before', st.n, 'n_after', v_n,
          'delta', case when st.n is not null and v_n is not null then v_n - st.n end,
          'max_ts', v_max, 'approx', (fpj ->> 'approx')::boolean)));
      changed := changed || s.key;
      update public.founder_live_state set present = v_present, n = v_n, max_ts = v_max, ts_column = fpj ->> 'ts_column',
             fp = v_fp, changed_at = now(), checked_at = now() where source = s.key;
    else
      update public.founder_live_state set checked_at = now() where source = s.key;
    end if;

    if v_stale is distinct from st.stale then
      insert into public.founder_live_events (source, kind, detail) values (
        s.key, case when v_stale then 'stale' else 'recover' end,
        jsonb_strip_nulls(jsonb_build_object('age_secs', v_age, 'expected_secs', s.expect_max_age_secs)));
      update public.founder_live_state set stale = v_stale where source = s.key;
      if not (s.key = any(changed)) then changed := changed || s.key; end if;
    end if;
  end loop;

  if p_record then recorded := public._founder_live_record(public._founder_live_values()); end if;
  select coalesce(max(id), 0) into v_ver from public.founder_live_events;
  return jsonb_build_object('version', v_ver, 'changed', to_jsonb(changed), 'recorded', recorded, 'at', now());
end $$;

-- ==============================================================================================================================
-- 5) SNAPSHOT — ek RPC, ek round trip (~0.5 s) in 5 REST sawalon ki jagah. Sirf padhta hai (STABLE). Har hissa apna "connected" khud batata hai.
-- ==============================================================================================================================
create or replace function public.founder_live_snapshot() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '12s' as $$
declare
  v jsonb := public._founder_live_values();
  v_target numeric; v_rows bigint; v_q numeric; v_ver bigint;
  money jsonb; cust jsonb; mail jsonb; pulse jsonb; rej jsonb; head jsonb; gates jsonb; dev jsonb; slo jsonb; trouble jsonb := '[]'::jsonb;
  worst text := 'ok'; mail_state text;
begin
  -- money (bridge.rs jaisa hi maani; ab ek jagah SQL mein)
  if v ? 'mrr_gbp' then
    v_target := public._fl_num('select target_gbp::numeric from public.revenue_targets order by month desc limit 1');
    v_rows := public._fl_count('public.revenue_accounts', 'true');
    money := jsonb_strip_nulls(jsonb_build_object(
      'connected', true, 'source', 'revenue_accounts', 'mrr_gbp', round((v ->> 'mrr_gbp')::numeric, 2),
      'active_accounts', coalesce((v ->> 'active_accounts')::bigint, 0), 'target_gbp', v_target,
      'target_source', case when v_target is not null then 'revenue_targets' end,
      'note', case when coalesce(v_rows, 0) = 0 then 'no accounts recorded - Polar/Billing connects in F3' end));
  else
    money := jsonb_build_object('connected', false, 'note', 'cannot reach revenue_accounts');
  end if;

  -- customers
  cust := case when v ? 'new_leads' then jsonb_build_object('connected', true, 'new_leads', (v ->> 'new_leads')::bigint)
               else jsonb_build_object('connected', false, 'note', 'cannot reach revenue_leads') end;

  -- mail queue + thresholds (0 ok, <25 warn, else fail — bridge.rs ke saath ek jaisa)
  if v ? 'mail_queue' then
    v_q := (v ->> 'mail_queue')::numeric;
    mail_state := case when v_q = 0 then 'ok' when v_q < 25 then 'warn' else 'fail' end;
    mail := jsonb_build_object('connected', true, 'queue', v_q::bigint, 'state', mail_state,
                               'detail', case when v_q = 0 then 'queue empty' else v_q::bigint || ' queued/failed' end);
  else
    mail := jsonb_build_object('connected', false, 'state', 'unknown', 'detail', 'unreachable');
  end if;

  -- polar (E105/E106): kisi ek ka masla poore snapshot ko na gire
  begin pulse := public.founder_polar_pulse(); exception when others then pulse := jsonb_build_object('connected', false, 'note', 'polar pulse error'); end;
  begin rej := public.founder_polar_rejects(); exception when others then rej := jsonb_build_object('connected', false, 'note', 'polar rejects error'); end;

  -- audit head (verify yahan nahi: wo mehnga hai, apna endpoint hai; head sasta hai aur seq/hash deta hai)
  begin head := public.founder_audit_head(); exception when others then head := null; end;

  -- gates: asli registry se (G1 low, G2 medium, G3 high) — kitne actions, kitne enabled
  if to_regclass('public.founder_actions') is not null then
    select jsonb_build_object(
      'G1', jsonb_build_object('actions', count(*) filter (where danger = 'low'),    'enabled', count(*) filter (where danger = 'low' and enabled)),
      'G2', jsonb_build_object('actions', count(*) filter (where danger = 'medium'), 'enabled', count(*) filter (where danger = 'medium' and enabled)),
      'G3', jsonb_build_object('actions', count(*) filter (where danger = 'high'),   'enabled', count(*) filter (where danger = 'high' and enabled))) into gates
      from public.founder_actions;
  end if;

  -- devices (sirf ginti; label/hash nahi)
  if to_regclass('public.founder_devices') is not null then
    select jsonb_build_object('approved', count(*) filter (where approved_at is not null and revoked_at is null),
                              'pending',  count(*) filter (where approved_at is null and revoked_at is null),
                              'revoked',  count(*) filter (where revoked_at is not null),
                              'last_seen_at', max(last_seen_at)) into dev from public.founder_devices;
  end if;

  -- freshness / SLO: har source ki asli umr
  select coalesce(jsonb_agg(jsonb_build_object('source', so.key, 'label', so.label, 'owner', so.owner, 'present', coalesce(st.present, false),
            'n', st.n, 'max_ts', st.max_ts, 'age_secs', case when st.max_ts is null then null else greatest(0, extract(epoch from (now() - st.max_ts))::bigint) end,
            'stale', coalesce(st.stale, false), 'expect_max_age_secs', so.expect_max_age_secs, 'checked_at', st.checked_at) order by so.sort), '[]'::jsonb)
    into slo
    from public.founder_live_sources so left join public.founder_live_state st on st.source = so.key where so.enabled;

  -- trouble list (bridge "needs attention" ka SQL-side hissa; expiry report file Rust se aati hai)
  if mail_state is not null then
    trouble := trouble || jsonb_build_array(jsonb_build_object('name', 'mail_outbox', 'state', mail_state, 'detail', mail ->> 'detail'));
  else
    trouble := trouble || jsonb_build_array(jsonb_build_object('name', 'mail_outbox', 'state', 'unknown', 'detail', 'unreachable'));
  end if;
  if exists (select 1 from jsonb_array_elements(slo) e where (e ->> 'stale')::boolean) then
    trouble := trouble || jsonb_build_array(jsonb_build_object('name', 'stale_sources', 'state', 'warn',
      'detail', (select string_agg(e ->> 'label', ', ') from jsonb_array_elements(slo) e where (e ->> 'stale')::boolean) || ' not updating'));
  end if;
  select case when bool_or(t ->> 'state' = 'fail') then 'fail' when bool_or(t ->> 'state' = 'warn') then 'warn'
              when bool_or(t ->> 'state' = 'unknown') then 'unknown' else 'ok' end into worst from jsonb_array_elements(trouble) t;

  select coalesce(max(id), 0) into v_ver from public.founder_live_events;
  return jsonb_build_object(
    'version', v_ver, 'generated_at', now(), 'values', v,
    'money', money, 'customers', cust, 'mail', mail, 'polar', pulse, 'polar_rejects', rej,
    'audit_head', head, 'gates', gates, 'devices', dev, 'sources', slo,
    'trouble', jsonb_build_object('level', worst, 'items', trouble));
end $$;

-- ==============================================================================================================================
-- 6) FEED — Last-Event-ID catch-up (browser ka connection toot jaye to jahan chhoda wahin se) + anomaly watch
-- ==============================================================================================================================
create or replace function public.founder_live_since(p_after bigint default 0, p_limit integer default 100) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_min bigint; v_max bigint; v_lim integer := least(greatest(coalesce(p_limit, 100), 1), 500); ev jsonb;
begin
  select coalesce(min(id), 0), coalesce(max(id), 0) into v_min, v_max from public.founder_live_events;
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'ts', e.ts, 'source', e.source, 'kind', e.kind, 'detail', e.detail) order by e.id), '[]'::jsonb)
    into ev from (select * from public.founder_live_events where id > greatest(coalesce(p_after, 0), 0) order by id limit v_lim) e;
  -- gap = true: browser ka purana id prune ho chuka; usay poora snapshot dobara lena chahiye (jhoota "sab theek" nahi)
  return jsonb_build_object('version', v_max, 'events', ev, 'gap', (coalesce(p_after, 0) > 0 and coalesce(p_after, 0) + 1 < v_min));
end $$;

-- N2 Anomaly watch: EWMA nahi, saada z-score: pichle 14 din ke ghante-wale points ka mean/stddev, aur abhi ki value. AI andaza nahi.
create or replace function public.founder_live_anomalies(p_min_points integer default 24, p_sigma numeric default 3) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare m text; mean_v numeric; sd numeric; cur numeric; n int; z numeric; out jsonb := '[]'::jsonb;
begin
  for m in select distinct metric from public.founder_metric_points loop
    select avg(mean), stddev_samp(mean), count(*) into mean_v, sd, n
      from public.founder_metric_hourly
     where metric = m and hour >= now() - interval '14 days' and hour < date_trunc('hour', now());
    select value into cur from public.founder_metric_points where metric = m order by bucket desc limit 1;
    continue when n < greatest(p_min_points, 6) or sd is null or sd = 0 or cur is null;
    z := (cur - mean_v) / sd;
    if abs(z) >= p_sigma then
      out := out || jsonb_build_array(jsonb_build_object('metric', m, 'value', cur, 'mean_14d', round(mean_v, 2), 'sigma', round(z, 2), 'points', n,
        'explain', format('%s is %s sigma %s the 14-day mean %s', m, round(abs(z), 1), case when z > 0 then 'above' else 'below' end, round(mean_v, 2))));
    end if;
  end loop;
  return out;
end $$;

-- Ek metric ki taza history (sparkline ke liye): sirf asli points, bina andaze ke.
create or replace function public.founder_live_series(p_metric text, p_hours integer default 24) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce(jsonb_agg(jsonb_build_object('t', bucket, 'v', value) order by bucket), '[]'::jsonb)
    from public.founder_metric_points
   where metric = p_metric and bucket >= now() - make_interval(hours => least(greatest(coalesce(p_hours, 24), 1), 720))
$$;

-- ==============================================================================================================================
-- 7) RETENTION — feed 30 din, points 90 din. Delete sirf is function se (trigger guard ke andar), aur kitna hata uski ginti wapas.
-- ==============================================================================================================================
create or replace function public.founder_live_prune(p_keep_events interval default interval '30 days', p_keep_points interval default interval '90 days') returns jsonb
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '60s' as $$
declare e bigint; p bigint;
begin
  if p_keep_events < interval '1 day' or p_keep_points < interval '7 days' then raise exception 'retention too short' using errcode = '22023'; end if;
  perform set_config('founder.live_prune', 'on', true);
  with d as (delete from public.founder_live_events where ts < now() - p_keep_events returning 1) select count(*) into e from d;
  perform set_config('founder.live_prune', 'off', true);
  with d as (delete from public.founder_metric_points where bucket < now() - p_keep_points returning 1) select count(*) into p from d;
  return jsonb_build_object('events_deleted', e, 'points_deleted', p);
end $$;

-- ==============================================================================================================================
-- 8) GRANTS — sirf service_role (Rust). PUBLIC ko default execute milta hai: yahan saaf hataya jata hai (anon/authenticated kabhi nahi).
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public._fl_count(text,text)', 'public._fl_num(text)', 'public._fl_tscol(text,text[])', 'public.founder_live_fp(text)',
    'public._founder_live_values()', 'public._founder_live_record(jsonb)', 'public.founder_live_tick(boolean)', 'public.founder_live_snapshot()',
    'public.founder_live_since(bigint,integer)', 'public.founder_live_anomalies(integer,numeric)', 'public.founder_live_series(text,integer)',
    'public.founder_live_prune(interval,interval)', 'public._founder_live_events_guard()'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke all on function %s from public, anon, authenticated', f);
      if f !~ '_guard' then execute format('grant execute on function %s to service_role', f); end if;
    end if;
  end loop;
end $$;

-- ==============================================================================================================================
-- 9) SELFTEST — asli behaviour, aakhir mein POORA rollback (kuch persist nahi). Fail ho to saaf wajah ka text wapas.
-- ==============================================================================================================================
create or replace function public.founder_live_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  t jsonb; s jsonb; sn jsonb; ev bigint; n1 bigint; ok boolean; msg text := 'E109 selftest OK'; a jsonb; v_ver bigint; k text;
begin
  if to_regclass('public.founder_live_sources') is null then return 'E109 selftest SKIP: E109 chalayein'; end if;
  begin
    -- test table + test source (rollback ke saath gayab)
    create table public._e109_probe (id int primary key, updated_at timestamptz not null default now());
    insert into public.founder_live_sources (key, label, relation, ts_candidates, owner, expect_max_age_secs, sort)
      values ('e109_probe', 'E109 probe', 'public._e109_probe', array['updated_at'], 'awam', 10, 9999);

    -- 1) pehli tick: baseline, koi event nahi
    t := public.founder_live_tick(false);
    select count(*) into ev from public.founder_live_events where source = 'e109_probe';
    if ev <> 0 then raise exception 'baseline par event nahi aana chahiye (%)', ev; end if;

    -- 2) row aayi => ek "change" event, delta=1
    insert into public._e109_probe (id) values (1);
    t := public.founder_live_tick(false);
    select count(*) into ev from public.founder_live_events where source = 'e109_probe' and kind = 'change' and (detail ->> 'delta') = '1';
    if ev <> 1 then raise exception 'change event (delta 1) nahi bana (%)', ev; end if;
    if not (t -> 'changed') ? 'e109_probe' then raise exception 'tick ne changed mein e109_probe nahi diya'; end if;

    -- 3) badlav nahi => koi naya event nahi (shor nahi)
    select max(id) into v_ver from public.founder_live_events;
    t := public.founder_live_tick(false);
    if (t ->> 'version')::bigint <> v_ver then raise exception 'bina badlav ke version badh gaya'; end if;

    -- 4) stale: row purani kar do (expect 10 s) => "stale", phir nayi row => "recover"
    update public._e109_probe set updated_at = now() - interval '1 hour';
    t := public.founder_live_tick(false);
    if not exists (select 1 from public.founder_live_events where source = 'e109_probe' and kind = 'stale') then raise exception 'stale event nahi bana'; end if;
    insert into public._e109_probe (id) values (2);
    t := public.founder_live_tick(false);
    if not exists (select 1 from public.founder_live_events where source = 'e109_probe' and kind = 'recover') then raise exception 'recover event nahi bana'; end if;

    -- 5) vanish / appear
    drop table public._e109_probe;
    t := public.founder_live_tick(false);
    if not exists (select 1 from public.founder_live_events where source = 'e109_probe' and kind = 'vanish') then raise exception 'vanish event nahi bana'; end if;

    -- 6) append-only: update, delete (bina prune), truncate teeno band
    begin update public.founder_live_events set kind = 'change' where id = v_ver; raise exception 'update chal gaya'; exception when insufficient_privilege then null; end;
    begin delete from public.founder_live_events where id = v_ver; raise exception 'delete chal gaya'; exception when insufficient_privilege then null; end;
    begin truncate public.founder_live_events; raise exception 'truncate chal gaya'; exception when insufficient_privilege then null; end;

    -- 7) PII constraint: email jaisa kuch detail mein jaye to reject
    begin insert into public.founder_live_events (source, kind, detail) values ('e109_probe', 'change', '{"who":"a@b.com"}'); raise exception 'PII ghus gaya';
    exception when check_violation then null; end;

    -- 8) since(): catch-up + gap
    s := public.founder_live_since(0, 500);
    if jsonb_array_length(s -> 'events') < 4 then raise exception 'since() ne events nahi diye'; end if;
    s := public.founder_live_since(v_ver, 500);
    if (s ->> 'gap')::boolean then raise exception 'taza id par gap nahi hona chahiye'; end if;

    -- 9) snapshot shape + privacy
    sn := public.founder_live_snapshot();
    foreach k in array array['version','generated_at','values','money','customers','mail','polar','audit_head','gates','devices','sources','trouble'] loop
      if not sn ? k then raise exception 'snapshot mein % nahi', k; end if;
    end loop;
    if sn::text ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' then raise exception 'snapshot mein email jaisa kuch'; end if;
    if (sn -> 'trouble' ->> 'level') not in ('ok','warn','fail','unknown') then raise exception 'trouble level galat'; end if;

    -- 10) metrics + anomaly: 30 ghante ka saaf series (10, 11, 9, 10 ...) phir bada jhatka
    delete from public.founder_metric_points where metric = 'new_leads';
    insert into public.founder_metric_points (metric, bucket, value)
      select 'new_leads', date_trunc('hour', now()) - make_interval(hours => g), 10 + (g % 3) - 1 from generate_series(2, 40) g;
    insert into public.founder_metric_points (metric, bucket, value) values ('new_leads', date_trunc('minute', now()), 60);
    a := public.founder_live_anomalies(24, 3);
    if not exists (select 1 from jsonb_array_elements(a) e where e ->> 'metric' = 'new_leads' and (e ->> 'sigma')::numeric > 3) then raise exception 'anomaly pakdi nahi: %', a; end if;
    delete from public.founder_metric_points where metric = 'new_leads';
    insert into public.founder_metric_points (metric, bucket, value)
      select 'new_leads', date_trunc('hour', now()) - make_interval(hours => g), 10 + (g % 3) - 1 from generate_series(2, 40) g;
    insert into public.founder_metric_points (metric, bucket, value) values ('new_leads', date_trunc('minute', now()), 10);
    a := public.founder_live_anomalies(24, 3);
    if exists (select 1 from jsonb_array_elements(a) e where e ->> 'metric' = 'new_leads') then raise exception 'normal value par jhoota anomaly'; end if;

    -- 11) record(): badla nahi => naya point nahi
    n1 := public._founder_live_record('{"new_leads": 10}'::jsonb);
    n1 := public._founder_live_record('{"new_leads": 10}'::jsonb);
    if n1 <> 0 then raise exception 'bina badlav ke point likha gaya'; end if;

    -- 12) prune: chhoti retention manzoor nahi; theek retention chalti hai
    begin perform public.founder_live_prune(interval '1 hour', interval '90 days'); raise exception 'chhoti retention chal gayi';
    exception when invalid_parameter_value then null; end;
    perform public.founder_live_prune(interval '30 days', interval '90 days');

    raise exception 'E109_ROLLBACK';
  exception
    when others then
      if sqlerrm = 'E109_ROLLBACK' then msg := 'E109 selftest OK'; else msg := 'E109 selftest FAIL: ' || sqlerrm; end if;
  end;
  return msg;
end $$;
revoke all on function public.founder_live_selftest() from public, anon, authenticated;
grant execute on function public.founder_live_selftest() to service_role;

do $$ begin raise notice 'E109 founder_live tayyar. Chalao: CHECK_E109.sql'; end $$;
