-- E52 — "5 free aliases" ka wada asli banao (Basic + Pro: 5; Business/Business Pro: unlimited 'on request').
-- Surgical: purana org_address_create ko haath nahi lagta; sirf org_addresses par BEFORE INSERT trigger.
-- Purane orgs jinke paas 5 se zyada alias hain wo chalte rahenge; sirf NAYA alias rokta hai.
create or replace function public.org_alias_cap(_plan text)
returns integer language sql immutable as $$
  select case _plan when 'basic' then 5 when 'pro' then 5 else null end;   -- NULL = unlimited
$$;

create or replace function public.org_alias_cap_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare plan text; cap integer; used integer;
begin
  if new.kind <> 'alias' or new.active is not true then return new; end if;
  plan := public.org_plan_of(new.org_id);
  cap  := public.org_alias_cap(plan);
  if cap is null then return new; end if;
  select count(*) into used from public.org_addresses where org_id = new.org_id and kind = 'alias' and active;
  if used >= cap then
    raise exception 'alias_limit:%:%', plan, cap using errcode = 'AX052';
  end if;
  return new;
end $$;

drop trigger if exists org_alias_cap_guard_trg on public.org_addresses;
create trigger org_alias_cap_guard_trg before insert on public.org_addresses
  for each row execute function public.org_alias_cap_guard();

revoke all on function public.org_alias_cap(text), public.org_alias_cap_guard() from public, anon, authenticated;
