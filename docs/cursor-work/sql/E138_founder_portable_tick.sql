
-- E138 — G5d part 2: the PORTABLE-PIN OBSERVER. SQL layer under the Rust route /founder/v1/audit/portable and the Rust tick (~60 s).
-- Founder order 3 Nov 07:24: "G5D shuru kero ... sql kam se kam 500 lines super advance". Quality law: SQL above super advanced.
-- TECHNOLOGY of this file: SQL (Supabase Postgres 16): constraints, triggers, append-only hash-chained ledgers, a fencing lease, RLS, selftest, CHECK file.
--   The Rust side (axum 0.8 + tokio, `portable.rs`) only CALLS these doors; the WASM kernel (part 3) does the verifying in the browser.
--
-- What E131 left open (part 1 wrote the horizon + bundle + log, but nothing RUNS them):
--   a) nobody calls founder_portable_observe() on a schedule, and nothing notices when the caller stops (a silent observer = a silent alarm);
--   b) two server processes (a restart overlap, a second host) must not both write the horizon log: they need a LEASE with a FENCING EPOCH;
--   c) the bundle is JSON; a browser must hash exactly the bytes the server hashed, so the server commits to ONE canonical text + its SHA-256;
--   d) "what did the server actually hand to the founder, and when" must itself be tamper-evident (serve ledger).
--
-- What this file adds (additive, idempotent; needs E102, E107, E120-E124, E131):
--   1) founder_portable_tick_policy : singleton knobs (lease length, heartbeat, stale limit, failure limit, serve throttle). Read-only at runtime, cross-column CHECK.
--   2) founder_portable_lease       : singleton row, ONE holder at a time, epoch only goes up (fencing token), takeover only after expiry, trigger-guarded.
--   3) founder_portable_tick_log    : APPEND-ONLY, hash-chained; the TRIGGER computes prev_hash / consec_fail / ts / hash; shape CHECK per outcome; epoch never goes back.
--   4) founder_portable_serve_log   : APPEND-ONLY, hash-chained record of every bundle handed out (who, which sha, which horizon/head), throttled in the door.
--   5) founder_portable_bundle_text(): the CANONICAL text of the bundle + its sha256 hex. The route sends the text as a string; the kernel hashes the same bytes.
--   6) founder_portable_lease_take() : grant / renew / takeover (epoch+1) / deny. Never longer than the policy allows.
--   7) founder_portable_tick()       : lease -> observe -> hash the canonical text -> ONE log row (de-duplicated by heartbeat). Any error becomes a 'failed' row, never a crash.
--   8) founder_portable_tick_fail()  : the Rust side reports its OWN failure (e.g. its re-hash disagreed) into the same chain, only while it holds the lease.
--   9) founder_portable_serve()      : founder only; returns the canonical bundle and appends the serve row (throttled per actor + sha).
--  10) founder_portable_tick_pulse() / founder_portable_status() : one honest level (off / ok / warn / fail) for the gauge; the worst of the horizon pulse and the observer pulse.
--  11) founder_portable_tick_verify(): re-checks both chains, the consec_fail rule, the epoch order and the lease. 12) selftest (rolls back) + CHECK_E138.
--
-- Honest limits: the observer proves that the SERVER kept watching; it does not make the server trustworthy. The proof is still the kernel's check in the browser.

set lock_timeout = '10s';
set statement_timeout = '120s';

-- 1) policy ------------------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_portable_tick:ddl', 0));
  create table if not exists public.founder_portable_tick_policy (
    id             boolean primary key default true check (id),
    lease_secs     integer not null default 90   check (lease_secs between 10 and 600),      -- a holder that stops renewing loses the lease after this long
    heartbeat_secs integer not null default 600  check (heartbeat_secs between 60 and 3600), -- an unchanged outcome is logged at most this often (the log is a heartbeat, not a flood)
    stale_secs     integer not null default 1800 check (stale_secs between 120 and 86400),   -- no log row for this long = the observer is silent (warn)
    max_consec_fail integer not null default 5   check (max_consec_fail between 2 and 50),   -- this many failed ticks in a row = fail
    serve_secs     integer not null default 60   check (serve_secs between 10 and 3600),     -- the same actor getting the same bundle is logged at most this often
    constraint founder_portable_tick_policy_stale check (stale_secs >= 2 * heartbeat_secs)   -- a healthy heartbeat can never look stale
  );
  insert into public.founder_portable_tick_policy (id) values (true) on conflict (id) do nothing;
  alter table public.founder_portable_tick_policy enable row level security;
  revoke all on public.founder_portable_tick_policy from public, anon, authenticated;
  grant select on public.founder_portable_tick_policy to service_role;
  revoke insert, update, delete, truncate, references, trigger on public.founder_portable_tick_policy from service_role;
end $$;

create or replace function public._fm_ptick_policy_guard() returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('app.portable_tick_policy_edit', true), '') = 'on' and tg_op <> 'TRUNCATE' then return coalesce(new, old); end if;
  raise exception 'E138: the observer policy is read-only at runtime' using errcode = '42501';
end $$;
drop trigger if exists founder_ptick_policy_guard on public.founder_portable_tick_policy;
create trigger founder_ptick_policy_guard before update or delete on public.founder_portable_tick_policy for each row execute function public._fm_ptick_policy_guard();
drop trigger if exists founder_ptick_policy_guard_trunc on public.founder_portable_tick_policy;
create trigger founder_ptick_policy_guard_trunc before truncate on public.founder_portable_tick_policy for each statement execute function public._fm_ptick_policy_guard();

-- helpers: a transaction-local floor (selftest only, like E131), the holder-name shape, the clock in ms --------------------------------------------
create or replace function public._fm_ptick_floor() returns bigint language sql stable set search_path = pg_catalog, public as $$
  select coalesce(nullif(current_setting('app.portable_tick_floor', true), '')::bigint, 0)
$$;
create or replace function public._fm_ptick_holder_ok(p text) returns boolean language sql immutable parallel safe set search_path = pg_catalog as $$
  select p is not null and p ~ '^[a-z0-9][a-z0-9._:-]{2,63}$'
$$;
create or replace function public._fm_ptick_now_ms() returns bigint language sql volatile set search_path = pg_catalog as $$
  select (extract(epoch from clock_timestamp()) * 1000)::bigint
$$;

-- 2) the lease (singleton, fencing epoch) ------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_portable_tick:ddl', 0));
  create table if not exists public.founder_portable_lease (
    id         boolean primary key default true check (id),
    holder     text,
    epoch      bigint  not null default 0 check (epoch >= 0),
    expires_ms bigint  not null default 0 check (expires_ms >= 0),
    taken_ms   bigint  not null default 0 check (taken_ms >= 0),
    constraint founder_portable_lease_holder_shape check (holder is null or public._fm_ptick_holder_ok(holder)),
    constraint founder_portable_lease_epoch_holder check ((holder is null) = (epoch = 0))   -- epoch 0 = never held; once held it is never empty again
  );
  insert into public.founder_portable_lease (id) values (true) on conflict (id) do nothing;
  alter table public.founder_portable_lease enable row level security;
  revoke all on public.founder_portable_lease from public, anon, authenticated;
  grant select on public.founder_portable_lease to service_role;
  revoke insert, update, delete, truncate, references, trigger on public.founder_portable_lease from service_role;   -- only the definer doors below can move it
