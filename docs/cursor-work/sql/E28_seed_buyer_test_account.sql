
-- E28 — asli BUYER test account (sirf payment skip) — blueprint #20, 14 Oct 2026
--
-- Maqsad: signup -> claim -> organisation+domain -> plan, bilkul asli business
-- buyer ki tarah; farq sirf yeh ke Polar payment ki jagah ek entitlement_state
-- row aati hai (E23 trigger usi se account ko active karta hai jaise asli
-- payment se). Kuch bhi nakli "success" nahi: har row wohi hai jo asli code banata.
--
-- Asli code ke rastay jo yahan SQL mein dohraye gaye:
--   server/routes/auth.ts  /signup           -> auth user, account_profiles, user_roles,
--                                               ensure_trial_account_row (pending_plan)
--   server/routes/auth.ts  /identity/claim   -> trial_claim_address (business: sirf claim,
--                                               trial_provision_workspace NAHI -- woh personal hai)
--   server/routes/workspace.ts POST /organisations -> createOperationalOrg + stampWorkspaceKind
--                                               + /onboarding/complete (onboarded=true)
--   E23 trigger entitlement_activates_account_trg -> activate_paid_account -> trial_subscribe
--
-- Chalane ka tareeqa: `docs/cursor-work/server/t7-send-identity-test.sh` (server par ek block).
-- Woh script password khud banati hai (openssl, 12 char) aur /root/test-accounts/<handle>.pw
-- (chmod 600, server par) mein rakhti hai; account pehle se ho to sirf naya password set karti hai.
-- Is file ko seedha chalana ho to: psql -v ON_ERROR_STOP=1 -v handle=.. -v nm=.. -v org=.. -v domain=.. -v plan=.. -v pw=.. -f -
--
-- Tarteeb (#20): Business Basic -> Pro -> Business -> Business Pro. Har plan ke liye
-- naya handle/domain/plan; ek dafa chalta hai (handle ya domain pehle se ho to
-- poora transaction rollback, kuch nahi badalta).
\set ON_ERROR_STOP on
set search_path = public, extensions;
begin;

select gen_random_uuid() as uid, gen_random_uuid() as oid,
       lower(:'handle') || '@anexomail.com' as em \gset
select left(trim(both '-' from regexp_replace(lower(:'org'), '[^a-z0-9]+', '-', 'g')), 40)
       || '-' || left(:'uid', 8) as slug \gset

\o /dev/null
-- 1) login (GoTrue) -- email = @anexomail.com address, jaisa asli signup mein hota hai
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token)
values ('00000000-0000-0000-0000-000000000000', :'uid', 'authenticated', 'authenticated', :'em',
  crypt(:'pw', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('name', :'nm', 'display_name', :'nm'), now(), now(),
  '', '', '', '', '', '', '', '');
insert into auth.identities (id, user_id, provider_id, provider, identity_data,
  last_sign_in_at, created_at, updated_at)
values (gen_random_uuid(), :'uid', :'uid', 'email',
  jsonb_build_object('sub', :'uid', 'email', :'em', 'email_verified', true, 'phone_verified', false),
  now(), now(), now());

-- 2) profile + role + plumbing row (status pending_plan) -- /signup jaisa
insert into public.account_profiles (user_id, email, legal_name, display_name, preferences, onboarded)
values (:'uid', :'em', :'nm', :'nm', '{"workspace_kind":"business"}', true)
on conflict (user_id) do update
  set preferences = coalesce(account_profiles.preferences, '{}'::jsonb) || '{"workspace_kind":"business"}',
      onboarded = true, updated_at = now();
insert into public.user_roles (user_id, role) values (:'uid', 'user') on conflict do nothing;
select public.ensure_trial_account_row(:'uid', :'em', 'email');
\o

-- 3) address claim -- handle liya/reserved/invalid ho to kuch nahi badalta
select (public.trial_claim_address(:'uid', :'handle') ->> 'ok') = 'true' as claimed \gset
\if :claimed
\else
  \echo 'HANDLE NAHI MILA (taken / reserved / invalid) -- kuch nahi badla'
  rollback;
  \quit
\endif

\o /dev/null
-- 4) organisation + domain (createOperationalOrg ka SQL roop)
insert into public.organisations (id, name, slug, domain, owner_id)
values (:'oid', :'org', :'slug', lower(:'domain'), :'uid');
insert into public.org_members (org_id, user_id, role, status, email)
values (:'oid', :'uid', 'owner', 'active', :'em');
insert into public.account_organisations (id, name, slug, domain, created_by)
values (:'oid', :'org', :'slug', lower(:'domain'), :'uid');
insert into public.account_org_members (org_id, user_id, role) values (:'oid', :'uid', 'owner');
select to_regclass('public.orgs') is not null as has_orgs \gset
\if :has_orgs
insert into public.orgs (id, name) values (:'oid', :'org') on conflict (id) do nothing;
\endif
insert into public.mail_accounts (org_id, address) values (:'oid', :'em');
\o

-- 5) payment ki jagah entitlement (E23 trigger account ko active karta hai)
insert into public.entitlement_state (user_id, plan, seats, support_active, active_until)
values (:'uid', :'plan', 1, false, now() + interval '31 days');

commit;

-- Natija: status active + plan wohi + organisation/domain
select u.email, t.status, t.plan, e.plan as entitlement, e.active_until::date as until,
       o.slug as org_slug, o.domain
  from auth.users u
  join public.trial_accounts t on t.user_id = u.id
  left join public.entitlement_state e on e.user_id = u.id
  left join public.organisations o on o.id = :'oid'
 where u.id = :'uid';
