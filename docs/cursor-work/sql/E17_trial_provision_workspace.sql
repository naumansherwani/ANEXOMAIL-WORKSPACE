-- E17: naya real buyer signup -- workspace provisioning (Rule 14, #5/#6).
--
-- Gap jo mila: phase32_trial.sql ka trial_claim_address() sirf
-- trial_accounts.anexomail_handle / anexomail_address set karta hai. Yeh kabhi
-- organisations / mail_accounts / org_members nahi banata -- pro.test aur
-- biz.test ke yeh rows manual SQL se bhare gaye the (12 Oct), khud-ba-khud
-- koi mechanism nahi tha. Yeh function wahi kaam idempotent + automated
-- banata hai, taake Rust (/rpc/account.signup.claim) sirf dispatch kare,
-- asal business logic Supabase mein rahe (constitution: TRUTH = Supabase).
--
-- Flat 30GB (32212254720 bytes) organisations.storage_limit_bytes -- yehi
-- value pro.test aur business_pro.test (12 Oct, manual) mein bhi hai; yeh
-- org-level starting allowance hai, workspace_plans.storage_per_mailbox_gb
-- se seedha jura nahi (woh alag hisaab hai, item #12/#13 mein already
-- flagged drift-risk).

create or replace function public.trial_provision_workspace(_user_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  a public.trial_accounts;
  existing_org uuid;
  new_org uuid;
  ws_name text;
  ws_slug text;
begin
  select * into a from public.trial_accounts where user_id = _user_id;
  if a.user_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_trial_account');
  end if;
  if a.anexomail_address is null then
    return jsonb_build_object('ok', false, 'error', 'address_not_claimed');
  end if;

  select org_id into existing_org from public.org_members where user_id = _user_id limit 1;
  if existing_org is not null then
    return jsonb_build_object('ok', true, 'already_provisioned', true, 'org_id', existing_org,
                               'address', a.anexomail_address);
  end if;

  ws_name := initcap(a.anexomail_handle) || ' workspace';
  ws_slug := a.anexomail_handle || '-' || substr(_user_id::text, 1, 8);

  insert into public.organisations (id, name, slug, owner_id, created_at, storage_limit_bytes)
  values (gen_random_uuid(), ws_name, ws_slug, _user_id, now(), 32212254720)
  returning id into new_org;

  insert into public.mail_accounts (id, org_id, address, kind, accepts_replies, auto_reply, created_at)
  values (gen_random_uuid(), new_org, a.anexomail_address, 'personal', true, false, now());

  insert into public.org_members (id, org_id, user_id, role, created_at, email, status)
  values (gen_random_uuid(), new_org, _user_id, 'owner', now(), a.anexomail_address, 'active');

  insert into public.trial_events (user_id, event_type, detail)
  values (_user_id, 'workspace_provisioned',
          jsonb_build_object('org_id', new_org, 'address', a.anexomail_address))
  on conflict do nothing;

  return jsonb_build_object('ok', true, 'already_provisioned', false, 'org_id', new_org,
                             'address', a.anexomail_address);
end $$;

grant execute on function public.trial_provision_workspace(uuid) to service_role, authenticated;

-- Verify (read-only):
-- select proname from pg_proc where proname = 'trial_provision_workspace';