end $$;

-- the epoch is a FENCING TOKEN: it never goes down, moves one step at a time, a new holder is always epoch+1 (the same name may also return as epoch+1 after an expiry), and the row can never be deleted.
create or replace function public._fm_ptick_lease_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op <> 'UPDATE' then raise exception 'E138: the lease row cannot be deleted or truncated' using errcode = '42501'; end if;
  if new.epoch < old.epoch then raise exception 'E138: the fencing epoch cannot go down (% -> %)', old.epoch, new.epoch using errcode = '42501'; end if;
  if new.holder is distinct from old.holder and new.epoch <> old.epoch + 1 then raise exception 'E138: a new holder must take epoch+1' using errcode = '42501'; end if;
  if new.epoch > old.epoch + 1 then raise exception 'E138: the epoch moves one step at a time' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_ptick_lease_guard on public.founder_portable_lease;
create trigger founder_ptick_lease_guard before update or delete on public.founder_portable_lease for each row execute function public._fm_ptick_lease_guard();
drop trigger if exists founder_ptick_lease_guard_trunc on public.founder_portable_lease;
create trigger founder_ptick_lease_guard_trunc before truncate on public.founder_portable_lease for each statement execute function public._fm_ptick_lease_guard();

-- 3) the tick log (append-only, hash-chained, computed by the trigger) -------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_portable_tick:ddl', 0));
  create table if not exists public.founder_portable_tick_log (
    id          bigint generated always as identity primary key,
    ts_ms       bigint  not null check (ts_ms > 0),
    epoch       bigint  not null check (epoch >= 1),
    holder      text    not null check (public._fm_ptick_holder_ok(holder)),
    outcome     text    not null check (outcome in ('observed', 'throttled', 'no_horizon', 'failed', 'lease_denied')),
    horizon_cp  bigint  check (horizon_cp is null or horizon_cp >= 1),
    bundle_sha  text    check (bundle_sha is null or bundle_sha ~ '^[0-9a-f]{64}$'),
    duration_ms integer not null default 0 check (duration_ms between 0 and 600000),
    error       text    check (error is null or length(error) between 1 and 300),
    consec_fail integer not null default 0 check (consec_fail >= 0),
    prev_hash   text    not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash        text    not null unique check (hash ~ '^[0-9a-f]{64}$'),
    -- the shape of every outcome is a database fact, not a Rust habit
    constraint founder_ptick_shape check (
         (outcome in ('observed', 'throttled') and horizon_cp is not null and bundle_sha is not null and error is null)
      or (outcome = 'no_horizon'  and horizon_cp is null and bundle_sha is null and error is null)
      or (outcome = 'failed'      and error is not null)
      or (outcome = 'lease_denied' and error is null))
  );
  create index if not exists founder_ptick_log_ts on public.founder_portable_tick_log (ts_ms desc);
  alter table public.founder_portable_tick_log enable row level security;
  revoke all on public.founder_portable_tick_log from public, anon, authenticated;
  grant select, insert on public.founder_portable_tick_log to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_portable_tick_log from service_role;
end $$;

create or replace function public._fm_ptick_hash(p_prev text, p_ts bigint, p_epoch bigint, p_holder text, p_outcome text, p_h bigint, p_sha text, p_dur integer, p_err text, p_cf integer) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || p_epoch || '|' || p_holder || '|' || p_outcome || '|' || coalesce(p_h::text, '-') || '|' || coalesce(p_sha, '-')
         || '|' || p_dur || '|' || coalesce(p_err, '-') || '|' || p_cf, 'UTF8'), 'sha256'), 'hex')
$$;

-- The trigger FILLS ts, prev_hash, consec_fail and hash: the caller names only the facts. The epoch may never be lower than the newest row's (fencing).
create or replace function public._fm_ptick_log_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_portable_tick_log%rowtype; q public.founder_portable_tick_log%rowtype;
begin
  if tg_op <> 'INSERT' then raise exception 'E138: tick log is append-only' using errcode = '42501'; end if;
  select * into p from public.founder_portable_tick_log order by id desc limit 1;
  if found and new.epoch < p.epoch then raise exception 'E138: a tick row with an older fencing epoch (% < %) was refused', new.epoch, p.epoch using errcode = '42501'; end if;
  select * into q from public.founder_portable_tick_log where id > public._fm_ptick_floor() order by id desc limit 1;
  new.ts_ms       := public._fm_ptick_now_ms();
  new.prev_hash   := coalesce(p.hash, repeat('0', 64));
  new.consec_fail := case new.outcome when 'failed' then coalesce(q.consec_fail, 0) + 1 when 'lease_denied' then coalesce(q.consec_fail, 0) else 0 end;
  new.hash        := public._fm_ptick_hash(new.prev_hash, new.ts_ms, new.epoch, new.holder, new.outcome, new.horizon_cp, new.bundle_sha, new.duration_ms, new.error, new.consec_fail);
  return new;
end $$;
create or replace function public._fm_ptick_stop() returns trigger language plpgsql as $$ begin raise exception 'E138: this ledger is append-only' using errcode = '42501'; end $$;
drop trigger if exists founder_ptick_log_guard on public.founder_portable_tick_log;
create trigger founder_ptick_log_guard before insert on public.founder_portable_tick_log for each row execute function public._fm_ptick_log_guard();
drop trigger if exists founder_ptick_log_stop on public.founder_portable_tick_log;
create trigger founder_ptick_log_stop before update or delete on public.founder_portable_tick_log for each row execute function public._fm_ptick_stop();
drop trigger if exists founder_ptick_log_stop_trunc on public.founder_portable_tick_log;
create trigger founder_ptick_log_stop_trunc before truncate on public.founder_portable_tick_log for each statement execute function public._fm_ptick_stop();

-- 4) the serve log (what the founder's browser was handed) -------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_portable_tick:ddl', 0));
  create table if not exists public.founder_portable_serve_log (
    id         bigint generated always as identity primary key,
    ts_ms      bigint not null check (ts_ms > 0),
    actor      uuid   not null,                                           -- no foreign key: an account delete must never rewrite or block a ledger
    bundle_sha text   not null check (bundle_sha ~ '^[0-9a-f]{64}$'),
    horizon_cp bigint not null check (horizon_cp >= 1),
    head_cp    bigint not null check (head_cp >= horizon_cp),             -- the head is never older than the horizon
    prev_hash  text   not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash       text   not null unique check (hash ~ '^[0-9a-f]{64}$')
  );
  create index if not exists founder_pserve_log_actor on public.founder_portable_serve_log (actor, bundle_sha, ts_ms desc);
  alter table public.founder_portable_serve_log enable row level security;
  revoke all on public.founder_portable_serve_log from public, anon, authenticated;
  grant select, insert on public.founder_portable_serve_log to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_portable_serve_log from service_role;
