-- E70 behaviour proof (sandbox ONLY, rollback). Chalao: cd docs/cursor-work/sql/proofs && psql -v ON_ERROR_STOP=1 -f E70_proof.sql
-- Pehle E66 + E68 + E69 + E70 lagti hain (auth/extension stubs ke saath), phir har dewar ka saboot.
begin;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key, email text, banned_until timestamptz, created_at timestamptz not null default now());
create table if not exists auth.sessions (id uuid primary key default gen_random_uuid(), user_id uuid references auth.users (id) on delete cascade);
create schema if not exists extensions;
create extension if not exists pgcrypto schema extensions;
create table if not exists public.account_integrity (user_id uuid primary key, state text not null default 'clean', reason text, evidence jsonb not null default '{}', accounts_on_device int not null default 1, signups_in_window int not null default 0, warned_at timestamptz, warned_by uuid, blocked_at timestamptz, blocked_by uuid, updated_at timestamptz not null default now(), export_until timestamptz);
create table if not exists public.device_ban_appeals (id uuid primary key default gen_random_uuid(), device_hash text not null default 'x', user_id uuid not null, statement text not null default 'x', state text not null default 'new', decided_by uuid);
create table if not exists public.founder_accounts (user_id uuid primary key);
create table if not exists public.polar_subscriptions (id uuid primary key default gen_random_uuid(), polar_customer_id text, user_id uuid, updated_at timestamptz not null default now());
create or replace function public.safety_can_review(_user uuid) returns boolean language sql stable as $f$ select exists (select 1 from public.founder_accounts where user_id = _user) $f$;
\i ../E66_identity_vault.sql
\i ../E68_identity_vault_admin.sql
\i ../E69_identity_mirror_health.sql
\i ../E70_identity_hardening.sql
create temp table r (ord int, item text, ok boolean) on commit drop;
-- Purane (3-guroh) saboot ke liye shim: gpu/font khali. Naye 5-guroh saboot neeche section 10b mein seedha full_raw se.
create function pg_temp.fr(p_email text, p_recovery text, p_device_key text, p_shape text, p_network text, p_hw text, p_gfx text, p_env text, p_key text)
returns jsonb language sql immutable as $f$ select public.identity_signals_full_raw(p_email, p_recovery, p_device_key, p_shape, p_network, p_hw, null, null, p_gfx, p_env, p_key) $f$;
do $$
declare
  k text := 'pepper';
  f uuid := gen_random_uuid(); stranger uuid := gen_random_uuid();
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); d uuid := gen_random_uuid(); ev uuid := gen_random_uuid();
  x uuid; i int;
  hw text := repeat('1', 64); gfx text := repeat('2', 64); env text := repeat('3', 64);
  hw2 text := repeat('4', 64); gfx2 text := repeat('5', 64); env2 text := repeat('6', 64);
  sig_a jsonb; res jsonb; s jsonb; cnt int; ok boolean; raised boolean;
  farm_hw text := repeat('7', 64); farm_gfx text := repeat('8', 64); farm_env text := repeat('9', 64);
  sa text;
