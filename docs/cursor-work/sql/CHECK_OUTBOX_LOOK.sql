
-- CHECK_OUTBOX_LOOK - READ ONLY: every outbox row of the last 6 hours in ANY state (queued, sending, failed, sent, cancelled, undone). Writes nothing.
select 'switch send_enabled=' || (select send_enabled::text from public.fmail_policy where id = 1) || ' now=' || to_char(now(), 'HH24:MI:SS') as line
union all
select * from (
  select 'outbox ' || left(o.id::text, 8) || ' made=' || to_char(o.created_at, 'HH24:MI:SS') || ' state=' || o.state || ' attempts=' || o.attempts || ' not_before=' || to_char(o.not_before, 'HH24:MI:SS') || ' err=' || coalesce(left(o.last_error, 90), '-') || ' reply=' || coalesce(left(o.smtp_reply, 90), '-') as line
  from public.fmail_outbox o
  where o.created_at > now() - interval '6 hours' order by o.created_at desc limit 8
) r;