end $$;

create or replace function public._fm_pserve_hash(p_prev text, p_ts bigint, p_actor uuid, p_sha text, p_h bigint, p_head bigint) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || p_actor::text || '|' || p_sha || '|' || p_h || '|' || p_head, 'UTF8'), 'sha256'), 'hex')
$$;
create or replace function public._fm_pserve_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_portable_serve_log%rowtype;
begin
  if tg_op <> 'INSERT' then raise exception 'E138: serve log is append-only' using errcode = '42501'; end if;
  select * into p from public.founder_portable_serve_log order by id desc limit 1;
  new.ts_ms     := public._fm_ptick_now_ms();
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.hash      := public._fm_pserve_hash(new.prev_hash, new.ts_ms, new.actor, new.bundle_sha, new.horizon_cp, new.head_cp);
  return new;
end $$;
drop trigger if exists founder_pserve_guard on public.founder_portable_serve_log;
create trigger founder_pserve_guard before insert on public.founder_portable_serve_log for each row execute function public._fm_pserve_guard();
drop trigger if exists founder_pserve_stop on public.founder_portable_serve_log;
create trigger founder_pserve_stop before update or delete on public.founder_portable_serve_log for each row execute function public._fm_ptick_stop();
drop trigger if exists founder_pserve_stop_trunc on public.founder_portable_serve_log;
create trigger founder_pserve_stop_trunc before truncate on public.founder_portable_serve_log for each statement execute function public._fm_ptick_stop();

-- 5) the canonical bundle text -----------------------------------------------------------------------------------------------------------------
-- Only the parts a fresh browser VERIFIES go in (horizon note + evidence, head note, keys, ONE proof). Counters that change with every ledger row stay out, so the sha is
-- stable while nothing relevant moves. jsonb prints keys in a fixed order, so the same state is always the same text, and the browser hashes these exact bytes (kernel sha256@1).
create or replace function public.founder_portable_bundle_text() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare b jsonb; t text;
begin
  b := public.founder_portable_bundle();
  if not coalesce((b ->> 'found')::boolean, false) then return jsonb_build_object('found', false, 'why', coalesce(b ->> 'why', 'no bundle')); end if;
  t := jsonb_build_object('v', 1, 'horizon', b -> 'horizon', 'head', b -> 'head', 'keys', b -> 'keys', 'proof', b -> 'proof', 'proof_problem', b -> 'proof_problem')::text;
  return jsonb_build_object('found', true, 'text', t, 'sha', encode(extensions.digest(convert_to(t, 'UTF8'), 'sha256'), 'hex'),
                            'horizon_cp', (b #>> '{horizon,cp_id}')::bigint, 'head_cp', (b #>> '{head,cp_id}')::bigint, 'bytes', octet_length(convert_to(t, 'UTF8')));
end $$;

-- 6) the lease door ----------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_portable_lease_take(p_holder text, p_secs integer default null) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare pol public.founder_portable_tick_policy%rowtype; l public.founder_portable_lease%rowtype; v_now bigint := public._fm_ptick_now_ms(); v_secs integer; v_exp bigint;
begin
  if not public._fm_ptick_holder_ok(p_holder) then raise exception 'E138: the holder name must be 3-64 characters of a-z 0-9 . _ : -' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_portable_tick:lease', 0));
  select * into pol from public.founder_portable_tick_policy where id;
  select * into l from public.founder_portable_lease where id for update;
  v_secs := least(greatest(coalesce(p_secs, pol.lease_secs), 5), pol.lease_secs);   -- a caller can ask for less, never for more than the policy
  v_exp  := v_now + v_secs * 1000;
  if l.holder is null or l.expires_ms <= v_now then
    -- first ever grant, or the old lease ran out (even if the SAME name comes back: it may have been paused, so it gets a new epoch)
    update public.founder_portable_lease set holder = p_holder, epoch = l.epoch + 1, expires_ms = v_exp, taken_ms = v_now where id returning * into l;
    return jsonb_build_object('granted', true, 'epoch', l.epoch, 'holder', l.holder, 'expires_ms', l.expires_ms, 'takeover', true);
  elsif l.holder = p_holder then
    update public.founder_portable_lease set expires_ms = v_exp where id returning * into l;
    return jsonb_build_object('granted', true, 'epoch', l.epoch, 'holder', l.holder, 'expires_ms', l.expires_ms, 'takeover', false);
  end if;
  return jsonb_build_object('granted', false, 'epoch', l.epoch, 'held_by', l.holder, 'retry_ms', greatest(l.expires_ms - v_now, 0));
end $$;

-- 7) the tick -----------------------------------------------------------------------------------------------------------------------------------
-- One call per ~60 s from Rust. It never raises for an operational problem: the problem becomes a 'failed' row, so the pulse can see it.
create or replace function public.founder_portable_tick(p_holder text) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare pol public.founder_portable_tick_policy%rowtype; ls jsonb; o jsonb; b jsonb; q public.founder_portable_tick_log%rowtype;
        v_t0 timestamptz := clock_timestamp(); v_out text; v_epoch bigint; v_h bigint; v_sha text; v_err text; v_dur integer; v_log boolean := true; v_id bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_portable_tick:run', 0));   -- ticks are serialised; the lease still decides WHO may run
  select * into pol from public.founder_portable_tick_policy where id;
  ls := public.founder_portable_lease_take(p_holder);
  v_epoch := (ls ->> 'epoch')::bigint;
  if not (ls ->> 'granted')::boolean then
    v_out := 'lease_denied';
  else
    begin
      o := public.founder_portable_observe();
      b := public.founder_portable_bundle_text();
      if (b ->> 'found')::boolean then
        v_h := (b ->> 'horizon_cp')::bigint; v_sha := b ->> 'sha';
        v_out := case when (o ->> 'observed')::boolean then 'observed' when o ->> 'horizon_cp' is not null then 'throttled' else 'failed' end;
        if v_out = 'failed' then v_err := 'the horizon is not in the log although a bundle exists: ' || left(coalesce(o ->> 'why', '?'), 200); v_h := null; v_sha := null; end if;
      elsif (o ->> 'observed')::boolean or o ->> 'horizon_cp' is not null then
        v_out := 'failed'; v_err := 'a horizon is logged but no bundle can be built: ' || left(coalesce(b ->> 'why', '?'), 200);
      else
        v_out := 'no_horizon';
      end if;
    exception when others then
      v_out := 'failed'; v_err := left('observe failed: ' || sqlerrm, 300); v_h := null; v_sha := null;
    end;
  end if;
  v_dur := least(greatest((extract(epoch from clock_timestamp() - v_t0) * 1000)::integer, 0), 600000);
  -- an unchanged, harmless outcome is logged once per heartbeat; anything new, any 'observed' and any 'failed' is always logged
  select * into q from public.founder_portable_tick_log where id > public._fm_ptick_floor() order by id desc limit 1;
  if v_out in ('throttled', 'no_horizon', 'lease_denied') and found and (q.outcome = v_out or (v_out = 'throttled' and q.outcome = 'observed')) and q.holder = p_holder and q.bundle_sha is not distinct from v_sha
     and q.horizon_cp is not distinct from v_h and public._fm_ptick_now_ms() - q.ts_ms < pol.heartbeat_secs * 1000 then v_log := false; end if;
  if v_log then
    insert into public.founder_portable_tick_log (ts_ms, epoch, holder, outcome, horizon_cp, bundle_sha, duration_ms, error, consec_fail, prev_hash, hash)
      values (1, v_epoch, p_holder, v_out, v_h, v_sha, v_dur, v_err, 0, repeat('0', 64), repeat('0', 64)) returning id into v_id;   -- the trigger overwrites ts, prev_hash, consec_fail, hash
  end if;
  return jsonb_build_object('outcome', v_out, 'epoch', v_epoch, 'holder', p_holder, 'logged', v_log, 'log_id', v_id, 'horizon_cp', v_h, 'bundle_sha', v_sha, 'error', v_err, 'duration_ms', v_dur);
