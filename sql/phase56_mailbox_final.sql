-- =============================================================================
-- ANEXOMAIL — Phase 56: FINAL ADDRESS LIST + FAMILY ACCOUNTS (locked 8 Sep 2026)
-- Supabase #4 -> SQL Editor. Idempotent. Backup pehle, delete baad mein.
--
-- Founder ka faisla (final):
--   REAL MAILBOX (sirf yeh):
--     hello@ · moveyourbusiness@ · resolved@ · billing@ · leo@
--     naumansherwani.founder@   (founder ka ek hi inbox)
--     humzasherwani@            (brother — aam user, AI Executive premium)
--     raanasherwani@            (mother  — aam user, AI Executive premium)
--   SEND-ONLY: noreply@
--   FORWARD-ONLY (koi inbox nahi, koi password nahi -> sab resolved@ par):
--     postmaster@ · abuse@ · dmarc@      (RFC + DMARC report ke liye lazmi)
--   DELETE (root se, backup ke baad): nauman@ · support@ · trials@
-- =============================================================================

-- ---------- 1) BACKUP (delete se pehle) ----------
do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if to_regclass('public.mailboxes') is null then
    raise exception 'mailboxes table nahi — pehle sql/phase52_mail_launch.sql chalao';
  end if;
  execute format('create table public.mailboxes_backup_%s as select * from public.mailboxes', ts);
  raise notice 'backup: public.mailboxes_backup_%', ts;
end $$;

-- ---------- 2) purani logic-wali addresses hatao ----------
delete from public.mailboxes
 where address in ('nauman@anexomail.com',
                   'support@anexomail.com',
                   'trials@anexomail.com');

-- ---------- 3) final list ----------
insert into public.mailboxes (address, display_name, box_type, alias_target, purpose, is_public) values
 ('hello@anexomail.com','ANEXOMAIL','mailbox',null,'First contact, footer, get-started',true),
 ('moveyourbusiness@anexomail.com','ANEXOMAIL Move-Ins','mailbox',null,'Move-in aur Priority Support inquiries',true),
 ('resolved@anexomail.com','ANEXOMAIL Resolved','mailbox',null,'Support ka asli inbox + resolved log (support/trials/abuse sab yahin)',false),
 ('billing@anexomail.com','ANEXOMAIL Billing','mailbox',null,'Invoices aur plan sawal',true),
 ('leo@anexomail.com','Leo — ANEXOMAIL AI','mailbox',null,'LEO reply pipeline',false),
 ('noreply@anexomail.com','ANEXOMAIL (no reply)','sendonly',null,'Outbound system mail. Inbound discard.',true),
 ('naumansherwani.founder@anexomail.com','Muhammad Nauman Sherwani','mailbox',null,'Founder ka ek hi inbox',false),
 ('humzasherwani@anexomail.com','Humza Sherwani','mailbox',null,'Family account — aam user, AI Executive premium',false),
 ('raanasherwani@anexomail.com','Raana Sherwani','mailbox',null,'Family account — aam user, AI Executive premium',false),
 ('postmaster@anexomail.com','Postmaster (forward)','alias','resolved@anexomail.com','RFC lazmi — sirf forward to resolved@',false),
 ('abuse@anexomail.com','Abuse (forward)','alias','resolved@anexomail.com','RFC lazmi — sirf forward to resolved@',false),
 ('dmarc@anexomail.com','DMARC reports (forward)','alias','resolved@anexomail.com','DMARC rua — sirf forward to resolved@',false)
on conflict (address) do update
  set display_name = excluded.display_name,
      box_type     = excluded.box_type,
      alias_target = excluded.alias_target,
      purpose      = excluded.purpose,
      is_public    = excluded.is_public,
      active       = true;

