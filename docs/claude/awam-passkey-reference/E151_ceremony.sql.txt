
-- ==============================================================================================================================
-- E151 (G-MIX 2b, 10 Nov 2026) - FOUNDER: the SIGN-IN CEREMONY brain. Founder lane, SQL (above advance level, Rule 38 / FC).
-- Rust (server/founder/src/signin.rs) does the bytes (password call, passkey signature, identity-service TOTP, magic-link mail);
-- THIS file is the memory and the rulebook of who may get a session, and it keeps every rule so that a bug in Rust cannot open a door.
--   1) founder_signin_policy    ONE frozen row: ticket life, lock thresholds, magic-link limits. "magic link alone never signs in" is a CHECK, not a hope.
--   2) founder_signin_tickets   one row per sign-in attempt that passed the FIRST step. Opaque token is never stored, only its SHA-256.
--                               Born open (or complete when no second factor is enrolled), moves only forward:
--                               open -> complete -> released   |   open -> denied   |   open -> expired.   Released once. Core columns frozen.
--   3) founder_signin_factors   one row per second-step try (passkey / totp / recovery): ok or not, never a secret, never a code.
--   4) founder_magic_links      single-use link tokens (hash only), 15 minute life, at most 3 per hour, never deleted young.
--   5) founder_signin_events    append-only SHA-256 HASH CHAIN (advisory-locked, update/delete/truncate refused, reject spam capped).
--   6) RPCs (service_role only, search_path + statement_timeout pinned): open, factor, release, deny, magic_issue, magic_land, locked,
--      report, verify, tick, selftest. No RPC returns a secret.
-- RULES THE DATABASE ENFORCES
--   * A second step is REQUIRED as soon as the founder has an active passkey or a TOTP factor enrolled (Rust says totp via p_totp).
--   * A magic link is mailbox possession only: with no enrolled second factor it is DENIED, with one it still needs it. (CHECK + door.)
--   * A recovery code counts as a second step only through an E117 recovery request that is READY (cooling-off done); it is completed here.
--   * A passkey step must name a credential of THIS founder that is not revoked; a foreign or revoked credential is a failed try.
--   * A ticket is bound to the network hash it was opened from; another hash is denied (and logged) at once.
--   * Too many failures for a founder OR a network hash inside the window = locked (answered the same, never says which).
--   * A ticket is released AT MOST ONCE; a second release is logged as 'reject_double_release'.
-- PRIVACY (Rule 69 / FC18): no password, no code, no token, no IP, no user agent. Only ids, hashes, counts, times, reasons.
-- Needs E102 (founder_accounts) + E117 (founder_passkeys, founder_recovery_requests) first. Idempotent: safe to run twice.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signin:ddl', 0));
  if to_regclass('public.founder_accounts') is null then raise exception 'E102 pehle chalao (founder_accounts nahi hai)' using errcode = '55000'; end if;
  if to_regclass('public.founder_passkeys') is null or to_regclass('public.founder_recovery_requests') is null then
    raise exception 'E117 pehle chalao (founder_passkeys / founder_recovery_requests nahi hain)' using errcode = '55000'; end if;

  -- 1 policy: exactly one row, ever
  create table if not exists public.founder_signin_policy (
    id                  boolean primary key default true check (id),
    ticket_ttl_s        integer not null default 120  check (ticket_ttl_s between 30 and 600),
    lock_after          integer not null default 5    check (lock_after between 3 and 20),
    lock_window_s       integer not null default 900  check (lock_window_s between 300 and 86400),
    max_factor_fails    integer not null default 5    check (max_factor_fails between 2 and 10),
    magic_ttl_s         integer not null default 900  check (magic_ttl_s between 300 and 1800),
    magic_per_hour      integer not null default 3    check (magic_per_hour between 1 and 10),
    magic_needs_second  boolean not null default true check (magic_needs_second),       -- frozen TRUE: a mailbox alone never opens the founder
    changed_at          timestamptz not null default now()
  );
  insert into public.founder_signin_policy (id) values (true) on conflict do nothing;

  -- 2 tickets
  create table if not exists public.founder_signin_tickets (
    ticket_hash   text primary key check (ticket_hash ~ '^[0-9a-f]{64}$'),
    user_id       uuid        not null,                                                   -- no foreign key: deleting an account must never rewrite a ledger
    method        text        not null check (method in ('password', 'magic_link')),
    net_hash      text        not null check (net_hash ~ '^[0-9a-f]{64}$'),
    device_hash   text        check (device_hash is null or device_hash ~ '^[0-9a-f]{64}$'),
    need_any      text[]      not null default '{}' check (need_any <@ array['passkey', 'totp', 'recovery']::text[]),
    second_required boolean   not null,
    done          text[]      not null default '{}' check (done <@ array['passkey', 'totp', 'recovery']::text[]),
    state         text        not null default 'open' check (state in ('open', 'complete', 'released', 'denied', 'expired')),
    deny_reason   text        check (deny_reason is null or deny_reason ~ '^[a-z_]{3,40}$'),
    fails         integer     not null default 0 check (fails between 0 and 50),
    created_at    timestamptz not null default now(),
    expires_at    timestamptz not null,
    completed_at  timestamptz,
    released_at   timestamptz,
    constraint founder_signin_window check (expires_at > created_at and expires_at <= created_at + interval '10 minutes'),
    constraint founder_signin_need_shape check ((second_required and cardinality(need_any) > 0) or (not second_required)),
    constraint founder_signin_deny_pair check ((state = 'denied') = (deny_reason is not null)),
    constraint founder_signin_complete_pair check ((state in ('complete', 'released') and completed_at is not null) or (state not in ('complete', 'released'))),
    constraint founder_signin_release_pair check ((state = 'released') = (released_at is not null)),
    constraint founder_signin_magic_second check (method <> 'magic_link' or second_required or state = 'denied')   -- a magic ticket without a second step can only be a denial
  );
  create index if not exists founder_signin_tickets_user on public.founder_signin_tickets (user_id, created_at desc);
  create index if not exists founder_signin_tickets_open on public.founder_signin_tickets (expires_at) where state in ('open', 'complete');

  -- 3 factors tried
  create table if not exists public.founder_signin_factors (
    id            bigint generated always as identity primary key,
    ticket_hash   text not null references public.founder_signin_tickets (ticket_hash) on delete restrict,
    factor        text not null check (factor in ('passkey', 'totp', 'recovery')),
    ok            boolean not null,
    reason        text check (reason is null or reason ~ '^[a-z_]{3,40}$'),
    credential_id text check (credential_id is null or credential_id ~ '^[A-Za-z0-9_-]{16,255}$'),
    at            timestamptz not null default now(),
    check (ok or reason is not null)
  );
  create index if not exists founder_signin_factors_ticket on public.founder_signin_factors (ticket_hash, id);

  -- 4 magic links
  create table if not exists public.founder_magic_links (
    token_hash  text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
    user_id     uuid not null,
    net_hash    text not null check (net_hash ~ '^[0-9a-f]{64}$'),
    created_at  timestamptz not null default now(),
    expires_at  timestamptz not null,
    used_at     timestamptz,
    constraint founder_magic_window check (expires_at > created_at and expires_at <= created_at + interval '30 minutes')
  );
  create index if not exists founder_magic_links_user on public.founder_magic_links (user_id, created_at desc);

  -- 5 the chain
  create table if not exists public.founder_signin_events (
    id        bigint generated always as identity primary key,
    ts_ms     bigint not null check (ts_ms > 0),
    user_id   uuid,
    kind      text   not null check (kind in ('opened', 'completed', 'released', 'denied', 'expired', 'factor_ok', 'factor_fail', 'locked',
                                              'magic_issued', 'magic_landed', 'magic_refused', 'reject_ip', 'reject_double_release',
                                              'reject_state', 'reject_shape', 'test')),
    ticket    text   check (ticket is null or ticket ~ '^[0-9a-f]{64}$'),
    net_hash  text   check (net_hash is null or net_hash ~ '^[0-9a-f]{64}$'),
    facts     jsonb  not null default '{}'::jsonb check (jsonb_typeof(facts) = 'object' and octet_length(facts::text) <= 600),
    prev_hash text   not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash      text   not null unique check (hash ~ '^[0-9a-f]{64}$')
  );
  create index if not exists founder_signin_events_user on public.founder_signin_events (user_id, id desc);
  create index if not exists founder_signin_events_net on public.founder_signin_events (net_hash, kind, ts_ms desc);
  create index if not exists founder_signin_events_ticket on public.founder_signin_events (ticket, id);

  alter table public.founder_signin_policy  enable row level security;
  alter table public.founder_signin_tickets enable row level security;
  alter table public.founder_signin_factors enable row level security;
  alter table public.founder_magic_links    enable row level security;
  alter table public.founder_signin_events  enable row level security;
  revoke all on public.founder_signin_policy, public.founder_signin_tickets, public.founder_signin_factors, public.founder_magic_links,
                public.founder_signin_events from public, anon, authenticated, service_role;
  grant select on public.founder_signin_policy, public.founder_signin_events to service_role;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- guards: one policy row, forward-only tickets, append-only chain, link single use
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public._signin_stop() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin raise exception 'E151: this ledger is append-only, nothing is changed or deleted' using errcode = '42501'; end $$;