end $$;

-- 8) the Rust side reports its own failure (for example: it re-hashed the canonical text and the sha did not match) -------------------------------------
create or replace function public.founder_portable_tick_fail(p_holder text, p_error text) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare l public.founder_portable_lease%rowtype; v_id bigint; v_cf integer;
begin
  if not public._fm_ptick_holder_ok(p_holder) then raise exception 'E138: bad holder name' using errcode = '22023'; end if;
  if p_error is null or length(btrim(p_error)) < 4 then raise exception 'E138: a failure needs a reason of at least 4 characters' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_portable_tick:run', 0));
  select * into l from public.founder_portable_lease where id;
  if l.holder is distinct from p_holder or l.expires_ms <= public._fm_ptick_now_ms() then
    raise exception 'E138: only the current lease holder may report a failure' using errcode = '42501'; end if;
  insert into public.founder_portable_tick_log (ts_ms, epoch, holder, outcome, error, prev_hash, hash)
    values (1, l.epoch, p_holder, 'failed', left(btrim(p_error), 300), repeat('0', 64), repeat('0', 64)) returning id, consec_fail into v_id, v_cf;
  return jsonb_build_object('logged', true, 'log_id', v_id, 'consec_fail', v_cf, 'epoch', l.epoch);
end $$;

-- 9) serve: what the founder's browser gets. Founder only; the row says WHO got WHICH bytes ---------------------------------------------------------
create or replace function public.founder_portable_serve(p_actor uuid) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare pol public.founder_portable_tick_policy%rowtype; b jsonb; v_logged boolean := false;
begin
  if p_actor is null or not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'E138: founder only' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_portable_tick:serve', 0));
  select * into pol from public.founder_portable_tick_policy where id;
  b := public.founder_portable_bundle_text();
  if not (b ->> 'found')::boolean then return b || jsonb_build_object('logged', false); end if;
  if not exists (select 1 from public.founder_portable_serve_log where actor = p_actor and bundle_sha = b ->> 'sha'
                  and ts_ms > public._fm_ptick_now_ms() - pol.serve_secs * 1000) then
    insert into public.founder_portable_serve_log (ts_ms, actor, bundle_sha, horizon_cp, head_cp, prev_hash, hash)
      values (1, p_actor, b ->> 'sha', (b ->> 'horizon_cp')::bigint, (b ->> 'head_cp')::bigint, repeat('0', 64), repeat('0', 64));
    v_logged := true;
  end if;
  return b || jsonb_build_object('logged', v_logged);
end $$;

-- 10) pulses -----------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_portable_tick_pulse(p_now_ms bigint default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare pol public.founder_portable_tick_policy%rowtype; l public.founder_portable_tick_log%rowtype; v_now bigint := coalesce(p_now_ms, public._fm_ptick_now_ms()); v_epochs bigint; v_level text := 'ok'; v_why text;
begin
  select * into pol from public.founder_portable_tick_policy where id;
  select * into l from public.founder_portable_tick_log where id > public._fm_ptick_floor() order by id desc limit 1;
  if l.id is null then return jsonb_build_object('level', 'off', 'why', 'the observer has not run yet', 'last_tick_ms', null); end if;
  select count(distinct epoch) into v_epochs from public.founder_portable_tick_log where id > public._fm_ptick_floor() and ts_ms > v_now - 86400000;
  if l.consec_fail >= pol.max_consec_fail then v_level := 'fail'; v_why := l.consec_fail || ' failed ticks in a row: ' || coalesce(l.error, '?');
  elsif v_now - l.ts_ms > pol.stale_secs * 1000 then v_level := 'warn'; v_why := 'the observer has been silent for ' || ((v_now - l.ts_ms) / 60000) || ' minutes';
  elsif v_epochs > 6 then v_level := 'warn'; v_why := 'the lease changed hands ' || (v_epochs - 1) || ' times in 24 hours';
  elsif l.outcome = 'failed' then v_level := 'warn'; v_why := 'the last tick failed: ' || coalesce(l.error, '?'); end if;
  return jsonb_build_object('level', v_level, 'why', v_why, 'last_tick_ms', l.ts_ms, 'last_outcome', l.outcome, 'consec_fail', l.consec_fail, 'epoch', l.epoch, 'holders_24h', v_epochs);
end $$;

create or replace function public.founder_portable_status() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare a jsonb; b jsonb; s public.founder_portable_serve_log%rowtype; v_level text; pol public.founder_portable_tick_policy%rowtype;
begin
  select * into pol from public.founder_portable_tick_policy where id;
  a := public.founder_portable_pulse(); b := public.founder_portable_tick_pulse();
  select * into s from public.founder_portable_serve_log order by id desc limit 1;
  v_level := case when 'fail' in (a ->> 'level', b ->> 'level') then 'fail' when 'warn' in (a ->> 'level', b ->> 'level') then 'warn'
                  when 'off' in (a ->> 'level', b ->> 'level') then 'off' else 'ok' end;
  return jsonb_build_object('level', v_level, 'portable', a, 'observer', b,
    'last_serve', case when s.id is null then null else jsonb_build_object('ts_ms', s.ts_ms, 'bundle_sha', s.bundle_sha, 'horizon_cp', s.horizon_cp, 'head_cp', s.head_cp) end,
    'serves', (select count(*) from public.founder_portable_serve_log),
    'policy', jsonb_build_object('lease_secs', pol.lease_secs, 'heartbeat_secs', pol.heartbeat_secs, 'stale_secs', pol.stale_secs, 'max_consec_fail', pol.max_consec_fail));
end $$;

-- 11) re-check what is STORED -------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_portable_tick_verify(p_last integer default 500) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r record; s record; v_probs jsonb := '[]'::jsonb; v_prev text; v_first boolean := true; v_n integer := 0; v_ns integer := 0; v_cf integer; v_ep bigint; l public.founder_portable_lease%rowtype;
        v_exp_cf integer; v_max bigint; v_lim integer := greatest(1, least(coalesce(p_last, 500), 5000));
