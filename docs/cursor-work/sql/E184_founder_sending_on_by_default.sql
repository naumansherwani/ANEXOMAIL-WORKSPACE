
-- E184 - SENDING IS ON BY DEFAULT (his word 17 Nov 03:31: "YEH BY DEFULT ON REHNA CHAIYE HAI").
-- E182 made the switch with default true, but his row was left OFF while testing. This turns it ON through the ledgered door (old and new value anchored) and re-asserts the column default.
-- The switch stays: he can still turn sending OFF on purpose from the screen. Same value = no change, no ledger noise. Needs E182. Re-run safe.
alter table public.fmail_policy alter column send_enabled set default true;

do $p$
declare v_actor uuid; r jsonb;
begin
  select user_id into v_actor from public.founder_accounts limit 1;
  if v_actor is null then raise exception 'E184: no founder account'; end if;
  r := public.fmail_sending_set182(v_actor, true, 'sending ON by default (founder word 17 Nov)');
  raise notice 'E184: %', r;
end $p$;

create or replace function public.fmail_selftest184() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare ok int := 0; bad int := 0;
begin
  if (select send_enabled from public.fmail_policy where id = 1) then ok := ok + 1; else bad := bad + 1; end if;
  if (select column_default from information_schema.columns where table_schema='public' and table_name='fmail_policy' and column_name='send_enabled') = 'true' then ok := ok + 1; else bad := bad + 1; end if;
  return format('E184 selftest: %s ok, %s failed', ok, bad);
end $$;
revoke all on function public.fmail_selftest184() from public, anon, authenticated;
grant execute on function public.fmail_selftest184() to service_role;
