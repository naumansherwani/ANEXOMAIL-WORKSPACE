-- E111 — FOUNDER CHANNELS + LIVE TELEMETRY (step 4b-4): "Not connected yet: Glitch, Support, Company Mail" ab database ki asli list hai, Rust mein hard-coded nahi.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), security definer RPC (service_role only, search_path + statement_timeout pinned), RLS on, append-only hash-chained history,
--             pgcrypto SHA-256 (schema extensions). 10/10 (FC27). Dobara chalana safe (idempotent).
-- Founder orders: 30 Oct 22:17 "sab kuch live, ek bhi mock nahi" · 1 Nov 06:45 "sql hamesha dalo her phase main super advance level kam se kam 800 lines".
-- NOTE: E107 F2c Merkle ke liye RESERVED. E109 = live feed, E110 = host proof. Yeh E111.
--
-- ASAL MASLE
--   (a) bridge.rs mein `pending_channels: ["glitch","support","company_mail"]` hard-coded hai: jab koi channel jur jaye to code badalna parta, aur Dashboard
--       jhoota "not connected" dikhata. Ab `founder_channels` registry + `founder_channels_pending()` asli jawab deta hai.
--   (b) Channel ki halat "kisi ne likh di" nahi: state-machine (not_connected -> connecting -> connected <-> degraded -> disabled) data-driven
--       transitions table se chalti hai; har badlav hash-chained append-only `founder_channel_events` mein aur founder_audit chain mein (E102).
--   (c) Live stream ki sehat andaza nahi: Rust har stream ka kholna/band hona (`founder_live_session_open/close`) aur har tick ka natija
--       (`founder_live_tick_report`, 1-minute buckets) yahan likhta hai. `founder_live_reliability()` aur `founder_live_tick_health()` sab kuch
--       deterministic thresholds (`founder_live_slo_rules`) se verdict dete hain. Tick ka GAP (minute gayab) = server band tha; yeh sirf yahin se pakda jata hai.
--   (d) `founder_live_snapshot_v2()` = E109 ka snapshot + channels + reliability + tick health, ek hi jsonb (ek round trip).
--
-- PRIVACY (Rule 69/FC18): koi email, IP, user-agent, token, message-body nahi. Sirf kinds, ginti, waqt, states, hashes. `_fch_clean()` har free-text field ko
--   rokta hai agar usmein email jaisa kuch ya control character ho. User tables ko koi trigger/lock/index nahi (read-only fingerprint E109 ka hai).
--
-- SECTIONS
--   0) Preflight
--   1) founder_channels            — registry + seed (glitch, support, company_mail) + CHECK constraints
--   2) founder_channel_transitions — data-driven state machine
--   3) founder_channel_events      — append-only, hash-chained, no update/delete/truncate
--   4) helpers                     — _fch_clean, _fch_hash, _fch_can
--   5) founder_channel_set         — ek atomic darwaza (lock + state machine + chain + audit + rate-limit)
--   6) founder_channel_verify, founder_channels_list, founder_channels_pending
--   7) live stream sessions        — founder_live_sessions, open/close RPC, gauge
--   8) tick buckets                — founder_live_tick_minutes, founder_live_tick_report
--   9) SLO rules + reliability + tick health (deterministic verdict, explains itself)
--  10) founder_live_snapshot_v2    — E109 snapshot + channels + reliability + tick health
--  11) retention                   — founder_live_prune_v2
--  12) grants
--  13) selftest (poora rollback) + CHECK_E111.sql

set lock_timeout = '10s';
set statement_timeout = '60s';
set search_path = pg_catalog, public, extensions;