begin
  for r in select * from (select * from public.founder_portable_tick_log order by id desc limit v_lim) q order by id loop
    v_n := v_n + 1;
    if not v_first and r.prev_hash <> v_prev then v_probs := v_probs || jsonb_build_array(jsonb_build_object('tick_id', r.id, 'problem', 'the tick log chain is broken here')); end if;
    if r.hash <> public._fm_ptick_hash(r.prev_hash, r.ts_ms, r.epoch, r.holder, r.outcome, r.horizon_cp, r.bundle_sha, r.duration_ms, r.error, r.consec_fail) then
      v_probs := v_probs || jsonb_build_array(jsonb_build_object('tick_id', r.id, 'problem', 'a tick row hash does not match its row')); end if;
    if not v_first and public._fm_ptick_floor() = 0 then
      v_exp_cf := case r.outcome when 'failed' then v_cf + 1 when 'lease_denied' then v_cf else 0 end;
      if r.consec_fail <> v_exp_cf then
        v_probs := v_probs || jsonb_build_array(jsonb_build_object('tick_id', r.id, 'problem', 'consec_fail does not follow the rule')); end if;
      if r.epoch < v_ep then v_probs := v_probs || jsonb_build_array(jsonb_build_object('tick_id', r.id, 'problem', 'the fencing epoch went backwards')); end if;
    end if;
    v_first := false; v_prev := r.hash; v_cf := r.consec_fail; v_ep := r.epoch;
  end loop;
  v_first := true;
  for s in select * from (select * from public.founder_portable_serve_log order by id desc limit v_lim) q order by id loop
    v_ns := v_ns + 1;
    if not v_first and s.prev_hash <> v_prev then v_probs := v_probs || jsonb_build_array(jsonb_build_object('serve_id', s.id, 'problem', 'the serve log chain is broken here')); end if;
    if s.hash <> public._fm_pserve_hash(s.prev_hash, s.ts_ms, s.actor, s.bundle_sha, s.horizon_cp, s.head_cp) then
      v_probs := v_probs || jsonb_build_array(jsonb_build_object('serve_id', s.id, 'problem', 'a serve row hash does not match its row')); end if;
    v_first := false; v_prev := s.hash;
  end loop;
  select * into l from public.founder_portable_lease where id;
  select coalesce(max(epoch), 0) into v_max from public.founder_portable_tick_log;
  if l.epoch < v_max then v_probs := v_probs || jsonb_build_array(jsonb_build_object('problem', 'the lease epoch is lower than a logged epoch')); end if;
  return jsonb_build_object('checked_ticks', v_n, 'checked_serves', v_ns, 'lease_epoch', l.epoch, 'ok', jsonb_array_length(v_probs) = 0, 'problems', v_probs);
end $$;

