
-- E200 — QC8a: hash-chained, append-only log of what the one-letter keys DID (archive / trash / star / unread, single or batch).
-- His word 21 Nov 2026 04:55 PKT: "DONO KERO". Pattern read first (schema-first law): E196 event log (guard trigger + per-owner chain + verify + posture + selftest)
-- and E102 founder_audit_append. This file is new tables/functions only; it edits nothing older.
-- Technology: SQL (Supabase Postgres, RLS forced, append-only trigger, SHA-256 hash chain per founder, advisory lock, rate cap).
--
-- PRIVACY BY DESIGN: the log stores NO mail id, NO subject, NO address, NO text. Only: which action, single key or batch, how many mails, which folder, when.
-- A batch is ONE row with n (2..50), so the cap of the UI (50 mails) is also the cap here.
-- RATE: at most 600 rows per founder per rolling hour (a runaway loop cannot flood the ledger); the 601st call is refused, the chain stays valid.
-- Honest scope: SQL only. Nothing calls fmail_keys_log200 until Rust adds a signed door and the UI reports a key action; then the Chairman can read
-- "who pressed what, how often" through fmail_keys_list200 / fmail_keys_stats200. Until then the table is empty and nothing claims otherwise.

do $$
begin
  if to_regclass('public.founder_accounts') is null then raise exception 'E200 needs the founder accounts table (E1xx)'; end if;
  if to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then raise exception 'E200 needs founder_audit_append (E102)'; end if;
end $$;

-- 1) the log
create table if not exists public.fmail_keys_events200 (
  user_id   uuid   not null,
  seq       bigint not null check (seq >= 1),
  action    text   not null check (action in ('archive', 'trash', 'star', 'unread')),
  via       text   not null check (via in ('key', 'batch')),
  n         integer not null check (n between 1 and 50),
  folder    text   not null check (folder ~ '^[a-z_]{1,24}$'),
  at        timestamptz not null,
  prev_hash bytea  not null check (octet_length(prev_hash) = 32),
  hash      bytea  not null check (octet_length(hash) = 32),
  primary key (user_id, seq),
  check ((via = 'key' and n = 1) or (via = 'batch' and n >= 2))
);
create index if not exists fmail_keys_events200_at on public.fmail_keys_events200 (user_id, at desc);
alter table public.fmail_keys_events200 enable row level security;
alter table public.fmail_keys_events200 force row level security;
revoke all on public.fmail_keys_events200 from public, anon, authenticated;
grant select on public.fmail_keys_events200 to service_role;
comment on table public.fmail_keys_events200 is 'E200: append-only, hash-chained log of one-letter mail key actions. No mail content, ids or addresses are stored.';

-- 2) append-only guard (insert only through the door, never update/delete/truncate)
create or replace function public.fmail_keys_guard200() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'INSERT' then
    if coalesce(current_setting('fmail.keys_events', true), 'off') <> 'on' then raise exception 'E200: the key log is written by fmail_keys_log200 only' using errcode = '42501'; end if;
    return new;
  end if;
  raise exception 'E200: the key log is append-only' using errcode = '42501';
end $$;
drop trigger if exists fmail_keys_guard200 on public.fmail_keys_events200;
create trigger fmail_keys_guard200 before insert or update or delete on public.fmail_keys_events200 for each row execute function public.fmail_keys_guard200();
drop trigger if exists fmail_keys_trunc200 on public.fmail_keys_events200;
create trigger fmail_keys_trunc200 before truncate on public.fmail_keys_events200 for each statement execute function public.fmail_keys_guard200();

-- 3) the hash (pure)
create or replace function public.fmail_keys_hash200(p_prev bytea, p_uid uuid, p_seq bigint, p_action text, p_via text, p_n integer, p_folder text, p_at timestamptz)
returns bytea language sql immutable set search_path = pg_catalog, public as $$
  select sha256(p_prev || convert_to(format('%s|%s|%s|%s|%s|%s|%s', p_uid, p_seq, p_action, p_via, p_n, p_folder, (extract(epoch from p_at) * 1000000)::bigint), 'UTF8'));