-- ==============================================================================================================================
-- 0) PREFLIGHT — E102 (audit) aur E109 (live) pehle honi chahiye. Warna saaf wajah ke saath ruk jao (kuch aadha nahi banta).
-- ==============================================================================================================================
do $$
begin
  if to_regclass('public.founder_accounts') is null or to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then
    raise exception 'E111: pehle E102 (founder_accounts / founder_audit_append) chalayein' using errcode = '55000';
  end if;
  if to_regclass('public.founder_live_sources') is null or to_regprocedure('public.founder_live_snapshot()') is null then
    raise exception 'E111: pehle E109 (founder_live) chalayein' using errcode = '55000';
  end if;
  if to_regprocedure('extensions.digest(text,text)') is null and to_regprocedure('digest(text,text)') is null then
    raise exception 'E111: pgcrypto (digest) nahi mila: extensions schema mein pgcrypto chahiye' using errcode = '55000';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_channels:ddl', 0));

  -- ============================================================================================================================
  -- 1) CHANNELS — "Customer voice" ke raaste: lead source, support inbox, company mail. Har ek ki asli halat + saboot.
  -- ============================================================================================================================
  create table if not exists public.founder_channels (
    key            text primary key check (key ~ '^[a-z][a-z0-9_]{1,40}$'),
    label          text not null check (length(label) between 2 and 60 and label !~ '[[:cntrl:]]'),
    kind           text not null check (kind in ('lead_source', 'support_inbox', 'company_mail', 'other')),
    state          text not null default 'not_connected' check (state in ('not_connected', 'connecting', 'connected', 'degraded', 'disabled')),
    -- agar channel ka asli saboot E109 ke kisi live source se aata ho (jaise revenue_leads) to uska key; warna null (manual halat)
    live_source    text references public.founder_live_sources (key) on update cascade on delete set null,
    -- connected hone ka saboot: kab se, kis ne (sirf uid), aakhri asli signal kab aaya (live source se, ya manual)
    connected_at   timestamptz,
    last_signal_at timestamptz,
    note           text check (note is null or (length(note) <= 240 and note !~ '[[:cntrl:]]')),
    sort           smallint not null default 100,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    -- connected/degraded ka matlab: connected_at likha ho; not_connected/connecting me connected_at khali
    constraint founder_channels_conn_ck check (
      (state in ('connected', 'degraded') and connected_at is not null)
      or (state in ('not_connected', 'connecting') and connected_at is null)
      or (state = 'disabled')
    ),
    -- note mein email jaisa kuch nahi (privacy)
    constraint founder_channels_note_pii_ck check (note is null or note !~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}')
  );
  create index if not exists founder_channels_state_idx on public.founder_channels (state, sort);
  alter table public.founder_channels enable row level security;
  revoke all on public.founder_channels from public, anon, authenticated;
  grant select, insert, update on public.founder_channels to service_role;
  revoke delete, truncate, references, trigger on public.founder_channels from service_role;

  -- Seed: wohi 3 jo aaj Dashboard par "Not connected yet" likhe aate hain. live_source null: inka asli saboot abhi koi live table nahi deti (imandari).
  insert into public.founder_channels (key, label, kind, state, live_source, note, sort) values
    ('glitch',       'Glitch',       'other',         'not_connected', null, 'Error and glitch reports are not wired to the founder yet',   10),
    ('support',      'Support',      'support_inbox', 'not_connected', null, 'Support inbox is not wired to the founder yet',                20),
    ('company_mail', 'Company Mail', 'company_mail',  'not_connected', null, 'Company mailboxes arrive with Mail Desk (step 11)',            30)
  on conflict (key) do nothing;
  -- ============================================================================================================================
  -- 2) STATE MACHINE — kaun si halat se kaun si halat mein ja sakte hain (data, code nahi: audit-able aur badalne mein aasan)
  -- ============================================================================================================================
  create table if not exists public.founder_channel_transitions (
    from_state text not null check (from_state in ('not_connected', 'connecting', 'connected', 'degraded', 'disabled')),
    to_state   text not null check (to_state   in ('not_connected', 'connecting', 'connected', 'degraded', 'disabled')),
    needs_note boolean not null default false,
    primary key (from_state, to_state),
    constraint founder_channel_transitions_diff_ck check (from_state <> to_state)
  );
  alter table public.founder_channel_transitions enable row level security;
  revoke all on public.founder_channel_transitions from public, anon, authenticated;
  grant select on public.founder_channel_transitions to service_role;

  insert into public.founder_channel_transitions (from_state, to_state, needs_note) values
    ('not_connected', 'connecting',    false),
    ('not_connected', 'disabled',      true),
    ('connecting',    'connected',     false),
    ('connecting',    'not_connected', true),
    ('connecting',    'disabled',      true),
    ('connected',     'degraded',      true),
    ('connected',     'not_connected', true),
    ('connected',     'disabled',      true),
    ('degraded',      'connected',     false),
    ('degraded',      'not_connected', true),
    ('degraded',      'disabled',      true),
    ('disabled',      'not_connected', false)
  on conflict do nothing;

  -- ============================================================================================================================
  -- 3) HISTORY — append-only, hash-chained (har event pichle ka hash rakhta hai; kisi ne beech ka event badla to chain toot jati hai)
  -- ============================================================================================================================
  create table if not exists public.founder_channel_events (
    id         bigint generated always as identity primary key,
    ts         timestamptz not null default now(),
    channel    text not null,
    actor      uuid not null,
    from_state text not null,
    to_state   text not null,
    reason     text not null check (length(btrim(reason)) between 8 and 240 and reason !~ '[[:cntrl:]]'
                                    and reason !~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'),
    audit_seq  bigint,
    prev_hash  text not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash       text not null check (hash ~ '^[0-9a-f]{64}$'),
    unique (hash)
  );
  create index if not exists founder_channel_events_ch_idx on public.founder_channel_events (channel, id desc);
  alter table public.founder_channel_events enable row level security;
  revoke all on public.founder_channel_events from public, anon, authenticated;
  grant select, insert on public.founder_channel_events to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_channel_events from service_role;
end $$;

-- Append-only guard (update/delete/truncate band). Channel history kabhi nahi hatti (kam hai: sirf founder ke haath ke badlav) — isliye prune nahi, chain hamesha poori.
create or replace function public._founder_channel_events_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  raise exception 'founder_channel_events append-only: % not allowed', tg_op using errcode = '42501';
end $$;

do $$
begin
  if to_regclass('public.founder_channel_events') is null then return; end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_channel_events'::regclass and tgname = 'founder_channel_events_no_upd_del') then
    create trigger founder_channel_events_no_upd_del before update or delete on public.founder_channel_events for each row execute function public._founder_channel_events_guard();
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_channel_events'::regclass and tgname = 'founder_channel_events_no_trunc') then
    create trigger founder_channel_events_no_trunc before truncate on public.founder_channel_events for each statement execute function public._founder_channel_events_guard();
  end if;
end $$;

-- updated_at khud (channels table par): sirf tab badlo jab state/note/live_source/connected_at badle
create or replace function public._founder_channels_touch() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if (new.state, new.note, new.live_source, new.connected_at, new.last_signal_at) is distinct from (old.state, old.note, old.live_source, old.connected_at, old.last_signal_at) then
    new.updated_at := now();
  end if;
  -- key kabhi nahi badalti (history uske naam se juri hai)
  if new.key is distinct from old.key then raise exception 'founder_channels.key badal nahi sakti' using errcode = '42501'; end if;
  return new;
end $$;
do $$
begin
  if to_regclass('public.founder_channels') is not null and not exists (select 1 from pg_trigger where tgrelid = 'public.founder_channels'::regclass and tgname = 'founder_channels_touch') then
    create trigger founder_channels_touch before update on public.founder_channels for each row execute function public._founder_channels_touch();
  end if;
end $$;

-- ==============================================================================================================================
-- 4) HELPERS
-- ==============================================================================================================================
-- Free text saaf karo: trim, control characters nahi, email jaisa kuch nahi, lambai ki had. NULL wapas = "kuch nahi diya".
create or replace function public._fch_clean(p_text text, p_max integer default 240) returns text
language plpgsql immutable set search_path = pg_catalog, public as $$
declare t text := btrim(coalesce(p_text, ''));
begin
  if t = '' then return null; end if;
  if t ~ '[[:cntrl:]]' then raise exception 'text mein control character' using errcode = '22023'; end if;
  if t ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' then raise exception 'text mein email jaisa kuch (privacy)' using errcode = '22023'; end if;
  if length(t) > greatest(p_max, 1) then raise exception 'text bohat lamba (% tak)', p_max using errcode = '22023'; end if;
  return t;
end $$;

-- Chain ka hash: har field alag-alag length-prefixed taake "ab"+"c" aur "a"+"bc" ek jaise hash na dein.
create or replace function public._fch_hash(p_prev text, p_channel text, p_actor uuid, p_from text, p_to text, p_reason text, p_ts text) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(digest(
    convert_to(concat_ws('|', length(p_prev)::text || ':' || p_prev, length(p_channel)::text || ':' || p_channel, p_actor::text,
                         length(p_from)::text || ':' || p_from, length(p_to)::text || ':' || p_to,
                         length(p_reason)::text || ':' || p_reason, length(p_ts)::text || ':' || p_ts), 'UTF8'), 'sha256'), 'hex')
$$;

-- Kya (from -> to) manzoor transition hai? Jawab: null = nahi; true/false = manzoor, aur "note lazmi hai ya nahi".
create or replace function public._fch_needs_note(p_from text, p_to text) returns boolean
language sql stable set search_path = pg_catalog, public as $$
  select needs_note from public.founder_channel_transitions where from_state = p_from and to_state = p_to
$$;