-- founder unified copy sirf company addresses par (family accounts par kabhi nahi)
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='mailboxes' and column_name='unified_target') then
    update public.mailboxes
       set founder_owned = true, unified_target = 'naumansherwani.founder@anexomail.com'
     where address in ('hello@anexomail.com','moveyourbusiness@anexomail.com',
                       'resolved@anexomail.com','billing@anexomail.com','leo@anexomail.com');
    update public.mailboxes
       set founder_owned = false, unified_target = null
     where address in ('humzasherwani@anexomail.com','raanasherwani@anexomail.com');
    update public.mailboxes
       set founder_owned = true, unified_target = null
     where address = 'naumansherwani.founder@anexomail.com';
  end if;
end $$;

-- =============================================================================
-- 4) FAMILY ACCOUNTS — aam user, magar AI Executive ke saray premium features
-- =============================================================================
create table if not exists public.family_accounts (
  email        text primary key,
  display_name text not null,
  relation     text not null,
  plan         text not null default 'business_pro',
  ai_plan      text not null default 'ai_executive',
  ai_credits   numeric(14,3) not null default 10000,
  founder_data_access boolean not null default false,  -- HAMESHA false
  awam_rules   boolean not null default true,          -- aam user ki tarah
  created_at   timestamptz not null default now(),
  constraint family_no_founder_data check (founder_data_access = false)
);

grant select on public.family_accounts to authenticated;
grant all    on public.family_accounts to service_role;
alter table public.family_accounts enable row level security;

drop policy if exists "family reads own row" on public.family_accounts;
create policy "family reads own row"
on public.family_accounts for select to authenticated
using (lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));

insert into public.family_accounts (email, display_name, relation) values
 ('humzasherwani@anexomail.com','Humza Sherwani','brother'),
 ('raanasherwani@anexomail.com','Raana Sherwani','mother')
on conflict (email) do update
  set display_name = excluded.display_name,
      relation     = excluded.relation,
      plan         = 'business_pro',
      ai_plan      = 'ai_executive',
      ai_credits   = 10000;

-- entitlement + AI credits apply (jab account sign-up ho jaye)
create or replace function public.family_grants_apply()
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare r record; n integer := 0; has_ai_plan boolean;
begin
  select exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='entitlement_state'
                    and column_name='ai_plan') into has_ai_plan;

  for r in select f.*, u.id as uid
             from public.family_accounts f
             join auth.users u on lower(u.email) = lower(f.email)
  loop
    if to_regclass('public.entitlement_state') is not null then
      insert into public.entitlement_state (user_id, plan, seats, support_active, active_until)
      values (r.uid, r.plan, 1, true, now() + interval '10 years')
      on conflict (user_id) do update
        set plan = r.plan, seats = greatest(1, entitlement_state.seats),
            support_active = true,
            active_until = greatest(coalesce(entitlement_state.active_until, now()), now() + interval '10 years'),
            revision = entitlement_state.revision + 1,
            updated_at = now();
      if has_ai_plan then
        execute 'update public.entitlement_state set ai_plan = $2 where user_id = $1'
          using r.uid, r.ai_plan;
      end if;
    end if;

    if to_regclass('public.ai_credit_wallets') is not null then
      insert into public.ai_credit_wallets (workspace_id, owner_id, plan_id, subscription_credits, renews_at)
      values (r.uid, r.uid, r.ai_plan, r.ai_credits, now() + interval '1 month')
      on conflict (workspace_id) do update
        set owner_id = r.uid, plan_id = r.ai_plan,
            subscription_credits = greatest(ai_credit_wallets.subscription_credits, r.ai_credits),
            updated_at = now();
    end if;

    if to_regclass('public.trial_accounts') is not null then
      update public.trial_accounts
         set status = 'active',
             trial_ends_at = greatest(trial_ends_at, now() + interval '10 years')
       where user_id = r.uid;
    end if;

    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function public.family_grants_apply() from public, anon, authenticated;
grant execute on function public.family_grants_apply() to service_role;

select public.family_grants_apply() as family_accounts_granted;

-- ---------------------------------------------------------------- VERIFY
select address, box_type, alias_target, active
  from public.mailboxes
 where address like '%@anexomail.com'
 order by box_type, address;

select email, relation, plan, ai_plan, ai_credits from public.family_accounts order by email;