$$;

-- 4) THE write door
create or replace function public.fmail_keys_log200(p_uid uuid, p_action text, p_via text, p_n integer, p_folder text)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare v_prev bytea; v_seq bigint; v_at timestamptz := clock_timestamp(); v_h bytea; v_recent integer;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if p_action is null or p_action not in ('archive', 'trash', 'star', 'unread') then raise exception 'unknown key action' using errcode = '22023'; end if;
  if p_via is null or p_via not in ('key', 'batch') then raise exception 'unknown via' using errcode = '22023'; end if;
  if p_n is null or p_n < 1 or p_n > 50 or (p_via = 'key' and p_n <> 1) or (p_via = 'batch' and p_n < 2) then raise exception 'bad count' using errcode = '22023'; end if;
  if p_folder is null or p_folder !~ '^[a-z_]{1,24}$' then raise exception 'bad folder' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('fmail_keys_events200:' || p_uid::text, 0));
  select count(*) into v_recent from public.fmail_keys_events200 where user_id = p_uid and at > v_at - interval '1 hour';
  if v_recent >= 600 then raise exception 'E200: more than 600 key actions in an hour; the log refuses (the chain stays valid)' using errcode = '54000'; end if;
  select e.seq, e.hash into v_seq, v_prev from public.fmail_keys_events200 e where e.user_id = p_uid order by e.seq desc limit 1;
  if v_seq is null then v_seq := 0; v_prev := sha256(convert_to('genesis200:' || p_uid::text, 'UTF8')); end if;
  v_seq := v_seq + 1;
  v_h := public.fmail_keys_hash200(v_prev, p_uid, v_seq, p_action, p_via, p_n, p_folder, v_at);
  perform set_config('fmail.keys_events', 'on', true);
  insert into public.fmail_keys_events200 (user_id, seq, action, via, n, folder, at, prev_hash, hash) values (p_uid, v_seq, p_action, p_via, p_n, p_folder, v_at, v_prev, v_h);
  perform set_config('fmail.keys_events', 'off', true);
  return jsonb_build_object('seq', v_seq, 'hash', encode(v_h, 'hex'));
end $$;
revoke all on function public.fmail_keys_log200(uuid, text, text, integer, text) from public, anon, authenticated;
grant execute on function public.fmail_keys_log200(uuid, text, text, integer, text) to service_role;

-- 5) verify the whole chain of one founder
create or replace function public.fmail_keys_verify200(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r record; v_prev bytea := sha256(convert_to('genesis200:' || p_uid::text, 'UTF8')); v_n bigint := 0; v_bad bigint;
begin
  for r in select * from public.fmail_keys_events200 where user_id = p_uid order by seq loop
    v_n := v_n + 1;
    if r.seq <> v_n or r.prev_hash <> v_prev or r.hash <> public.fmail_keys_hash200(v_prev, r.user_id, r.seq, r.action, r.via, r.n, r.folder, r.at) then v_bad := r.seq; exit; end if;
    v_prev := r.hash;
  end loop;
  return jsonb_build_object('ok', v_bad is null, 'rows', v_n, 'first_bad', v_bad);
end $$;
revoke all on function public.fmail_keys_verify200(uuid) from public, anon, authenticated;
grant execute on function public.fmail_keys_verify200(uuid) to service_role;

-- 6) list (newest first, keyset paging) and stats (what he can read on a screen)
create or replace function public.fmail_keys_list200(p_uid uuid, p_before bigint default null, p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('seq', x.seq, 'action', x.action, 'via', x.via, 'n', x.n, 'folder', x.folder, 'at_ms', (extract(epoch from x.at) * 1000)::bigint) order by x.seq desc)
    from (select * from public.fmail_keys_events200 e where e.user_id = p_uid and (p_before is null or e.seq < p_before) order by e.seq desc limit v_lim) x), '[]'::jsonb);
