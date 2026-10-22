-- E68 behaviour proof (sandbox ONLY, rollback). Chalao: cd docs/cursor-work/sql/proofs && psql -v ON_ERROR_STOP=1 -f E68_proof.sql
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto schema extensions;
-- sandbox stubs (production mein asli tables hain)
create table if not exists public.account_integrity (user_id uuid primary key, state text not null default 'clean', reason text, evidence jsonb not null default '{}', accounts_on_device int not null default 1, signups_in_window int not null default 0, warned_at timestamptz, warned_by uuid, blocked_at timestamptz, blocked_by uuid, updated_at timestamptz not null default now());
create table if not exists public.device_ban_appeals (id uuid primary key default gen_random_uuid(), device_hash text not null default 'x', user_id uuid not null, statement text not null default 'x', state text not null default 'new', decided_by uuid);
create table if not exists public.founder_accounts (user_id uuid primary key);
create or replace function public.safety_can_review(_user uuid) returns boolean language sql stable as $f$ select exists (select 1 from public.founder_accounts where user_id = _user) $f$;
\i ../E68_identity_vault_admin.sql
create temp table r (ord int, item text, ok boolean) on commit drop;
do $$
declare
  f uuid := gen_random_uuid(); a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); d uuid := gen_random_uuid(); stranger uuid := gen_random_uuid();
  k text := 'pepper'; res jsonb; n int; ap uuid; hx text;
