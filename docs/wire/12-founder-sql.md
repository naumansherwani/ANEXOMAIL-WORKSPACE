# 12 — FOUNDER WIRING SQL (editor mein copy-paste)

Founder kahin nahi mara. Jo purani file delete hui thi woh `mailboxes` table ko
dobara banane ki koshish kar rahi thi (isi se `mailboxes_address_key already exists`
error aata tha). Founder ki asli do cheezein yeh hain:

1. **Founder mailbox row** — `naumansherwani.founder@anexomail.com` + alias `nauman@`
   pehle se Wire 11 (Phase 52) ke final address list mein maujood hai. Kuch alag nahi karna.
2. **Founder identity/role** — neeche wala block. Isi se `/app/founder`, Founder view,
   billing aur entitlement founder ke naam par khulte hain.

Supabase SQL Editor mein poora block paste karo (baar baar chala sakte ho):

```sql
do $$
declare
  v_uid   uuid := '3e3a60ea-1580-4443-94f6-b758de732dce';
  v_email text := 'naumansherwani.founder@anexomail.com';
  v_exists boolean;
begin
  select exists (select 1 from auth.users u where u.id = v_uid) into v_exists;
  if not v_exists then
    raise exception 'Auth user % mojood nahi — Authentication -> Users check karo', v_uid;
  end if;

  -- 1) FOUNDER ROLE (role kabhi profile par nahi, apni authority table par)
  if to_regclass('public.founder_accounts') is null then
    create table public.founder_accounts (
      user_id    uuid primary key references auth.users(id) on delete cascade,
      email      text not null,
      created_at timestamptz not null default now()
    );
    grant select on public.founder_accounts to authenticated;
    grant all    on public.founder_accounts to service_role;
    alter table public.founder_accounts enable row level security;
    create policy founder_accounts_self on public.founder_accounts
      for select to authenticated using (user_id = auth.uid());
  end if;

  insert into public.founder_accounts (user_id, email)
  values (v_uid, v_email)
  on conflict (user_id) do update set email = excluded.email;

  -- 2) founder trial mein kabhi nahi phansta
  if to_regclass('public.trial_accounts') is not null then
    insert into public.trial_accounts (
      user_id, social_email, social_provider,
      anexomail_address, anexomail_handle,
      status, plan, passkey_set, recovery_set, trial_ends_at
    ) values (
      v_uid, v_email, 'email', v_email, 'naumansherwani.founder',
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

  -- 3) top plan, charge zero (koi paid intent nahi banta)
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

  -- 4) founder mailbox + alias (agar Wire 11 chal chuki hai to sirf refresh)
  if to_regclass('public.mailboxes') is not null then
    insert into public.mailboxes (address, display_name, box_type, alias_target, purpose, is_public)
    values
      (v_email, 'Muhammad Nauman Sherwani', 'mailbox', null, 'Founder primary (/app/founder)', false),
      ('nauman@anexomail.com', 'Nauman', 'alias', v_email, 'Short alias to founder primary', false)
    on conflict (address) do update set
      display_name = excluded.display_name,
      box_type     = excluded.box_type,
      alias_target = excluded.alias_target,
      active       = true;
  end if;

  raise notice 'FOUNDER WIRED: % (%)', v_email, v_uid;
end $$;
```

## Verify (usi editor mein)

```sql
select u.email,
       (f.user_id is not null) as founder_role,
       e.plan, e.support_active,
       (select count(*) from public.mailboxes
         where address in ('naumansherwani.founder@anexomail.com','nauman@anexomail.com')) as founder_boxes
from auth.users u
left join public.founder_accounts f on f.user_id = u.id
left join public.entitlement_state e on e.user_id = u.id
where u.id = '3e3a60ea-1580-4443-94f6-b758de732dce';
```

Chahiye: `founder_role = true`, `plan = business_pro`, `founder_boxes = 2`.
