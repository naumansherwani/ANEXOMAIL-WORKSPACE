
-- E178 - FIX of the E167 selftest (found on his real server 16 Nov 05:40 by CHECK_E177C): the check "a row inside its undo window is not claimed yet"
-- counted ALL claimable outbox rows, so one real mail past its hold made the selftest fail (sandbox outbox was empty). The selftest runs in a rolled-back
-- subtransaction, so the real mail was never touched. Fix: count only the test row. Re-run safe. Needs E167, E177.

do $p$
declare d text;
begin
  select pg_get_functiondef('public.fmail_selftest167()'::regprocedure) into d;
  if d not like '%from public.fmail_outbox_claim(10) cl where cl = v_o%' then
    d := replace(d, 'select count(*) into v_n from public.fmail_outbox_claim(10);', 'select count(*) into v_n from public.fmail_outbox_claim(10) cl where cl = v_o;');
    if d not like '%from public.fmail_outbox_claim(10) cl where cl = v_o%' then raise exception 'E178: the E167 selftest text was not found, nothing changed'; end if;
    execute d;
  end if;
end $p$;

select public.fmail_selftest177() as e178_selftest177;