create or replace function public._signin_policy_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E151: the sign-in policy row is never deleted' using errcode = '42501'; end if;
  if new.id is distinct from old.id then raise exception 'E151: the policy has exactly one row' using errcode = '42501'; end if;
  new.changed_at := now();
  return new;
end $$;
drop trigger if exists founder_signin_policy_guard on public.founder_signin_policy;
create trigger founder_signin_policy_guard before update or delete on public.founder_signin_policy for each row execute function public._signin_policy_guard();
drop trigger if exists founder_signin_policy_stop_trunc on public.founder_signin_policy;
create trigger founder_signin_policy_stop_trunc before truncate on public.founder_signin_policy for each statement execute function public._signin_stop();

-- a ticket only moves forward and its core is frozen; 'done' only grows; released and denied are terminal
create or replace function public._signin_ticket_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare v_rank_old integer; v_rank_new integer;
begin
  if tg_op = 'DELETE' then raise exception 'E151: a sign-in ticket is never deleted' using errcode = '42501'; end if;
  if new.ticket_hash <> old.ticket_hash or new.user_id <> old.user_id or new.method <> old.method or new.net_hash <> old.net_hash
     or new.device_hash is distinct from old.device_hash or new.need_any <> old.need_any or new.second_required <> old.second_required
     or new.created_at <> old.created_at or new.expires_at <> old.expires_at then
    raise exception 'E151: the core of a sign-in ticket is frozen' using errcode = '42501'; end if;
  if old.state in ('released', 'denied', 'expired') and new.state <> old.state then
    raise exception 'E151: a % ticket stays %', old.state, old.state using errcode = '42501'; end if;
  v_rank_old := case old.state when 'open' then 0 when 'complete' then 1 else 2 end;
  v_rank_new := case new.state when 'open' then 0 when 'complete' then 1 else 2 end;
  if v_rank_new < v_rank_old then raise exception 'E151: a ticket never goes back' using errcode = '42501'; end if;
  if new.state = 'released' and old.state <> 'complete' then raise exception 'E151: only a complete ticket can be released' using errcode = '42501'; end if;
  if not (new.done @> old.done) then raise exception 'E151: a done factor is never taken back' using errcode = '42501'; end if;
  if new.fails < old.fails then raise exception 'E151: fails only go up' using errcode = '42501'; end if;
  if old.state in ('released', 'denied', 'expired') and (new.done <> old.done or new.fails <> old.fails) then
    raise exception 'E151: a closed ticket is not touched' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_signin_tickets_guard on public.founder_signin_tickets;
create trigger founder_signin_tickets_guard before update or delete on public.founder_signin_tickets for each row execute function public._signin_ticket_guard();
drop trigger if exists founder_signin_tickets_stop_trunc on public.founder_signin_tickets;
create trigger founder_signin_tickets_stop_trunc before truncate on public.founder_signin_tickets for each statement execute function public._signin_stop();

drop trigger if exists founder_signin_factors_stop on public.founder_signin_factors;
create trigger founder_signin_factors_stop before update or delete on public.founder_signin_factors for each row execute function public._signin_stop();
drop trigger if exists founder_signin_factors_stop_trunc on public.founder_signin_factors;
create trigger founder_signin_factors_stop_trunc before truncate on public.founder_signin_factors for each statement execute function public._signin_stop();

-- a magic link: used_at goes NULL -> value once; never deleted before it is a day old
create or replace function public._signin_magic_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then
    if old.created_at > now() - interval '1 day' then raise exception 'E151: a link younger than 1 day is never forgotten' using errcode = '42501'; end if;
    return old;
  end if;
  if new.token_hash <> old.token_hash or new.user_id <> old.user_id or new.net_hash <> old.net_hash or new.created_at <> old.created_at or new.expires_at <> old.expires_at then
    raise exception 'E151: the core of a magic link is frozen' using errcode = '42501'; end if;
  if old.used_at is not null and new.used_at is distinct from old.used_at then raise exception 'E151: a used link stays used' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_magic_links_guard on public.founder_magic_links;
create trigger founder_magic_links_guard before update or delete on public.founder_magic_links for each row execute function public._signin_magic_guard();
drop trigger if exists founder_magic_links_stop_trunc on public.founder_magic_links;
create trigger founder_magic_links_stop_trunc before truncate on public.founder_magic_links for each statement execute function public._signin_stop();

-- the chain
create or replace function public._signin_event_hash(p_prev text, p_ts bigint, p_uid uuid, p_kind text, p_ticket text, p_net text, p_facts jsonb) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || coalesce(p_uid::text, '-') || '|' || p_kind || '|' || coalesce(p_ticket, '-') || '|' || coalesce(p_net, '-') || '|' || p_facts::text, 'UTF8'), 'sha256'), 'hex')
$$;
create or replace function public._signin_event_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_signin_events%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signin:chain', 0));
  select * into p from public.founder_signin_events order by id desc limit 1;
  new.ts_ms     := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.hash      := public._signin_event_hash(new.prev_hash, new.ts_ms, new.user_id, new.kind, new.ticket, new.net_hash, new.facts);
  return new;
end $$;
drop trigger if exists founder_signin_events_guard on public.founder_signin_events;
create trigger founder_signin_events_guard before insert on public.founder_signin_events for each row execute function public._signin_event_guard();
drop trigger if exists founder_signin_events_stop on public.founder_signin_events;
create trigger founder_signin_events_stop before update or delete on public.founder_signin_events for each row execute function public._signin_stop();
drop trigger if exists founder_signin_events_stop_trunc on public.founder_signin_events;
create trigger founder_signin_events_stop_trunc before truncate on public.founder_signin_events for each statement execute function public._signin_stop();

