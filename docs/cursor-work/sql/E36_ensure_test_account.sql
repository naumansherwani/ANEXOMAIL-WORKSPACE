
-- E36 — test account ko poora theek karo ("ensure"), har layer par, dobara chalane par bhi safe — 19 Oct 2026
--
-- Kyun: `business_pro.test@anexomail.com` se login nahi ho raha tha. E28 sirf NAYA account banata hai (aur `_` wale naam par
-- poora rollback: address-claim ka handle rule `^[a-z0-9][a-z0-9.-]{1,28}[a-z0-9]$` underscore nahi leta). Yeh file "jo bhi haalat ho":
--   account hi nahi  -> asli signup jaisa poora account banata hai (E28 ke wohi steps)
--   account hai par kharab -> jo kharabi ho woh theek karta hai aur batata hai:
--       password alag/khali, email confirm nahi, ban laga, soft-delete, GoTrue ke token columns NULL
--       (GoTrue NULL string scan nahi kar sakta => "Database error querying schema"), identity row nahi,
--       aud/role/instance_id galat, profile/role/trial row nahi, plan galat/trial/expired, organisation ya mailbox nahi,
--       purani workspace_subscriptions row mein galat plan.
-- Password yahan kabhi plain nahi aata: chalane wali script usse `crypt()` se hash kar ke sirf hash deti hai (psql variable `pwhash`).
--
-- Chalane ka tareeqa: `docs/cursor-work/server/bizpro-login-fix.sh` (password silent prompt se; kahin store nahi hota).
-- Seedha: psql -v ON_ERROR_STOP=1 -v handle=.. -v nm=.. -v org=.. -v domain=.. -v plan=.. -v pw=.. -f E36_ensure_test_account.sql
--
-- Test seats: entitlement_state.seats kam se kam 5 rakhi jati hai (E28 ki 1 seat se team invite/seat-limit test nahi ho sakta); Business Pro par seat limit hai hi nahi.
-- Kya NAHI chhedta: family_accounts (sirf dikhata hai agar plan alag ho), polar-rust-payment, kisi aur user ki koi row.
-- Natija: step | result ki list + aakhri "RESULT" row (OK / KUCH ADHURA). Har public step apna alag subtransaction hai: ek table ki
-- galti baqi ko nahi rokti; login wali layer (auth.users) hamesha poori hoti hai.
\set ON_ERROR_STOP on
set search_path = public, extensions;

-- plain password sirf is ek statement mein; aage sirf hash chalta hai
select crypt(:'pw', gen_salt('bf')) as pwhash \gset

begin;

create or replace function pg_temp.ax_ensure_account(
  _handle text, _nm text, _org text, _domain text, _plan text, _hash text)
returns table(step text, result text)
language plpgsql
set search_path = public, extensions, pg_temp
as $f$
declare
  h      text := lower(btrim(_handle));
  em     text := lower(btrim(_handle)) || '@anexomail.com';
  uid    uuid;
  oid_   uuid;
  j      jsonb;
  bad    text[] := '{}';
  sets   text[];
  c      text;
  n      int;
  r      jsonb;
  th     text;
  ts     text;
  tp     text;
  ep     text;
  dom    text;
  slug   text;
  mo     uuid;
  fails  int := 0;
  created boolean := false;
