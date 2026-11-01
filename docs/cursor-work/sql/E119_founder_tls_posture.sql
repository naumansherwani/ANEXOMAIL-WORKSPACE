-- E119 — Founder T256-1 (SQL half): the PROOF LEDGER of what TLS every host really negotiates (1 Nov 2026, founder 14:33 "super advance level sql ke saath").
-- Technology: SQL (Supabase Postgres, RLS on). The Rust prober (server/founder/src/tls256.rs) does a REAL handshake three ways and writes the result here:
--   browser  = a normal browser's offer (AES-128 first)  -> what real users get
--   aes256_only / aes128_only                            -> is 256 available, is 128 refused
-- Nothing is invented: no row exists unless a handshake was attempted. Verdicts are computed from rows, never typed in.
-- Safe to run again. The selftest rolls back everything it writes.

create table if not exists public.founder_tls_checks (
  id         bigint generated always as identity primary key,
  checked_at timestamptz not null default now(),
  host       text not null check (host ~ '^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$'),
  port       integer not null check (port between 1 and 65535),
  offered    text not null check (offered in ('browser','aes256_only','aes128_only')),
  ok         boolean not null,
  protocol   text check (protocol is null or length(protocol) <= 20),
  cipher     text check (cipher is null or cipher ~ '^[A-Z0-9_]{5,60}$'),
  kex        text check (kex is null or kex ~ '^[A-Za-z0-9_]{3,40}$'),
  error      text check (error is null or length(error) <= 200),
  source     text not null default 'rust' check (source in ('rust','manual')),
  constraint founder_tls_ok_shape check ((ok and cipher is not null and protocol is not null and error is null) or (not ok and error is not null and cipher is null))
);
create index if not exists founder_tls_checks_host_idx on public.founder_tls_checks (host, port, offered, checked_at desc);
alter table public.founder_tls_checks enable row level security;
revoke all on public.founder_tls_checks from public, anon, authenticated, service_role;
grant select on public.founder_tls_checks to service_role;
comment on table public.founder_tls_checks is 'E119: real TLS handshakes made by the founder Rust prober. Written only through founder_tls_check_record.';

create or replace function public.founder_tls_check_record(p_host text, p_port integer, p_offered text, p_ok boolean, p_protocol text, p_cipher text, p_kex text, p_error text, p_source text default 'rust')
returns bigint language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_id bigint; v_host text := lower(btrim(coalesce(p_host, '')));
begin
  insert into public.founder_tls_checks (host, port, offered, ok, protocol, cipher, kex, error, source)
    values (v_host, p_port, p_offered, coalesce(p_ok, false), nullif(p_protocol, ''), nullif(p_cipher, ''), nullif(p_kex, ''), nullif(left(p_error, 200), ''), coalesce(p_source, 'rust'))
    returning id into v_id;
  delete from public.founder_tls_checks where host = v_host and port = p_port and checked_at < now() - interval '60 days';   -- bounded history, nothing grows forever
  return v_id;
end $$;

