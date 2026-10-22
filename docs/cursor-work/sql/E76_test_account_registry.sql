
-- E76 — test account REGISTRY (test aur asli user kabhi mix na hon). 23 Oct 2026. Dobara chalana safe. Koi DROP nahi.
-- Loophole (audit): passkey gate ki chhoot naam-pattern `(^|[._-])test@` par thi => koi bhi ASLI user "naam.test" handle le kar
--   27 Oct ka passkey gate / banner se bach jata. Ab chhoot sirf us email ko jo is registry (test_accounts) mein ho. Pattern + registry DONO chahiye.
-- Registry ek baar mojooda auth.users se bhari jati hai (jo pehle se pattern par hain = founder ke test accounts); asli signup kabhi isme nahi aata.
-- Naya test account: E28/E36 script isme khud dalti hai (neeche function). Fail-closed: registry/rpc na mile to chhoot NAHI (asli user jaisa gate).
set lock_timeout = '5s';
set statement_timeout = '60s';

create table if not exists public.test_accounts (
  email      text primary key check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+$'),
  note       text,
  created_at timestamptz not null default now()
);
alter table public.test_accounts enable row level security;
revoke all on public.test_accounts from public, anon, authenticated;
grant select, insert, delete on public.test_accounts to service_role;

-- mojooda test accounts (pattern par) ek baar registry mein; jo naam dikhe woh NOTICE mein taake founder dekh sake
do $$
declare r record;
begin
  for r in
    select lower(u.email) as e from auth.users u
     where lower(u.email) ~ '(^|[._-])test@' and u.deleted_at is null
  loop
    insert into public.test_accounts (email, note) values (r.e, 'E76 seed: pattern par mojood tha') on conflict do nothing;
    raise notice 'E76 registry: %', r.e;
  end loop;
end $$;

create or replace function public.is_registered_test_account(_email text)
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select exists (select 1 from public.test_accounts t where t.email = lower(btrim(_email)));
$$;
revoke all on function public.is_registered_test_account(text) from public, anon, authenticated;
grant execute on function public.is_registered_test_account(text) to service_role;

comment on table public.test_accounts is 'Founder test accounts only. Passkey gate exemption needs pattern AND a row here (E76). Real signups never land here.';
