-- e2e ke liye: asli mail_ingest ki nakal. Message org 1111... mein banata hai; `stub_cfg.make_rows` true ho to payload ke attachments ki
-- metadata rows bhi (jaisa live ingest karta ho to) — warna nahi (jaisa live par dikha: R1a mail mein chip nahi tha).
alter table mail_messages add column if not exists message_id text;
create table if not exists stub_cfg (k text primary key, v text);
insert into stub_cfg values ('make_rows','true') on conflict (k) do update set v = excluded.v;
create or replace function public.mail_ingest(payload jsonb) returns jsonb language plpgsql security definer as $$
declare m uuid := gen_random_uuid(); a jsonb;
begin
  if payload->>'envelope_to' like 'nobody%' then return jsonb_build_object('ok', true, 'quarantined', true, 'reason', 'unknown_recipient'); end if;
  insert into mail_messages(id, org_id, message_id) values (m, '11111111-1111-1111-1111-111111111111', payload->>'message_id');
  if (select v from stub_cfg where k = 'make_rows') = 'true' then
    for a in select * from jsonb_array_elements(coalesce(payload->'attachments', '[]'::jsonb)) loop
      insert into mail_attachments(message_id, filename, mime_type, size_bytes) values (m, a->>'filename', a->>'mime', (a->>'size')::bigint);
    end loop;
  end if;
  return jsonb_build_object('ok', true, 'org_id', '11111111-1111-1111-1111-111111111111', 'thread_id', gen_random_uuid(), 'message_id', m);
end $$;
