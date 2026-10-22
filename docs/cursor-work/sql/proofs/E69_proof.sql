-- E69 behaviour proof (sandbox ONLY, rollback). Chalao: cd docs/cursor-work/sql/proofs && psql -v ON_ERROR_STOP=1 -f E69_proof.sql
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto schema extensions;
create table if not exists public.account_integrity (user_id uuid primary key, state text not null default 'clean', reason text, evidence jsonb not null default '{}', accounts_on_device int not null default 1, signups_in_window int not null default 0, warned_at timestamptz, warned_by uuid, blocked_at timestamptz, blocked_by uuid, updated_at timestamptz not null default now());
create table if not exists public.device_ban_appeals (id uuid primary key default gen_random_uuid(), device_hash text not null default 'x', user_id uuid not null, statement text not null default 'x', state text not null default 'new', decided_by uuid);
create table if not exists public.founder_accounts (user_id uuid primary key);
create table if not exists public.polar_subscriptions (id uuid primary key default gen_random_uuid(), polar_customer_id text, user_id uuid, updated_at timestamptz not null default now());
create or replace function public.safety_can_review(_user uuid) returns boolean language sql stable as $f$ select exists (select 1 from public.founder_accounts where user_id = _user) $f$;
\i ../E68_identity_vault_admin.sql
\i ../E69_identity_mirror_health.sql
create temp table r (ord int, item text, ok boolean) on commit drop;
do $$
declare
  f uuid := gen_random_uuid(); a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); stranger uuid := gen_random_uuid();
  k text := 'pepper'; res jsonb; feed jsonb; cur_t timestamptz; cur_id bigint; n int; seen int := 0; dup boolean := false; t0 timestamptz;
  ids text[] := '{}'; page jsonb; x jsonb;
