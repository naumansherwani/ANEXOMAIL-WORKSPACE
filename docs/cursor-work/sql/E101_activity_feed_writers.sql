
-- E101 — "Recent activity" dashboard par KHALI kyun? activity_log table ko koi likhta hi nahi tha.
-- Ab: har nayi mail (mail_messages INSERT) apne aap activity_log mein: in => message_received, out => message_sent.
-- Backfill: pichle 30 din ki mail (sirf jinki entry pehle se nahi). Sirf apni org ke members dekhte hain (activity_log ki policy pehle se).
-- Privacy: sirf subject (200 akshar tak) + bhejne wala; mail ka BODY activity_log mein kabhi nahi.
-- Dobara chalana safe (trigger drop+create, backfill sirf jo nahi hai). Polar :3400 NO-TOUCH.
set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = public, extensions;

create or replace function public.activity_from_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_kind text; v_label text;
begin
  if new.org_id is null then return new; end if;
  v_kind := case when new.direction::text = 'in' then 'message_received'
                 when new.direction::text = 'out' then 'message_sent' else null end;
  if v_kind is null then return new; end if;
  v_label := coalesce(nullif(trim(new.from_name), ''), nullif(trim(new.from_address), ''), 'mail');
  insert into public.activity_log (org_id, actor_label, kind, subject, detail, created_at)
  values (new.org_id, left(v_label, 120), v_kind,
          left(coalesce(nullif(trim(new.subject), ''), '(no subject)'), 200),
          case when v_kind = 'message_received' then 'Received' else 'Sent' end,
          coalesce(new.sent_at, now()));
  return new;
exception when others then
  -- activity likhne ka masla mail ko kabhi nahi rokta
  return new;
end $$;
revoke all on function public.activity_from_message() from public, anon, authenticated;

drop trigger if exists mail_messages_activity on public.mail_messages;
create trigger mail_messages_activity after insert on public.mail_messages
  for each row execute function public.activity_from_message();

-- backfill: pichle 30 din, jinki entry nahi
insert into public.activity_log (org_id, actor_label, kind, subject, detail, created_at)
select m.org_id,
       left(coalesce(nullif(trim(m.from_name), ''), nullif(trim(m.from_address), ''), 'mail'), 120),
       case when m.direction::text = 'in' then 'message_received' else 'message_sent' end,
       left(coalesce(nullif(trim(m.subject), ''), '(no subject)'), 200),
       case when m.direction::text = 'in' then 'Received' else 'Sent' end,
       m.sent_at
  from public.mail_messages m
 where m.org_id is not null
   and m.direction::text in ('in', 'out')
   and m.sent_at > now() - interval '30 days'
   and not exists (select 1 from public.activity_log a
                    where a.org_id = m.org_id
                      and a.kind = case when m.direction::text = 'in' then 'message_received' else 'message_sent' end
                      and a.created_at = m.sent_at
                      and a.subject = left(coalesce(nullif(trim(m.subject), ''), '(no subject)'), 200));