begin
  insert into auth.users (id) select u from unnest(array[f, a, b, c, d]) u on conflict do nothing;
  insert into public.founder_accounts values (f);

  insert into r values (1, 'canon email: gmail dots + plus + case',
    public.identity_canon_email(' Ali.Khan+x@GoogleMail.com ') = 'alikhan@gmail.com' and public.identity_canon_email('A+b@Outlook.com') = 'a@outlook.com' and public.identity_canon_email('nope') is null);
  insert into r values (2, 'hmac: 64 hex, kind alag => hash alag, key alag => hash alag, null => null',
    public.identity_hmac_hex('email','a@b.com',k) ~ '^[0-9a-f]{64}$' and public.identity_hmac_hex('email','a@b.com',k) <> public.identity_hmac_hex('recovery','a@b.com',k)
    and public.identity_hmac_hex('email','a@b.com',k) <> public.identity_hmac_hex('email','a@b.com','other') and public.identity_hmac_hex('email',null,k) is null);
  insert into r values (3, 'signals_raw: sirf diye hue, aur signals_ok qubool',
    jsonb_array_length(public.identity_signals_raw('a@b.com', null, 'DK1', null, '1.2.3.4', k)) = 3 and public.identity_signals_ok(public.identity_signals_raw('a@b.com', null, 'DK1', null, '1.2.3.4', k)));

  res := public.identity_register_raw(a, 'ali.khan@gmail.com', 'rec@outlook.com', 'DK-A', 'shape-A', '10.0.0.1', k);
  insert into r values (4, 'register_raw: 5 nishan, allow', (res ->> 'registered')::int = 5 and res ->> 'decision' = 'allow');
  insert into public.account_integrity (user_id, state) values (a, 'clean');

  -- founder ka maujooda Block button (state => blocked) => vault ban
  update public.account_integrity set state = 'blocked', reason = 'repeated spam to many customers', blocked_by = f where user_id = a;
  insert into r values (5, 'Block => 5 nishan ban (3 mazboot + 2 kamzor), reason spam, 2 saal ki expiry',
    (select count(*) from public.identity_bans where source_ref = a and lifted_at is null and reason = 'spam' and expires_at between now() + interval '729 days' and now() + interval '731 days') = 5);
  -- email,recovery,device_key strong => 3 ban; shape/network kamzor => ban table mein bhi? (kind check strong-or-weak allowed)
  insert into r values (6, 'Block ke baad woh account mit bhi jaye to ban baqi', (select count(*) from public.identity_bans where source_ref = a) >= 3);
  delete from auth.users where id = a;
  insert into r values (7, 'account delete ke baad ban maujood', (select count(*) from public.identity_bans where source_ref = a and lifted_at is null) >= 3);

  res := public.identity_signup_check_raw('ali.khan+new@googlemail.com', null, 'DK-NEW', null, null, k);
  insert into r values (8, 'wahi email (gmail dots/plus ke baad) dobara => deny', res ->> 'decision' = 'deny' and (res -> 'matched') ? 'email');
  res := public.identity_signup_check_raw('fresh@x.com', 'rec@outlook.com', null, null, null, k);
  insert into r values (9, 'wahi recovery email => deny', res ->> 'decision' = 'deny');
  res := public.identity_signup_check_raw('fresh@x.com', null, 'DK-A', null, null, k);
  insert into r values (10, 'wahi device key => deny', res ->> 'decision' = 'deny');
  res := public.identity_signup_check_raw('fresh@x.com', 'fresh2@x.com', 'DK-FRESH', 'shape-A', '10.0.0.1', k);
  insert into r values (11, 'sirf kamzor nishan (shape+network) match => deny nahi, allow/review', res ->> 'decision' in ('review', 'allow') and res ->> 'decision' <> 'deny');
  insert into r values (12, 'response mein hash/account nahi', not (res::text ~ '[0-9a-f]{64}'));

  -- logged-out appeal
  res := public.identity_signup_appeal_open('me@y.com', 'short', 'ali.khan@gmail.com', null, null, null, null, k);
  insert into r values (13, 'chhota bayan => statement_required', res ->> 'error' = 'statement_required');
  res := public.identity_signup_appeal_open('me@y.com', 'This was my cousin on my shared laptop, not me at all.', 'fresh@x.com', null, null, null, null, k);
  insert into r values (14, 'jis par ban nahi => nothing_to_appeal', res ->> 'error' = 'nothing_to_appeal');
  res := public.identity_signup_appeal_open('me@y.com', 'This was my cousin on my shared laptop, not me at all.', 'ali.khan@gmail.com', null, null, null, null, k);
  ap := (res ->> 'appeal_id')::uuid;
  insert into r values (15, 'appeal khuli', (res ->> 'ok')::boolean and ap is not null);
  res := public.identity_signup_appeal_open('me@y.com', 'This was my cousin on my shared laptop, not me at all.', 'ali.khan@gmail.com', null, null, null, null, k);
  insert into r values (16, 'dusri appeal usi contact se mana', res ->> 'error' = 'appeal_already_open');
  insert into r values (17, 'admin overview: bahar wale ko allowed=false', (public.identity_admin_overview(stranger) ->> 'allowed') = 'false');
  res := public.identity_admin_overview(f);
  insert into r values (18, 'overview founder ko: 1 appeal khuli, bans active', (res ->> 'appeals_open')::int = 1 and (res ->> 'bans_active')::int >= 3 and not (res::text ~ '[0-9a-f]{64}'));
  res := public.identity_signup_appeal_decide(stranger, ap, 'granted', 'not allowed person here');
  insert into r values (19, 'faisla sirf reviewer', res ->> 'error' = 'not_allowed');
  res := public.identity_signup_appeal_decide(f, ap, 'granted', 'short');
  insert into r values (20, 'faisla bina 12 char wajah mana', res ->> 'error' = 'reason_required');
  res := public.identity_signup_appeal_decide(f, ap, 'granted', 'verified shared laptop with the cousin');
  insert into r values (21, 'granted => ban hat gaye', (res ->> 'ok')::boolean and (res ->> 'lifted')::int >= 3 and (select count(*) from public.identity_bans where source_ref = a and lifted_at is null) = 0);
  res := public.identity_signup_check_raw('ali.khan@gmail.com', null, null, null, null, k);
  insert into r values (22, 'appeal manzoor => ab signup allow', res ->> 'decision' = 'allow');
  res := public.identity_signup_appeal_decide(f, ap, 'denied', 'second decision should fail');
  insert into r values (23, 'dobara faisla mana', res ->> 'error' = 'already_decided');

  -- severe: hamesha, appeal nahi, release se bhi nahi hat-ta
  insert into auth.users (id) values (b) on conflict do nothing;
  perform public.identity_register_raw(b, 'bad@x.com', null, 'DK-B', null, null, k);
  insert into public.account_integrity (user_id, state) values (b, 'clean');
  update public.account_integrity set state = 'blocked', reason = 'severe threat of violence to staff', blocked_by = f where user_id = b;
  insert into r values (24, 'severe => hamesha (expires NULL), appealable=false',
    (select count(*) from public.identity_bans where source_ref = b and expires_at is null and not appealable and reason = 'severe_pattern') >= 2);
  update public.account_integrity set state = 'released', reason = 'released by mistake test' where user_id = b;
  insert into r values (25, 'Release se bhi severe ban nahi hat-ta', (select count(*) from public.identity_bans where source_ref = b and lifted_at is null) >= 2);
  res := public.identity_signup_appeal_open('z@y.com', 'I really am a different person, please check this.', 'bad@x.com', null, null, null, null, k);
  insert into r values (26, 'severe par appeal mana', res ->> 'error' = 'not_appealable');

  -- fraud: hamesha, release se hat sakta? fraud appealable=true par expires NULL
  insert into auth.users (id) values (c) on conflict do nothing;
  perform public.identity_register_raw(c, 'fr@x.com', null, null, null, null, k);
  insert into public.account_integrity (user_id, state) values (c, 'clean');
  update public.account_integrity set state = 'blocked', reason = 'chargeback fraud on three orders', blocked_by = f where user_id = c;
  insert into r values (27, 'fraud => hamesha (expires NULL)', (select count(*) from public.identity_bans where source_ref = c and expires_at is null and reason = 'fraud') >= 1);
  update public.account_integrity set state = 'released', reason = 'founder reviewed and cleared it' where user_id = c;
  insert into r values (28, 'Release (insaan ka faisla) => fraud ban bhi hat gaya', (select count(*) from public.identity_bans where source_ref = c and lifted_at is null) = 0);

  -- device appeal granted => lift
  insert into auth.users (id) values (d) on conflict do nothing;
  perform public.identity_register_raw(d, 'dd@x.com', null, 'DK-D', null, null, k);
  insert into public.account_integrity (user_id, state) values (d, 'clean');
  update public.account_integrity set state = 'blocked', reason = 'abuse towards other users', blocked_by = f where user_id = d;
  insert into public.device_ban_appeals (user_id) values (d) returning id into ap;
  update public.device_ban_appeals set state = 'granted', decided_by = f where id = ap;
  insert into r values (29, 'device appeal granted => vault ban hat gaye', (select count(*) from public.identity_bans where source_ref = d and lifted_at is null) = 0);

  -- review => suspicious flag, signup nahi rukta
  declare u uuid[] := array[gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()]; x int;
  begin
    insert into auth.users (id) select unnest(u);
    for x in 1..3 loop perform public.identity_register_raw(u[x], 'shared' || x || '@x.com', null, 'DK-SHARED', null, null, k); end loop;
    res := public.identity_register_raw(u[4], 'shared9@x.com', null, 'DK-SHARED', null, null, k);
    insert into r values (31, 'shared device (4th account) => review, signup nahi ruka', res ->> 'decision' = 'review' and (res ->> 'registered')::int = 2);
    insert into r values (32, 'review => founder queue mein suspicious flag', (select state from public.account_integrity where user_id = u[4]) = 'suspicious');
  end;
  res := public.identity_register_payment(c, 'card_fp_123', k);
  insert into r values (30, 'payment nishan likha jata hai (retain NULL)',
    (res ->> 'registered')::int = 1 and (select count(*) from public.identity_signals where account_id = c and kind = 'payment' and retain_until is null) = 1);
end $$;
select (select count(*) from r where ok) || '/' || count(*) as passed from r;
select ord, item from r where ok is not true order by ord;
rollback;