end $$;
revoke all on function public.fmail_keys_list200(uuid, bigint, integer) from public, anon, authenticated;
grant execute on function public.fmail_keys_list200(uuid, bigint, integer) to service_role;

create or replace function public.fmail_keys_stats200(p_uid uuid, p_days integer default 7) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_d integer := least(greatest(coalesce(p_days, 7), 1), 90); v_since timestamptz;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  v_since := now() - make_interval(days => v_d);
  return jsonb_build_object('days', v_d,
    'actions', (select count(*) from public.fmail_keys_events200 where user_id = p_uid and at >= v_since),
    'mails_touched', coalesce((select sum(n) from public.fmail_keys_events200 where user_id = p_uid and at >= v_since), 0),
    'batches', (select count(*) from public.fmail_keys_events200 where user_id = p_uid and at >= v_since and via = 'batch'),
    'by_action', coalesce((select jsonb_object_agg(a, c) from (select action as a, count(*) as c from public.fmail_keys_events200 where user_id = p_uid and at >= v_since group by action) q), '{}'::jsonb),
    'busiest_hour_utc', (select extract(hour from at at time zone 'UTC')::int from public.fmail_keys_events200 where user_id = p_uid and at >= v_since group by 1 order by count(*) desc, 1 limit 1));
end $$;
revoke all on function public.fmail_keys_stats200(uuid, integer) from public, anon, authenticated;
grant execute on function public.fmail_keys_stats200(uuid, integer) to service_role;