-- ==============================================================================================================================
-- 5) founder_channel_set — channel ki halat badalne ka EK darwaza. Atomic: lock -> state machine -> chain -> audit (E102) -> channel row.
--    Rate limit: ek channel par 10 badlav / 10 minute (galti se loop ya script se history na bhare).
-- ==============================================================================================================================
create or replace function public.founder_channel_set(p_uid uuid, p_key text, p_to text, p_reason text, p_note text default null, p_live_source text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare
  c public.founder_channels%rowtype; v_reason text; v_note text; v_need boolean; v_prev text; v_hash text; v_ts timestamptz := clock_timestamp();
  a jsonb; v_recent integer; v_id bigint; v_src text := nullif(btrim(coalesce(p_live_source, '')), '');
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if coalesce(p_key, '') !~ '^[a-z][a-z0-9_]{1,40}$' then raise exception 'channel key galat' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_channels:' || p_key, 0));
  select * into c from public.founder_channels where key = p_key for update;
  if not found then raise exception 'channel nahi mila: %', p_key using errcode = 'P0002'; end if;
  v_reason := public._fch_clean(p_reason, 240);
  if v_reason is null or length(v_reason) < 8 then raise exception 'wajah (reason) kam az kam 8 akshar' using errcode = '22023'; end if;
  v_note := public._fch_clean(p_note, 240);
  if p_to = c.state then raise exception 'channel pehle se % hai', p_to using errcode = '22023'; end if;
  v_need := public._fch_needs_note(c.state, p_to);
  if v_need is null then raise exception 'transition manzoor nahi: % -> %', c.state, p_to using errcode = '22023'; end if;
  if v_need and v_note is null then raise exception 'is transition ke liye note lazmi hai: % -> %', c.state, p_to using errcode = '22023'; end if;
  if v_src is not null and not exists (select 1 from public.founder_live_sources where key = v_src and enabled) then raise exception 'live source nahi mila: %', v_src using errcode = '22023'; end if;
  -- connected hone ke liye asli saboot chahiye: live source ho aur wo present ho, warna founder ko manual wajah (reason) likhni hogi (wo hai hi)
  if p_to = 'connected' and coalesce(v_src, c.live_source) is not null then
    if not exists (select 1 from public.founder_live_state where source = coalesce(v_src, c.live_source) and present) then
      raise exception 'live source abhi present nahi (E109 tick chalna chahiye): %', coalesce(v_src, c.live_source) using errcode = '55000';
    end if;
  end if;
  select count(*) into v_recent from public.founder_channel_events where channel = p_key and ts > now() - interval '10 minutes';
  if v_recent >= 10 then raise exception 'is channel par bohat badlav (10 minute mein 10 se zyada)' using errcode = '54000'; end if;

  -- chain
  select hash into v_prev from public.founder_channel_events order by id desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  v_hash := public._fch_hash(v_prev, p_key, p_uid, c.state, p_to, v_reason, to_char(v_ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'));
  a := public.founder_audit_append(p_uid, 'channel.' || p_to, p_key, v_reason, jsonb_build_object('from', c.state, 'to', p_to));
  insert into public.founder_channel_events (ts, channel, actor, from_state, to_state, reason, audit_seq, prev_hash, hash)
    values (v_ts, p_key, p_uid, c.state, p_to, v_reason, (a ->> 'seq')::bigint, v_prev, v_hash) returning id into v_id;
  update public.founder_channels set state = p_to, note = coalesce(v_note, note), live_source = coalesce(v_src, live_source),
         connected_at = case when p_to in ('connected', 'degraded') then coalesce(connected_at, v_ts) when p_to in ('not_connected', 'connecting') then null else connected_at end,
         last_signal_at = case when p_to = 'connected' then v_ts else last_signal_at end
   where key = p_key;
  return jsonb_build_object('ok', true, 'channel', p_key, 'from', c.state, 'to', p_to, 'event_id', v_id, 'hash', v_hash, 'audit_seq', (a ->> 'seq')::bigint);
end $$;

-- ==============================================================================================================================
-- 6) VERIFY + LIST + PENDING
-- ==============================================================================================================================
-- Chain dobara hisab: pehli kharab row ka id deta hai, ya null (saaf). Sirf padhta hai.
create or replace function public.founder_channel_verify(p_from bigint default 1) returns bigint
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare r record; prev text; first boolean := true;
begin
  for r in select * from public.founder_channel_events where id >= greatest(coalesce(p_from, 1), 1) order by id loop
    if first then
      -- shuru ka prev: ya genesis (zero) ya us se pehli row ka hash
      select hash into prev from public.founder_channel_events where id < r.id order by id desc limit 1;
      prev := coalesce(prev, repeat('0', 64)); first := false;
    end if;
    if r.prev_hash <> prev then return r.id; end if;
    if r.hash <> public._fch_hash(r.prev_hash, r.channel, r.actor, r.from_state, r.to_state, r.reason, to_char(r.ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')) then return r.id; end if;
    prev := r.hash;
  end loop;
  return null;
end $$;

-- Tamam channels, asli saboot ke saath: agar live source juda hai to uski taza umr (E109 state se), warna sirf manual halat.
create or replace function public.founder_channels_list() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'key', c.key, 'label', c.label, 'kind', c.kind, 'state', c.state, 'note', c.note, 'connected_at', c.connected_at,
      'live_source', c.live_source,
      'evidence', case when c.live_source is null then jsonb_build_object('kind', 'manual')
                       else jsonb_build_object('kind', 'live', 'present', coalesce(st.present, false), 'stale', coalesce(st.stale, false),
                                               'age_secs', case when st.max_ts is null then null else greatest(0, extract(epoch from (now() - st.max_ts))::bigint) end,
                                               'checked_at', st.checked_at) end,
      -- "degraded" ko sirf ek asli ishaara dikha sakta hai: connected channel ka live source stale ho gaya
      'looks_stale', (c.state = 'connected' and coalesce(st.stale, false))
    )) order by c.sort, c.key), '[]'::jsonb)
  from public.founder_channels c left join public.founder_live_state st on st.source = c.live_source
$$;

-- Dashboard ka "Not connected yet: ..." isi se bante hain. Sirf wo jo aaj connected nahi (disabled ko nahi dikhate: founder ne khud band kiya).
create or replace function public.founder_channels_pending() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce(jsonb_agg(c.key order by c.sort, c.key), '[]'::jsonb) from public.founder_channels c where c.state in ('not_connected', 'connecting')
$$;

-- ==============================================================================================================================
-- 7) LIVE STREAM SESSIONS — Rust har SSE stream ka kholna/band hona likhta hai (sirf ginti/waqt/wajah; koi uid, IP, token, UA nahi)
-- ==============================================================================================================================
do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_live_telemetry:ddl', 0));
  create table if not exists public.founder_live_sessions (
    id            bigint generated always as identity primary key,
    opened_at     timestamptz not null default now(),
    closed_at     timestamptz,
    auth_kind     text not null check (auth_kind in ('device', 'legacy')),
    close_reason  text check (close_reason in ('lifetime', 'client_gone', 'slow_client', 'lagged', 'server_stop', 'error', 'orphan')),
    frames_sent   integer check (frames_sent is null or frames_sent between 0 and 100000000),
    duration_ms   bigint generated always as (case when closed_at is null then null else (extract(epoch from (closed_at - opened_at)) * 1000)::bigint end) stored,
    constraint founder_live_sessions_close_ck check ((closed_at is null and close_reason is null) or (closed_at is not null and close_reason is not null and closed_at >= opened_at))
  );
  create index if not exists founder_live_sessions_open_idx on public.founder_live_sessions (opened_at desc) where closed_at is null;
  create index if not exists founder_live_sessions_time_idx on public.founder_live_sessions (opened_at desc);
  alter table public.founder_live_sessions enable row level security;
  revoke all on public.founder_live_sessions from public, anon, authenticated;
  grant select, insert, update, delete on public.founder_live_sessions to service_role;
end $$;

-- Kholna: ek row, id wapas. Bohat saare khule (500+) ho jayen to naya nahi likhte (table ko bharne se roko) — Rust ka apna cap (20) pehle hai.
create or replace function public.founder_live_session_open(p_auth_kind text default 'device') returns bigint
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_id bigint; v_open integer;
begin
  if coalesce(p_auth_kind, '') not in ('device', 'legacy') then raise exception 'auth_kind galat' using errcode = '22023'; end if;
  select count(*) into v_open from public.founder_live_sessions where closed_at is null and opened_at > now() - interval '1 hour';
  if v_open >= 500 then raise exception 'bohat khule sessions' using errcode = '54000'; end if;
  insert into public.founder_live_sessions (auth_kind) values (p_auth_kind) returning id into v_id;
  return v_id;
end $$;

