/* =====================================================================
   PHASE 45 — FOUNDER IDENTITY LOCK
   Kahan chalti hai: SUPABASE #4 -> SQL Editor (Hetzner par NAHI)

   Maqsad: mojooda Supabase Auth user ko founder ke tor par map karna.
   Founder Auth user (pehle se bana hua, dobara NAHI banana):
     email : naumansherwani.founder@anexomail.com
     uid   : 3e3a60ea-1580-4443-94f6-b758de732dce

   Idempotent + self-healing: baar baar run karo, kuch nahi tootega.
   ===================================================================== */

do $$
declare
  v_uid   uuid := '3e3a60ea-1580-4443-94f6-b758de732dce';
  v_email text := 'naumansherwani.founder@anexomail.com';
  v_exists boolean;
begin
  /* 0) safety: Auth user waqai mojood hai? */
  select exists (select 1 from auth.users u where u.id = v_uid) into v_exists;
  if not v_exists then
    raise exception 'Auth user % mojood nahi — Supabase #4 Authentication -> Users check karo', v_uid;
  end if;

  /* 1) FOUNDER ROLE — authority table (role kabhi profile par nahi) */
  insert into public.founder_accounts (user_id, email)
  values (v_uid, v_email)
  on conflict (user_id) do update set email = excluded.email;

  /* 2) TRIAL/ACCOUNT STATE — founder trial mein kabhi phansta nahi */
  if to_regclass('public.trial_accounts') is not null then
    insert into public.trial_accounts (
      user_id, social_email, social_provider,
      anexomail_address, anexomail_handle,
      status, plan, passkey_set, recovery_set, trial_ends_at
    ) values (
      v_uid, v_email, 'email',
      v_email, 'naumansherwani.founder',
      'active', 'business', true, true, now() + interval '10 years'
    )
    on conflict (user_id) do update set
      status            = 'active',
      anexomail_address = excluded.anexomail_address,
      anexomail_handle  = excluded.anexomail_handle,
      trial_ends_at     = greatest(public.trial_accounts.trial_ends_at, now() + interval '10 years'),
      passkey_set       = true,
      recovery_set      = true,
      updated_at        = now();
  end if;

  /* 3) ENTITLEMENT — founder ko top plan, charge zero (paid intent nahi banta) */
  if to_regclass('public.entitlement_state') is not null then
    insert into public.entitlement_state (user_id, plan, seats, support_active, active_until, revision)
    values (v_uid, 'business_pro', 1, true, now() + interval '10 years', 1)
    on conflict (user_id) do update set
      plan           = 'business_pro',
      seats          = greatest(public.entitlement_state.seats, 1),
      support_active = true,
      active_until   = greatest(coalesce(public.entitlement_state.active_until, now()), now() + interval '10 years'),
      revision       = public.entitlement_state.revision + 1,
      updated_at     = now();
  end if;

  /* 4) audit trail (agar log table mojood hai) */
  if to_regclass('public.billing_state_log') is not null then
    insert into public.billing_state_log (user_id, to_state, reason, source)
    values (v_uid, 'founder_entitled', 'Phase 45 founder identity lock', 'sql');
  end if;

  raise notice 'FOUNDER LOCKED: % (%).', v_email, v_uid;
end $$;

/* ---------------------------------------------------------------- VERIFY */

-- A) Auth user + founder role ek hi UID par resolve hota hai?
select u.id as auth_uid,
       u.email,
       (u.email_confirmed_at is not null) as confirmed,
       (f.user_id is not null)            as founder_role
from auth.users u
left join public.founder_accounts f on f.user_id = u.id
where u.id = '3e3a60ea-1580-4443-94f6-b758de732dce';

-- B) Account state (trial se azaad) + entitlement
select t.status as trial_status, t.anexomail_address, t.trial_ends_at
from public.trial_accounts t
where t.user_id = '3e3a60ea-1580-4443-94f6-b758de732dce';

select e.plan, e.seats, e.support_active, e.active_until
from public.entitlement_state e
where e.user_id = '3e3a60ea-1580-4443-94f6-b758de732dce';

-- C) Ek se zyada founder na ho (sirf yeh 1 row aani chahiye)
select user_id, email, created_at from public.founder_accounts order by created_at;