begin
  if _plan not in ('basic','pro','business','business_pro') then
    step := 'RESULT'; result := 'KUCH ADHURA — plan galat: ' || coalesce(_plan,'null'); return next; return;
  end if;
  if h !~ '^[a-z0-9][a-z0-9._-]{1,38}[a-z0-9]$' then
    step := 'RESULT'; result := 'KUCH ADHURA — handle galat: ' || h; return next; return;
  end if;

  -- ───────── 1) login (GoTrue) — yeh layer sab se zaroori ─────────
  select u.id into uid from auth.users u where lower(btrim(u.email)) = em order by u.created_at limit 1;

  if uid is null then
    uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', em, _hash, now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('name', _nm, 'display_name', _nm), now(), now(),
      '', '', '', '', '', '', '', '');
    created := true;
    step := '1 login (auth.users)'; result := 'naya account banaya'; return next;
  else
    select to_jsonb(u) into j from auth.users u where u.id = uid;
    if j->>'email_confirmed_at' is null then bad := array_append(bad, 'email confirm nahi tha'); end if;
    if coalesce(j->>'banned_until','') <> '' and (j->>'banned_until')::timestamptz > now() then bad := array_append(bad, 'ban laga tha'); end if;
    if coalesce(j->>'deleted_at','') <> '' then bad := array_append(bad, 'soft-delete tha'); end if;
    if coalesce(j->>'encrypted_password','') = '' then bad := array_append(bad, 'password tha hi nahi'); end if;
    if coalesce(j->>'aud','') <> 'authenticated' or coalesce(j->>'role','') <> 'authenticated' then bad := array_append(bad, 'aud/role galat'); end if;
    if j->>'instance_id' is null then bad := array_append(bad, 'instance_id khali'); end if;
    if (j->>'email') is distinct from em then bad := array_append(bad, 'email likhawat alag (' || coalesce(j->>'email','?') || ')'); end if;
    foreach c in array array['confirmation_token','recovery_token','email_change_token_new','email_change',
                             'email_change_token_current','phone_change','phone_change_token','reauthentication_token'] loop
      if j ? c and jsonb_typeof(j->c) = 'null' then bad := array_append(bad, (c || ' NULL tha')); end if;
    end loop;
    if coalesce(j->>'is_sso_user','false') = 'true' then bad := array_append(bad, 'is_sso_user true tha'); end if;

    sets := array[
      format('encrypted_password = %L', _hash),
      format('email = %L', em),
      'email_confirmed_at = coalesce(email_confirmed_at, now())',
      '"aud" = ''authenticated''',
      '"role" = ''authenticated''',
      'instance_id = coalesce(instance_id, ''00000000-0000-0000-0000-000000000000''::uuid)',
      'raw_app_meta_data = coalesce(raw_app_meta_data, ''{}''::jsonb) || ''{"provider":"email","providers":["email"]}''::jsonb',
      'updated_at = now()'];
    foreach c in array array['confirmation_token','recovery_token','email_change_token_new','email_change',
                             'email_change_token_current','phone_change','phone_change_token','reauthentication_token'] loop
      if j ? c then sets := array_append(sets, format('%I = coalesce(%I, '''')', c, c)); end if;
    end loop;
    if j ? 'banned_until' then sets := array_append(sets, 'banned_until = null'); end if;
    if j ? 'deleted_at'   then sets := array_append(sets, 'deleted_at = null');   end if;
    if j ? 'is_sso_user'  then sets := array_append(sets, 'is_sso_user = false'); end if;
    execute 'update auth.users set ' || array_to_string(sets, ', ') || ' where id = $1' using uid;
    step := '1 login (auth.users)';
    result := 'account pehle se tha; password dobara set + sab theek kiya' ||
              case when array_length(bad,1) is null then ' (koi aur kharabi nahi mili)'
                   else ' — mili kharabiyan: ' || array_to_string(bad, ', ') end;
    return next;
  end if;

  select count(*) into n from auth.identities i where i.user_id = uid and i.provider = 'email';
  if n = 0 then
    insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid, uid::text, 'email',
      jsonb_build_object('sub', uid::text, 'email', em, 'email_verified', true, 'phone_verified', false),
      now(), now(), now());
    step := '1 login (auth.identities)'; result := 'identity row banayi (nahi thi)'; return next;
  else
    update auth.identities i
       set provider_id = coalesce(nullif(i.provider_id, ''), uid::text),
           identity_data = coalesce(i.identity_data, '{}'::jsonb)
                           || jsonb_build_object('sub', uid::text, 'email', em, 'email_verified', true),
           updated_at = now()
     where i.user_id = uid and i.provider = 'email';
    step := '1 login (auth.identities)'; result := 'identity row theek'; return next;
  end if;

  -- ───────── 2) profile + role + trial row ─────────
  begin
    insert into public.account_profiles (user_id, email, legal_name, display_name, preferences, onboarded)
    values (uid, em, _nm, _nm, '{"workspace_kind":"business"}', true)
    on conflict (user_id) do update
      set preferences = coalesce(account_profiles.preferences, '{}'::jsonb) || '{"workspace_kind":"business"}',
          onboarded = true, updated_at = now();
    insert into public.user_roles (user_id, role) values (uid, 'user') on conflict do nothing;
    perform public.ensure_trial_account_row(uid, em, 'email');
    step := '2 profile/role/trial row'; result := 'theek'; return next;
  exception when others then
    fails := fails + 1; step := '2 profile/role/trial row'; result := 'FAIL: ' || sqlerrm; return next;
  end;

  -- ───────── 3) address (handle) ─────────
  begin
    select t.anexomail_handle, t.status into th, ts from public.trial_accounts t where t.user_id = uid;
    if th is not distinct from h then
      step := '3 address'; result := h || '@anexomail.com pehle se is account ka hai'; return next;
    else
      if to_regprocedure('public.register_test_account(text,text)') is not null then perform public.register_test_account(em, 'E36 ensure'); end if; -- E76: pehle registry
      r := public.trial_claim_address(uid, h);
      if (r->>'ok') = 'true' then
        step := '3 address'; result := h || '@anexomail.com asli claim se mila'; return next;
      elsif r->>'error' = 'invalid_handle' then
        -- awam ka handle rule underscore nahi leta; yeh sirf TEST account hai, isliye seedha likha (login ka uss se koi taluq nahi)
        if exists (select 1 from public.trial_accounts t where lower(t.anexomail_handle) = h and t.user_id <> uid) then
          fails := fails + 1; step := '3 address'; result := 'FAIL: handle kisi aur ke paas hai'; return next;
        else
          update public.trial_accounts t set anexomail_handle = h, anexomail_address = em, updated_at = now() where t.user_id = uid;
          step := '3 address'; result := 'awam ka rule is handle (underscore) ko nahi leta; test account hai, seedha set kiya'; return next;
        end if;
      else
        fails := fails + 1; step := '3 address'; result := 'FAIL: claim = ' || r::text; return next;
      end if;
    end if;
  exception when others then
    fails := fails + 1; step := '3 address'; result := 'FAIL: ' || sqlerrm; return next;
  end;

  -- ───────── 4) organisation + domain + mailbox ─────────
  begin
    select m.org_id into oid_ from public.org_members m
     where m.user_id = uid
     order by (coalesce(m.status::text, 'active') = 'active') desc, m.org_id limit 1;
    if oid_ is null then
      oid_ := gen_random_uuid();
      dom := lower(_domain);
      if exists (select 1 from public.organisations o where lower(o.domain) = dom) then
        dom := left(replace(uid::text, '-', ''), 6) || '-' || dom;   -- domain pehle se kisi aur org ka: naya unique test domain
      end if;
      slug := left(trim(both '-' from regexp_replace(lower(_org), '[^a-z0-9]+', '-', 'g')), 40) || '-' || left(uid::text, 8);
      insert into public.organisations (id, name, slug, domain, owner_id) values (oid_, _org, slug, dom, uid);
      insert into public.org_members (org_id, user_id, role, status, email) values (oid_, uid, 'owner', 'active', em);
      insert into public.account_organisations (id, name, slug, domain, created_by) values (oid_, _org, slug, dom, uid);
      insert into public.account_org_members (org_id, user_id, role) values (oid_, uid, 'owner');
      if to_regclass('public.orgs') is not null then
        execute format('insert into public.orgs (id, name) values (%L, %L) on conflict (id) do nothing', oid_, _org);
      end if;
      step := '4 organisation'; result := 'naya organisation banaya (' || _org || ', domain ' || dom || ')'; return next;
    else
      update public.org_members m set status = 'active'
       where m.org_id = oid_ and m.user_id = uid and coalesce(m.status::text, 'active') <> 'active';
      get diagnostics n = row_count;
      step := '4 organisation';
      result := 'pehle se hai' || case when n > 0 then ' (member status dobara active kiya)' else '' end; return next;
    end if;

    select a.org_id into mo from public.mail_accounts a where lower(a.address) = em limit 1;
    if mo is null then
      insert into public.mail_accounts (org_id, address) values (oid_, em);
      step := '4 mailbox'; result := em || ' banaya'; return next;
    elsif mo <> oid_ then
      fails := fails + 1; step := '4 mailbox'; result := 'FAIL: ' || em || ' kisi aur organisation ka hai (' || mo::text || ') — kuch nahi badla'; return next;
    else
      step := '4 mailbox'; result := em || ' theek'; return next;
    end if;
  exception when others then
    fails := fails + 1; step := '4 organisation/mailbox'; result := 'FAIL: ' || sqlerrm; return next;
  end;

  -- ───────── 5) plan (payment ki jagah entitlement; baqi sab asli code ke raaste) ─────────
  begin
    if exists (select 1 from public.entitlement_state e where e.user_id = uid) then
      execute format('update public.entitlement_state set plan = %L, seats = greatest(coalesce(seats, 0), 5), active_until = greatest(coalesce(active_until, now()), now() + interval ''31 days'') where user_id = %L', _plan, uid);
    else
      execute format('insert into public.entitlement_state (user_id, plan, seats, support_active, active_until) values (%L, %L, 5, false, now() + interval ''31 days'')', uid, _plan);
    end if;
    select t.status, t.plan into ts, tp from public.trial_accounts t where t.user_id = uid;
    if ts is distinct from 'active' or tp is distinct from _plan then
      perform public.trial_subscribe(uid, _plan, 'e36-ensure-test-account');
      step := '5 plan'; result := 'trial_subscribe se ' || _plan || ' active kiya (pehle: ' || coalesce(ts,'?') || '/' || coalesce(tp,'-') || ')'; return next;
    else
      step := '5 plan'; result := _plan || ' pehle se active'; return next;
    end if;
    if to_regclass('public.workspace_subscriptions') is not null then
      execute format('update public.workspace_subscriptions set plan = %L, state = ''active'', updated_at = now() where user_id = %L and plan is distinct from %L', _plan, uid, _plan);
      get diagnostics n = row_count;
      if n > 0 then step := '5 workspace_subscriptions'; result := 'purani galat-plan row theek ki'; return next; end if;
    end if;
    if to_regclass('public.family_accounts') is not null then
      execute format('select plan::text from public.family_accounts where lower(email) = %L limit 1', em) into ep;
      if ep is not null and ep <> _plan then
        fails := fails + 1; step := '5 family_accounts'; result := 'DHYAN: is email ki family_accounts row plan=' || ep || ' hai — login/session mein yahi jeet'; return next;
      end if;
    end if;
  exception when others then
    fails := fails + 1; step := '5 plan'; result := 'FAIL: ' || sqlerrm; return next;
  end;

  select t.status, t.plan into ts, tp from public.trial_accounts t where t.user_id = uid;
  step := 'RESULT';
  result := case when fails = 0 then 'OK' else 'KUCH ADHURA (' || fails || ' step)' end
            || ' | ' || em || ' | uid=' || uid::text || ' | status=' || coalesce(ts,'?') || ' | plan=' || coalesce(tp,'-')
            || case when created then ' | NAYA' else ' | pehle se tha' end;
  return next;
end
$f$;

select * from pg_temp.ax_ensure_account(:'handle', :'nm', :'org', :'domain', :'plan', :'pwhash');

commit;