-- 7) posture
create or replace function public.fmail_keys_posture200() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r jsonb := '{}'::jsonb;
begin
  r := r || jsonb_build_object('rls_forced', (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.fmail_keys_events200'::regclass));
  r := r || jsonb_build_object('no_client_grants', not exists (select 1 from information_schema.role_table_grants where table_name = 'fmail_keys_events200' and grantee in ('anon', 'authenticated', 'PUBLIC')));
  r := r || jsonb_build_object('append_only', (select count(*) from pg_trigger where tgrelid = 'public.fmail_keys_events200'::regclass and tgname in ('fmail_keys_guard200', 'fmail_keys_trunc200') and not tgisinternal) = 2);
  r := r || jsonb_build_object('doors_service_only', has_function_privilege('service_role', 'public.fmail_keys_log200(uuid,text,text,integer,text)', 'execute')
    and not has_function_privilege('anon', 'public.fmail_keys_log200(uuid,text,text,integer,text)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_keys_log200(uuid,text,text,integer,text)', 'execute')
    and not has_function_privilege('authenticated', 'public.fmail_keys_list200(uuid,bigint,integer)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_keys_stats200(uuid,integer)', 'execute'));
  r := r || jsonb_build_object('doors_volatile', (select provolatile = 'v' from pg_proc where oid = 'public.fmail_keys_log200(uuid,text,text,integer,text)'::regprocedure));
  r := r || jsonb_build_object('no_content_columns', not exists (select 1 from information_schema.columns where table_name = 'fmail_keys_events200' and column_name in ('message_id', 'subject', 'address', 'body', 'text')));
  return r;
end $$;
revoke all on function public.fmail_keys_posture200() from public, anon, authenticated;
grant execute on function public.fmail_keys_posture200() to service_role;

-- 8) selftest (rolled back)
create or replace function public.fmail_keys_selftest200() returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '60s' as $$
declare u uuid; n int := 0; p int := 0; v_msg text; j jsonb; i int;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return jsonb_build_object('ok', true, 'skipped', 'no founder account', 'passed', 0, 'total', 0); end if;
  begin
    n := n + 1; j := public.fmail_keys_log200(u, 'star', 'key', 1, 'inbox'); if (j ->> 'seq')::bigint < 1 then raise exception 'first row'; end if; p := p + 1;
    n := n + 1; j := public.fmail_keys_log200(u, 'archive', 'batch', 5, 'inbox'); if (j ->> 'seq')::bigint < 2 then raise exception 'second row'; end if; p := p + 1;
    n := n + 1; if (public.fmail_keys_verify200(u) ->> 'ok')::boolean is not true then raise exception 'chain must verify'; end if; p := p + 1;
    n := n + 1; begin perform public.fmail_keys_log200(u, 'delete', 'key', 1, 'inbox'); raise exception 'unknown action accepted'; exception when sqlstate '22023' then p := p + 1; end;
    n := n + 1; begin perform public.fmail_keys_log200(u, 'star', 'batch', 1, 'inbox'); raise exception 'batch of one accepted'; exception when sqlstate '22023' then p := p + 1; end;
    n := n + 1; begin perform public.fmail_keys_log200(u, 'star', 'key', 2, 'inbox'); raise exception 'key with n=2 accepted'; exception when sqlstate '22023' then p := p + 1; end;
    n := n + 1; begin perform public.fmail_keys_log200(u, 'star', 'batch', 51, 'inbox'); raise exception 'n=51 accepted'; exception when sqlstate '22023' then p := p + 1; end;
    n := n + 1; begin perform public.fmail_keys_log200(u, 'star', 'key', 1, 'In Box;--'); raise exception 'bad folder accepted'; exception when sqlstate '22023' then p := p + 1; end;
    n := n + 1; begin perform public.fmail_keys_log200(gen_random_uuid(), 'star', 'key', 1, 'inbox'); raise exception 'stranger accepted'; exception when sqlstate '42501' then p := p + 1; end;
    n := n + 1; begin update public.fmail_keys_events200 set n = 9 where user_id = u; raise exception 'update allowed'; exception when sqlstate '42501' then p := p + 1; end;
    n := n + 1; begin delete from public.fmail_keys_events200 where user_id = u; raise exception 'delete allowed'; exception when sqlstate '42501' then p := p + 1; end;
    n := n + 1; begin insert into public.fmail_keys_events200 values (u, 99, 'star', 'key', 1, 'inbox', now(), sha256('a'), sha256('b')); raise exception 'direct insert allowed'; exception when sqlstate '42501' then p := p + 1; end;
    n := n + 1; j := public.fmail_keys_stats200(u, 7); if (j ->> 'actions')::int < 2 or (j ->> 'mails_touched')::int < 6 or (j ->> 'batches')::int < 1 then raise exception 'stats wrong %', j; end if; p := p + 1;
    n := n + 1; j := public.fmail_keys_list200(u, null, 10); if jsonb_array_length(j) < 2 or (j -> 0 ->> 'seq')::int < (j -> 1 ->> 'seq')::int then raise exception 'list must be newest first'; end if; p := p + 1;
    n := n + 1; perform set_config('fmail.keys_events', 'on', true);
      alter table public.fmail_keys_events200 disable trigger fmail_keys_guard200;
      update public.fmail_keys_events200 set n = 3 where user_id = u and seq = 2;   -- tamper (guard disabled only inside this rolled-back test)
      alter table public.fmail_keys_events200 enable trigger fmail_keys_guard200;
      if (public.fmail_keys_verify200(u) ->> 'ok')::boolean is not false or (public.fmail_keys_verify200(u) ->> 'first_bad')::int <> 2 then raise exception 'tamper must be found at row 2'; end if; p := p + 1;
    raise exception 'E200_ROLLBACK';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'E200_ROLLBACK' then return jsonb_build_object('ok', false, 'passed', p, 'total', n, 'failed_at', n, 'error', v_msg); end if;
  end;
  if exists (select 1 from public.fmail_keys_events200 where user_id = u and seq >= 99) then return jsonb_build_object('ok', false, 'error', 'selftest left rows behind'); end if;
  return jsonb_build_object('ok', p = n, 'passed', p, 'total', n);
end $$;
revoke all on function public.fmail_keys_selftest200() from public, anon, authenticated;
grant execute on function public.fmail_keys_selftest200() to service_role;