-- One answer for the UI: per host:port the LATEST result of each offer, plus verdicts computed from those rows.
--   forced_256        = the browser-style offer ended on AES-256 AND an AES-128-only client was refused   (256 at every cost)
--   available_not_default = a 256-only client works but the browser-style offer lands on AES-128           (Caddy today)
--   no_256            = a 256-only client failed
--   stale             = newest row older than 24 h (the prober should run every 6 h)
create or replace function public.founder_tls_posture() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare r jsonb;
begin
  with latest as (
    select distinct on (host, port, offered) host, port, offered, ok, protocol, cipher, kex, error, checked_at
      from public.founder_tls_checks order by host, port, offered, checked_at desc, id desc
  ), per as (
    select host, port,
      max(checked_at) as newest,
      bool_or(offered = 'browser' and ok) as browser_ok,
      max(cipher) filter (where offered = 'browser') as browser_cipher,
      max(kex) filter (where offered = 'browser') as browser_kex,
      max(protocol) filter (where offered = 'browser') as protocol,
      bool_or(offered = 'aes256_only' and ok) as a256_ok,
      bool_or(offered = 'aes128_only' and not ok) as a128_refused,
      count(*) filter (where offered = 'aes128_only') as a128_seen,
      jsonb_object_agg(offered, jsonb_build_object('ok', ok, 'cipher', cipher, 'kex', kex, 'error', error, 'at_ms', (extract(epoch from checked_at) * 1000)::bigint)) as detail
    from latest group by host, port
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'host', host, 'port', port, 'protocol', protocol, 'browser_cipher', browser_cipher, 'kex', browser_kex, 'detail', detail,
      'newest_ms', (extract(epoch from newest) * 1000)::bigint,
      'stale', newest < now() - interval '24 hours',
      'verdict', case when not browser_ok and not a256_ok then 'unreachable'
                      when browser_ok and browser_cipher like '%AES_256%' and a128_refused then 'forced_256'
                      when browser_ok and browser_cipher like '%AES_256%' then 'default_256'
                      when a256_ok then 'available_not_default'
                      else 'no_256' end) order by host, port), '[]'::jsonb) into r from per;
  return jsonb_build_object('connected', true, 'hosts', r, 'note', 'Every row is a real handshake made by the Rust prober; the prober does not offer post-quantum groups, so key exchange shown is what it could negotiate, not a claim about browsers.');
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.founder_tls_check_record(text,integer,text,boolean,text,text,text,text,text)','public.founder_tls_posture()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- selftest: behaviour on the REAL table (other hosts' rows stay as they are), everything rolled back
create or replace function public.founder_tls_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '30s' as $$
declare r text := ''; b bigint; j jsonb; h jsonb;
begin
  select count(*) into b from public.founder_tls_checks;
  begin
    -- a bad row is refused by the table, not by trust in the caller
    if not public._fs_fails($q$select public.founder_tls_check_record('Bad Host!', 443, 'browser', true, 'TLSv1_3', 'TLS13_AES_256_GCM_SHA384', 'X25519', null)$q$) then raise exception 'a bad host was accepted'; end if;
    if not public._fs_fails($q$select public.founder_tls_check_record('t.example', 70000, 'browser', true, 'TLSv1_3', 'TLS13_AES_256_GCM_SHA384', 'X25519', null)$q$) then raise exception 'a bad port was accepted'; end if;
    if not public._fs_fails($q$select public.founder_tls_check_record('t.example', 443, 'mystery', true, 'TLSv1_3', 'TLS13_AES_256_GCM_SHA384', 'X25519', null)$q$) then raise exception 'an unknown offer was accepted'; end if;
    if not public._fs_fails($q$select public.founder_tls_check_record('t.example', 443, 'browser', true, null, null, null, null)$q$) then raise exception 'an ok row without a cipher was accepted'; end if;
    if not public._fs_fails($q$select public.founder_tls_check_record('t.example', 443, 'browser', false, null, null, null, null)$q$) then raise exception 'a failed row without an error was accepted'; end if;
    if not public._fs_fails($q$select public.founder_tls_check_record('t.example', 443, 'browser', true, 'TLSv1_3', 'x; drop table', 'X25519', null)$q$) then raise exception 'a malformed cipher was accepted'; end if;
    r := r || 'validation OK; ';
    -- Caddy-like host: browser lands on AES-128, 256-only works, 128-only works  => available_not_default
    perform public.founder_tls_check_record('caddy.test', 443, 'browser',     true,  'TLSv1_3', 'TLS13_AES_128_GCM_SHA256', 'X25519', null);
    perform public.founder_tls_check_record('caddy.test', 443, 'aes256_only', true,  'TLSv1_3', 'TLS13_AES_256_GCM_SHA384', 'X25519', null);
    perform public.founder_tls_check_record('caddy.test', 443, 'aes128_only', true,  'TLSv1_3', 'TLS13_AES_128_GCM_SHA256', 'X25519', null);
    -- 256-only terminator: browser lands on AES-256, 128-only refused => forced_256
    perform public.founder_tls_check_record('force.test', 8443, 'browser',     true,  'TLSv1_3', 'TLS13_AES_256_GCM_SHA384', 'X25519', null);
    perform public.founder_tls_check_record('force.test', 8443, 'aes256_only', true,  'TLSv1_3', 'TLS13_AES_256_GCM_SHA384', 'X25519', null);
    perform public.founder_tls_check_record('force.test', 8443, 'aes128_only', false, null, null, null, 'peer is incompatible: no cipher suites in common');
    -- a host that is down
    perform public.founder_tls_check_record('down.test', 443, 'browser',     false, null, null, null, 'connect timeout');
    perform public.founder_tls_check_record('down.test', 443, 'aes256_only', false, null, null, null, 'connect timeout');
    j := public.founder_tls_posture();
    select e into h from jsonb_array_elements(j -> 'hosts') e where e ->> 'host' = 'caddy.test';
    if h ->> 'verdict' <> 'available_not_default' then raise exception 'caddy-like verdict: %', h; end if;
    select e into h from jsonb_array_elements(j -> 'hosts') e where e ->> 'host' = 'force.test';
    if h ->> 'verdict' <> 'forced_256' then raise exception 'forced verdict: %', h; end if;
    select e into h from jsonb_array_elements(j -> 'hosts') e where e ->> 'host' = 'down.test';
    if h ->> 'verdict' <> 'unreachable' then raise exception 'down verdict: %', h; end if;
    r := r || 'verdicts OK; ';
    -- the LATEST row wins: the Caddy-like host later starts forcing 256
    perform public.founder_tls_check_record('caddy.test', 443, 'browser',     true,  'TLSv1_3', 'TLS13_AES_256_GCM_SHA384', 'X25519', null);
    perform public.founder_tls_check_record('caddy.test', 443, 'aes128_only', false, null, null, null, 'no cipher suites in common');
    select e into h from jsonb_array_elements(public.founder_tls_posture() -> 'hosts') e where e ->> 'host' = 'caddy.test';
    if h ->> 'verdict' <> 'forced_256' then raise exception 'latest row did not win: %', h; end if;
    r := r || 'latest wins OK; ';
    -- staleness is computed, not typed
    update public.founder_tls_checks set checked_at = now() - interval '2 days' where host = 'down.test';
    select e into h from jsonb_array_elements(public.founder_tls_posture() -> 'hosts') e where e ->> 'host' = 'down.test';
    if not (h ->> 'stale')::boolean then raise exception 'a 2-day-old result was not stale'; end if;
    r := r || 'stale OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E119 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_tls_checks) <> b then raise exception 'E119 selftest left rows behind'; end if;
  return 'E119 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_tls_selftest() from public, anon, authenticated;
grant execute on function public.founder_tls_selftest() to service_role;