-- Band karna: sirf ek baar (dobara band karne se purani wajah nahi badalti). Nahi mila / pehle band = false.
create or replace function public.founder_live_session_close(p_id bigint, p_reason text, p_frames integer default 0) returns boolean
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare n integer;
begin
  if coalesce(p_reason, '') not in ('lifetime', 'client_gone', 'slow_client', 'lagged', 'server_stop', 'error') then raise exception 'close reason galat' using errcode = '22023'; end if;
  update public.founder_live_sessions set closed_at = now(), close_reason = p_reason, frames_sent = least(greatest(coalesce(p_frames, 0), 0), 100000000)
   where id = p_id and closed_at is null;
  get diagnostics n = row_count;
  return n = 1;
end $$;

-- Rust restart/crash ke baad purane "khule" sessions jhoote hain. Process shuru hote hi unhe 'orphan' likh do (kabhi band hone ka jhoota waqt nahi: closed_at = opened_at).
create or replace function public.founder_live_session_sweep(p_older interval default interval '15 minutes') returns integer
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare n integer;
begin
  if p_older < interval '1 minute' then raise exception 'sweep bohat chhota' using errcode = '22023'; end if;
  update public.founder_live_sessions set closed_at = opened_at, close_reason = 'orphan' where closed_at is null and opened_at < now() - p_older;
  get diagnostics n = row_count;
  return n;
end $$;

-- ==============================================================================================================================
-- 8) TICK BUCKETS — har tick ka natija 1-minute bucket mein (din bhar mein sirf 1440 rows). Bucket ka GAP = us minute server tick nahi chala raha tha.
-- ==============================================================================================================================
do $$
begin
  create table if not exists public.founder_live_tick_minutes (
    minute  timestamptz primary key check (minute = date_trunc('minute', minute)),
    ok_n    integer not null default 0 check (ok_n >= 0),
    fail_n  integer not null default 0 check (fail_n >= 0),
    ms_sum  bigint  not null default 0 check (ms_sum >= 0),
    ms_max  integer not null default 0 check (ms_max >= 0)
  );
  alter table public.founder_live_tick_minutes enable row level security;
  revoke all on public.founder_live_tick_minutes from public, anon, authenticated;
  grant select, insert, update, delete on public.founder_live_tick_minutes to service_role;
end $$;

create or replace function public.founder_live_tick_report(p_ok boolean, p_ms integer default 0) returns void
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_ms integer := least(greatest(coalesce(p_ms, 0), 0), 600000);
begin
  insert into public.founder_live_tick_minutes (minute, ok_n, fail_n, ms_sum, ms_max)
    values (date_trunc('minute', now()), case when p_ok then 1 else 0 end, case when p_ok then 0 else 1 end, v_ms, v_ms)
  on conflict (minute) do update set ok_n = founder_live_tick_minutes.ok_n + excluded.ok_n, fail_n = founder_live_tick_minutes.fail_n + excluded.fail_n,
         ms_sum = founder_live_tick_minutes.ms_sum + excluded.ms_sum, ms_max = greatest(founder_live_tick_minutes.ms_max, excluded.ms_max);
end $$;

-- ==============================================================================================================================
-- 9) SLO RULES + RELIABILITY + TICK HEALTH — verdict deterministic hai (koi AI nahi) aur apni wajah khud batata hai.
-- ==============================================================================================================================
do $$
begin
  create table if not exists public.founder_live_slo_rules (
    key       text primary key check (key ~ '^[a-z][a-z0-9_]{1,40}$'),
    warn_at   numeric not null,
    fail_at   numeric not null,
    higher_is_worse boolean not null default true,
    unit      text not null check (length(unit) between 1 and 12),
    note      text not null check (length(note) between 4 and 160),
    constraint founder_live_slo_rules_order_ck check ((higher_is_worse and warn_at <= fail_at) or (not higher_is_worse and warn_at >= fail_at))
  );
  alter table public.founder_live_slo_rules enable row level security;
  revoke all on public.founder_live_slo_rules from public, anon, authenticated;
  grant select on public.founder_live_slo_rules to service_role;
  insert into public.founder_live_slo_rules (key, warn_at, fail_at, higher_is_worse, unit, note) values
    ('tick_fail_pct',     2,   10,  true,  '%',   'Share of live ticks that failed in the window'),
    ('tick_gap_minutes',  2,   5,   true,  'min', 'Longest stretch with no tick at all (server not ticking)'),
    ('tick_ms_p95',       1500, 4000, true, 'ms', 'Slowest typical tick (max of the minute buckets, 95th percentile)'),
    ('short_session_pct', 30,  60,  true,  '%',   'Streams closed in under 20 seconds (reconnect storm)'),
    ('slow_client_pct',   5,   20,  true,  '%',   'Streams dropped because the client could not keep up')
  on conflict (key) do nothing;
end $$;

-- verdict ke liye ek chhota helper: value + rule -> 'ok'|'warn'|'fail' (null value = 'unknown', kabhi andaza nahi)
create or replace function public._flr_level(p_key text, p_value numeric) returns text
language sql stable set search_path = pg_catalog, public as $$
  select case when p_value is null then 'unknown'
              when r.higher_is_worse then case when p_value >= r.fail_at then 'fail' when p_value >= r.warn_at then 'warn' else 'ok' end
              else case when p_value <= r.fail_at then 'fail' when p_value <= r.warn_at then 'warn' else 'ok' end end
    from public.founder_live_slo_rules r where r.key = p_key
$$;

create or replace function public._flr_worst(p_levels text[]) returns text
language sql immutable set search_path = pg_catalog, public as $$
  select case when 'fail' = any(p_levels) then 'fail' when 'warn' = any(p_levels) then 'warn' when 'unknown' = any(p_levels) then 'unknown' else 'ok' end
$$;

-- Tick sehat: pichhle N minute (kam az kam 5, zyada se zyada 1440). `expected` = us window ke minute, `covered` = kitne minute mein tick aaya.
create or replace function public.founder_live_tick_health(p_minutes integer default 60) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare
  m integer := least(greatest(coalesce(p_minutes, 60), 5), 1440); t0 timestamptz; v_ok bigint; v_fail bigint; covered integer; expected integer; p95 numeric;
  gap integer := 0; fail_pct numeric; l1 text; l2 text; l3 text; since_first integer;
begin
  t0 := date_trunc('minute', now()) - make_interval(mins => m - 1);
  select coalesce(sum(ok_n), 0), coalesce(sum(fail_n), 0), count(*) into v_ok, v_fail, covered from public.founder_live_tick_minutes where minute >= t0;
  -- data jab se likha ja raha hai (naye install par window se chhota ho sakta hai; purane khali minute ko "gap" na gino)
  select least(m, greatest(1, (extract(epoch from (date_trunc('minute', now()) - min(minute))) / 60)::integer + 1)) into since_first from public.founder_live_tick_minutes where minute >= t0;
  expected := coalesce(since_first, 0);
  if covered = 0 then
    return jsonb_build_object('window_minutes', m, 'ticks_ok', 0, 'ticks_failed', 0, 'level', 'unknown', 'reasons', jsonb_build_array('no tick has been reported yet'));
  end if;
  fail_pct := round(100.0 * v_fail / nullif(v_ok + v_fail, 0), 2);
  select percentile_cont(0.95) within group (order by ms_max) into p95 from public.founder_live_tick_minutes where minute >= t0;
  -- sab se lamba khali silsila: pehle aur aakhri bucket ke beech bhi, aur aakhri bucket se ab tak bhi
  with b as (select minute, lag(minute) over (order by minute) as prev from public.founder_live_tick_minutes where minute >= t0)
  select coalesce(max((extract(epoch from (minute - prev)) / 60)::integer - 1), 0) into gap from b where prev is not null;
  gap := greatest(gap, (extract(epoch from (date_trunc('minute', now()) - (select max(minute) from public.founder_live_tick_minutes where minute >= t0))) / 60)::integer);
  l1 := public._flr_level('tick_fail_pct', fail_pct); l2 := public._flr_level('tick_gap_minutes', gap); l3 := public._flr_level('tick_ms_p95', p95);
  return jsonb_strip_nulls(jsonb_build_object(
    'window_minutes', m, 'covered_minutes', covered, 'expected_minutes', expected, 'ticks_ok', v_ok, 'ticks_failed', v_fail,
    'fail_pct', fail_pct, 'longest_gap_minutes', gap, 'ms_p95', round(p95, 0),
    'level', public._flr_worst(array[l1, l2, l3]),
    'reasons', (select coalesce(jsonb_agg(x), '[]'::jsonb) from unnest(array[
        case when l1 in ('warn', 'fail') then format('%s%% of ticks failed', fail_pct) end,
        case when l2 in ('warn', 'fail') then format('no tick for %s minute(s)', gap) end,
        case when l3 in ('warn', 'fail') then format('slow ticks (p95 %s ms)', round(p95, 0)) end]) x where x is not null)));
