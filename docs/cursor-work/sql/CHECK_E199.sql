
-- CHECK E199 - Single-letter keys setting sync. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E199 key mail.single_keys registered (area mail, bool)' as item, (public.founder_keys_posture199() ->> 'key_registered')::boolean as ok, 1 as n
union all select 'E199 default is ON (true)', (public.founder_keys_posture199() ->> 'default_true')::boolean, 2
union all select 'E199 plain-words info row present', (public.founder_keys_posture199() ->> 'info_row')::boolean, 3
union all select 'E199 validator wrapper in place (E115 keys untouched)', (public.founder_keys_posture199() ->> 'wrapper_in_place')::boolean, 4
union all select 'E199 validator not callable by public/anon', (public.founder_keys_posture199() ->> 'validator_not_public')::boolean, 5
union all select 'E199 read door is service_role only', (public.founder_keys_posture199() ->> 'read_door_service_only')::boolean, 6
union all select 'E199 founder_settings.key still references the registry', (public.founder_keys_posture199() ->> 'fk_to_registry')::boolean, 7
union all select 'E199 selftest all ok (' || (public.founder_keys_selftest199() ->> 'passed') || ' of ' || (public.founder_keys_selftest199() ->> 'total') || ')', (public.founder_keys_selftest199() ->> 'ok')::boolean, 8
) t order by n;
