
-- E52 — alias FAIR-USE cap (chhupa hua, card par nahi likha): har plan par 25 active alias.
-- Wajah: card 'free aliases' kehta hai (asli product unlimited tha); abuse (spam/catch-all farm) se bachao.
-- Surgical: org_address_create ko haath nahi; sirf org_addresses par BEFORE INSERT trigger.
-- Jin orgs ke paas pehle se 25+ alias hain wo chalte rahenge; sirf NAYA alias rukta hai.
create or replace function public.org_alias_fair_use_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare used integer;
begin
  if new.kind <> 'alias' or new.active is not true then return new; end if;
  select count(*) into used from public.org_addresses where org_id = new.org_id and kind = 'alias' and active;
  if used >= 25 then
    raise exception 'alias_fair_use:25' using errcode = 'AX052';
  end if;
  return new;
end $$;
drop trigger if exists org_alias_fair_use_trg on public.org_addresses;
create trigger org_alias_fair_use_trg before insert on public.org_addresses
  for each row execute function public.org_alias_fair_use_guard();
revoke all on function public.org_alias_fair_use_guard() from public, anon, authenticated;