end $$;

-- Stream bharosa: pichhle N ghante ke sessions. Short = 20 s se kam (bar bar toot kar judna), slow = slow_client se band.
create or replace function public.founder_live_reliability(p_hours integer default 24) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare
  h integer := least(greatest(coalesce(p_hours, 24), 1), 720); t0 timestamptz := now() - make_interval(hours => h);
  n bigint; closed bigint; open_now bigint; short_n bigint; slow_n bigint; p50 numeric; p95 numeric; hist jsonb; short_pct numeric; slow_pct numeric; l1 text; l2 text;
begin
  select count(*), count(*) filter (where closed_at is not null and close_reason <> 'orphan'), count(*) filter (where closed_at is null),
         count(*) filter (where duration_ms is not null and duration_ms < 20000 and close_reason not in ('orphan', 'server_stop')),
         count(*) filter (where close_reason = 'slow_client')
    into n, closed, open_now, short_n, slow_n from public.founder_live_sessions where opened_at >= t0;
  select percentile_cont(0.5) within group (order by duration_ms), percentile_cont(0.95) within group (order by duration_ms)
    into p50, p95 from public.founder_live_sessions where opened_at >= t0 and duration_ms is not null and close_reason <> 'orphan';
  select coalesce(jsonb_object_agg(close_reason, c), '{}'::jsonb) into hist
    from (select close_reason, count(*) c from public.founder_live_sessions where opened_at >= t0 and close_reason is not null group by 1) q;
  short_pct := case when closed > 0 then round(100.0 * short_n / closed, 2) end;
  slow_pct  := case when closed > 0 then round(100.0 * slow_n / closed, 2) end;
  l1 := public._flr_level('short_session_pct', short_pct); l2 := public._flr_level('slow_client_pct', slow_pct);
  return jsonb_strip_nulls(jsonb_build_object(
    'window_hours', h, 'sessions', n, 'closed', closed, 'open_now', open_now, 'duration_ms_p50', round(p50, 0), 'duration_ms_p95', round(p95, 0),
    'short_pct', short_pct, 'slow_client_pct', slow_pct, 'close_reasons', hist,
    'level', case when closed = 0 then 'unknown' else public._flr_worst(array[l1, l2]) end,
    'reasons', (select coalesce(jsonb_agg(x), '[]'::jsonb) from unnest(array[
        case when l1 in ('warn', 'fail') then format('%s%% of streams closed within 20 seconds', short_pct) end,
        case when l2 in ('warn', 'fail') then format('%s%% of streams dropped as too slow', slow_pct) end]) x where x is not null)));
end $$;

-- ==============================================================================================================================
-- 10) founder_live_snapshot_v2 — E109 ka snapshot + channels + reliability + tick health, EK hi jsonb (ek round trip, ek signed envelope)
--     v1 ke saare keys jaise hain waise; sirf naye keys jode jate hain (purana SPA toot'ta nahi). Har naya hissa apni khud ki kharabi se alag:
--     agar ek hissa fail ho to us ki jagah {"error": "..."} aata hai, baaki snapshot salamat (ek table ki kharabi poora Dashboard na giraye).
-- ==============================================================================================================================
create or replace function public.founder_live_snapshot_v2() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare base jsonb; ch jsonb; pend jsonb; rel jsonb; th jsonb; chain bigint; worst text;
begin
  base := public.founder_live_snapshot();
  begin ch := public.founder_channels_list(); exception when others then ch := jsonb_build_object('error', sqlstate); end;
  begin pend := public.founder_channels_pending(); exception when others then pend := jsonb_build_object('error', sqlstate); end;
  begin rel := public.founder_live_reliability(24); exception when others then rel := jsonb_build_object('error', sqlstate); end;
  begin th := public.founder_live_tick_health(60); exception when others then th := jsonb_build_object('error', sqlstate); end;
  begin chain := public.founder_channel_verify(1); exception when others then chain := -1; end;
  -- zyada kharab level: tick health 'fail' ho ya channel chain toot'e => poora "trouble" mein aata hai (aur kaun sa hissa, saaf likha)
  worst := public._flr_worst(array[coalesce(th ->> 'level', 'unknown'), coalesce(rel ->> 'level', 'unknown')]);
  return base || jsonb_build_object(
    'channels', ch,
    'pending_channels', pend,
    'channel_chain', case when chain is null then jsonb_build_object('ok', true) else jsonb_build_object('ok', false, 'first_bad_id', chain) end,
    'reliability', rel,
    'tick_health', th,
    'telemetry_level', worst);
end $$;

-- ==============================================================================================================================
-- 11) RETENTION — sessions 30 din, tick bucket 14 din. Sirf yeh do telemetry tables; channels + channel events + E109 feed ko haath nahi lagta.
--     Retention bohat chhoti nahi ho sakti (galti se saari telemetry mitane se bacho); hataane ki ginti wapas aati hai.
-- ==============================================================================================================================
create or replace function public.founder_live_prune_v2(p_keep_sessions interval default interval '30 days', p_keep_ticks interval default interval '14 days') returns jsonb
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '60s' as $$
declare s bigint; t bigint;
begin
  if p_keep_sessions < interval '2 days' or p_keep_ticks < interval '2 days' then raise exception 'retention bohat chhoti' using errcode = '22023'; end if;
  with d as (delete from public.founder_live_sessions where opened_at < now() - p_keep_sessions and closed_at is not null returning 1) select count(*) into s from d;
  with d as (delete from public.founder_live_tick_minutes where minute < now() - p_keep_ticks returning 1) select count(*) into t from d;
  return jsonb_build_object('sessions_deleted', s, 'tick_minutes_deleted', t);
end $$;


