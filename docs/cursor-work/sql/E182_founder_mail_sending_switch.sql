
-- E182 - REAL ON/OFF SWITCH FOR SENDING (his 16 Nov 06:21 order: "on and off toggle ... real working").
-- One flag in the one-row policy: send_enabled (default true). OFF = nothing is handed to the SMTP worker: fmail_outbox_claim returns no row and fmail_outbox_next_due177 returns null,
-- so mail still queues (after its 30 s hold) and WAITS in the Outbox, nothing is lost, nothing is sent; incoming mail is not touched (the mailbox stays active). ON = the exact-time sender takes them at once.
-- Every change goes through fmail_sending_set182 -> fmail_policy_set -> hash-chained ledger (old and new value anchored). No passkey touch (normal-send policy, his E177 word); the key/DNS touches stay.
-- Needs E167, E177. Re-run safe.
alter table public.fmail_policy add column if not exists send_enabled boolean not null default true;

do $p$
declare d text;
begin
  select pg_get_functiondef('public.fmail_policy_set(uuid,text,text,text)'::regprocedure) into d;
  if d not like '%send_enabled%' then
    d := replace(d, '''require_touch_send'',''require_touch_delete''', '''send_enabled'',''require_touch_send'',''require_touch_delete''');
    d := replace(d, 'p_key in (''require_touch_send'',', 'p_key in (''send_enabled'',''require_touch_send'',');
    if d not like '%''send_enabled'',''require_touch_send''%' or d not like '%in (''send_enabled'',''require_touch_send'',%' then raise exception 'E182: fmail_policy_set text not found, nothing changed'; end if;
    execute d;
  end if;
  select pg_get_functiondef('public.fmail_outbox_claim(integer)'::regprocedure) into d;
  if d not like '%send_enabled%' then
    d := replace(d, 'begin
  if p_max < 1', 'begin
  if not (select send_enabled from public.fmail_policy where id = 1) then return; end if;
  if p_max < 1');
    if d not like '%send_enabled%' then raise exception 'E182: fmail_outbox_claim text not found, nothing changed'; end if;
    execute d;
  end if;
end $p$;

create or replace function public.fmail_outbox_next_due177() returns double precision language sql stable security definer set search_path = pg_catalog, public as $f$
  select extract(epoch from (min(o.not_before) - now()))::double precision from public.fmail_outbox o where o.state in ('queued', 'scheduled') and (select send_enabled from public.fmail_policy where id = 1)
$f$;

-- DOOR: switch sending on/off (ledgered). Same value twice = no change, no ledger noise.
create or replace function public.fmail_sending_set182(p_actor uuid, p_on boolean, p_reason text default null)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare v_old boolean; v_led jsonb;
begin
  if p_actor is null or p_on is null then raise exception 'E182: actor and value needed' using errcode = '22023'; end if;
  select send_enabled into v_old from public.fmail_policy where id = 1;
  if v_old = p_on then return jsonb_build_object('ok', true, 'changed', false, 'send_enabled', v_old); end if;
  v_led := public.fmail_policy_set(p_actor, 'send_enabled', p_on::text, coalesce(nullif(left(p_reason, 160), ''), case when p_on then 'sending switched ON by the founder' else 'sending switched OFF by the founder' end));
  return jsonb_build_object('ok', true, 'changed', true, 'send_enabled', p_on, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_sending_set182(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.fmail_sending_set182(uuid, boolean, text) to service_role;

-- READ: the state the screens show (volatile only to stay safe under PostgREST; it writes nothing).
create or replace function public.fmail_sending_state182()
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('send_enabled', p.send_enabled, 'undo_seconds', p.undo_seconds,
    'waiting', (select count(*) from public.fmail_outbox where state in ('queued', 'scheduled', 'failed')),
    'changed_at_ms', (select max(ts_ms) from public.fmail_ledger where action = 'policy_change' and target = 'send_enabled'))
  from public.fmail_policy p where p.id = 1
$$;
revoke all on function public.fmail_sending_state182() from public, anon, authenticated;
grant execute on function public.fmail_sending_state182() to service_role;

create or replace function public.fmail_selftest182() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare ok int := 0; bad int := 0; v_actor uuid; v_was boolean; r jsonb; n int;
begin
  select user_id into v_actor from public.founder_accounts limit 1;
  select send_enabled into v_was from public.fmail_policy where id = 1;
  if v_actor is null then return 'E182 selftest: 0 ok, 1 failed (no founder account)'; end if;
  begin
    perform public.fmail_sending_set182(v_actor, false, 'selftest: off');
    if (public.fmail_sending_state182() ->> 'send_enabled')::boolean = false then ok := ok + 1; else bad := bad + 1; end if;
    select count(*) into n from public.fmail_outbox_claim(10); if n = 0 then ok := ok + 1; else bad := bad + 1; end if;
    if public.fmail_outbox_next_due177() is null then ok := ok + 1; else bad := bad + 1; end if;
    r := public.fmail_sending_set182(v_actor, false, 'selftest: same'); if (r ->> 'changed')::boolean = false then ok := ok + 1; else bad := bad + 1; end if;
    perform public.fmail_sending_set182(v_actor, true, 'selftest: on');
    if (public.fmail_sending_state182() ->> 'send_enabled')::boolean then ok := ok + 1; else bad := bad + 1; end if;
    if exists (select 1 from public.fmail_ledger where action = 'policy_change' and target = 'send_enabled') then ok := ok + 1; else bad := bad + 1; end if;
    raise exception 'E182 rollback';
  exception when others then
    if sqlerrm <> 'E182 rollback' then bad := bad + 1; end if;
  end;
  if has_function_privilege('service_role', 'public.fmail_sending_set182(uuid,boolean,text)', 'execute') and not has_function_privilege('anon', 'public.fmail_sending_set182(uuid,boolean,text)', 'execute') then ok := ok + 1; else bad := bad + 1; end if;
  if not exists (select 1 from public.fmail_door_audit179()) then ok := ok + 1; else bad := bad + 1; end if;
  return 'E182 selftest: ' || ok || ' ok, ' || bad || ' failed';
end $$;
revoke all on function public.fmail_selftest182() from public, anon, authenticated;
grant execute on function public.fmail_selftest182() to service_role;
select public.fmail_selftest182() as e182_selftest;