-- 12) selftest: everything inside a block that ends in ROLLBACK; safe on a live ledger (deltas + floors) ---------------------------------------------
create or replace function public.founder_portable_e138_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '120s' as $$
declare r text := ''; v_uid uuid; j jsonb; b jsonb; p jsonb; v_name text := 'selftest.example/portable-tick'; v_pub text := repeat('ef', 32); v_kid text; v_key_id bigint; v_cp jsonb;
        v_c1 bigint; v_c2 bigint; v_c3 bigint; v_note text; v_sig_ms bigint; v_dig text; v_ev text; v_j1 bigint; v_j2 bigint; v_j3 bigint; i integer; n0 bigint; n1 bigint; v_base integer;
        t_log bigint; t_srv bigint; t_h text; t_s text; t_aud bigint; t_epoch bigint; t_holder text; t_exp bigint; t_evi bigint; t_jobs bigint; t_hlog bigint; v_sha1 text; v_sha2 text; v_max integer;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E138 selftest SKIP (no founder account yet)'; end if;
  select count(*), coalesce(max(hash), '') into t_log, t_h from public.founder_portable_tick_log;
  select count(*), coalesce(max(hash), '') into t_srv, t_s from public.founder_portable_serve_log;
  select count(*) into t_aud from public.founder_audit; select count(*) into t_evi from public.founder_anchor_evidence; select count(*) into t_jobs from public.founder_anchor_jobs;
  select count(*) into t_hlog from public.founder_portable_horizon_log;
  select epoch, holder, expires_ms into t_epoch, t_holder, t_exp from public.founder_portable_lease where id;
  select max_consec_fail into v_max from public.founder_portable_tick_policy where id;
  begin
    perform set_config('app.portable_tick_floor', coalesce((select max(id) from public.founder_portable_tick_log), 0)::text, true);
    perform set_config('app.portable_floor', coalesce((select max(id) from public.founder_audit_checkpoints), 0)::text, true);

    -- policy: read-only at runtime, and the cross-column rule holds even for an editor
    if not public._fs_fails($q$update public.founder_portable_tick_policy set heartbeat_secs = 61$q$) or not public._fs_fails($q$delete from public.founder_portable_tick_policy$q$)
       or not public._fs_fails($q$truncate public.founder_portable_tick_policy$q$) then raise exception 'the observer policy can be changed at runtime'; end if;
    perform set_config('app.portable_tick_policy_edit', 'on', true);
    if not public._fs_fails($q$update public.founder_portable_tick_policy set heartbeat_secs = 1000, stale_secs = 1500$q$) then raise exception 'stale < 2 x heartbeat was accepted'; end if;
    if not public._fs_fails($q$update public.founder_portable_tick_policy set lease_secs = 9$q$) then raise exception 'a lease shorter than 10 s was accepted'; end if;
    perform set_config('app.portable_tick_policy_edit', '', true);
    r := r || 'policy read-only + cross-column CHECK OK; ';

    -- lease: shape, grant, renew, deny, expiry takeover = epoch+1, fencing guard
    if not public._fs_fails($q$select public.founder_portable_lease_take('AB')$q$) or not public._fs_fails($q$select public.founder_portable_lease_take('has space here')$q$)
       or not public._fs_fails($q$select public.founder_portable_lease_take(null)$q$) then raise exception 'a bad holder name was accepted'; end if;
    update public.founder_portable_lease set expires_ms = 0 where id;                                  -- the owner may expire a lease (the selftest starts from a free lease)
    j := public.founder_portable_lease_take('selftest-a', 5000);
    if not (j ->> 'granted')::boolean or (j ->> 'epoch')::bigint <> t_epoch + 1 or not (j ->> 'takeover')::boolean then raise exception 'first grant is wrong: %', j; end if;
    if (j ->> 'expires_ms')::bigint - public._fm_ptick_now_ms() > _fm_ptick_lease_ms() then raise exception 'the lease is longer than the policy allows: %', j; end if;
    j := public.founder_portable_lease_take('selftest-a');
    if not (j ->> 'granted')::boolean or (j ->> 'epoch')::bigint <> t_epoch + 1 or (j ->> 'takeover')::boolean then raise exception 'a renew must keep the epoch: %', j; end if;
    j := public.founder_portable_lease_take('selftest-b');
    if (j ->> 'granted')::boolean or j ->> 'held_by' <> 'selftest-a' or (j ->> 'retry_ms')::bigint <= 0 then raise exception 'a second holder must be denied: %', j; end if;
    update public.founder_portable_lease set expires_ms = 1 where id;
    j := public.founder_portable_lease_take('selftest-b');
    if not (j ->> 'granted')::boolean or (j ->> 'epoch')::bigint <> t_epoch + 2 then raise exception 'a takeover after expiry must be epoch+1: %', j; end if;
    update public.founder_portable_lease set expires_ms = 1 where id;
    j := public.founder_portable_lease_take('selftest-b');
    if (j ->> 'epoch')::bigint <> t_epoch + 3 then raise exception 'the SAME name returning after expiry must also get a new epoch: %', j; end if;
    if not public._fs_fails($q$update public.founder_portable_lease set epoch = epoch - 1$q$) or not public._fs_fails($q$update public.founder_portable_lease set holder = 'selftest-c'$q$)
       or not public._fs_fails($q$update public.founder_portable_lease set epoch = epoch + 2$q$) or not public._fs_fails($q$delete from public.founder_portable_lease$q$)
       or not public._fs_fails($q$truncate public.founder_portable_lease$q$) or not public._fs_fails($q$insert into public.founder_portable_lease (id) values (false)$q$) then
      raise exception 'the lease guard has a hole'; end if;
    update public.founder_portable_lease set holder = 'selftest-b' where id;                           -- same holder, same epoch: allowed
    r := r || 'lease grant/renew/deny/takeover + fencing guard OK; ';

    -- tick without any outside evidence = no_horizon, de-duplicated by the heartbeat; a lease denial is logged once
    n0 := (select count(*) from public.founder_portable_tick_log);
    j := public.founder_portable_tick('selftest-b');
    if j ->> 'outcome' <> 'no_horizon' or not (j ->> 'logged')::boolean or j ->> 'bundle_sha' is not null then raise exception 'tick without evidence must read no_horizon: %', j; end if;
    j := public.founder_portable_tick('selftest-b');
    if j ->> 'outcome' <> 'no_horizon' or (j ->> 'logged')::boolean then raise exception 'an unchanged no_horizon must not be logged twice inside the heartbeat: %', j; end if;
    j := public.founder_portable_tick('selftest-a');
    if j ->> 'outcome' <> 'lease_denied' or not (j ->> 'logged')::boolean then raise exception 'a denied holder must be logged: %', j; end if;
    j := public.founder_portable_tick('selftest-a');
    if (j ->> 'logged')::boolean then raise exception 'a repeated denial must be de-duplicated: %', j; end if;
    if (select count(*) from public.founder_portable_tick_log) <> n0 + 2 then raise exception 'wrong number of tick rows'; end if;
    r := r || 'tick no_horizon + lease_denied + heartbeat de-dup OK; ';

    -- failures chain, reset, and only the lease holder may report one
    if not public._fs_fails($q$select public.founder_portable_tick_fail('selftest-a', 'reported by a stranger')$q$) or not public._fs_fails($q$select public.founder_portable_tick_fail('selftest-b', 'xx')$q$) then
      raise exception 'tick_fail accepted a stranger or a one-word reason'; end if;
    v_base := coalesce((select consec_fail from public.founder_portable_tick_log where id > public._fm_ptick_floor() order by id desc limit 1), 0);
    j := public.founder_portable_tick_fail('selftest-b', 'the re-hash of the canonical text disagreed');
    if (j ->> 'consec_fail')::int <> v_base + 1 then raise exception 'consec_fail must count up: % (base %)', j, v_base; end if;
    j := public.founder_portable_tick_fail('selftest-b', 'second failure');
    if (j ->> 'consec_fail')::int <> v_base + 2 then raise exception 'consec_fail must keep counting: %', j; end if;
    p := public.founder_portable_tick_pulse();
    if p ->> 'level' <> 'warn' or p ->> 'last_outcome' <> 'failed' then raise exception 'a failed last tick must read warn: %', p; end if;
    for i in 1 .. greatest(v_max, 2) loop perform public.founder_portable_tick_fail('selftest-b', 'failure number ' || i); end loop;
    p := public.founder_portable_tick_pulse();
    if p ->> 'level' <> 'fail' then raise exception 'max_consec_fail failures must read fail: %', p; end if;
    j := public.founder_portable_tick('selftest-b');
    if j ->> 'outcome' <> 'no_horizon' then raise exception 'a clean tick after failures: %', j; end if;
    p := public.founder_portable_tick_pulse();
    if p ->> 'level' <> 'ok' or (p ->> 'consec_fail')::int <> 0 then raise exception 'a clean tick must reset the failure count: %', p; end if;
    p := public.founder_portable_tick_pulse(public._fm_ptick_now_ms() + 3 * 3600 * 1000);
    if p ->> 'level' <> 'warn' or p ->> 'why' not like 'the observer has been silent%' then raise exception 'a silent observer must read warn: %', p; end if;
    r := r || 'failures chain + reset + stale + fail levels OK; ';

    -- the log: append-only, the caller cannot choose ts/prev/consec/hash, bad shapes and older epochs are refused
    if not public._fs_fails($q$update public.founder_portable_tick_log set outcome = 'observed'$q$) or not public._fs_fails($q$delete from public.founder_portable_tick_log$q$)
       or not public._fs_fails($q$truncate public.founder_portable_tick_log$q$) then raise exception 'the tick log is not append-only'; end if;
    insert into public.founder_portable_tick_log (ts_ms, epoch, holder, outcome, prev_hash, hash, consec_fail) values (1, (select epoch from public.founder_portable_lease where id), 'selftest-b', 'no_horizon', repeat('f', 64), repeat('f', 64), 99);
    select to_jsonb(l) into p from public.founder_portable_tick_log l order by id desc limit 1;
    if (p ->> 'consec_fail')::int <> 0 or p ->> 'prev_hash' = repeat('f', 64) or p ->> 'hash' = repeat('f', 64) or (p ->> 'ts_ms')::bigint < public._fm_ptick_now_ms() - 60000 then raise exception 'the caller chose a computed column: %', p; end if;
    if not public._fs_fails($q$insert into public.founder_portable_tick_log (ts_ms, epoch, holder, outcome, prev_hash, hash) values (1, 1, 'selftest-b', 'no_horizon', repeat('0', 64), repeat('0', 64))$q$) then raise exception 'an older fencing epoch was accepted'; end if;
    if not public._fs_fails($q$insert into public.founder_portable_tick_log (ts_ms, epoch, holder, outcome, prev_hash, hash) values (1, 9000000, 'selftest-b', 'observed', repeat('0', 64), repeat('0', 64))$q$)
       or not public._fs_fails($q$insert into public.founder_portable_tick_log (ts_ms, epoch, holder, outcome, prev_hash, hash) values (1, 9000000, 'selftest-b', 'failed', repeat('0', 64), repeat('0', 64))$q$)
       or not public._fs_fails($q$insert into public.founder_portable_tick_log (ts_ms, epoch, holder, outcome, prev_hash, hash) values (1, 9000000, 'selftest-b', 'sleeping', repeat('0', 64), repeat('0', 64))$q$) then
      raise exception 'a bad outcome shape was accepted'; end if;
    j := public.founder_portable_tick_verify(500);
    if not (j ->> 'ok')::boolean then raise exception 'verify failed on a good state: %', j; end if;
    r := r || 'tick log append-only + trigger-computed + shape CHECK OK; ';

    -- a real horizon (same scaffolding as the E131 selftest): serve, canonical text, sha, throttle, a changed state = a new sha
    update public.founder_audit_log_keys set status = 'retired', retired_ms = greatest(created_ms, (extract(epoch from clock_timestamp()) * 1000)::bigint) where status = 'active';
    v_kid := substr(encode(extensions.digest(convert_to(v_name, 'UTF8') || '\x0a01'::bytea || decode(v_pub, 'hex'), 'sha256'), 'hex'), 1, 8);
    perform public.founder_audit_log_key_register(v_uid, v_name, v_pub, v_kid);
    select id into v_key_id from public.founder_audit_log_keys where status = 'active';
    for i in 1 .. 3 loop
      perform public.founder_audit_append(v_uid, 'e138.selftest', 'row-' || i, 'selftest entry ' || i, '{}'::jsonb);
      perform public.founder_audit_checkpoint(v_uid, 'selftest seal ' || i);
      v_cp := (public.founder_audit_signed_cp_pending(50)) -> -1;
      v_note := v_name || E'\n' || (v_cp ->> 'size') || E'\n' || encode(decode(v_cp ->> 'root', 'hex'), 'base64') || E'\n' || E'\n' || E'— ' || v_name || ' '
                || replace(encode(decode(v_kid, 'hex') || decode(repeat('22', 64), 'hex'), 'base64'), E'\n', '') || E'\n';
      perform public.founder_audit_signed_cp_add((v_cp ->> 'cp_id')::bigint, v_key_id, v_note);
      if i = 1 then v_c1 := (v_cp ->> 'cp_id')::bigint; elsif i = 2 then v_c2 := (v_cp ->> 'cp_id')::bigint; else v_c3 := (v_cp ->> 'cp_id')::bigint; end if;
    end loop;
    b := public.founder_portable_bundle_text();
    if (b ->> 'found')::boolean then raise exception 'a canonical bundle exists without outside evidence: %', b; end if;
    if not public._fs_fails($q$select public.founder_portable_serve('00000000-0000-0000-0000-000000000000'::uuid)$q$) then raise exception 'serve accepted a non-founder'; end if;
    j := public.founder_portable_serve(v_uid);
    if (j ->> 'found')::boolean or (j ->> 'logged')::boolean then raise exception 'serve must not log when there is no bundle: %', j; end if;
    perform public.founder_anchor_enqueue();
    update public.founder_anchor_jobs set next_try_ms = 0;
    select id into v_j1 from public.founder_anchor_jobs where cp_id = v_c2 and provider_id = (select id from public.founder_anchor_providers where name = 'freetsa');
    select id into v_j2 from public.founder_anchor_jobs where cp_id = v_c2 and provider_id = (select id from public.founder_anchor_providers where name = 'digicert-tsa');
    select id into v_j3 from public.founder_anchor_jobs where cp_id = v_c2 and provider_id = (select id from public.founder_anchor_providers where name = 'sectigo-tsa');
    perform public.founder_anchor_next(60);
    select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = v_c2;
    v_dig := public._fm_anchor_digest(v_c2);
    v_ev := encode('\x3082'::bytea || decode(v_dig, 'hex') || '\x0102030405'::bytea, 'hex');
    perform public.founder_anchor_record_tsa(v_j1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'a1', 'signer_pin', repeat('a', 64)));
    perform public.founder_anchor_record_tsa(v_j2, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 2000, 'serial', 'b2', 'signer_pin', repeat('b', 64)));
    b := public.founder_portable_bundle_text();
    if not (b ->> 'found')::boolean or (b ->> 'horizon_cp')::bigint <> v_c2 or (b ->> 'head_cp')::bigint <> v_c3 then raise exception 'canonical bundle is wrong: %', b; end if;
    v_sha1 := b ->> 'sha';
    if v_sha1 <> encode(extensions.digest(convert_to(b ->> 'text', 'UTF8'), 'sha256'), 'hex') then raise exception 'the sha is not the sha256 of the text'; end if;
    if (b ->> 'bytes')::int <> octet_length(convert_to(b ->> 'text', 'UTF8')) or (public.founder_portable_bundle_text() ->> 'text') <> (b ->> 'text') then raise exception 'the canonical text is not stable'; end if;
    p := (b ->> 'text')::jsonb;                                                                  -- the browser parses the very text it hashed
    if p ->> 'v' <> '1' or (p #>> '{horizon,cp_id}')::bigint <> v_c2 or (p #>> '{head,cp_id}')::bigint <> v_c3 or p -> 'proof' is null or p -> 'keys' is null then raise exception 'the text lacks a part: %', p; end if;
    if p ? 'coverage' or p ? 'horizon_log' then raise exception 'volatile counters leaked into the committed text'; end if;
    n0 := (select count(*) from public.founder_portable_serve_log);
    j := public.founder_portable_serve(v_uid);
    if not (j ->> 'found')::boolean or not (j ->> 'logged')::boolean or j ->> 'sha' <> v_sha1 then raise exception 'first serve must be logged: %', j; end if;
    j := public.founder_portable_serve(v_uid);
    if (j ->> 'logged')::boolean then raise exception 'the same serve inside the throttle window was logged twice'; end if;
    -- a third authority adds evidence -> the bytes change -> the sha changes -> a new serve row
    perform public.founder_anchor_record_tsa(v_j3, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 3000, 'serial', 'c3', 'signer_pin', repeat('c', 64)));
    j := public.founder_portable_serve(v_uid);
    v_sha2 := j ->> 'sha';
    if v_sha2 = v_sha1 or not (j ->> 'logged')::boolean then raise exception 'new evidence must give a new sha and a new serve row: %', j; end if;
    if (select count(*) from public.founder_portable_serve_log) <> n0 + 2 then raise exception 'wrong number of serve rows'; end if;
    if (select head_cp >= horizon_cp from public.founder_portable_serve_log order by id desc limit 1) is not true then raise exception 'serve row head < horizon'; end if;
    if not public._fs_fails($q$update public.founder_portable_serve_log set horizon_cp = 1$q$) or not public._fs_fails($q$delete from public.founder_portable_serve_log$q$)
       or not public._fs_fails($q$truncate public.founder_portable_serve_log$q$) then raise exception 'the serve log is not append-only'; end if;
    if not public._fs_fails($q$insert into public.founder_portable_serve_log (ts_ms, actor, bundle_sha, horizon_cp, head_cp, prev_hash, hash) values (1, gen_random_uuid(), repeat('a', 64), 5, 4, repeat('0', 64), repeat('0', 64))$q$) then
      raise exception 'a serve row with head < horizon was accepted'; end if;
    r := r || 'canonical text + sha + serve throttle + new evidence = new sha OK; ';

    -- tick with a real horizon: observed once (logged), then throttled (de-duplicated), and the sha is the canonical one
    j := public.founder_portable_tick('selftest-b');
    if j ->> 'outcome' <> 'observed' or not (j ->> 'logged')::boolean or j ->> 'bundle_sha' <> v_sha2 or (j ->> 'horizon_cp')::bigint <> v_c2 then raise exception 'first tick with a horizon must read observed: %', j; end if;
    j := public.founder_portable_tick('selftest-b');
    if j ->> 'outcome' <> 'throttled' or (j ->> 'logged')::boolean or j ->> 'bundle_sha' <> v_sha2 then raise exception 'second tick must be throttled and not logged: %', j; end if;
    p := public.founder_portable_status();
    if p #>> '{portable,level}' <> 'ok' or p #>> '{observer,level}' <> 'ok' or p ->> 'level' <> 'ok' or (p ->> 'serves')::bigint < 2 then raise exception 'status should be ok: %', p; end if;
    r := r || 'tick observed + throttled + status ok OK; ';

    -- the worst level wins: a regressed horizon (E131 trigger) makes the whole status fail while the observer is still ok
    insert into public.founder_portable_horizon_log (ts_ms, horizon_cp, best_cp, regressed, anchored_ms, prev_hash, hash) values (1, v_c3, v_c3, false, 1, repeat('0', 64), repeat('0', 64));
    p := public.founder_portable_status();
    if p ->> 'level' <> 'fail' or p #>> '{observer,level}' <> 'ok' then raise exception 'the worst level must win: %', p; end if;
    -- tamper detection: switch the guard off (rolled back) and edit a stored row; the verifier must see it
    alter table public.founder_portable_tick_log disable trigger founder_ptick_log_stop;
    update public.founder_portable_tick_log set outcome = 'throttled', horizon_cp = 1, bundle_sha = repeat('1', 64), error = null where id = (select max(id) from public.founder_portable_tick_log where outcome = 'observed');
    j := public.founder_portable_tick_verify(500);
    if (j ->> 'ok')::boolean then raise exception 'verify missed an edited tick row'; end if;
    alter table public.founder_portable_tick_log enable trigger founder_ptick_log_stop;
    r := r || 'worst-level + tamper detection OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E138 selftest FAIL: %', sqlerrm; end if;
  end;
  perform set_config('app.portable_tick_floor', '', true); perform set_config('app.portable_floor', '', true);
  if (select count(*) from public.founder_portable_tick_log) <> t_log or coalesce((select max(hash) from public.founder_portable_tick_log), '') <> t_h
     or (select count(*) from public.founder_portable_serve_log) <> t_srv or coalesce((select max(hash) from public.founder_portable_serve_log), '') <> t_s
     or (select count(*) from public.founder_audit) <> t_aud or (select count(*) from public.founder_anchor_evidence) <> t_evi or (select count(*) from public.founder_anchor_jobs) <> t_jobs
     or (select count(*) from public.founder_portable_horizon_log) <> t_hlog
     or (select epoch from public.founder_portable_lease where id) <> t_epoch or (select holder from public.founder_portable_lease where id) is distinct from t_holder
     or (select expires_ms from public.founder_portable_lease where id) <> t_exp then raise exception 'E138 selftest left rows behind'; end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_portable_tick_log'::regclass and tgname = 'founder_ptick_log_stop' and tgenabled = 'O') then raise exception 'E138 selftest left a trigger disabled'; end if;
  return 'E138 selftest OK — ' || r || 'rollback clean';