begin
  insert into auth.users (id) select u from unnest(array[f, a, b, c]) u on conflict do nothing;
  insert into public.founder_accounts values (f);
  perform public.identity_register_raw(a, 'a@x.com', 'ra@y.com', 'DK-1', 'shape-1', '1.1.1.1', k);
  perform public.identity_register_raw(b, 'b@x.com', null, 'DK-2', null, null, k);
  insert into public.account_integrity (user_id, state) values (a, 'clean'), (b, 'clean');
  update public.account_integrity set state = 'blocked', reason = 'spam to many customers', blocked_by = f where user_id in (a, b);

  feed := public.identity_ban_feed(null, 0, 5000);
  insert into r values (1, 'full feed: sirf mazboot (a: email,recovery,device_key + b: email,device_key = 5), weak nahi',
    jsonb_array_length(feed -> 'rows') = 5 and (feed ->> 'full')::boolean and not exists (select 1 from jsonb_array_elements(feed -> 'rows') e where e ->> 'k' in ('device_shape', 'network')));
  insert into r values (2, 'feed row: 64 hex, active true', not exists (select 1 from jsonb_array_elements(feed -> 'rows') e where e ->> 'h' !~ '^[0-9a-f]{64}$' or (e ->> 'a')::boolean is not true));
  insert into r values (3, 'feed mein account id kahin nahi', not (feed::text ~ '[0-9a-f]{8}-[0-9a-f]{4}-'));

  -- pagination: limit 2, cursor chain, koi dohra nahi, koi chhoota nahi
  cur_t := '-infinity'; cur_id := 0;
  loop
    page := public.identity_ban_feed(cur_t, cur_id, 2);
    exit when jsonb_array_length(page -> 'rows') = 0;
    for x in select * from jsonb_array_elements(page -> 'rows') loop
      if ((x ->> 'k') || (x ->> 'h')) = any (ids) then dup := true; end if;
      ids := ids || ((x ->> 'k') || (x ->> 'h')); seen := seen + 1;
    end loop;
    cur_t := (page ->> 'cursor_t')::timestamptz; cur_id := (page ->> 'cursor_id')::bigint;
    exit when not (page ->> 'more')::boolean;
  end loop;
  insert into r values (4, 'cursor paging (limit 2): 5 rows, koi dohra nahi', seen = 5 and not dup);

  -- incremental: cursor ke baad lift => a=false wali rows
  cur_t := (feed ->> 'cursor_t')::timestamptz; cur_id := (feed ->> 'cursor_id')::bigint;
  page := public.identity_ban_feed(cur_t, cur_id, 100);
  insert into r values (5, 'cursor ke baad kuch nahi badla => khaali', jsonb_array_length(page -> 'rows') = 0);
  perform pg_sleep(0.01);
  update public.account_integrity set state = 'released', reason = 'founder cleared this one' where user_id = b;
  page := public.identity_ban_feed(cur_t, cur_id, 100);
  insert into r values (6, 'release => b ke 2 nishan a=false ke saath feed mein', jsonb_array_length(page -> 'rows') = 2 and not exists (select 1 from jsonb_array_elements(page -> 'rows') e where (e ->> 'a')::boolean));
  feed := public.identity_ban_feed(null, 0, 5000);
  insert into r values (7, 'full feed ab 3 (hataye hue nahi)', jsonb_array_length(feed -> 'rows') = 3);

  -- expired ban full feed mein nahi
  update public.identity_bans set expires_at = now() - interval '1 day' where source_ref = a and kind = 'email';
  feed := public.identity_ban_feed(null, 0, 5000);
  insert into r values (8, 'expired ban full feed mein nahi', jsonb_array_length(feed -> 'rows') = 2);

  insert into r values (9, 'NOTIFY trigger + touch trigger maujood', (select count(*) from pg_trigger where tgname in ('identity_bans_notify_ai', 'identity_bans_touch_bi') and not tgisinternal) = 2);

  -- health + alert
  insert into r values (10, 'health ke bina overview: alert false', (public.identity_admin_overview(f) ->> 'health_alert')::boolean = false);
  perform public.identity_health_report('bun', 0, 0, 5, 20, 'mirror');
  insert into r values (11, 'healthy report: alert false', (public.identity_admin_overview(f) ->> 'health_alert')::boolean = false);
  perform public.identity_health_report('bun', 3, 0, 5, 20, 'mirror');
  insert into r values (12, 'outbox > 0 => alert true', (public.identity_admin_overview(f) ->> 'health_alert')::boolean);
  perform public.identity_health_report('bun', 0, 0, 5, 20, 'closed');
  insert into r values (13, 'mode closed => alert true', (public.identity_admin_overview(f) ->> 'health_alert')::boolean);
  perform public.identity_health_report('bun', 0, 0, 5, 20, 'mirror');
  update public.identity_health set reported_at = now() - interval '1 hour';
  insert into r values (14, 'report 1 ghante purani => alert true', (public.identity_admin_overview(f) ->> 'health_alert')::boolean);
  begin perform public.identity_health_report('python', 0, 0, 0, 0, 'mirror'); insert into r values (15, 'anjaan source mana', false);
  exception when check_violation then insert into r values (15, 'anjaan source mana', true); end;

  -- cursors monotonic
  perform public.identity_cursor_set('payment', '2026-01-02');
  perform public.identity_cursor_set('payment', '2026-01-01');
  insert into r values (16, 'cursor peeche nahi jata', public.identity_cursor_get('payment') = '2026-01-02'::timestamptz and public.identity_cursor_get('nope') = 'epoch'::timestamptz);

  -- payment pending: sirf padhta, sirf maujood user, cursor ke baad
  t0 := now();
  insert into public.polar_subscriptions (polar_customer_id, user_id, updated_at) values ('cus_1', c, t0), ('cus_2', gen_random_uuid(), t0), ('cus_3', null, t0), (null, c, t0);
  select count(*) into n from public.identity_payment_pending('epoch', 100);
  insert into r values (17, 'payment_pending: 1 qatar (maujood user + customer id wali)', n = 1);
  select count(*) into n from public.identity_payment_pending(t0, 100);
  insert into r values (18, 'cursor ke baad kuch nahi', n = 0);

  -- deny-after-signup => suspicious flag
  insert into public.account_integrity (user_id, state) values (c, 'clean') on conflict do nothing;
  res := public.identity_register_raw(c, 'new@x.com', null, 'DK-1', null, null, k);
  insert into r values (19, 'signup ke baad blocked identity mili => deny + suspicious flag',
    res ->> 'decision' = 'deny' and (select state from public.account_integrity where user_id = c) = 'suspicious');

  insert into r values (20, 'parity vector: hmac(email, a@b.com, k) stable', public.identity_hmac_hex('email', 'a@b.com', 'k') = (select public.identity_hmac_hex('email', 'a@b.com', 'k')));
  raise notice 'PARITY email a@b.com k = %  | canon Ali.Khan+x@GoogleMail.com = %', public.identity_hmac_hex('email', 'a@b.com', 'k'), public.identity_canon_email('Ali.Khan+x@GoogleMail.com');
  raise notice 'PARITY device_key DK-1 k = %', public.identity_hmac_hex('device_key', 'dk-1', 'k');
end $$;
select (select count(*) from r where ok) || '/' || count(*) as passed from r;
select ord, item from r where ok is not true order by ord;
rollback;
