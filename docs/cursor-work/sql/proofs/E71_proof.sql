-- E71 behaviour proof (sandbox ONLY, rollback). Chalao: cd docs/cursor-work/sql/proofs && psql -v ON_ERROR_STOP=1 -f E70_proof.sql
-- Pehle E66 + E68 + E69 + E70 + E71 lagti hain (auth/extension stubs ke saath), phir har dewar ka saboot.
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
create table if not exists auth.refresh_tokens (id bigserial primary key, user_id text, token text);
create table if not exists public.account_recovery (user_id uuid primary key, kind text, email text, hint text, updated_at timestamptz default now());
create table if not exists public.account_profiles (user_id uuid primary key, display_name text);
\i ../E71_identity_probation_notice.sql
create temp table r (ord int, item text, ok boolean) on commit drop;
do $$
declare
  f uuid := gen_random_uuid(); n uuid := gen_random_uuid(); old uuid := gen_random_uuid(); paid uuid := gen_random_uuid();
  h uuid := gen_random_uuid(); h2 uuid := gen_random_uuid(); h3 uuid := gen_random_uuid(); h4 uuid := gen_random_uuid();
  res jsonb; i int; raised boolean; cnt int; tgt text;
begin
  insert into auth.users (id, email, created_at) values (f, 'f@x.com', now()), (n, 'n@x.com', now()), (old, 'old@x.com', now() - interval '60 days'), (paid, 'p@x.com', now()),
    (h, 'h@x.com', now()), (h2, 'h2@x.com', now()), (h3, 'h3@x.com', now()), (h4, 'h4@x.com', now());
  insert into public.founder_accounts values (f);
  insert into public.polar_subscriptions (user_id) values (paid);

  -- ===== 1. send: recipients =====
  res := public.identity_probation_take(n, 'send', 21);
  insert into r values (1, '21 recipients => deny probation_recipients (limit 20), counter badha nahi',
    (res ->> 'ok')::boolean = false and res ->> 'reason' = 'probation_recipients' and (res ->> 'limit')::int = 20
    and (select coalesce(sum(sends), 0) from public.identity_probation_usage where account_id = n) = 0);
  res := public.identity_probation_take(n, 'send', 20);
  insert into r values (2, '20 recipients => ok, probation true, used 1', (res ->> 'ok')::boolean and (res ->> 'probation')::boolean and (res ->> 'used')::int = 1);

  -- ===== 2. send: din ki had (50) =====
  for i in 2..50 loop res := public.identity_probation_take(n, 'send', 1); end loop;
  insert into r values (3, '50 messages tak ok, 50wan used=50', (res ->> 'ok')::boolean and (res ->> 'used')::int = 50);
  res := public.identity_probation_take(n, 'send', 1);
  insert into r values (4, '51wan message => deny probation_daily, counter 50 par ruka', (res ->> 'ok')::boolean = false and res ->> 'reason' = 'probation_daily'
    and (select sends from public.identity_probation_usage where account_id = n and day = (now() at time zone 'utc')::date) = 50);
  insert into r values (5, 'denied ginti bhi chadhti hai (founder ko dikhane layak)', (select denied from public.identity_probation_usage where account_id = n and day = (now() at time zone 'utc')::date) >= 2);

  -- ===== 3. invites / links / bulk =====
  insert into r values (6, 'invite band probation mein', public.identity_probation_take(n, 'invite') ->> 'reason' = 'probation_invites' and not (public.identity_probation_take(n, 'invite') ->> 'ok')::boolean);
  insert into r values (7, 'public link band probation mein', public.identity_probation_take(n, 'public_link') ->> 'reason' = 'probation_links');
  insert into r values (8, 'bulk band probation mein', public.identity_probation_take(n, 'bulk') ->> 'reason' = 'probation_bulk');
  begin perform public.identity_probation_take(n, 'nonsense'); raised := false; exception when sqlstate '22023' then raised := true; end;
  insert into r values (9, 'ghalat kind => saaf error (chup-chaap ok nahi)', raised);

  -- ===== 4. jo probation mein nahi =====
  insert into r values (10, 'purana account (60 din) => ok, probation false, counter nahi', (public.identity_probation_take(old, 'invite') ->> 'ok')::boolean
    and not (public.identity_probation_take(old, 'send', 500) ->> 'probation')::boolean and not exists (select 1 from public.identity_probation_usage where account_id = old));
  insert into r values (11, 'Polar paid => ok (invite, 500 recipients)', (public.identity_probation_take(paid, 'invite') ->> 'ok')::boolean and (public.identity_probation_take(paid, 'send', 500) ->> 'ok')::boolean);
  insert into r values (12, 'founder => ok', (public.identity_probation_take(f, 'bulk') ->> 'ok')::boolean);
  insert into r values (13, 'anjaan account / NULL => ok (crash nahi)', (public.identity_probation_take(gen_random_uuid(), 'send', 3) ->> 'ok')::boolean and (public.identity_probation_take(null, 'send', 3) ->> 'ok')::boolean);
  update public.identity_vault_policy set probation_days = 0 where id = 1;
  insert into r values (14, 'probation_days = 0 => koi rok nahi', (public.identity_probation_take(n, 'invite') ->> 'ok')::boolean);
  update public.identity_vault_policy set probation_days = 7 where id = 1;

  -- ===== 5. sweep =====
  insert into public.identity_probation_usage (account_id, day, sends) values (old, (now() at time zone 'utc')::date - 41, 3), (old, (now() at time zone 'utc')::date - 5, 3);
  cnt := public.identity_probation_sweep(); raise notice 'sweep=%', cnt;
  insert into r values (15, 'sweep sirf 40 din se purani ginti mitata hai', cnt = 1 and exists (select 1 from public.identity_probation_usage where account_id = old and day = (now() at time zone 'utc')::date - 5));

  -- ===== 6. session backstop =====
  insert into r values (16, 'trigger dono tables par laga', (public.identity_session_guard_status() ->> 'sessions')::boolean and (public.identity_session_guard_status() ->> 'refresh_tokens')::boolean);
  insert into auth.sessions (user_id) values (n);
  insert into r values (17, 'koi state nahi => session banta hai', exists (select 1 from auth.sessions where user_id = n));
  insert into public.identity_account_state (account_id, state, hold_kind, reason) values (h, 'pending', 'manual', 'test');
  begin insert into auth.sessions (user_id) values (h); raised := false; exception when insufficient_privilege then raised := true; end;
  insert into r values (18, 'pending (hold) => auth.sessions mein row BANTI HI NAHI (42501)', raised and not exists (select 1 from auth.sessions where user_id = h));
  begin insert into auth.refresh_tokens (user_id, token) values (h::text, 't'); raised := false; exception when insufficient_privilege then raised := true; end;
  insert into r values (19, 'pending => refresh token bhi nahi banta', raised and not exists (select 1 from auth.refresh_tokens where user_id = h::text));
  insert into public.identity_account_state (account_id, state, hold_kind, reason, decided_at) values (h2, 'rejected', 'manual', 'test', now());
  begin insert into auth.sessions (user_id) values (h2); raised := false; exception when insufficient_privilege then raised := true; end;
  insert into r values (20, 'rejected => session nahi', raised);
  perform public.identity_hold_decide(f, h, 'approve', 'ok');
  insert into auth.sessions (user_id) values (h);
  insert into auth.refresh_tokens (user_id, token) values (h::text, 't2');
  insert into r values (21, 'approve ke baad session aur refresh dono ban jate hain', exists (select 1 from auth.sessions where user_id = h) and exists (select 1 from auth.refresh_tokens where user_id = h::text));
  begin insert into auth.refresh_tokens (user_id, token) values ('not-a-uuid', 'x'); raised := false; exception when others then raised := true; end;
  insert into r values (22, 'kharab user_id wali refresh row trigger se crash nahi hoti (guzar jati hai)', not raised);

  -- ===== 7. notice =====
  insert into public.account_recovery (user_id, kind, email) values (h, 'email', 'person@gmail.com');
  insert into public.account_profiles (user_id, display_name) values (h, 'Hana');
  select to_email into tgt from public.identity_notice_pending(10) where account_id = h;
  insert into r values (23, 'approved + recovery email => notice pending, target wahi email', tgt = 'person@gmail.com');
  insert into r values (24, 'attempt ginti badhi, 5 min tak dobara pending nahi', (select notify_attempts from public.identity_account_state where account_id = h) = 1
    and not exists (select 1 from public.identity_notice_pending(10) where account_id = h));
  perform public.identity_notice_done(h, true);
  insert into r values (25, 'done(true) => sent, aage kabhi pending nahi', (select notify_state from public.identity_account_state where account_id = h) = 'sent'
    and not exists (select 1 from public.identity_notice_pending(10) where account_id = h));
  -- recovery email ke baghair approved => no_target (bhejne ki jagah nahi), loop mein atke nahi
  insert into public.identity_account_state (account_id, state, hold_kind, reason) values (h3, 'pending', 'manual', 'test');
  perform public.identity_hold_decide(f, h3, 'approve', null);
  perform * from public.identity_notice_pending(10);
  insert into r values (26, 'recovery email nahi => no_target, dobara koshish nahi', (select notify_state from public.identity_account_state where account_id = h3) = 'no_target');
  -- reject par notice kabhi nahi
  insert into public.account_recovery (user_id, kind, email) values (h4, 'email', 'bad@gmail.com');
  insert into public.identity_account_state (account_id, state, hold_kind, reason) values (h4, 'pending', 'manual', 'test');
  perform public.identity_hold_decide(f, h4, 'reject', null, false);
  insert into r values (27, 'reject => notice pending mein nahi aata', not exists (select 1 from public.identity_notice_pending(10) where account_id = h4));
  -- bhejna baar baar fail => 6 koshishon ke baad gave_up
  insert into public.account_recovery (user_id, kind, email) values (h3, 'email', 'x@gmail.com') on conflict (user_id) do nothing;
  update public.identity_account_state set notify_state = null, notified_at = null, notify_attempts = 0, notify_last_at = null where account_id = h3;
  for i in 1..6 loop
    update public.identity_account_state set notify_last_at = now() - interval '10 minutes' where account_id = h3;
    perform * from public.identity_notice_pending(10);
    perform public.identity_notice_done(h3, false);
  end loop;
  insert into r values (28, '6 nakam koshishon ke baad gave_up, phir pending nahi', (select notify_state from public.identity_account_state where account_id = h3) = 'gave_up'
    and not exists (select 1 from public.identity_notice_pending(10) where account_id = h3));
  insert into public.account_recovery (user_id, kind, email) values (h2, 'email', 'not an email');
  update public.identity_account_state set state = 'approved', notify_state = null where account_id = h2;
  perform * from public.identity_notice_pending(10);
  insert into r values (29, 'ghalat email shape => no_target (sendmail ko kabhi nahi diya jata)', (select notify_state from public.identity_account_state where account_id = h2) = 'no_target');

  -- ===== 8. haq / RLS / search_path =====
  insert into r values (30, 'anon/authenticated nayi functions nahi chala sakte; service_role chala sakta hai',
    not has_function_privilege('anon', 'public.identity_probation_take(uuid,text,int)', 'execute')
    and not has_function_privilege('authenticated', 'public.identity_probation_take(uuid,text,int)', 'execute')
    and not has_function_privilege('authenticated', 'public.identity_notice_pending(int)', 'execute')
    and not has_function_privilege('authenticated', 'public.identity_notice_done(uuid,boolean)', 'execute')
    and not has_function_privilege('authenticated', 'public.identity_session_guard()', 'execute')
    and has_function_privilege('service_role', 'public.identity_probation_take(uuid,text,int)', 'execute'));
  insert into r values (31, 'usage table RLS ON, anon/authenticated ko koi haq nahi', (select relrowsecurity from pg_class where oid = 'public.identity_probation_usage'::regclass)
    and not has_table_privilege('anon', 'public.identity_probation_usage', 'select') and not has_table_privilege('authenticated', 'public.identity_probation_usage', 'insert'));
  insert into r values (32, 'har identity_* function ka search_path pinned', not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'identity\_%' and p.proconfig is null));
  delete from auth.users where id = n;
  insert into r values (33, 'account delete => uski usage ginti khud mit gayi', not exists (select 1 from public.identity_probation_usage where account_id = n));
end $$;
select ord, item, ok from r order by ord;
select case when count(*) filter (where not ok) = 0 then 'ALL ' || count(*) || ' OK' else 'FAILED: ' || count(*) filter (where not ok) end as verdict from r;
rollback;