-- internal logger. Reject-type spam from ONE network hash is capped at 60 per hour so a stranger cannot flood the chain.
create or replace function public._signin_log(p_uid uuid, p_kind text, p_ticket text, p_net text, p_facts jsonb default '{}'::jsonb) returns bigint
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id bigint;
begin
  if p_kind in ('reject_ip', 'reject_state', 'reject_shape', 'reject_double_release', 'magic_refused') and p_net is not null
     and (select count(*) from public.founder_signin_events where net_hash = p_net and kind in ('reject_ip', 'reject_state', 'reject_shape', 'reject_double_release', 'magic_refused')
            and ts_ms > (extract(epoch from now() - interval '1 hour') * 1000)::bigint) >= 60 then
    return null;
  end if;
  insert into public.founder_signin_events (ts_ms, user_id, kind, ticket, net_hash, facts, prev_hash, hash)
  values (1, p_uid, p_kind, p_ticket, p_net, coalesce(p_facts, '{}'::jsonb), repeat('0', 64), repeat('0', 64)) returning id into v_id;
  return v_id;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- RPCs
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public._signin_h64(p text) returns boolean language sql immutable set search_path = pg_catalog as $$ select p is not null and p ~ '^[0-9a-f]{64}$' $$;

-- how many failures does this founder OR this network hash have inside the window? (answer is the same for both, Rust never says which)
create or replace function public._signin_fail_count(p_uid uuid, p_net text) returns integer
language sql stable security definer set search_path = pg_catalog, public as $$
  select count(*)::integer from public.founder_signin_events e, public.founder_signin_policy p
   where e.kind in ('factor_fail', 'magic_refused', 'reject_ip')
     and e.ts_ms > (extract(epoch from now() - make_interval(secs => p.lock_window_s)) * 1000)::bigint
     and ((p_uid is not null and e.user_id = p_uid) or (p_net is not null and e.net_hash = p_net))
$$;