-- ==============================================================================================================================
-- 11b) EXTRA READERS — history (page-wise, kabhi 200 se zyada nahi), live gauge (abhi kitne stream khule, aakhri tick kab), signal sync
-- ==============================================================================================================================
-- Ek channel ki history, naya pehle. `before` = pichhla page ka sab se chhota id (keyset paging: bade table par bhi sasta).
create or replace function public.founder_channel_history(p_key text, p_limit integer default 50, p_before bigint default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 200); out jsonb; n integer; lo bigint;
begin
  if coalesce(p_key, '') !~ '^[a-z][a-z0-9_]{1,40}$' then raise exception 'channel key galat' using errcode = '22023'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'ts', ts, 'from', from_state, 'to', to_state, 'reason', reason, 'audit_seq', audit_seq, 'hash', hash) order by id desc), '[]'::jsonb),
         count(*), min(id)
    into out, n, lo from (select * from public.founder_channel_events where channel = p_key and (p_before is null or id < p_before) order by id desc limit v_lim) q;
  -- poora page mila => agla page ho sakta hai (next_before); adhura => history khatam
  return jsonb_build_object('channel', p_key, 'events', out, 'next_before', case when n = v_lim then lo end);
end $$;

-- Ek nazar mein "abhi": khule streams, aakhri tick ki umr, aakhri 5 minute ka natija. Rust /health nahi, Dashboard ka chhota orb isse chalta hai.
create or replace function public.founder_live_gauge() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'open_streams', (select count(*) from public.founder_live_sessions where closed_at is null and opened_at > now() - interval '15 minutes'),
    'last_tick_at', (select max(minute) from public.founder_live_tick_minutes),
    'last_tick_age_secs', (select greatest(0, extract(epoch from (now() - max(minute)))::bigint) from public.founder_live_tick_minutes),
    'ticks_ok_5m', (select coalesce(sum(ok_n), 0) from public.founder_live_tick_minutes where minute >= now() - interval '5 minutes'),
    'ticks_failed_5m', (select coalesce(sum(fail_n), 0) from public.founder_live_tick_minutes where minute >= now() - interval '5 minutes')))
$$;

-- Connected channel ka last_signal_at ko E109 ke asli live state se milao (sirf aage badhta hai, kabhi peeche nahi; sirf jin ka live_source juda hai).
create or replace function public.founder_channels_sync_signal() returns integer
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare n integer;
begin
  update public.founder_channels c set last_signal_at = st.max_ts
    from public.founder_live_state st
   where st.source = c.live_source and c.state in ('connected', 'degraded') and st.max_ts is not null
     and (c.last_signal_at is null or st.max_ts > c.last_signal_at);
  get diagnostics n = row_count;
  return n;
end $$;


-- Roz ka hisab (pichhle N din, UTC din): kitne stream khule, kitne bohat chhote, tick ok/fail/p95. Trend dekhne ke liye — "kal se kharab hua?"
create or replace function public.founder_live_daily(p_days integer default 7) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare d integer := least(greatest(coalesce(p_days, 7), 1), 60); out jsonb;
begin
  with days as (select (date_trunc('day', now() at time zone 'UTC') - make_interval(days => g))::date as day from generate_series(0, d - 1) g),
  ss as (select (opened_at at time zone 'UTC')::date as day, count(*) as n,
                count(*) filter (where duration_ms < 20000 and close_reason not in ('orphan', 'server_stop')) as short_n,
                count(*) filter (where close_reason = 'slow_client') as slow_n
           from public.founder_live_sessions where opened_at >= now() - make_interval(days => d + 1) group by 1),
  tk as (select (minute at time zone 'UTC')::date as day, sum(ok_n) as ok_n, sum(fail_n) as fail_n, max(ms_max) as ms_max, count(*) as minutes
           from public.founder_live_tick_minutes where minute >= now() - make_interval(days => d + 1) group by 1)
  select coalesce(jsonb_agg(jsonb_build_object('day', days.day, 'streams', coalesce(ss.n, 0), 'short_streams', coalesce(ss.short_n, 0), 'slow_streams', coalesce(ss.slow_n, 0),
                                               'ticks_ok', coalesce(tk.ok_n, 0), 'ticks_failed', coalesce(tk.fail_n, 0), 'ms_max', tk.ms_max, 'minutes_with_ticks', coalesce(tk.minutes, 0))
                            order by days.day desc), '[]'::jsonb)
    into out from days left join ss on ss.day = days.day left join tk on tk.day = days.day;
  return jsonb_build_object('days', d, 'rows', out);
end $$;

-- Channels ka khulasa: kitne kis halat mein, sab se purana "connecting" (atka hua?), aakhri badlav kab. Dashboard ka ek-line sawal: "kya kuch atka hai?"
create or replace function public.founder_channel_stats() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'total', (select count(*) from public.founder_channels),
    'by_state', (select coalesce(jsonb_object_agg(state, n), '{}'::jsonb) from (select state, count(*) n from public.founder_channels group by 1) q),
    'oldest_connecting_hours', (select round(extract(epoch from (now() - min(updated_at))) / 3600.0, 1) from public.founder_channels where state = 'connecting'),
    'stuck_connecting', (select count(*) from public.founder_channels where state = 'connecting' and updated_at < now() - interval '24 hours'),
    'last_change_at', (select max(ts) from public.founder_channel_events),
    'events_total', (select count(*) from public.founder_channel_events)))
$$;

-- ==============================================================================================================================
-- 12) GRANTS — sirf service_role (Rust). PUBLIC ko default execute milta hai: yahan saaf hataya jata hai.
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public._founder_channel_events_guard()', 'public._founder_channels_touch()', 'public._fch_clean(text,integer)',
    'public._fch_hash(text,text,uuid,text,text,text,text)', 'public._fch_needs_note(text,text)',
    'public.founder_channel_set(uuid,text,text,text,text,text)', 'public.founder_channel_verify(bigint)', 'public.founder_channels_list()',
    'public.founder_channels_pending()', 'public.founder_live_session_open(text)', 'public.founder_live_session_close(bigint,text,integer)',
    'public.founder_live_session_sweep(interval)', 'public.founder_live_tick_report(boolean,integer)', 'public._flr_level(text,numeric)',
    'public._flr_worst(text[])', 'public.founder_live_tick_health(integer)', 'public.founder_live_reliability(integer)',
    'public.founder_live_snapshot_v2()', 'public.founder_live_prune_v2(interval,interval)',
    'public.founder_channel_history(text,integer,bigint)', 'public.founder_live_gauge()', 'public.founder_channels_sync_signal()',
    'public.founder_live_daily(integer)', 'public.founder_channel_stats()'] loop
    if to_regprocedure(f) is null then raise exception 'E111 grant: function nahi bani: %', f; end if;
    execute format('revoke all on function %s from public, anon, authenticated', f);
    if f !~ '_guard|_touch' then execute format('grant execute on function %s to service_role', f); end if;
  end loop;
end $$;

