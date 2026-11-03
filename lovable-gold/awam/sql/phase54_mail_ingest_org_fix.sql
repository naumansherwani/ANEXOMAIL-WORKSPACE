-- ============================================================================
-- ANEXOMAIL — PHASE 54 · mail_ingest org/account fix (idempotent, self-healing)
--
--   Asli masla: legacy `mail_threads` / `mail_messages` mein `org_id` NOT NULL
--   hai, lekin `mail_ingest()` usay set nahi karta tha ->
--   'null value in column "org_id" ... violates not-null constraint'
--   aur Postfix pipe 75 par queue mein reh jaati thi.
--
--   Yeh patch:
--     1. org_id / account_id columns ensure karta hai (agar missing hon)
--     2. system org row ensure karta hai (ANEXOMAIL System — sirf fallback)
--     3. mail_ingest() ko dobara banata hai: org_id pehle mailbox ke
--        mail_accounts row se, warna system org se (kabhi null nahi)
--   Koi table drop nahi, koi mail delete nahi.
-- ============================================================================

set search_path = public, extensions;

-- 1) columns ---------------------------------------------------------------
alter table public.mail_threads  add column if not exists org_id     uuid;
alter table public.mail_threads  add column if not exists account_id uuid;
alter table public.mail_messages add column if not exists org_id     uuid;

-- 2) system org (sirf fallback ke liye) ------------------------------------
do $$
declare
  v_sys uuid := 'dbd5aef3-8d6d-415f-9b5b-8d32f0adce3a';
begin
  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'orgs') then
    if not exists (select 1 from public.orgs where id = v_sys) then
      begin
        insert into public.orgs (id, name) values (v_sys, 'ANEXOMAIL System');
      exception when others then
        -- schema thora mukhtalif ho to fallback row insert skip; org_id
        -- resolution phir bhi mail_accounts se chalti rahegi.
        null;
      end;
    end if;
  end if;
end $$;

-- 3) mail_ingest — org_id kabhi null nahi ----------------------------------
create or replace function public.mail_ingest(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_box    text := lower(coalesce(payload->>'envelope_to',''));
  v_subj   text := coalesce(nullif(trim(payload->>'subject'),''), '(no subject)');
  v_msgid  text := nullif(payload->>'message_id','');
  v_reply  text := nullif(payload->>'in_reply_to','');
  v_sent   timestamptz := coalesce((payload->>'sent_at')::timestamptz, now());
  v_sys    uuid := 'dbd5aef3-8d6d-415f-9b5b-8d32f0adce3a';
  v_org    uuid;
  v_acct   uuid;
  v_thread uuid;
  v_msg    uuid;
begin
  insert into public.mail_inbound_raw (envelope_from, envelope_to, raw_size, raw_sha256, headers)
  values (payload->>'envelope_from', v_box,
          coalesce((payload->>'raw_size')::int, 0), payload->>'raw_sha256',
          coalesce(payload->'headers','{}'::jsonb));

  -- mailbox ka asli owner: mail_accounts se (yahi sach hai)
  begin
    select a.id, a.org_id into v_acct, v_org
      from public.mail_accounts a
     where lower(a.address) = v_box
     limit 1;
  exception when undefined_table or undefined_column then
    v_acct := null; v_org := null;
  end;
  v_org := coalesce(v_org, v_sys);

  -- duplicate delivery (Postfix retry) — chup-chaap wahi message id wapas
  if v_msgid is not null then
    select id into v_msg from public.mail_messages where message_id = v_msgid;
    if v_msg is not null then
      return jsonb_build_object('ok', true, 'duplicate', true, 'message_id', v_msg);
    end if;
  end if;

  -- reply chain: pehle In-Reply-To se thread, warna subject+mailbox
  if v_reply is not null then
    select thread_id into v_thread from public.mail_messages where message_id = v_reply limit 1;
  end if;
  if v_thread is null then
    select id into v_thread from public.mail_threads
     where mailbox_address = v_box
       and subject = regexp_replace(v_subj, '^((re|fwd|fw)\s*:\s*)+', '', 'i')
       and last_message_at > now() - interval '30 days'
     order by last_message_at desc limit 1;
  end if;

  if v_thread is null then
    insert into public.mail_threads (org_id, account_id, mailbox_address, subject, snippet,
                                     from_name, from_address, message_count, unread, last_message_at)
    values (v_org, v_acct, v_box, regexp_replace(v_subj, '^((re|fwd|fw)\s*:\s*)+', '', 'i'),
            left(coalesce(payload->>'body_text',''), 180),
            payload->>'from_name', lower(coalesce(payload->>'from_address','unknown')),
            0, true, v_sent)
    returning id into v_thread;
  end if;

  insert into public.mail_messages (org_id, thread_id, direction, message_id, in_reply_to, from_name,
    from_address, to_addresses, cc_addresses, subject, body_text, body_html,
    spf_result, dkim_result, sent_at)
  values (v_org, v_thread, 'in', v_msgid, v_reply, payload->>'from_name',
    lower(coalesce(payload->>'from_address','unknown')),
    coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(payload->'to','[]'::jsonb)) x), array[v_box]),
    coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(payload->'cc','[]'::jsonb)) x), '{}'),
    v_subj, payload->>'body_text', payload->>'body_html',
    payload->>'spf', payload->>'dkim', v_sent)
  returning id into v_msg;

  update public.mail_threads
     set message_count = message_count + 1,
         unread = true,
         org_id = coalesce(org_id, v_org),
         snippet = left(coalesce(payload->>'body_text', snippet, ''), 180),
         last_message_at = greatest(last_message_at, v_sent)
   where id = v_thread;

  return jsonb_build_object('ok', true, 'thread_id', v_thread, 'message_id', v_msg,
                            'org_id', v_org);
end $$;

revoke all on function public.mail_ingest(jsonb) from public, anon, authenticated;
grant execute on function public.mail_ingest(jsonb) to service_role;

-- purani rows jinme org_id null reh gaya (queue se pehle wali koshishein)
update public.mail_threads  set org_id = 'dbd5aef3-8d6d-415f-9b5b-8d32f0adce3a' where org_id is null;
update public.mail_messages set org_id = 'dbd5aef3-8d6d-415f-9b5b-8d32f0adce3a' where org_id is null;
