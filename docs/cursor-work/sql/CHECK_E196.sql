
-- CHECK E196 - follow-up reminders. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E196 tables have forced RLS (reminders, policy, event log)' as item, (public.fmail_posture196() ->> 'rls_forced')::boolean as ok, 1 as n
union all select 'E196 ledger knows followup_set / followup_cancel / followup_due', (public.fmail_posture196() ->> 'ledger_knows_followups')::boolean, 2
union all select 'E196 live change log knows kind followup', (public.fmail_posture196() ->> 'change_log_knows_followup')::boolean, 3
union all select 'E196 doors are VOLATILE', (public.fmail_posture196() ->> 'doors_volatile')::boolean, 4
union all select 'E196 doors are service_role only', (public.fmail_posture196() ->> 'doors_service_only')::boolean, 5
union all select 'E196 event log is append-only (row guard + truncate guard)', (public.fmail_posture196() ->> 'event_log_append_only')::boolean, 6
union all select 'E196 guard + reply triggers present', (public.fmail_posture196() ->> 'guard_trigger_present')::boolean and (public.fmail_posture196() ->> 'reply_trigger_present')::boolean, 7
union all select 'E196 door audit (E179) clean', (public.fmail_posture196() ->> 'door_audit_clean')::boolean, 8
union all select 'E196 selftest all ok (' || (public.fmail_selftest196() ->> 'passed') || ' of ' || (public.fmail_selftest196() ->> 'total') || ')', (public.fmail_selftest196() ->> 'ok')::boolean, 9
) t order by n;