end $$;

-- the policy's lease length in ms (the selftest compares a granted lease against it)
create or replace function public._fm_ptick_lease_ms() returns bigint language sql stable set search_path = pg_catalog, public as $$
  select lease_secs * 1000::bigint from public.founder_portable_tick_policy where id
$$;

-- grants: nothing for anon/authenticated, execute for service_role only ---------------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['public._fm_ptick_policy_guard()', 'public._fm_ptick_floor()', 'public._fm_ptick_holder_ok(text)', 'public._fm_ptick_now_ms()', 'public._fm_ptick_lease_guard()',
    'public._fm_ptick_hash(text,bigint,bigint,text,text,bigint,text,integer,text,integer)', 'public._fm_ptick_log_guard()', 'public._fm_ptick_stop()',
    'public._fm_pserve_hash(text,bigint,uuid,text,bigint,bigint)', 'public._fm_pserve_guard()', 'public._fm_ptick_lease_ms()',
    'public.founder_portable_bundle_text()', 'public.founder_portable_lease_take(text,integer)', 'public.founder_portable_tick(text)', 'public.founder_portable_tick_fail(text,text)',
    'public.founder_portable_serve(uuid)', 'public.founder_portable_tick_pulse(bigint)', 'public.founder_portable_status()', 'public.founder_portable_tick_verify(integer)',
    'public.founder_portable_e138_selftest()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on table public.founder_portable_tick_log is 'E138: append-only, hash-chained log of the portable-pin observer ticks (ts, prev_hash, consec_fail, hash are computed by the trigger).';
comment on table public.founder_portable_serve_log is 'E138: append-only, hash-chained record of every portable bundle handed to the founder (who, which sha256, which horizon and head).';
comment on table public.founder_portable_lease is 'E138: singleton lease with a fencing epoch; one observer at a time; the epoch never goes down.';
comment on function public.founder_portable_bundle_text() is 'E138: the canonical text a fresh browser hashes (kernel sha256) plus its sha256 hex.';

do $$ begin raise notice '%', public.founder_portable_e138_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E138_founder_portable_tick CHECK_E138  (after fetch). Needs E102 + E107 + E113 + E120-E124 + E131.
-- Undo (nothing else depends on it): drop the founder_portable_tick_*/serve_log/lease objects; the E131 horizon log, the signed checkpoints, the anchors and the ledger are untouched.