begin
  insert into auth.users (id, email) values (f, 'founder@x.com'), (stranger, 's@x.com'), (a, 'a@x.com'), (b, 'b@x.com'), (c, 'c@x.com'), (d, 'd@x.com'), (ev, 'e@x.com');
  insert into public.founder_accounts values (f);
  -- purane saboot 3-guroh siyasat par likhe gaye: 2-of-3 milan, evasion band. Naye defaults (3-of-5, evasion=review) section 10b mein.
  update public.identity_vault_policy set fp_match_min = 2, fp_min_usable = 1, fp_evasion = 'allow' where id = 1;

  -- ===== 1. fingerprint kinds: parity + shape =====
  s := pg_temp.fr('A@x.com', null, 'dk-1', 'shape', '1.1.1.1', hw, gfx, env, k);
  insert into r values (1, 'full_raw: 3 fingerprint + purane nishan, har hmac 64 hex',
    (select count(*) from jsonb_array_elements(s) e where e ->> 'kind' in ('fp_hw', 'fp_gfx', 'fp_env')) = 3
    and not exists (select 1 from jsonb_array_elements(s) e where e ->> 'hmac' !~ '^[0-9a-f]{64}$'));
  insert into r values (2, 'ghalat fingerprint (chhota / hex nahi) chupchap girta hai, baqi nishan rehte hain',
    (select count(*) from jsonb_array_elements(pg_temp.fr('a@x.com', null, 'dk', null, null, 'zz', repeat('G', 64), null, k)) e where e ->> 'kind' like 'fp\_%') = 0
    and jsonb_array_length(pg_temp.fr('a@x.com', null, 'dk', null, null, 'zz', 'abc', null, k)) = 2);
  insert into r values (3, 'fingerprint hmac: kind-label se alag (fp_hw != fp_gfx, same input), pepper se alag',
    public.identity_hmac_hex('fp_hw', hw, k) <> public.identity_hmac_hex('fp_gfx', hw, k) and public.identity_hmac_hex('fp_hw', hw, k) <> public.identity_hmac_hex('fp_hw', hw, 'other'));
  raise notice 'PARITY fp_hw(%,k)=%', repeat('a', 64), public.identity_hmac_hex('fp_hw', repeat('a', 64), 'k');
  raise notice 'PARITY fp_gfx(%,k)=%', repeat('b', 64), public.identity_hmac_hex('fp_gfx', repeat('b', 64), 'k');
  raise notice 'PARITY fp_env(%,k)=%', repeat('c', 64), public.identity_hmac_hex('fp_env', repeat('c', 64), 'k');
  raise notice 'PARITY fp_gpu(%,k)=%', repeat('d', 64), public.identity_hmac_hex('fp_gpu', repeat('d', 64), 'k');
  raise notice 'PARITY fp_font(%,k)=%', repeat('e', 64), public.identity_hmac_hex('fp_font', repeat('e', 64), 'k');

  -- ===== 2. disposable =====
  insert into r values (4, 'disposable: mailinator.com + sub-domain pakde gaye; gmail/outlook nahi',
    public.identity_email_is_disposable('x@mailinator.com') and public.identity_email_is_disposable('y@sub.guerrillamail.com')
    and public.identity_email_is_disposable('yopmail.com') and not public.identity_email_is_disposable('z@gmail.com') and not public.identity_email_is_disposable('z@outlook.com')
    and not public.identity_email_is_disposable(null) and not public.identity_email_is_disposable('no-at-sign.example'));
  res := public.identity_signup_decide(pg_temp.fr('x@mailinator.com', null, null, null, null, null, null, null, k), 'mailinator.com');
  insert into r values (5, 'disposable signup => deny, reason disposable_email, appealable false',
    res ->> 'decision' = 'deny' and res ->> 'reason' = 'disposable_email' and (res ->> 'appealable')::boolean = false);
  res := public.identity_signup_decide(pg_temp.fr('x@mailinator.com', null, null, null, null, null, null, null, k), null);
  insert into r values (6, 'domain na diya (purana caller) => disposable check nahi, allow', res ->> 'decision' = 'allow');
  res := public.identity_disposable_set(f, 'gmail.com', true);
  insert into r values (7, 'founder gmail.com ko disposable nahi bana sakta (protected)', (res ->> 'ok')::boolean = false and res ->> 'error' = 'protected_domain');
  res := public.identity_disposable_set(stranger, 'evil-temp.example', true);
  insert into r values (8, 'founder ke ilawa koi disposable list nahi badal sakta', (res ->> 'allowed')::boolean = false
    and not exists (select 1 from public.identity_disposable_domains where domain = 'evil-temp.example'));
  res := public.identity_disposable_set(f, 'My-Burner.example', true);
  insert into r values (9, 'founder apna domain jodta hai (lowercase), phir pakda jata hai', (res ->> 'ok')::boolean and public.identity_email_is_disposable('q@my-burner.example'));
  res := public.identity_disposable_set(f, 'my-burner.example', false);
  insert into r values (10, 'band karne par chhoot jata hai', (res ->> 'ok')::boolean and not public.identity_email_is_disposable('q@my-burner.example'));
  res := public.identity_disposable_set(f, 'not a domain', true);
  insert into r values (11, 'ghalat domain rad', (res ->> 'ok')::boolean = false and res ->> 'error' = 'bad_domain');
  update public.identity_vault_policy set disposable_block = false where id = 1;
  res := public.identity_signup_decide(pg_temp.fr('x@mailinator.com', null, null, null, null, null, null, null, k), 'mailinator.com');
  insert into r values (12, 'policy mein disposable_block band => allow', res ->> 'decision' = 'allow');
  update public.identity_vault_policy set disposable_block = true where id = 1;

  -- ===== 3. ek account jiska fingerprint + email + network ban ho =====
  sig_a := pg_temp.fr('a@x.com', null, 'dk-a', 'shape-a', '9.9.9.9', hw, gfx, env, k);
  perform public.identity_register(a, sig_a);
  perform public.identity_ban_account(a, 'abuse', false, f);
  select count(*) into cnt from public.identity_bans where source_ref = a and lifted_at is null;
  insert into r values (13, 'ban: 7 nishan (email, device_key, shape, network, 3 fingerprint) blacklist mein', cnt = 7);
  select count(*) into cnt from jsonb_array_elements(public.identity_ban_feed(null, 0, 5000) -> 'rows') e where e ->> 'k' like 'fp\_%' or e ->> 'k' in ('device_shape', 'network');
  insert into r values (14, 'mirror feed mein ab bhi sirf mazboot nishan (fingerprint/kamzor nahi) — parity surat badli nahi', cnt = 0);

  -- fingerprint: do guroh mile (env alag), koi aur nishan nahi => HOLD
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', null, '8.8.8.8', hw, gfx, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (15, 'fingerprint ke 2 guroh mile, akele => HOLD (hold_kind match)', res ->> 'decision' = 'hold' and res ->> 'hold_kind' = 'match' and res ->> 'reason' = 'fingerprint_match');
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', null, '8.8.8.8', hw, gfx2, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (16, 'sirf ek guroh mila => allow (ek jaise phone par bekasoor nahi rukte)', res ->> 'decision' = 'allow');
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', null, '9.9.9.9', hw, gfx, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (17, 'fingerprint (2) + wahi network => DENY', res ->> 'decision' = 'deny' and (res -> 'matched') ? 'fp_hw' and (res -> 'matched') ? 'network');
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', 'shape-a', '8.8.8.8', hw, gfx, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (18, 'fingerprint (2) + wahi device_shape => DENY', res ->> 'decision' = 'deny' and (res -> 'matched') ? 'device_shape');
  s := pg_temp.fr('A@x.com', null, 'dk-new1', null, '8.8.8.8', hw2, gfx2, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (19, 'mazboot nishan (email) => DENY, fingerprint ke baghair bhi', res ->> 'decision' = 'deny' and (res -> 'matched') ? 'email');
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', null, '8.8.8.8', hw, gfx, env, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (20, 'teeno guroh mile, akele => HOLD (deny nahi: ek jaise laptop ka darwaza)', res ->> 'decision' = 'hold');
  update public.identity_vault_policy set fp_match_min = 3 where id = 1;
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', null, '8.8.8.8', hw, gfx, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (21, 'fp_match_min=3: do guroh kaafi nahi => allow', res ->> 'decision' = 'allow');
  update public.identity_vault_policy set fp_match_min = 2 where id = 1;
  update public.identity_vault_policy set signup_gate = 'open' where id = 1;
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', null, '8.8.8.8', hw, gfx, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (22, 'gate open: fingerprint match => sirf review (hold nahi)', res ->> 'decision' = 'review' and res ->> 'reason' = 'fingerprint_match');
  update public.identity_vault_policy set signup_gate = 'hold_matches' where id = 1;
  res := public.identity_signup_decide(sig_a, 'x.com');
  insert into r values (23, 'jawab mein hash ya uuid kahin nahi', not (res::text ~ '[0-9a-f]{32}') and not (res::text ~ '[0-9a-f]{8}-[0-9a-f]{4}-'));
  insert into r values (24, 'purana naam identity_signup_check wahi faisla deta hai', public.identity_signup_check(sig_a) = public.identity_signup_decide(sig_a, null));

  -- ===== 3b. bheed ka nishan: 25+ accounts par ek hi guroh => match nahi ginta =====
  for i in 1..25 loop
    x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'crowd' || i || '@x.com');
    perform public.identity_register(x, pg_temp.fr('crowd' || i || '@x.com', null, null, null, null, hw, null, null, k));
  end loop;
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', null, '8.8.8.8', hw, gfx, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (70, 'bheed: fp_hw 25+ accounts par => guroh match nahi ginta; ab sirf gfx mila => allow (hazaron Tor users hold nahi hote)', res ->> 'decision' = 'allow');
  delete from auth.users where email like 'crowd%@x.com';
  s := pg_temp.fr('new1@x.com', null, 'dk-new1', null, '8.8.8.8', hw, gfx, env2, k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (71, 'bheed khatam => guroh dobara ginta hai => hold', res ->> 'decision' = 'hold');

  -- ===== 4. register => hold =====
  insert into auth.sessions (user_id) values (b), (b);
  res := public.identity_register(b, pg_temp.fr('b@x.com', null, 'dk-b', null, '7.7.7.7', hw, gfx, env2, k));
  insert into r values (25, 'register: decision hold, held=true', res ->> 'decision' = 'hold' and (res ->> 'held')::boolean);
  insert into r values (26, 'hold: state pending + GoTrue banned_until ~100 saal + purane sessions saaf',
    (select state from public.identity_account_state where account_id = b) = 'pending'
    and (select banned_until from auth.users where id = b) > now() + interval '90 years'
    and not exists (select 1 from auth.sessions where user_id = b));
  res := public.identity_register(b, pg_temp.fr('b@x.com', null, 'dk-b', null, '7.7.7.7', hw, gfx, env2, k));
  insert into r values (27, 'register dobara (outbox retry): ek hi state row, held=false, lekin pending=true (route ab bhi 202 dega)',
    (select count(*) from public.identity_account_state where account_id = b) = 1 and not (res ->> 'held')::boolean and (res ->> 'pending')::boolean);
  select count(*) into cnt from public.identity_signals where account_id = b and public.identity_kind_fp(kind) and retain_until is not null and retain_until > now() + interval '170 days';
  insert into r values (28, 'fingerprint nishan finite retention (180 din) par; email retain NULL',
    cnt = 3 and (select retain_until from public.identity_signals where account_id = b and kind = 'email') is null);

  -- ===== 5. founder ka faisla =====
  res := public.identity_hold_decide(stranger, b, 'approve');
  insert into r values (29, 'founder ke ilawa (reviewer nahi) approve nahi kar sakta', (res ->> 'allowed')::boolean = false and (select state from public.identity_account_state where account_id = b) = 'pending');
  res := public.identity_hold_decide(f, b, 'approve', 'verified by call');
  insert into r values (30, 'approve: state approved, banned_until NULL, probation_until ~7 din',
    (res ->> 'ok')::boolean and (select state from public.identity_account_state where account_id = b) = 'approved'
    and (select banned_until from auth.users where id = b) is null
    and (select probation_until from public.identity_account_state where account_id = b) between now() + interval '6 days' and now() + interval '8 days');
  res := public.identity_hold_decide(f, b, 'reject');
  insert into r values (31, 'faisla ek hi baar: dobara => not_pending', (res ->> 'ok')::boolean = false and res ->> 'error' = 'not_pending');
  res := public.identity_register(b, pg_temp.fr('b@x.com', null, 'dk-b', null, '7.7.7.7', hw, gfx, env2, k));
  insert into r values (32, 'manzoor shuda account dobara register (retry) => dobara hold nahi', (select state from public.identity_account_state where account_id = b) = 'approved' and not (res ->> 'held')::boolean
    and (select banned_until from auth.users where id = b) is null and not (res ->> 'pending')::boolean);
  begin
    perform public.identity_hold_decide(f, b, 'maybe');
    raised := false;
  exception when sqlstate '22023' then raised := true; end;
  insert into r values (33, 'ghalat decision => 22023', raised);

  res := public.identity_register(c, pg_temp.fr('c@x.com', 'rc@y.com', 'dk-c', null, '6.6.6.6', hw, gfx, env2, k));
  res := public.identity_hold_decide(f, c, 'reject', 'looks like the blocked person', true);
  select count(*) into cnt from public.identity_bans where source_ref = c and lifted_at is null;
  insert into r values (34, 'reject + ban: state rejected, account band hi, c ke nishan blacklist mein',
    (res ->> 'ok')::boolean and (select state from public.identity_account_state where account_id = c) = 'rejected'
    and (select banned_until from auth.users where id = c) > now() + interval '90 years' and cnt >= 4);
  res := public.identity_register(d, pg_temp.fr('d@x.com', null, 'dk-d', null, '5.5.5.5', hw, gfx, env2, k));
  -- d bhi match (c ke ban ke baad bhi hold), reject bina ban
  res := public.identity_hold_decide(f, d, 'reject', null, false);
  select count(*) into cnt from public.identity_bans where source_ref = d;
  insert into r values (35, 'reject (bina ban): state rejected, d ke koi nishan blacklist nahi', (res ->> 'ok')::boolean and cnt = 0);

  -- ===== 6. gate: approval_all =====
  res := public.identity_gate_set(stranger, 'approval_all');
  insert into r values (36, 'gate sirf founder badalta hai', (res ->> 'allowed')::boolean = false and (select signup_gate from public.identity_vault_policy where id = 1) = 'hold_matches');
  res := public.identity_gate_set(f, 'approval_all');
  insert into r values (37, 'founder gate approval_all karta hai; audit mein from/to', (res ->> 'ok')::boolean and (select signup_gate from public.identity_vault_policy where id = 1) = 'approval_all'
    and exists (select 1 from public.identity_vault_audit where event = 'gate' and detail ->> 'from' = 'hold_matches' and detail ->> 'to' = 'approval_all'));
  begin
    perform public.identity_gate_set(f, 'anything');
    raised := false;
  exception when sqlstate '22023' then raised := true; end;
  insert into r values (38, 'ghalat gate mode => 22023', raised);
  s := pg_temp.fr('clean@x.com', null, 'dk-clean', null, '4.4.4.4', repeat('a', 64), repeat('b', 64), repeat('c', 64), k);
  res := public.identity_signup_decide(s, 'x.com');
  insert into r values (39, 'approval_all: bilkul saaf signup bhi HOLD (hold_kind gate)', res ->> 'decision' = 'hold' and res ->> 'hold_kind' = 'gate' and res ->> 'reason' = 'approval_required');
  res := public.identity_signup_decide(sig_a, 'x.com');
  insert into r values (40, 'approval_all mein bhi ban wale ka DENY hold se upar', res ->> 'decision' = 'deny');
  res := public.identity_register(ev, s);
  insert into r values (41, 'approval_all: register => pending + GoTrue ban', (res ->> 'held')::boolean and (select hold_kind from public.identity_account_state where account_id = ev) = 'gate'
    and (select banned_until from auth.users where id = ev) > now() + interval '90 years');
  perform public.identity_gate_set(f, 'hold_matches');

  -- ===== 7. farm + velocity (review, hold/deny nahi) =====
  update public.identity_vault_policy set fp_match_min = 3 where id = 1;
  for i in 1..4 loop
    x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'farm' || i || '@x.com');
    perform public.identity_register(x, pg_temp.fr('farm' || i || '@x.com', null, 'dk-farm' || i, null, '3.3.' || i || '.1', farm_hw, farm_gfx, farm_env, k));
  end loop;
  res := public.identity_signup_decide(pg_temp.fr('farm5@x.com', null, 'dk-farm5', null, '3.3.9.1', farm_hw, farm_gfx, farm_env, k), 'x.com');
  insert into r values (42, 'ek hi 3-guroh fingerprint 4 accounts par => REVIEW fingerprint_farm', res ->> 'decision' = 'review' and res ->> 'reason' = 'fingerprint_farm');
  res := public.identity_signup_decide(pg_temp.fr('farm5@x.com', null, 'dk-farm5', null, '3.3.9.1', farm_hw, farm_gfx, repeat('d', 64), k), 'x.com');
  insert into r values (43, 'sirf 2 guroh same => farm nahi (3 hi gino)', res ->> 'decision' <> 'review' or res ->> 'reason' <> 'fingerprint_farm');
  update public.identity_vault_policy set fp_match_min = 2 where id = 1;
  for i in 1..8 loop
    x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'vel' || i || '@x.com');
    perform public.identity_register(x, pg_temp.fr('vel' || i || '@x.com', null, 'dk-vel' || i, null, '2.2.2.2', null, null, null, k));
  end loop;
  res := public.identity_signup_decide(pg_temp.fr('vel9@x.com', null, 'dk-vel9', null, '2.2.2.2', null, null, null, k), 'x.com');
  insert into r values (44, 'ek ghante mein 8 accounts ek network se => 9wa REVIEW signup_velocity (deny nahi)', res ->> 'decision' = 'review' and res ->> 'reason' = 'signup_velocity');
  update public.identity_signals set first_seen = now() - interval '3 hours' where kind = 'network';
  res := public.identity_signup_decide(pg_temp.fr('vel9@x.com', null, 'dk-vel9', null, '2.2.2.2', null, null, null, k), 'x.com');
  insert into r values (45, '3 ghante purane signup velocity mein nahi gine jate', res ->> 'decision' = 'allow');

  -- ===== 8. payment =====
  perform public.identity_register_payment(a, 'polar:cus-bad', k);
  perform public.identity_ban_account(a, 'fraud', true, f);
  x := gen_random_uuid(); insert into auth.users (id, email, created_at) values (x, 'newpay@x.com', now() - interval '2 days');
  res := public.identity_register_payment(x, 'polar:cus-bad', k);
  insert into r values (46, 'naye account ka payment ban wale se mila => suspicious + HOLD', (res ->> 'blocked_match')::boolean and (res ->> 'held')::boolean
    and (select state from public.account_integrity where user_id = x) = 'suspicious' and (select state from public.identity_account_state where account_id = x) = 'pending');
  x := gen_random_uuid(); insert into auth.users (id, email, created_at) values (x, 'oldpay@x.com', now() - interval '90 days');
  res := public.identity_register_payment(x, 'polar:cus-bad', k);
  insert into r values (47, 'purane (30+ din) account par sirf suspicious flag, hold nahi (paying customer ko bina faisle band nahi karte)',
    (res ->> 'blocked_match')::boolean and not (res ->> 'held')::boolean and (select state from public.account_integrity where user_id = x) = 'suspicious'
    and not exists (select 1 from public.identity_account_state where account_id = x));
  x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'okpay@x.com');
  res := public.identity_register_payment(x, 'polar:cus-fine', k);
  insert into r values (48, 'saaf payment par kuch nahi', not (res ->> 'blocked_match')::boolean and not exists (select 1 from public.account_integrity where user_id = x));
  res := public.identity_register_payment(a, 'polar:cus-bad', k);
  insert into r values (49, 'ban wale ka apna payment dobara likhna khud ko hold nahi karta', not (res ->> 'blocked_match')::boolean);

  -- ===== 9. hold sweep =====
  update public.identity_account_state set held_at = now() - interval '31 days' where account_id = ev;
  res := public.identity_hold_sweep();
  insert into r values (50, '31 din purana pending => rejected (expired), account band hi, sirf wahi', (res ->> 'expired')::int = 1
    and (select state from public.identity_account_state where account_id = ev) = 'rejected'
    and (select note from public.identity_account_state where account_id = ev) like 'expired%'
    and (select banned_until from auth.users where id = ev) > now() + interval '90 years');
  res := public.identity_vault_purge();
  insert into r values (51, 'purge ab hold sweep bhi chalata hai (holds_expired key maujood)', res ? 'holds_expired');

  -- ===== 10. limits =====
  x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'newbie@x.com');
  res := public.identity_account_limits(x);
  insert into r values (52, 'naya account: probation true + had (20 recipients, invites band)', (res ->> 'probation')::boolean and (res -> 'rules' ->> 'max_recipients_per_message')::int = 20 and (res -> 'rules' ->> 'invites')::boolean = false);
  update auth.users set created_at = now() - interval '30 days' where id = x;
  insert into r values (53, '30 din purana: probation khatam, rules khaali', not (public.identity_account_limits(x) ->> 'probation')::boolean and public.identity_account_limits(x) -> 'rules' is not distinct from null or public.identity_account_limits(x) -> 'rules' = '{}'::jsonb);
  x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'payer@x.com'); insert into public.polar_subscriptions (user_id) values (x);
  insert into r values (54, 'paid (Polar subscription) account probation mein nahi', not (public.identity_account_limits(x) ->> 'probation')::boolean);
  insert into r values (55, 'founder probation mein nahi', not (public.identity_account_limits(f) ->> 'probation')::boolean);
  insert into r values (56, 'anjaan account => probation false (kabhi crash nahi)', not (public.identity_account_limits(gen_random_uuid()) ->> 'probation')::boolean);
  update public.identity_vault_policy set probation_days = 0 where id = 1;
  x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'nolimit@x.com');
  insert into r values (57, 'probation_days=0 => koi had nahi', not (public.identity_account_limits(x) ->> 'probation')::boolean);
  update public.identity_vault_policy set probation_days = 7 where id = 1;


  -- ===== 10b. PANCH-guroh siyasat (naye defaults: 3-of-5 milan, evasion=review) =====
  update public.identity_vault_policy set fp_match_min = 3, fp_min_usable = 3, fp_evasion = 'review', signup_gate = 'hold_matches' where id = 1;
  delete from auth.users where email in ('new1@x.com');
  declare
    m uuid := gen_random_uuid(); e1 uuid := gen_random_uuid(); sm jsonb; s5 jsonb; r5 jsonb;
    mh text := repeat('a1', 32); mg text := repeat('b1', 32); mf text := repeat('c1', 32); mx text := repeat('d1', 32); me text := repeat('e1', 32);
  begin
    insert into auth.users (id, email) values (m, 'machine@x.com'), (e1, 'evader@x.com');
    sm := public.identity_signals_full_raw('machine@x.com', null, 'dk-m', null, '20.0.0.1', mh, mg, mf, mx, me, k);
    insert into r values (100, 'full_raw ab 5 fingerprint guroh deta hai (hw, gpu, font, gfx, env), har hmac alag',
      (select count(distinct e ->> 'hmac') from jsonb_array_elements(sm) e where e ->> 'kind' like 'fp\_%') = 5
      and (select count(*) from jsonb_array_elements(sm) e where e ->> 'kind' in ('fp_gpu', 'fp_font')) = 2);
    perform public.identity_register(m, sm);
    perform public.identity_ban_account(m, 'abuse', false, f);
    insert into r values (101, 'ban: 5 fingerprint guroh bhi blacklist mein (email, device_key, network + 5)', (select count(*) from public.identity_bans where source_ref = m and lifted_at is null and kind like 'fp\_%') = 5);

    -- doosra BROWSER usi mashin par: hw+gpu+font wahi, gfx+env alag => 3-of-5 => HOLD (browser badalna bacha nahi sakta)
    s5 := public.identity_signals_full_raw('evader@x.com', null, 'dk-e', null, '20.0.0.9', mh, mg, mf, repeat('f1', 32), repeat('f2', 32), k);
    res := public.identity_signup_decide(s5, 'x.com');
    insert into r values (102, 'browser badla (Chrome -> Firefox), mashin wahi: hw+gpu+font match => HOLD fingerprint_match', res ->> 'decision' = 'hold' and res ->> 'reason' = 'fingerprint_match');
    s5 := public.identity_signals_full_raw('evader@x.com', null, 'dk-e', null, '20.0.0.1', mh, mg, mf, repeat('f1', 32), repeat('f2', 32), k);
    res := public.identity_signup_decide(s5, 'x.com');
    insert into r values (103, 'wahi + purana network bhi => DENY (do alag nishaniyan)', res ->> 'decision' = 'deny');
    s5 := public.identity_signals_full_raw('evader@x.com', null, 'dk-e', null, '20.0.0.9', mh, mg, repeat('f3', 32), repeat('f1', 32), repeat('f2', 32), k);
    res := public.identity_signup_decide(s5, 'x.com');
    insert into r values (104, 'sirf 2 guroh (hw+gpu) mile => hold nahi (3 chahiye): ek jaise laptop wale bekasoor bachte hain', res ->> 'decision' = 'allow');
    update public.identity_vault_policy set fp_match_min = 2 where id = 1;
    res := public.identity_signup_decide(s5, 'x.com');
    insert into r values (105, 'policy fp_match_min=2 karne par wahi 2-guroh milan HOLD (founder sakhti badha sakta hai)', res ->> 'decision' = 'hold');
    update public.identity_vault_policy set fp_match_min = 3 where id = 1;

    -- chhupane wale
    s5 := public.identity_signals_full_raw('evader@x.com', null, 'dk-e', null, '20.0.0.9', repeat('91', 32), null, null, null, null, k);
    res := public.identity_signup_decide(s5, 'x.com');
    insert into r values (106, 'sirf 1 guroh nikla (noise/blocker) => REVIEW fingerprint_unavailable', res ->> 'decision' = 'review' and res ->> 'reason' = 'fingerprint_unavailable');
    res := public.identity_signup_decide(public.identity_signals_full_raw('evader@x.com', null, 'dk-e', null, '20.0.0.9', null, null, null, null, null, k), 'x.com');
    insert into r values (107, 'fingerprint bheja hi nahi (seedha API bot) => REVIEW fingerprint_unavailable', res ->> 'decision' = 'review' and res ->> 'reason' = 'fingerprint_unavailable');
    update public.identity_vault_policy set fp_evasion = 'hold' where id = 1;
    res := public.identity_signup_decide(s5, 'x.com');
    insert into r values (108, 'fp_evasion=hold => HOLD (hold_kind evasion)', res ->> 'decision' = 'hold' and res ->> 'hold_kind' = 'evasion');
    update public.identity_vault_policy set signup_gate = 'open' where id = 1;
    res := public.identity_signup_decide(s5, 'x.com');
    insert into r values (109, 'gate open ho to evasion=hold bhi sirf review (founder ne hold band kiya hua hai)', res ->> 'decision' = 'review');
    update public.identity_vault_policy set signup_gate = 'hold_matches', fp_evasion = 'allow' where id = 1;
    res := public.identity_signup_decide(s5, 'x.com');
    insert into r values (110, 'fp_evasion=allow => allow', res ->> 'decision' = 'allow');
    update public.identity_vault_policy set fp_evasion = 'review' where id = 1;

    -- poori tarah bheed (Tor/RFP): har bheja hua guroh 25+ accounts par => pehchan nahi => evasion
    for i in 1..25 loop
      x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'tor' || i || '@x.com');
      perform public.identity_register(x, public.identity_signals_full_raw('tor' || i || '@x.com', null, null, null, null, repeat('71', 32), repeat('72', 32), repeat('73', 32), repeat('74', 32), repeat('75', 32), k));
    end loop;
    res := public.identity_signup_decide(public.identity_signals_full_raw('torx@x.com', null, 'dk-tor', null, '21.0.0.1', repeat('71', 32), repeat('72', 32), repeat('73', 32), repeat('74', 32), repeat('75', 32), k), 'x.com');
    insert into r values (111, 'har guroh bheed ka (Tor Browser jaisa) => REVIEW fingerprint_unavailable (hold/deny nahi)', res ->> 'decision' = 'review' and res ->> 'reason' = 'fingerprint_unavailable');
    delete from auth.users where email like 'tor%@x.com';

    -- asli naya insaan: koi galat-pakar nahi
    res := public.identity_signup_decide(public.identity_signals_full_raw('real@x.com', null, 'dk-real', 'shape-r', '22.0.0.1', repeat('81', 32), repeat('82', 32), repeat('83', 32), repeat('84', 32), repeat('85', 32), k), 'x.com');
    insert into r values (112, 'bilkul naya insaan, 5 guroh, koi milan nahi => ALLOW', res ->> 'decision' = 'allow');

    -- farm: 3-of-5 same machine, 4 accounts => review, chahe gfx/env har baar alag hon
    for i in 1..4 loop
      x := gen_random_uuid(); insert into auth.users (id, email) values (x, 'fm' || i || '@x.com');
      perform public.identity_register(x, public.identity_signals_full_raw('fm' || i || '@x.com', null, 'dk-fm' || i, null, '23.0.' || i || '.1', repeat('61', 32), repeat('62', 32), repeat('63', 32), repeat(to_hex(i), 64), repeat(to_hex(i + 8), 64), k));
    end loop;
    res := public.identity_signup_decide(public.identity_signals_full_raw('fm5@x.com', null, 'dk-fm5', null, '23.0.9.1', repeat('61', 32), repeat('62', 32), repeat('63', 32), repeat('a', 64), repeat('b', 64), k), 'x.com');
    insert into r values (113, 'ek mashin (hw+gpu+font) par 4 accounts, gfx/env har baar alag => 5wa REVIEW fingerprint_farm', res ->> 'decision' = 'review' and res ->> 'reason' = 'fingerprint_farm');
    delete from auth.users where email like 'fm%@x.com';

    -- founder ka switch
    sm := public.identity_evasion_set(f, 'hold');
    insert into r values (114, 'evasion_set: founder ne badla, purana mode wapas, policy badli', (sm ->> 'ok')::boolean and sm ->> 'was' = 'review' and (select fp_evasion from public.identity_vault_policy where id = 1) = 'hold');
    sm := public.identity_evasion_set(f, 'review');
    insert into r values (115, 'evasion_set: baghair founder allowed false, policy nahi badli', (public.identity_evasion_set(stranger, 'allow') ->> 'allowed')::boolean = false
      and (select fp_evasion from public.identity_vault_policy where id = 1) = 'review');
    begin perform public.identity_evasion_set(f, 'nonsense'); raised := false; exception when sqlstate '22023' then raised := true; end;
    insert into r values (116, 'evasion_set: ghalat mode saaf error', raised);
    insert into r values (117, 'overview mein evasion + fp_min_usable', public.identity_admin_overview(f) #>> '{gate,evasion}' = 'review' and (public.identity_admin_overview(f) #>> '{gate,fp_min_usable}')::int = 3);
  end;
  -- aage ke purane saboot (overview/hold) ke liye purani nazm
  update public.identity_vault_policy set fp_match_min = 2, fp_min_usable = 1, fp_evasion = 'allow' where id = 1;

  -- ===== 11. overview =====
  res := public.identity_admin_overview(f);
  insert into r values (58, 'overview: gate/holds/disposable maujood; purani keys (bans_active, health, appeals) salamat',
    res #>> '{gate,mode}' = 'hold_matches' and res ? 'holds_pending' and res ? 'holds' and (res ->> 'disposable_domains')::int > 100
    and res ? 'bans_active' and res ? 'health_alert' and res ? 'appeals' and res ? 'signals_total');
  insert into public.identity_account_state (account_id, state, hold_kind, reason) values (d, 'pending', 'manual', 'test') on conflict (account_id) do update set state = 'pending', decided_at = null;
  res := public.identity_admin_overview(f);
  insert into r values (59, 'overview ki hold queue mein email dikhti hai (sirf reviewer ko)', exists (select 1 from jsonb_array_elements(res -> 'holds') h where h ->> 'email' = 'd@x.com'));
  res := public.identity_admin_overview(stranger);
  insert into r values (60, 'reviewer nahi => allowed false aur kuch nahi', (res ->> 'allowed')::boolean = false and not (res ? 'holds'));

  -- ===== 12. privileges, RLS, audit, search_path =====
  insert into r values (61, 'anon/authenticated nayi functions nahi chala sakte; service_role chala sakta hai',
    not has_function_privilege('anon', 'public.identity_signup_decide(jsonb,text)', 'execute')
    and not has_function_privilege('authenticated', 'public.identity_hold_decide(uuid,uuid,text,text,boolean)', 'execute')
    and not has_function_privilege('authenticated', 'public.identity_gate_set(uuid,text)', 'execute')
    and not has_function_privilege('authenticated', 'public.identity_account_limits(uuid)', 'execute')
    and has_function_privilege('service_role', 'public.identity_hold_decide(uuid,uuid,text,text,boolean)', 'execute'));
  insert into r values (62, 'nayi tables RLS ON, anon/authenticated ko koi haq nahi',
    (select count(*) from pg_class where oid in ('public.identity_account_state'::regclass, 'public.identity_disposable_domains'::regclass) and relrowsecurity) = 2
    and not has_table_privilege('anon', 'public.identity_account_state', 'select') and not has_table_privilege('authenticated', 'public.identity_disposable_domains', 'select'));
  insert into r values (63, 'har identity_* function ka search_path pinned',
    not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'identity\_%' and p.proconfig is null));
  insert into r values (64, 'audit mein koi hash ya email nahi (sirf ginti/kind/reason)',
    not exists (select 1 from public.identity_vault_audit where detail::text ~ '[0-9a-f]{40}' or detail::text ~ '@'));
  insert into r values (65, 'audit ke naye events (hold, approve, reject, gate, domain, expire) maujood',
    (select count(distinct event) from public.identity_vault_audit where event in ('hold', 'approve', 'reject', 'gate', 'domain', 'expire')) = 6);
  insert into r values (66, 'identity_account_state: pending <=> decided_at NULL (DB constraint)', exists (select 1 from pg_constraint where conname = 'identity_account_state_decided_ck'));
  begin
    insert into public.identity_account_state (account_id, state) values (gen_random_uuid(), 'pending');
    raised := false;
  exception when foreign_key_violation then raised := true; end;
  insert into r values (67, 'account ke baghair state nahi (FK)', raised);
  delete from auth.users where id = b;
  insert into r values (68, 'account delete => uski state row khud mit gayi', not exists (select 1 from public.identity_account_state where account_id = b));
  insert into r values (69, 'policy ki nayi hadein DB-checked (fp_match_min 1 mana)', (select count(*) from pg_constraint where conrelid = 'public.identity_vault_policy'::regclass and contype = 'c') >= 9);
end $$;
select ord, item, ok from r order by ord;
select case when count(*) filter (where not ok) = 0 then 'ALL ' || count(*) || ' OK' else 'FAILED: ' || count(*) filter (where not ok) end as verdict from r;
rollback;
