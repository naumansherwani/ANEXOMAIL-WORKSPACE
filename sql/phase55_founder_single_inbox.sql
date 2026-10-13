-- =============================================================================
-- ANEXOMAIL — Phase 55: FOUNDER SINGLE INBOX + RECOVERY (locked 8 Sep 2026)
-- Kahan chalti hai: SUPABASE #4 -> SQL Editor. Idempotent + self-healing.
--
-- Founder rule (locked):
--   * founder ka EK hi inbox: naumansherwani.founder@anexomail.com
--   * anexomail.com ki har address ki mail us ek inbox mein bhi nazar aati hai
--   * sab founder-side logins ka password EK (server par mail.env mein)
--   * recovery account: anexomail27@gmail.com
--   * founder par awam ke limits (trial, plan, credits, fair-use) apply nahi hote
--   * MAGAR: awam ka data breach kabhi nahi — awam ki mail/conversation founder
--     inbox mein nahi aati; sirf anexomail.com ki apni company addresses aati hain
-- =============================================================================

do $$
declare
  v_uid   uuid := '3e3a60ea-1580-4443-94f6-b758de732dce';
  v_email text := 'naumansherwani.founder@anexomail.com';
begin
  if not exists (select 1 from auth.users where id = v_uid) then
    raise exception 'Auth user % mojood nahi — pehle sql/phase45_founder_identity.sql chalao', v_uid;
  end if;
end $$;

-- ---------- founder inbox truth ----------
create table if not exists public.founder_inbox_config (
  user_id            uuid primary key,
  primary_address    text not null,
  recovery_email     text not null,
  unified_inbox      boolean not null default true,
  shared_password    boolean not null default true,
  awam_limits_apply  boolean not null default false,
  awam_data_access   boolean not null default false, -- HAMESHA false: breach mamnu
  updated_at         timestamptz not null default now(),
  constraint founder_inbox_no_awam_access check (awam_data_access = false)
);

grant select on public.founder_inbox_config to authenticated;
grant all    on public.founder_inbox_config to service_role;
alter table public.founder_inbox_config enable row level security;

drop policy if exists "founder reads own inbox config" on public.founder_inbox_config;
create policy "founder reads own inbox config"
on public.founder_inbox_config for select to authenticated
using (user_id = auth.uid());

insert into public.founder_inbox_config
  (user_id, primary_address, recovery_email, unified_inbox, shared_password,
   awam_limits_apply, awam_data_access)
values ('3e3a60ea-1580-4443-94f6-b758de732dce',
        'naumansherwani.founder@anexomail.com',
        'anexomail27@gmail.com',
        true, true, false, false)
on conflict (user_id) do update set
  primary_address   = excluded.primary_address,
  recovery_email    = excluded.recovery_email,
  unified_inbox     = true,
  shared_password   = true,
  awam_limits_apply = false,
  awam_data_access  = false,
  updated_at        = now();

-- ---------- founder ki har company address ek hi inbox par ----------
-- mailboxes table maujood ho to founder-owned flag + unified target set karo.
do $$
begin
  if to_regclass('public.mailboxes') is null then
    raise notice 'mailboxes table nahi — pehle sql/phase52_mail_launch.sql chalao';
    return;
  end if;

  alter table public.mailboxes
    add column if not exists founder_owned boolean not null default false;
  alter table public.mailboxes
    add column if not exists unified_target text;

  update public.mailboxes
     set founder_owned  = true,
         unified_target = 'naumansherwani.founder@anexomail.com'
   where box_type <> 'sendonly'
     and address <> 'naumansherwani.founder@anexomail.com'
     and address like '%@anexomail.com';

  update public.mailboxes
     set founder_owned = true, unified_target = null
   where address = 'naumansherwani.founder@anexomail.com';
end $$;

-- ---------- founder par awam limits off ----------
do $$
declare v_uid uuid := '3e3a60ea-1580-4443-94f6-b758de732dce';
begin
  if to_regclass('public.trial_accounts') is not null then
    update public.trial_accounts
       set status = 'active', trial_ends_at = greatest(trial_ends_at, now() + interval '10 years')
     where user_id = v_uid;
  end if;
  if to_regclass('public.entitlement_state') is not null then
    update public.entitlement_state
       set plan = 'business_pro', support_active = true,
           active_until = greatest(coalesce(active_until, now()), now() + interval '10 years')
     where user_id = v_uid;
  end if;
end $$;

-- ---------------------------------------------------------------- VERIFY
select primary_address, recovery_email, unified_inbox, shared_password,
       awam_limits_apply, awam_data_access
  from public.founder_inbox_config
 where user_id = '3e3a60ea-1580-4443-94f6-b758de732dce';

select address, box_type, founder_owned, unified_target
  from public.mailboxes
 order by founder_owned desc, address;
