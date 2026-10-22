
-- TOOL: naya founder TEST account banao — Supabase SQL EDITOR mein seedha chalta hai (psql ke \set/\if/\o NAHI). 23 Oct 2026.
-- Yeh E-series migration NAHI hai (sql-run.sh isay khud nahi chalata). E76 pehle chal chuki ho.
-- Kaise: sirf neeche wali LAST select ki 6 values badlo (handle, naam, org, domain, plan, seats) aur Run. Password khud banta hai, result mein EK dafa dikhta hai.
-- Kya karta hai (asli signup/E28 ke wohi steps, kuch nakli nahi): auth user + identity, profile + role + trial row, PEHLE test registry (E76 wall),
--   phir address claim, organisation + member + mailbox, entitlement (payment ki jagah) — sab ek atomic call mein; kisi step par error to POORA rollback.
-- Mix-wall: handle/email pehle se kisi (founder/family/test/asli) ka ho to RUKTA hai. Asli buyer ke rastay ko kabhi nahi chhooti. Account pehle se ho to E36 (bizpro-login-fix.sh) se theek karo.
set search_path = public, extensions;

create or replace function pg_temp.ax_make_test_account(
  _handle text, _name text, _org text, _domain text, _plan text, _seats int default 5)
returns table(step text, result text)
language plpgsql
set search_path = public, extensions, pg_temp
as $f$
declare
  h    text := lower(btrim(_handle));
  em   text := lower(btrim(_handle)) || '@anexomail.com';
  uid  uuid := gen_random_uuid();
  oid_ uuid := gen_random_uuid();
  slug text;
  pw   text := translate(encode(gen_random_bytes(18), 'base64'), '+/=', 'AB9');
  r    jsonb;
begin
  pw := left(pw, 16);
  if h = 'edit.me' then raise exception 'Pehle aakhri select ki 6 values badlo (handle abhi edit.me hai) — kuch nahi bana'; end if;
  if h !~ '^[a-z0-9]([a-z0-9.-]{1,28})[a-z0-9]$' then raise exception 'handle ghalat: % (a-z 0-9 . -, 3..30)', _handle; end if;
  if btrim(coalesce(_name, '')) = '' or btrim(coalesce(_org, '')) = '' or btrim(coalesce(_domain, '')) = '' then raise exception 'naam/org/domain khali'; end if;
  if _plan !~ '^[a-z_]{3,24}$' then raise exception 'plan ghalat: %', _plan; end if;
  if _seats not between 1 and 50 then raise exception 'seats 1..50'; end if;
  if to_regprocedure('public.register_test_account(text,text)') is null then raise exception 'E76 pehle chalayen (register_test_account nahi mila)'; end if;
  if exists (select 1 from auth.users where lower(email) = em) then raise exception '% pehle se hai — theek karne ke liye E36 (bizpro-login-fix.sh)', em; end if;
  if public.account_class(em) <> 'real' then raise exception '% pehle se % account hai', em, public.account_class(em); end if;
  if exists (select 1 from public.organisations where domain = lower(_domain)) then raise exception 'domain % pehle se kisi org ka hai', _domain; end if;
  slug := left(trim(both '-' from regexp_replace(lower(_org), '[^a-z0-9]+', '-', 'g')), 40) || '-' || left(uid::text, 8);

  -- 1) login (GoTrue): email = @anexomail.com pata
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token)
  values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', em,
    crypt(pw, gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}',
    jsonb_build_object('name', _name, 'display_name', _name), now(), now(), '', '', '', '', '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), uid, uid::text, 'email',
    jsonb_build_object('sub', uid, 'email', em, 'email_verified', true, 'phone_verified', false), now(), now(), now());
  step := '1 login'; result := em || ' bana'; return next;

  -- 2) profile + role + trial row (asli /signup jaisa)
  insert into public.account_profiles (user_id, email, legal_name, display_name, preferences, onboarded)
  values (uid, em, _name, _name, '{"workspace_kind":"business"}', true)
  on conflict (user_id) do update set onboarded = true, updated_at = now();
  insert into public.user_roles (user_id, role) values (uid, 'user') on conflict do nothing;
  perform public.ensure_trial_account_row(uid, em, 'email');
  step := '2 profile'; result := 'profile + role + trial row'; return next;

  -- 3) PEHLE registry (E76 wall), PHIR address claim
  r := public.register_test_account(em, 'create_test_account tool');
  if (r ->> 'ok') <> 'true' then raise exception 'registry: %', r; end if;
  r := public.trial_claim_address(uid, h);
  if (r ->> 'ok') <> 'true' then raise exception 'claim fail: % (taken/reserved)', r ->> 'error'; end if;
  step := '3 registry+claim'; result := 'test registry mein + address mila'; return next;

  -- 4) organisation + domain + member + mailbox (createOperationalOrg ka SQL roop)
  insert into public.organisations (id, name, slug, domain, owner_id) values (oid_, _org, slug, lower(_domain), uid);
  insert into public.org_members (org_id, user_id, role, status, email) values (oid_, uid, 'owner', 'active', em);
  insert into public.account_organisations (id, name, slug, domain, created_by) values (oid_, _org, slug, lower(_domain), uid);
  insert into public.account_org_members (org_id, user_id, role) values (oid_, uid, 'owner');
  if to_regclass('public.orgs') is not null then
    insert into public.orgs (id, name) values (oid_, _org) on conflict (id) do nothing;
  end if;
  insert into public.mail_accounts (org_id, address) values (oid_, em);
  step := '4 org'; result := slug || ' / ' || lower(_domain); return next;

  -- 5) payment ki jagah entitlement (E23 trigger account ko active karta hai)
  insert into public.entitlement_state (user_id, plan, seats, support_active, active_until)
  values (uid, _plan, _seats, false, now() + interval '31 days');
  step := '5 plan'; result := _plan || ', seats ' || _seats; return next;

  step := 'LOGIN'; result := em || '   password: ' || pw || '   (sirf ab dikhta hai — kahin save karo)'; return next;
  step := 'RESULT'; result := 'OK — ' || public.account_class(em) || ' account'; return next;
end $f$;

-- >>> SIRF YEH 6 VALUES BADLO <<<   (handle, naam, org, domain, plan, seats)
select * from pg_temp.ax_make_test_account('edit.me', 'Test Name', 'Test Org', 'testorg.example.com', 'pro', 5);