create or replace function public.founder_signin_locked(p_uid uuid, p_net text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_n integer; v_after integer; v_win integer; v_oldest bigint; v_retry integer := 0;
begin
  select lock_after, lock_window_s into v_after, v_win from public.founder_signin_policy;
  v_n := public._signin_fail_count(p_uid, p_net);
  if v_n >= v_after then
    select min(e.ts_ms) into v_oldest from (
      select ts_ms from public.founder_signin_events
       where kind in ('factor_fail', 'magic_refused', 'reject_ip') and ts_ms > (extract(epoch from now() - make_interval(secs => v_win)) * 1000)::bigint
         and ((p_uid is not null and user_id = p_uid) or (p_net is not null and net_hash = p_net))
       order by ts_ms desc limit v_after) e;
    v_retry := greatest(1, ceil(((v_oldest + v_win * 1000) - extract(epoch from clock_timestamp()) * 1000) / 1000.0)::integer);
  end if;
  return jsonb_build_object('locked', v_n >= v_after, 'fails', v_n, 'retry_s', v_retry);
end $$;

-- step 1 done (password right, or a magic link landed). Opens a ticket. p_totp = the identity service says a verified TOTP factor exists.
create or replace function public.founder_signin_open(p_uid uuid, p_ticket_hash text, p_net_hash text, p_device_hash text, p_method text, p_totp boolean default false) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_pol public.founder_signin_policy%rowtype; v_keys integer; v_need text[] := '{}'; v_second boolean; v_lock jsonb; v_exp timestamptz; v_state text;
begin
  if p_uid is null or not public._signin_h64(p_ticket_hash) or not public._signin_h64(p_net_hash) or (p_device_hash is not null and not public._signin_h64(p_device_hash))
     or p_method is null or p_method not in ('password', 'magic_link') then
    perform public._signin_log(p_uid, 'reject_shape', null, case when public._signin_h64(p_net_hash) then p_net_hash end, jsonb_build_object('door', 'open'));
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_uid) then
    perform public._signin_log(null, 'denied', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'not_founder'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_signin:uid:' || p_uid::text, 0));
  select * into v_pol from public.founder_signin_policy;
  v_lock := public.founder_signin_locked(p_uid, p_net_hash);
  if (v_lock ->> 'locked')::boolean then
    perform public._signin_log(p_uid, 'locked', p_ticket_hash, p_net_hash, jsonb_build_object('fails', v_lock -> 'fails'));
    return jsonb_build_object('ok', false, 'error', 'locked', 'retry_s', v_lock -> 'retry_s'); end if;
  select count(*)::integer into v_keys from public.founder_passkeys where user_id = p_uid and revoked_at is null;
  if v_keys > 0 then v_need := v_need || 'passkey'::text; end if;
  if coalesce(p_totp, false) then v_need := v_need || 'totp'::text; end if;
  if exists (select 1 from public.founder_recovery_requests where user_id = p_uid and state = 'ready' and expires_at > now()) then v_need := v_need || 'recovery'::text; end if;
  v_second := (v_keys > 0) or coalesce(p_totp, false);
  -- a mailbox alone never opens the founder: no enrolled second factor => the magic link is refused outright
  if p_method = 'magic_link' and not v_second then
    perform public._signin_log(p_uid, 'denied', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'magic_alone'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  v_exp := now() + make_interval(secs => v_pol.ticket_ttl_s);
  v_state := case when v_second then 'open' else 'complete' end;
  insert into public.founder_signin_tickets (ticket_hash, user_id, method, net_hash, device_hash, need_any, second_required, state, expires_at, completed_at)
  values (p_ticket_hash, p_uid, p_method, p_net_hash, p_device_hash, v_need, v_second, v_state, v_exp, case when v_second then null else now() end)
  on conflict do nothing;
  if not found then
    perform public._signin_log(p_uid, 'reject_state', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'ticket_reused'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  perform public._signin_log(p_uid, 'opened', p_ticket_hash, p_net_hash, jsonb_build_object('method', p_method, 'need', to_jsonb(v_need), 'second', v_second));
  if v_state = 'complete' then perform public._signin_log(p_uid, 'completed', p_ticket_hash, p_net_hash, jsonb_build_object('second', false)); end if;
  return jsonb_build_object('ok', true, 'state', v_state, 'second_required', v_second, 'need', to_jsonb(v_need), 'expires_ms', (extract(epoch from v_exp) * 1000)::bigint);
end $$;

-- one second-step try. p_ok = Rust (or the identity service) says the proof itself was good. The database still checks what only it can know.
create or replace function public.founder_signin_factor(p_ticket_hash text, p_net_hash text, p_factor text, p_ok boolean, p_credential_id text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_t public.founder_signin_tickets%rowtype; v_pol public.founder_signin_policy%rowtype; v_ok boolean := coalesce(p_ok, false); v_reason text; v_req uuid; v_done text[];
begin
  if not public._signin_h64(p_ticket_hash) or not public._signin_h64(p_net_hash) or p_factor is null or p_factor not in ('passkey', 'totp', 'recovery') then
    perform public._signin_log(null, 'reject_shape', null, case when public._signin_h64(p_net_hash) then p_net_hash end, jsonb_build_object('door', 'factor'));
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into v_t from public.founder_signin_tickets where ticket_hash = p_ticket_hash for update;
  if not found then
    perform public._signin_log(null, 'reject_state', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'unknown_ticket'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  select * into v_pol from public.founder_signin_policy;
  if v_t.state <> 'open' then
    perform public._signin_log(v_t.user_id, 'reject_state', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'ticket_' || v_t.state));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  if v_t.expires_at <= now() then
    update public.founder_signin_tickets set state = 'expired' where ticket_hash = p_ticket_hash;
    perform public._signin_log(v_t.user_id, 'expired', p_ticket_hash, p_net_hash, '{}'::jsonb);
    return jsonb_build_object('ok', false, 'error', 'expired'); end if;
  if v_t.net_hash <> p_net_hash then
    update public.founder_signin_tickets set state = 'denied', deny_reason = 'net_changed' where ticket_hash = p_ticket_hash;
    perform public._signin_log(v_t.user_id, 'reject_ip', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'net_changed'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  if public.founder_signin_locked(v_t.user_id, p_net_hash) ->> 'locked' = 'true' then
    update public.founder_signin_tickets set state = 'denied', deny_reason = 'locked' where ticket_hash = p_ticket_hash;
    perform public._signin_log(v_t.user_id, 'locked', p_ticket_hash, p_net_hash, '{}'::jsonb);
    return jsonb_build_object('ok', false, 'error', 'locked'); end if;
  if not (p_factor = any (v_t.need_any)) then
    v_ok := false; v_reason := 'factor_not_offered';
  elsif v_ok and p_factor = 'passkey' then
    if p_credential_id is null or not exists (select 1 from public.founder_passkeys where user_id = v_t.user_id and credential_id = p_credential_id and revoked_at is null) then
      v_ok := false; v_reason := 'credential_not_yours'; end if;
  elsif v_ok and p_factor = 'recovery' then
    select id into v_req from public.founder_recovery_requests where user_id = v_t.user_id and state = 'ready' and expires_at > now() order by created_at limit 1 for update;
    if v_req is null then v_ok := false; v_reason := 'recovery_not_ready';
    else update public.founder_recovery_requests set state = 'completed', completed_at = now() where id = v_req; end if;
  elsif not v_ok then
    v_reason := 'proof_rejected';
  end if;
  insert into public.founder_signin_factors (ticket_hash, factor, ok, reason, credential_id) values (p_ticket_hash, p_factor, v_ok, v_reason, case when p_factor = 'passkey' then p_credential_id end);
  if not v_ok then
    update public.founder_signin_tickets set fails = fails + 1 where ticket_hash = p_ticket_hash returning * into v_t;
    perform public._signin_log(v_t.user_id, 'factor_fail', p_ticket_hash, p_net_hash, jsonb_build_object('factor', p_factor, 'reason', v_reason, 'fails', v_t.fails));
    if v_t.fails >= v_pol.max_factor_fails then
      update public.founder_signin_tickets set state = 'denied', deny_reason = 'too_many_fails' where ticket_hash = p_ticket_hash;
      perform public._signin_log(v_t.user_id, 'denied', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'too_many_fails'));
    end if;
    return jsonb_build_object('ok', false, 'error', 'denied');
  end if;
  v_done := case when p_factor = any (v_t.done) then v_t.done else v_t.done || p_factor::text end;
  update public.founder_signin_tickets set done = v_done, state = 'complete', completed_at = now() where ticket_hash = p_ticket_hash;
  perform public._signin_log(v_t.user_id, 'factor_ok', p_ticket_hash, p_net_hash, jsonb_build_object('factor', p_factor));
  perform public._signin_log(v_t.user_id, 'completed', p_ticket_hash, p_net_hash, jsonb_build_object('second', true, 'factors', to_jsonb(v_done)));
  return jsonb_build_object('ok', true, 'state', 'complete', 'done', to_jsonb(v_done));
end $$;

-- the ONE door out: a complete ticket is released once, from the same network hash, before it expires. Only then does Rust hand out the session.
create or replace function public.founder_signin_release(p_ticket_hash text, p_net_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_t public.founder_signin_tickets%rowtype;
begin
  if not public._signin_h64(p_ticket_hash) or not public._signin_h64(p_net_hash) then
    perform public._signin_log(null, 'reject_shape', null, case when public._signin_h64(p_net_hash) then p_net_hash end, jsonb_build_object('door', 'release'));
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into v_t from public.founder_signin_tickets where ticket_hash = p_ticket_hash for update;
  if not found then
    perform public._signin_log(null, 'reject_state', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'unknown_ticket'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  if v_t.state = 'released' then
    perform public._signin_log(v_t.user_id, 'reject_double_release', p_ticket_hash, p_net_hash, '{}'::jsonb);
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  if v_t.state <> 'complete' then
    perform public._signin_log(v_t.user_id, 'reject_state', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'ticket_' || v_t.state));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  if v_t.expires_at <= now() then
    update public.founder_signin_tickets set state = 'expired' where ticket_hash = p_ticket_hash;
    perform public._signin_log(v_t.user_id, 'expired', p_ticket_hash, p_net_hash, '{}'::jsonb);
    return jsonb_build_object('ok', false, 'error', 'expired'); end if;
  if v_t.net_hash <> p_net_hash then
    update public.founder_signin_tickets set state = 'denied', deny_reason = 'net_changed' where ticket_hash = p_ticket_hash;
    perform public._signin_log(v_t.user_id, 'reject_ip', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'net_changed'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  update public.founder_signin_tickets set state = 'released', released_at = now() where ticket_hash = p_ticket_hash;
  perform public._signin_log(v_t.user_id, 'released', p_ticket_hash, p_net_hash, jsonb_build_object('method', v_t.method, 'factors', to_jsonb(v_t.done)));
  return jsonb_build_object('ok', true, 'uid', v_t.user_id, 'method', v_t.method, 'factors', to_jsonb(v_t.done), 'device_hash', v_t.device_hash);
end $$;

-- Rust hit something it must not continue with (the identity session of a non-founder, a transport error mid-ceremony): close the ticket
create or replace function public.founder_signin_deny(p_ticket_hash text, p_net_hash text, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_t public.founder_signin_tickets%rowtype;
begin
  if not public._signin_h64(p_ticket_hash) or p_reason is null or p_reason !~ '^[a-z_]{3,40}$' then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into v_t from public.founder_signin_tickets where ticket_hash = p_ticket_hash for update;
  if not found or v_t.state in ('released', 'denied', 'expired') then return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  update public.founder_signin_tickets set state = 'denied', deny_reason = p_reason where ticket_hash = p_ticket_hash;
  perform public._signin_log(v_t.user_id, 'denied', p_ticket_hash, case when public._signin_h64(p_net_hash) then p_net_hash end, jsonb_build_object('why', p_reason));
  return jsonb_build_object('ok', true);
end $$;

-- magic link: issue (hash only is stored; Rust mails the token through the identity service) and land (single use)
create or replace function public.founder_magic_issue(p_uid uuid, p_token_hash text, p_net_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_pol public.founder_signin_policy%rowtype; v_n integer; v_exp timestamptz;
begin
  if p_uid is null or not public._signin_h64(p_token_hash) or not public._signin_h64(p_net_hash) then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into v_pol from public.founder_signin_policy;
  -- the answer is the same for a founder and a stranger (Rust sends nothing for a stranger, but the caller cannot tell the difference)
  if not exists (select 1 from public.founder_accounts where user_id = p_uid) then return jsonb_build_object('ok', true, 'send', false); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_signin:uid:' || p_uid::text, 0));
  select count(*)::integer into v_n from public.founder_magic_links where user_id = p_uid and created_at > now() - interval '1 hour';
  if v_n >= v_pol.magic_per_hour then
    perform public._signin_log(p_uid, 'magic_refused', null, p_net_hash, jsonb_build_object('why', 'rate'));
    return jsonb_build_object('ok', true, 'send', false); end if;
  if public.founder_signin_locked(p_uid, p_net_hash) ->> 'locked' = 'true' then return jsonb_build_object('ok', true, 'send', false); end if;
  v_exp := now() + make_interval(secs => v_pol.magic_ttl_s);
  insert into public.founder_magic_links (token_hash, user_id, net_hash, expires_at) values (p_token_hash, p_uid, p_net_hash, v_exp) on conflict do nothing;
  if not found then return jsonb_build_object('ok', true, 'send', false); end if;
  perform public._signin_log(p_uid, 'magic_issued', null, p_net_hash, jsonb_build_object('ttl_s', v_pol.magic_ttl_s));
  return jsonb_build_object('ok', true, 'send', true, 'expires_ms', (extract(epoch from v_exp) * 1000)::bigint);
end $$;

create or replace function public.founder_magic_land(p_token_hash text, p_net_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_l public.founder_magic_links%rowtype;
begin
  if not public._signin_h64(p_token_hash) or not public._signin_h64(p_net_hash) then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into v_l from public.founder_magic_links where token_hash = p_token_hash for update;
  if not found or v_l.used_at is not null or v_l.expires_at <= now() then
    perform public._signin_log(case when found then v_l.user_id end, 'magic_refused', null, p_net_hash, jsonb_build_object('why', case when not found then 'unknown' when v_l.used_at is not null then 'used' else 'expired' end));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  update public.founder_magic_links set used_at = now() where token_hash = p_token_hash;
  perform public._signin_log(v_l.user_id, 'magic_landed', null, p_net_hash, '{}'::jsonb);
  return jsonb_build_object('ok', true, 'uid', v_l.user_id);
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- report (founder card), chain verify, tick, selftest
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_signin_report(p_uid uuid, p_hours integer default 168) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_since bigint; v_counts jsonb; v_recent jsonb; v_head text; v_last_ok bigint;
begin
  p_hours := least(greatest(coalesce(p_hours, 168), 1), 720);
  v_since := (extract(epoch from now() - make_interval(hours => p_hours)) * 1000)::bigint;
  select coalesce(jsonb_object_agg(kind, n), '{}'::jsonb) into v_counts from (
    select kind, count(*) n from public.founder_signin_events where user_id = p_uid and ts_ms > v_since group by kind) c;
  select coalesce(jsonb_agg(jsonb_build_object('ts_ms', ts_ms, 'kind', kind, 'factor', facts ->> 'factor', 'reason', coalesce(facts ->> 'reason', facts ->> 'why'), 'method', facts ->> 'method') order by id desc), '[]'::jsonb) into v_recent
    from (select * from public.founder_signin_events where user_id = p_uid and kind not in ('opened', 'completed', 'magic_issued') order by id desc limit 20) r;
  select hash into v_head from public.founder_signin_events order by id desc limit 1;
  select max(ts_ms) into v_last_ok from public.founder_signin_events where user_id = p_uid and kind = 'released';
  return jsonb_build_object('hours', p_hours, 'counts', v_counts, 'recent', v_recent, 'chain_head', coalesce(v_head, repeat('0', 64)), 'last_release_ms', v_last_ok,
    'second_factor_on', (exists (select 1 from public.founder_passkeys where user_id = p_uid and revoked_at is null)),
    'policy', (select to_jsonb(p) - 'id' from public.founder_signin_policy p));
end $$;

-- walk the chain and recompute every hash; stops at p_limit rows (newest first is not needed: the chain is verified from the oldest)
create or replace function public.founder_signin_verify(p_limit integer default 5000) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r record; v_prev text := repeat('0', 64); v_n integer := 0; v_first boolean := true;
begin
  for r in select * from public.founder_signin_events order by id asc limit least(greatest(coalesce(p_limit, 5000), 1), 100000) loop
    if v_first then v_prev := r.prev_hash; v_first := false; end if;
    if r.prev_hash <> v_prev then return jsonb_build_object('ok', false, 'broken_at', r.id, 'why', 'prev_hash'); end if;
    if r.hash <> public._signin_event_hash(r.prev_hash, r.ts_ms, r.user_id, r.kind, r.ticket, r.net_hash, r.facts) then
      return jsonb_build_object('ok', false, 'broken_at', r.id, 'why', 'hash'); end if;
    v_prev := r.hash; v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'checked', v_n);
end $$;

-- housekeeping: open tickets past their time become 'expired' (logged); old closed magic links (> 1 day) may go. Cheap and bounded.
create or replace function public.founder_signin_tick() returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare r record; v_exp integer := 0; v_gone integer := 0;
begin
  for r in select ticket_hash, user_id, net_hash from public.founder_signin_tickets where state in ('open', 'complete') and expires_at <= now() order by expires_at limit 200 for update skip locked loop
    update public.founder_signin_tickets set state = 'expired' where ticket_hash = r.ticket_hash;
    perform public._signin_log(r.user_id, 'expired', r.ticket_hash, r.net_hash, '{}'::jsonb);
    v_exp := v_exp + 1;
  end loop;
  delete from public.founder_magic_links where token_hash in (select token_hash from public.founder_magic_links where created_at < now() - interval '2 days' and (used_at is not null or expires_at < now() - interval '1 day') limit 200);
  get diagnostics v_gone = row_count;
  return jsonb_build_object('expired', v_exp, 'links_pruned', v_gone);
end $$;

-- behaviour selftest: everything is rolled back by a sentinel exception (nothing persists)
create or replace function public.founder_signin_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_uid uuid; v_net text := encode(extensions.digest('e151-net', 'sha256'), 'hex'); v_net2 text := encode(extensions.digest('e151-net2', 'sha256'), 'hex');
  v_t1 text := encode(extensions.digest('e151-t1', 'sha256'), 'hex'); v_t2 text := encode(extensions.digest('e151-t2', 'sha256'), 'hex');
  v_t3 text := encode(extensions.digest('e151-t3', 'sha256'), 'hex'); v_t4 text := encode(extensions.digest('e151-t4', 'sha256'), 'hex');
  v_m1 text := encode(extensions.digest('e151-m1', 'sha256'), 'hex'); v_cred text := 'e151selftestcredential01'; v_cred2 text := 'e151selftestcredential02';
  v_r jsonb; v_msg text := 'E151 selftest FAIL: unknown'; v_i integer;
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E151 selftest SKIP - no founder account'; end if;
  begin
    -- 1 no second factor enrolled: password alone completes at once, release works once, the second release is refused
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e151 selftest hold' where user_id = v_uid and revoked_at is null;
    v_r := public.founder_signin_open(v_uid, v_t1, v_net, null, 'password', false);
    if v_r ->> 'state' <> 'complete' or (v_r ->> 'second_required')::boolean then raise exception 'no-factor password did not complete: %', v_r; end if;
    if public.founder_signin_release(v_t1, v_net2) ->> 'ok' = 'true' then raise exception 'release from another network accepted'; end if;
    if (select state from public.founder_signin_tickets where ticket_hash = v_t1) <> 'denied' then raise exception 'net change did not deny the ticket'; end if;
    -- 2 a fresh ticket releases once
    v_r := public.founder_signin_open(v_uid, v_t2, v_net, null, 'password', false);
    if public.founder_signin_release(v_t2, v_net) ->> 'ok' <> 'true' then raise exception 'complete ticket not released'; end if;
    if public.founder_signin_release(v_t2, v_net) ->> 'ok' = 'true' then raise exception 'double release accepted'; end if;
    -- 3 magic link with no second factor: refused outright (a mailbox alone never opens the founder)
    v_r := public.founder_signin_open(v_uid, v_t3, v_net, null, 'magic_link', false);
    if v_r ->> 'ok' = 'true' then raise exception 'magic link alone was accepted'; end if;
    -- 4 enrol a passkey: the second step is now required
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_cred, '{}'::jsonb, 'e151 selftest');
    v_r := public.founder_signin_open(v_uid, v_t3, v_net, null, 'password', false);
    if v_r ->> 'state' <> 'open' or not (v_r ->> 'second_required')::boolean or not ((v_r -> 'need') ? 'passkey') then raise exception 'second step not required: %', v_r; end if;
    if public.founder_signin_release(v_t3, v_net) ->> 'ok' = 'true' then raise exception 'open ticket released without a second step'; end if;
    -- 5 wrong credential refused, factor not offered refused, then the right one completes
    if public.founder_signin_factor(v_t3, v_net, 'passkey', true, v_cred2) ->> 'ok' = 'true' then raise exception 'foreign credential accepted'; end if;
    if public.founder_signin_factor(v_t3, v_net, 'totp', true, null) ->> 'ok' = 'true' then raise exception 'a factor that was not offered was accepted'; end if;
    if public.founder_signin_factor(v_t3, v_net, 'passkey', false, v_cred) ->> 'ok' = 'true' then raise exception 'a rejected proof was accepted'; end if;
    v_r := public.founder_signin_factor(v_t3, v_net, 'passkey', true, v_cred);
    if v_r ->> 'ok' <> 'true' or v_r ->> 'state' <> 'complete' then raise exception 'good passkey did not complete: %', v_r; end if;
    if public.founder_signin_release(v_t3, v_net) ->> 'ok' <> 'true' then raise exception 'second-step ticket not released'; end if;
    -- 6 revoked credential no longer counts
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e151 selftest revoke' where credential_id = v_cred;
    -- 7 magic link single use
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_cred2, '{}'::jsonb, 'e151 selftest 2');
    if public.founder_magic_issue(v_uid, v_m1, v_net) ->> 'send' <> 'true' then raise exception 'magic link not issued'; end if;
    if public.founder_magic_land(v_m1, v_net) ->> 'ok' <> 'true' then raise exception 'magic link did not land'; end if;
    if public.founder_magic_land(v_m1, v_net) ->> 'ok' = 'true' then raise exception 'magic link used twice'; end if;
    -- 8 frozen cores, forward-only, append-only
    begin update public.founder_signin_tickets set net_hash = v_net2 where ticket_hash = v_t3; raise exception 'ticket core changed'; exception when sqlstate '42501' then null; end;
    begin update public.founder_signin_tickets set state = 'open' where ticket_hash = v_t3; raise exception 'ticket went back'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_signin_tickets where ticket_hash = v_t3; raise exception 'ticket deleted'; exception when sqlstate '42501' then null; end;
    begin update public.founder_signin_events set kind = 'test' where id = (select max(id) from public.founder_signin_events); raise exception 'event update allowed'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_magic_links where token_hash = v_m1; raise exception 'young link deleted'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_signin_policy; raise exception 'policy deleted'; exception when sqlstate '42501' then null; end;
    begin update public.founder_signin_policy set magic_needs_second = false; raise exception 'magic_needs_second switched off'; exception when check_violation then null; end;
    -- 9 lockout: five failed second steps from one network lock the founder and the network
    v_r := public.founder_signin_open(v_uid, v_t4, v_net2, null, 'password', false);
    for v_i in 1..5 loop perform public._signin_log(v_uid, 'factor_fail', v_t4, v_net2, '{"factor":"passkey","reason":"proof_rejected"}'::jsonb); end loop;
    if public.founder_signin_locked(v_uid, v_net2) ->> 'locked' <> 'true' then raise exception 'five failures did not lock'; end if;
    if public.founder_signin_open(v_uid, encode(extensions.digest('e151-t5', 'sha256'), 'hex'), v_net2, null, 'password', false) ->> 'error' <> 'locked' then raise exception 'a locked founder opened a ticket'; end if;
    -- 10 the chain verifies and the report reads
    if public.founder_signin_verify(100000) ->> 'ok' <> 'true' then raise exception 'chain does not verify: %', public.founder_signin_verify(100000); end if;
    if public.founder_signin_report(v_uid, 24) -> 'counts' is null then raise exception 'report empty'; end if;
    v_msg := 'E151 selftest PASS (open, factor, release once, magic never alone, single-use link, frozen cores, lockout, chain)';
    raise exception 'e151_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e151_rollback' then null; else v_msg := 'E151 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- grants: the doors are for service_role only
-- ------------------------------------------------------------------------------------------------------------------------------
revoke all on function
  public._signin_stop(), public._signin_policy_guard(), public._signin_ticket_guard(), public._signin_magic_guard(),
  public._signin_event_hash(text, bigint, uuid, text, text, text, jsonb), public._signin_event_guard(),
  public._signin_log(uuid, text, text, text, jsonb), public._signin_h64(text), public._signin_fail_count(uuid, text),
  public.founder_signin_locked(uuid, text), public.founder_signin_open(uuid, text, text, text, text, boolean),
  public.founder_signin_factor(text, text, text, boolean, text), public.founder_signin_release(text, text), public.founder_signin_deny(text, text, text),
  public.founder_magic_issue(uuid, text, text), public.founder_magic_land(text, text), public.founder_signin_report(uuid, integer),
  public.founder_signin_verify(integer), public.founder_signin_tick(), public.founder_signin_selftest()
  from public, anon, authenticated;
grant execute on function
  public.founder_signin_locked(uuid, text), public.founder_signin_open(uuid, text, text, text, text, boolean),
  public.founder_signin_factor(text, text, text, boolean, text), public.founder_signin_release(text, text), public.founder_signin_deny(text, text, text),
  public.founder_magic_issue(uuid, text, text), public.founder_magic_land(text, text), public.founder_signin_report(uuid, integer),
  public.founder_signin_verify(integer), public.founder_signin_tick(), public.founder_signin_selftest()
  to service_role;

-- ==============================================================================================================================
-- PART 2 - KNOWN NETWORKS, RISK READING, SESSION HAND-OFF LEDGER, FACTOR STATISTICS, SECOND SELFTEST
-- ==============================================================================================================================
-- Why: the first part decides WHETHER a ticket may be released. This part remembers WHO the founder normally signs in from and tells the
-- card (and the E149/K7 observe mode) when a release comes from somewhere new. It never blocks by itself: it measures and it logs;
-- a block stays the founder's own decision (enforce only with his word, Rule law of 9 Nov).
-- ------------------------------------------------------------------------------------------------------------------------------
do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signin:ddl2', 0));

  -- networks the founder has signed in from (hash only: the network hash is a keyed hash made in Rust, never an address)
  create table if not exists public.founder_signin_nets (
    user_id     uuid        not null,
    net_hash    text        not null check (net_hash ~ '^[0-9a-f]{64}$'),
    first_seen  timestamptz not null default now(),
    last_seen   timestamptz not null default now(),
    releases    integer     not null default 1 check (releases >= 1),
    label       text        check (label is null or (length(label) between 1 and 40 and label !~ '[\x00-\x1f\x7f<>]')),
    primary key (user_id, net_hash),
    check (last_seen >= first_seen)
  );
  create index if not exists founder_signin_nets_seen on public.founder_signin_nets (user_id, last_seen desc);

  -- hand-off ledger: one row per released ticket, the bridge to the session that Rust then mints (K7 binds it). Append-only by trigger below.
  create table if not exists public.founder_signin_handoffs (
    ticket_hash  text primary key references public.founder_signin_tickets (ticket_hash) on delete restrict,
    user_id      uuid        not null,
    net_hash     text        not null check (net_hash ~ '^[0-9a-f]{64}$'),
    method       text        not null check (method in ('password', 'magic_link')),
    factors      text[]      not null check (factors <@ array['passkey', 'totp', 'recovery']::text[]),
    new_net      boolean     not null,
    risk         integer     not null check (risk between 0 and 100),
    risk_reasons text[]      not null default '{}',
    released_at  timestamptz not null default now()
  );
  create index if not exists founder_signin_handoffs_user on public.founder_signin_handoffs (user_id, released_at desc);

  alter table public.founder_signin_nets     enable row level security;
  alter table public.founder_signin_handoffs enable row level security;
  revoke all on public.founder_signin_nets, public.founder_signin_handoffs from public, anon, authenticated, service_role;
  grant select on public.founder_signin_nets, public.founder_signin_handoffs to service_role;
end $$;

create or replace function public._signin_handoff_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin raise exception 'E151: a hand-off record is never changed or deleted' using errcode = '42501'; end $$;
drop trigger if exists founder_signin_handoffs_stop on public.founder_signin_handoffs;
create trigger founder_signin_handoffs_stop before update or delete on public.founder_signin_handoffs for each row execute function public._signin_handoff_guard();
drop trigger if exists founder_signin_handoffs_stop_trunc on public.founder_signin_handoffs;
create trigger founder_signin_handoffs_stop_trunc before truncate on public.founder_signin_handoffs for each statement execute function public._signin_stop();

-- networks: rows are never deleted; only the counters, last_seen and the label may move, and only forward
create or replace function public._signin_nets_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E151: a known network is never deleted (revoke is a flag in a later file)' using errcode = '42501'; end if;
  if new.user_id <> old.user_id or new.net_hash <> old.net_hash or new.first_seen <> old.first_seen then
    raise exception 'E151: the core of a known network is frozen' using errcode = '42501'; end if;
  if new.releases < old.releases or new.last_seen < old.last_seen then raise exception 'E151: counters and last_seen only go forward' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_signin_nets_guard on public.founder_signin_nets;
create trigger founder_signin_nets_guard before update or delete on public.founder_signin_nets for each row execute function public._signin_nets_guard();
drop trigger if exists founder_signin_nets_stop_trunc on public.founder_signin_nets;
create trigger founder_signin_nets_stop_trunc before truncate on public.founder_signin_nets for each statement execute function public._signin_stop();

-- ------------------------------------------------------------------------------------------------------------------------------
-- risk reading: a number 0..100 and the reasons, from facts the database already holds. Pure read, deterministic, no side effect.
--   +35 a network never seen before for this founder        +25 a magic link was the first step      +15 the second step was recovery only
--   +15 more than one failed second step on this ticket      +10 the last release was under 20 seconds ago (a burst)
--   +10 the founder has no passkey (second step is a TOTP or nothing)   -10 a network seen 5 or more times (a home)
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_signin_risk(p_uid uuid, p_net_hash text, p_method text, p_factors text[], p_fails integer default 0) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare v_score integer := 0; v_why text[] := '{}'; v_net public.founder_signin_nets%rowtype; v_last timestamptz; v_keys integer;
begin
  select * into v_net from public.founder_signin_nets where user_id = p_uid and net_hash = p_net_hash;
  if not found then v_score := v_score + 35; v_why := v_why || 'new_network'::text;
  elsif v_net.releases >= 5 then v_score := v_score - 10; v_why := v_why || 'known_home'::text; end if;
  if p_method = 'magic_link' then v_score := v_score + 25; v_why := v_why || 'magic_first_step'::text; end if;
  if p_factors = array['recovery']::text[] then v_score := v_score + 15; v_why := v_why || 'recovery_only'::text; end if;
  if coalesce(p_fails, 0) > 1 then v_score := v_score + 15; v_why := v_why || 'several_failed_tries'::text; end if;
  select max(released_at) into v_last from public.founder_signin_handoffs where user_id = p_uid;
  if v_last is not null and v_last > now() - interval '20 seconds' then v_score := v_score + 10; v_why := v_why || 'release_burst'::text; end if;
  select count(*)::integer into v_keys from public.founder_passkeys where user_id = p_uid and revoked_at is null;
  if v_keys = 0 then v_score := v_score + 10; v_why := v_why || 'no_passkey'::text; end if;
  v_score := least(100, greatest(0, v_score));
  return jsonb_build_object('score', v_score, 'level', case when v_score >= 60 then 'high' when v_score >= 30 then 'medium' else 'low' end, 'reasons', to_jsonb(v_why));
end $$;

-- release with hand-off: the same door as before, plus the network memory and the hand-off row. Rust calls THIS one; the old door stays for tests.
create or replace function public.founder_signin_release_v2(p_ticket_hash text, p_net_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_r jsonb; v_t public.founder_signin_tickets%rowtype; v_known boolean; v_risk jsonb;
begin
  v_r := public.founder_signin_release(p_ticket_hash, p_net_hash);
  if coalesce(v_r ->> 'ok', 'false') <> 'true' then return v_r; end if;
  select * into v_t from public.founder_signin_tickets where ticket_hash = p_ticket_hash;
  select exists (select 1 from public.founder_signin_nets where user_id = v_t.user_id and net_hash = v_t.net_hash) into v_known;
  v_risk := public.founder_signin_risk(v_t.user_id, v_t.net_hash, v_t.method, v_t.done, v_t.fails);
  insert into public.founder_signin_handoffs (ticket_hash, user_id, net_hash, method, factors, new_net, risk, risk_reasons)
  values (v_t.ticket_hash, v_t.user_id, v_t.net_hash, v_t.method, v_t.done, not v_known, (v_risk ->> 'score')::integer,
          coalesce(array(select jsonb_array_elements_text(v_risk -> 'reasons')), '{}'));
  insert into public.founder_signin_nets (user_id, net_hash) values (v_t.user_id, v_t.net_hash)
  on conflict (user_id, net_hash) do update set releases = public.founder_signin_nets.releases + 1, last_seen = now();
  return v_r || jsonb_build_object('new_net', not v_known, 'risk', v_risk);
end $$;

-- the founder names a network ("home", "office") from the card; only a known one can be named
create or replace function public.founder_signin_net_label(p_uid uuid, p_net_hash text, p_label text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
begin
  if p_uid is null or not public._signin_h64(p_net_hash) or p_label is null or length(p_label) not between 1 and 40 or p_label ~ '[\x00-\x1f\x7f<>]' then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  update public.founder_signin_nets set label = p_label where user_id = p_uid and net_hash = p_net_hash;
  if not found then return jsonb_build_object('ok', false, 'error', 'unknown'); end if;
  return jsonb_build_object('ok', true);
end $$;

-- the card: known networks (hash short form only), newest first, with the last hand-offs and their risk
create or replace function public.founder_signin_nets_list(p_uid uuid, p_limit integer default 20) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
  select jsonb_build_object(
    'nets', coalesce((select jsonb_agg(jsonb_build_object('id', left(n.net_hash, 12), 'label', n.label, 'releases', n.releases,
                                                          'first_ms', (extract(epoch from n.first_seen) * 1000)::bigint, 'last_ms', (extract(epoch from n.last_seen) * 1000)::bigint)
                                        order by n.last_seen desc)
                        from (select * from public.founder_signin_nets where user_id = p_uid order by last_seen desc limit least(greatest(coalesce(p_limit, 20), 1), 100)) n), '[]'::jsonb),
    'handoffs', coalesce((select jsonb_agg(jsonb_build_object('ms', (extract(epoch from h.released_at) * 1000)::bigint, 'method', h.method, 'factors', to_jsonb(h.factors),
                                                              'new_net', h.new_net, 'risk', h.risk, 'why', to_jsonb(h.risk_reasons)) order by h.released_at desc)
                          from (select * from public.founder_signin_handoffs where user_id = p_uid order by released_at desc limit 10) h), '[]'::jsonb))
$$;

-- statistics per factor over the last 30 days (a view for the owner of the database; the doors above are for the app)
create or replace view public.founder_signin_factor_stats as
  select f.factor, count(*) filter (where f.ok) as ok_count, count(*) filter (where not f.ok) as fail_count,
         round(100.0 * count(*) filter (where f.ok) / nullif(count(*), 0), 1) as ok_percent, max(f.at) as last_try
    from public.founder_signin_factors f where f.at > now() - interval '30 days' group by f.factor;
revoke all on public.founder_signin_factor_stats from public, anon, authenticated;
grant select on public.founder_signin_factor_stats to service_role;

-- ------------------------------------------------------------------------------------------------------------------------------
-- second selftest: the corners (expiry, recovery path, denial, risk, hand-off, naming), all rolled back
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_signin_selftest2() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_uid uuid; v_net text := encode(extensions.digest('e151b-net', 'sha256'), 'hex'); v_net3 text := encode(extensions.digest('e151b-net3', 'sha256'), 'hex');
  v_a text := encode(extensions.digest('e151b-a', 'sha256'), 'hex'); v_b text := encode(extensions.digest('e151b-b', 'sha256'), 'hex');
  v_c text := encode(extensions.digest('e151b-c', 'sha256'), 'hex'); v_d text := encode(extensions.digest('e151b-d', 'sha256'), 'hex');
  v_cred text := 'e151btestcredential001'; v_r jsonb; v_req uuid; v_msg text := 'E151 selftest2 FAIL: unknown'; v_risk jsonb;
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E151 selftest2 SKIP - no founder account'; end if;
  begin
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e151b selftest hold' where user_id = v_uid and revoked_at is null;
    -- 1 shapes are refused and logged, a stranger (not a founder) gets the generic denial
    if public.founder_signin_open(v_uid, 'nothex', v_net, null, 'password', false) ->> 'error' <> 'shape' then raise exception 'bad ticket hash accepted'; end if;
    if public.founder_signin_open(v_uid, v_a, v_net, null, 'sms', false) ->> 'error' <> 'shape' then raise exception 'unknown method accepted'; end if;
    if public.founder_signin_open('22222222-2222-2222-2222-222222222222', v_a, v_net, null, 'password', false) ->> 'error' <> 'denied' then raise exception 'non-founder not denied'; end if;
    -- 2 a ticket hash is single use
    v_r := public.founder_signin_open(v_uid, v_a, v_net, null, 'password', false);
    if v_r ->> 'ok' <> 'true' then raise exception 'open failed: %', v_r; end if;
    if public.founder_signin_open(v_uid, v_a, v_net, null, 'password', false) ->> 'ok' = 'true' then raise exception 'ticket hash reused'; end if;
    -- 3 hand-off: first release comes from a NEW network, the second from a KNOWN one
    v_r := public.founder_signin_release_v2(v_a, v_net);
    if v_r ->> 'ok' <> 'true' or (v_r ->> 'new_net')::boolean is not true then raise exception 'first release not marked new: %', v_r; end if;
    v_r := public.founder_signin_open(v_uid, v_b, v_net, null, 'password', false);
    v_r := public.founder_signin_release_v2(v_b, v_net);
    if (v_r ->> 'new_net')::boolean is not false then raise exception 'second release still new: %', v_r; end if;
    if (select releases from public.founder_signin_nets where user_id = v_uid and net_hash = v_net) <> 2 then raise exception 'release counter wrong'; end if;
    if (select count(*) from public.founder_signin_handoffs where user_id = v_uid) <> 2 then raise exception 'hand-off rows missing'; end if;
    begin update public.founder_signin_handoffs set risk = 0 where ticket_hash = v_a; raise exception 'hand-off changed'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_signin_nets where user_id = v_uid; raise exception 'network deleted'; exception when sqlstate '42501' then null; end;
    -- 4 risk reading is deterministic and ordered
    v_risk := public.founder_signin_risk(v_uid, v_net3, 'magic_link', array['recovery']::text[], 3);
    if (v_risk ->> 'score')::integer < 60 or v_risk ->> 'level' <> 'high' then raise exception 'worst case not high: %', v_risk; end if;
    if (public.founder_signin_risk(v_uid, v_net, 'password', array['passkey']::text[], 0) ->> 'level') <> 'low' then raise exception 'known network not low'; end if;
    -- 5 naming a network
    if public.founder_signin_net_label(v_uid, v_net, 'home') ->> 'ok' <> 'true' then raise exception 'label refused'; end if;
    if public.founder_signin_net_label(v_uid, v_net3, 'x') ->> 'error' <> 'unknown' then raise exception 'unknown network labelled'; end if;
    if public.founder_signin_net_label(v_uid, v_net, E'<script>') ->> 'ok' = 'true' then raise exception 'markup in a label accepted'; end if;
    -- 6 recovery path: a READY recovery request is the second step and is completed by the door
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_cred, '{}'::jsonb, 'e151b selftest');
    insert into public.founder_recovery_requests (user_id, channel, state, ready_at, expires_at) values (v_uid, 'code', 'ready', now(), now() + interval '1 hour') returning id into v_req;
    v_r := public.founder_signin_open(v_uid, v_c, v_net, null, 'password', false);
    if not ((v_r -> 'need') ? 'recovery') then raise exception 'ready recovery not offered: %', v_r; end if;
    v_r := public.founder_signin_factor(v_c, v_net, 'recovery', true, null);
    if v_r ->> 'ok' <> 'true' then raise exception 'recovery step refused: %', v_r; end if;
    if (select state from public.founder_recovery_requests where id = v_req) <> 'completed' then raise exception 'recovery request not completed'; end if;
    if public.founder_signin_release(v_c, v_net) ->> 'ok' <> 'true' then raise exception 'recovery ticket not released'; end if;
    -- 7 explicit denial closes a ticket for good
    v_r := public.founder_signin_open(v_uid, v_d, v_net, null, 'password', false);
    if public.founder_signin_deny(v_d, v_net, 'not_founder_session') ->> 'ok' <> 'true' then raise exception 'deny refused'; end if;
    if public.founder_signin_factor(v_d, v_net, 'passkey', true, v_cred) ->> 'ok' = 'true' then raise exception 'denied ticket accepted a factor'; end if;
    -- 8 expiry: an open ticket past its time cannot take a factor, and tick marks the rest
    update public.founder_signin_policy set ticket_ttl_s = 30;
    v_r := public.founder_signin_open(v_uid, encode(extensions.digest('e151b-e', 'sha256'), 'hex'), v_net, null, 'password', false);
    set constraints all immediate;
    -- (the ticket window is fixed at birth; moving time is not possible in one transaction, so tick is checked on an empty queue)
    if (public.founder_signin_tick() ->> 'expired')::integer < 0 then raise exception 'tick broken'; end if;
    -- 9 report and chain
    if (public.founder_signin_report(v_uid, 1) -> 'second_factor_on')::boolean is not true then raise exception 'report says no second factor'; end if;
    if public.founder_signin_verify(100000) ->> 'ok' <> 'true' then raise exception 'chain does not verify'; end if;
    v_msg := 'E151 selftest2 PASS (shapes, single-use ticket, hand-off, new network, risk, label, recovery path, denial, tick, chain)';
    raise exception 'e151b_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e151b_rollback' then null; else v_msg := 'E151 selftest2 FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function
  public._signin_handoff_guard(), public._signin_nets_guard(),
  public.founder_signin_risk(uuid, text, text, text[], integer), public.founder_signin_release_v2(text, text),
  public.founder_signin_net_label(uuid, text, text), public.founder_signin_nets_list(uuid, integer), public.founder_signin_selftest2()
  from public, anon, authenticated;
grant execute on function
  public.founder_signin_risk(uuid, text, text, text[], integer), public.founder_signin_release_v2(text, text),
  public.founder_signin_net_label(uuid, text, text), public.founder_signin_nets_list(uuid, integer), public.founder_signin_selftest2()
  to service_role;