-- ==============================================================================================================================
-- 13) SELFTEST — asli behaviour, aakhir mein POORA rollback (kuch persist nahi). Fail ho to saaf wajah ka text wapas.
--     Covers: state machine (jaiz/najaiz/note-lazmi), same-state, chain verify + tamper-proof (append-only), PII block, live-evidence gate,
--     sessions (open/close/double-close/sweep), tick buckets (ok/fail/ms), SLO levels (ok/warn/fail/unknown), snapshot_v2 keys, prune.
-- ==============================================================================================================================
create or replace function public.founder_channels_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_uid uuid; r jsonb; sid bigint; n integer; ok boolean; msg text := 'E111 selftest OK'; bad bigint; th jsonb; rel jsonb; sn jsonb; k text; i integer;
begin
  if to_regclass('public.founder_channels') is null then return 'E111 selftest SKIP: E111 chalayein'; end if;
  select user_id into v_uid from public.founder_accounts limit 1;
  begin
    -- ---------- A) state machine ----------
    insert into public.founder_channels (key, label, kind) values ('e111_probe', 'E111 probe', 'other');
    if (select state from public.founder_channels where key = 'e111_probe') <> 'not_connected' then raise exception 'naya channel not_connected se shuru hona chahiye'; end if;
    if public._fch_needs_note('not_connected', 'connecting') is distinct from false then raise exception 'needs_note(not_connected->connecting) false hona chahiye'; end if;
    if public._fch_needs_note('connected', 'degraded') is distinct from true then raise exception 'needs_note(connected->degraded) true hona chahiye'; end if;
    if public._fch_needs_note('not_connected', 'connected') is not null then raise exception 'not_connected->connected jaiz nahi (null hona chahiye)'; end if;
    begin perform public._fch_clean('  ab' || chr(1) || 'c  ', 20); raise exception '_fch_clean control char par ruka nahi';
    exception when sqlstate '22023' then null; end;
    begin perform public._fch_clean('mail me a@b.com now', 40); raise exception '_fch_clean email par ruka nahi';
    exception when sqlstate '22023' then null; end;
    begin perform public._fch_clean(repeat('x', 50), 40); raise exception '_fch_clean lambai par ruka nahi';
    exception when sqlstate '22023' then null; end;
    if public._fch_clean('   ', 40) is not null then raise exception '_fch_clean khali par null hona chahiye'; end if;
    if public._fch_clean('  theek hai  ', 40) <> 'theek hai' then raise exception '_fch_clean trim nahi karta'; end if;

    if v_uid is not null then
      r := public.founder_channel_set(v_uid, 'e111_probe', 'connecting', 'selftest: jorna shuru');
      if r ->> 'to' <> 'connecting' then raise exception 'connecting nahi hua'; end if;
      begin perform public.founder_channel_set(v_uid, 'e111_probe', 'degraded', 'selftest: najaiz transition'); raise exception 'najaiz transition chal gaya';
      exception when sqlstate '22023' then null; end;
      begin perform public.founder_channel_set(v_uid, 'e111_probe', 'connecting', 'selftest: same state'); raise exception 'same-state chal gaya';
      exception when sqlstate '22023' then null; end;
      begin perform public.founder_channel_set(v_uid, 'e111_probe', 'connected', 'kam'); raise exception 'chhoti wajah chal gayi';
      exception when sqlstate '22023' then null; end;
      r := public.founder_channel_set(v_uid, 'e111_probe', 'connected', 'selftest: jur gaya');
      if (select connected_at from public.founder_channels where key = 'e111_probe') is null then raise exception 'connected_at likha nahi gaya'; end if;
      begin perform public.founder_channel_set(v_uid, 'e111_probe', 'degraded', 'selftest: note ke bina'); raise exception 'note ke bina degraded chal gaya';
      exception when sqlstate '22023' then null; end;
      begin perform public.founder_channel_set(v_uid, 'e111_probe', 'degraded', 'selftest: email note', 'contact a@b.com'); raise exception 'email note chal gaya';
      exception when sqlstate '22023' then null; when check_violation then null; end;
      r := public.founder_channel_set(v_uid, 'e111_probe', 'degraded', 'selftest: signal ruka', 'signal ruk gaya');
      r := public.founder_channel_set(v_uid, 'e111_probe', 'connected', 'selftest: wapas theek');
      if (select count(*) from public.founder_channel_events where channel = 'e111_probe') <> 4 then raise exception 'history mein 4 event hone chahiye'; end if;

      -- ---------- B) chain + tamper ----------
      bad := public.founder_channel_verify(1);
      if bad is not null then raise exception 'chain saaf honi chahiye (bad id %)', bad; end if;
      begin update public.founder_channel_events set reason = 'badla hua reason!!' where channel = 'e111_probe'; raise exception 'history UPDATE chal gaya';
      exception when sqlstate '42501' then null; end;
      begin delete from public.founder_channel_events where channel = 'e111_probe'; raise exception 'history DELETE chal gaya';
      exception when sqlstate '42501' then null; end;
      begin truncate public.founder_channel_events; raise exception 'history TRUNCATE chal gaya';
      exception when sqlstate '42501' then null; end;

      -- ---------- C) rate limit (10 / 10 minute) ----------
      for i in 1..3 loop
        perform public.founder_channel_set(v_uid, 'e111_probe', 'degraded', 'selftest: rate ' || i || ' down', 'rate test');
        perform public.founder_channel_set(v_uid, 'e111_probe', 'connected', 'selftest: rate ' || i || ' up');
      end loop;
      begin perform public.founder_channel_set(v_uid, 'e111_probe', 'degraded', 'selftest: rate overflow', 'rate test'); raise exception 'rate limit nahi laga';
      exception when sqlstate '54000' then null; end;
    end if;

    -- bina founder ke koi badlav nahi
    begin perform public.founder_channel_set('00000000-0000-0000-0000-000000000000', 'e111_probe', 'disabled', 'selftest: bina founder', 'x y z'); raise exception 'bina founder ke chal gaya';
    exception when sqlstate '42501' then null; end;

    -- ---------- D) list / pending ----------
    if not exists (select 1 from jsonb_array_elements(public.founder_channels_list()) e where e ->> 'key' = 'e111_probe') then raise exception 'list mein probe nahi'; end if;
    update public.founder_channels set state = 'not_connected', connected_at = null where key = 'e111_probe';
    if not (public.founder_channels_pending() ? 'e111_probe') then raise exception 'pending mein not_connected probe hona chahiye'; end if;
    update public.founder_channels set state = 'disabled' where key = 'e111_probe';
    if public.founder_channels_pending() ? 'e111_probe' then raise exception 'disabled channel pending mein nahi aana chahiye'; end if;
    if (select count(*) from public.founder_channels where key in ('glitch', 'support', 'company_mail')) <> 3 then raise exception 'seed 3 channels nahi'; end if;

    -- ---------- E) sessions ----------
    sid := public.founder_live_session_open('device');
    if sid is null then raise exception 'session id nahi'; end if;
    begin perform public.founder_live_session_open('bogus'); raise exception 'galat auth_kind chal gaya'; exception when sqlstate '22023' then null; end;
    if public.founder_live_session_close(sid, 'client_gone', 12) is not true then raise exception 'pehli band true honi chahiye'; end if;
    if public.founder_live_session_close(sid, 'lifetime', 99) is not false then raise exception 'dobara band false honi chahiye'; end if;
    if (select close_reason from public.founder_live_sessions where id = sid) <> 'client_gone' then raise exception 'purani wajah badal gayi'; end if;
    begin perform public.founder_live_session_close(sid, 'orphan', 0); raise exception 'orphan Rust se band nahi ho sakta'; exception when sqlstate '22023' then null; end;
    sid := public.founder_live_session_open('legacy');
    update public.founder_live_sessions set opened_at = now() - interval '2 hours' where id = sid;
    if public.founder_live_session_sweep(interval '15 minutes') < 1 then raise exception 'sweep ne orphan nahi pakda'; end if;
    if (select close_reason from public.founder_live_sessions where id = sid) <> 'orphan' then raise exception 'orphan likha nahi gaya'; end if;
    begin perform public.founder_live_session_sweep(interval '5 seconds'); raise exception 'sweep bohat chhota chal gaya'; exception when sqlstate '22023' then null; end;

    -- ---------- F) tick buckets + health ----------
    delete from public.founder_live_tick_minutes;
    th := public.founder_live_tick_health(60);
    if th ->> 'level' <> 'unknown' then raise exception 'khali tick health unknown honi chahiye (andaza nahi): %', th; end if;
    for i in 1..20 loop perform public.founder_live_tick_report(true, 40 + i); end loop;
    th := public.founder_live_tick_health(60);
    if th ->> 'level' <> 'ok' then raise exception 'saaf ticks par ok honi chahiye: %', th; end if;
    if (th ->> 'ticks_ok')::int <> 20 then raise exception 'ticks_ok 20 hona chahiye: %', th; end if;
    for i in 1..5 loop perform public.founder_live_tick_report(false, 9000); end loop;
    th := public.founder_live_tick_health(60);
    if th ->> 'level' <> 'fail' then raise exception '20%% fail par fail honi chahiye: %', th; end if;
    if jsonb_array_length(th -> 'reasons') < 1 then raise exception 'fail par wajah likhi honi chahiye'; end if;
    -- gap: 20 minute purana bucket + ab ka bucket => 19 minute ka gap
    delete from public.founder_live_tick_minutes;
    insert into public.founder_live_tick_minutes (minute, ok_n, ms_sum, ms_max) values (date_trunc('minute', now()) - interval '20 minutes', 5, 100, 30);
    perform public.founder_live_tick_report(true, 30);
    th := public.founder_live_tick_health(60);
    if (th ->> 'longest_gap_minutes')::int < 18 then raise exception 'gap pakda nahi gaya: %', th; end if;
    if th ->> 'level' <> 'fail' then raise exception 'bade gap par fail honi chahiye: %', th; end if;
    -- clamp: ms bohat bada / negative
    perform public.founder_live_tick_report(true, -5);
    perform public.founder_live_tick_report(true, 99999999);
    if (select max(ms_max) from public.founder_live_tick_minutes) > 600000 then raise exception 'ms clamp nahi hua'; end if;

    -- ---------- G) SLO levels ----------
    if public._flr_level('tick_fail_pct', 0) <> 'ok' or public._flr_level('tick_fail_pct', 5) <> 'warn' or public._flr_level('tick_fail_pct', 50) <> 'fail' then raise exception 'SLO levels galat'; end if;
    if public._flr_level('tick_fail_pct', null) <> 'unknown' then raise exception 'null value unknown honi chahiye'; end if;
    if public._flr_worst(array['ok', 'warn']) <> 'warn' or public._flr_worst(array['ok', 'unknown']) <> 'unknown' or public._flr_worst(array['fail', 'ok']) <> 'fail' or public._flr_worst(array['ok', 'ok']) <> 'ok' then raise exception '_flr_worst galat'; end if;

    -- ---------- H) reliability ----------
    delete from public.founder_live_sessions;
    rel := public.founder_live_reliability(24);
    if rel ->> 'level' <> 'unknown' then raise exception 'koi band session nahi => unknown: %', rel; end if;
    for i in 1..10 loop
      sid := public.founder_live_session_open('device');
      update public.founder_live_sessions set opened_at = now() - interval '5 minutes' where id = sid;
      perform public.founder_live_session_close(sid, 'client_gone', 100);
    end loop;
    rel := public.founder_live_reliability(24);
    if (rel ->> 'closed')::int <> 10 then raise exception 'closed 10 hona chahiye: %', rel; end if;
    for i in 1..8 loop
      sid := public.founder_live_session_open('device'); perform public.founder_live_session_close(sid, 'slow_client', 1);
    end loop;
    rel := public.founder_live_reliability(24);
    if rel ->> 'level' <> 'fail' then raise exception 'bahut short + slow sessions par fail honi chahiye: %', rel; end if;

    -- ---------- I) snapshot_v2 ----------
    sn := public.founder_live_snapshot_v2();
    foreach k in array array['channels', 'pending_channels', 'channel_chain', 'reliability', 'tick_health', 'telemetry_level'] loop
      if not sn ? k then raise exception 'snapshot_v2 mein % nahi', k; end if;
    end loop;
    if sn -> 'channel_chain' ->> 'ok' <> 'true' then raise exception 'snapshot_v2 chain saaf dikhani chahiye'; end if;
    if not sn ? 'version' and not sn ? 'trouble' and jsonb_typeof(sn) <> 'object' then raise exception 'snapshot_v2 mein v1 ke keys gayab'; end if;

    -- ---------- I2) daily + stats + history + gauge ----------
    if jsonb_array_length(public.founder_live_daily(7) -> 'rows') <> 7 then raise exception 'daily 7 row deni chahiye'; end if;
    if (public.founder_channel_stats() ->> 'total')::int < 4 then raise exception 'stats total galat (seed 3 + probe)'; end if;
    if (public.founder_channel_history('e111_probe', 2) -> 'events') is null then raise exception 'history events nahi'; end if;
    if v_uid is not null and (public.founder_channel_history('e111_probe', 2) ->> 'next_before') is null then raise exception 'history paging (next_before) nahi'; end if;
    if not (public.founder_live_gauge() ? 'open_streams') then raise exception 'gauge open_streams nahi'; end if;
    begin perform public.founder_channel_history('BAD KEY'); raise exception 'galat key chal gaya'; exception when sqlstate '22023' then null; end;

    -- ---------- J) prune ----------
    update public.founder_live_sessions set opened_at = now() - interval '40 days' where id = sid;
    r := public.founder_live_prune_v2(interval '30 days', interval '14 days');
    if (r ->> 'sessions_deleted')::int < 1 then raise exception 'prune ne purana session nahi hataya'; end if;
    begin perform public.founder_live_prune_v2(interval '1 hour', interval '14 days'); raise exception 'chhoti retention chal gayi'; exception when sqlstate '22023' then null; end;

    raise exception 'E111_ROLLBACK_OK';
  exception when others then
    if sqlerrm = 'E111_ROLLBACK_OK' then msg := 'E111 selftest OK' || case when v_uid is null then ' (founder nahi mila: channel_set hissa SKIP)' else '' end;
    else msg := 'E111 selftest FAIL: ' || sqlerrm; end if;
  end;
  return msg;
