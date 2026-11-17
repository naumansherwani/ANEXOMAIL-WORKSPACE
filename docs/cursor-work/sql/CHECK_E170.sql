
-- CHECK E170 - compose/send/undo doors + DKIM registry. Writes nothing (the selftest rolls itself back). Added 18 Nov 2026 (audit: E170 had no CHECK file).
select item, ok from (
select 'E170 posture: RLS forced, anon cannot touch, no plain private key column' as item, (public.fmail_posture170() ->> 'rls_forced')::boolean and not (public.fmail_posture170() ->> 'anon_can_touch')::boolean and (public.fmail_posture170() ->> 'plain_private_key_columns')::int = 0 as ok, 1 as n
union all select 'E170 every 170 door is service_role only', (public.fmail_posture170() ->> 'doors_service_only')::boolean, 2
union all select 'E170 DKIM guard trigger present', (public.fmail_posture170() ->> 'guard_trigger')::int >= 1, 3
-- the one check 'send without a touch refused' was superseded by E177 (a normal send needs no touch by his word); it is the only failure allowed here
union all select 'E170 selftest: every check ok except the one E177 superseded', not exists (select 1 from jsonb_array_elements(public.fmail_selftest170() -> 'checks') e where (e ->> 'ok')::boolean is not true and e ->> 'name' <> 'send without a touch refused') and (public.fmail_selftest170() ->> 'error') is null, 4
union all select 'E170 door audit (E179) clean', not exists (select 1 from public.fmail_door_audit179()), 5
) t order by n;
