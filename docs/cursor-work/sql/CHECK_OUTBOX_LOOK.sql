
-- CHECK_OUTBOX_LOOK - READ ONLY: why is a mail still in the Outbox? Prints the real state of every outbox row that is not finished, plus the sending switch. Writes nothing.
select 'switch send_enabled=' || (select send_enabled::text from public.fmail_policy where id = 1) || ' now=' || to_char(now(), 'HH24:MI:SS') as line
union all
select 'outbox ' || left(id::text, 8) || ' state=' || state || ' attempts=' || attempts || ' not_before=' || to_char(not_before, 'HH24:MI:SS') || ' next_attempt=' || coalesce(to_char(next_attempt, 'HH24:MI:SS'), '-') || ' err=' || coalesce(left(last_error, 110), '-') || ' reply=' || coalesce(left(smtp_reply, 110), '-')
from public.fmail_outbox where state in ('queued', 'scheduled', 'sending', 'failed')
union all
select 'last sent ' || left(id::text, 8) || ' tls=' || coalesce(tls_out, '-') || ' at=' || to_char(finished_at, 'DD HH24:MI:SS') from (select * from public.fmail_outbox where state = 'sent' order by finished_at desc limit 1) s;