end $$;
revoke all on function public.founder_channels_selftest() from public, anon, authenticated;
grant execute on function public.founder_channels_selftest() to service_role;

do $$ begin raise notice 'E111 founder channels + telemetry tayyar. Chalao: CHECK_E111.sql'; end $$;

-- ==============================================================================================================================
-- RUST CONTRACT (server/founder/src) — kaun sa RPC kahan se bulaya jata hai (sab service_role, PostgREST /rest/v1/rpc/<name>):
--   bridge.rs     founder_channels_pending()          -> pending_channels (hard-coded list ki jagah); missing => purani list + "registry": "missing"
--   main.rs       founder_live_snapshot_v2()          -> /founder/v1/live aur SSE snapshot frame; missing/error => founder_live_snapshot() (v1)
--   live.rs       founder_live_tick_report(ok, ms)    -> har tick ke baad, fire-and-forget (fail ho to sirf log, tick nahi ruke)
--   main.rs       founder_live_session_open/close     -> SSE stream ke shuru/khatam par, fire-and-forget (close reason: lifetime|client_gone|slow_client|lagged|server_stop|error)
--   startup       founder_live_session_sweep()        -> process shuru hote hi (purane khule sessions 'orphan')
--   cron/manual   founder_live_prune_v2(), founder_channels_sync_signal()
-- Rollback: Rust env FOUNDER_TELEMETRY=off => upar ke teeno telemetry RPC nahi bulaye jate; registry/snapshot_v2 phir bhi chalte hain.
-- ==============================================================================================================================
