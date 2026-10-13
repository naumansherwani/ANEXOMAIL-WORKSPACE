-- ============================================================================
-- ANEXOChat · PHASE 11B — attachment_count flag on message rows
-- (Phase 11 — NEW ADDED, idempotent + self-healing)
--
-- chat_messages_page ab har message ke saath `attachment_count` bhejta hai
-- (sirf state='ready' attachments). Frontend isi flag par gallery kholta hai —
-- kisi message ke liye bina wajah attachments fetch nahi hote.
--
-- Run: Supabase #4 SQL Editor mein poora block paste karo.
-- ============================================================================

begin;

drop function if exists public.chat_messages_page(uuid, uuid, bigint, integer);

create or replace function public.chat_messages_page(
  _conv uuid, _me uuid, _before_seq bigint default null, _limit integer default 80
) returns table (
  id uuid, seq bigint, body text, sender_user_id uuid, sender_name text,
  mine boolean, device_label text, transport text,
  created_at timestamptz, edited_at timestamptz,
  delivered_at timestamptz, read_at timestamptz,
  reply_to_id uuid, reply_to_body text, reply_to_sender text,
  pinned_at timestamptz, reactions jsonb,
  attachment_count bigint
) language sql stable security definer set search_path = public as $$
  select m.id, m.seq, m.body, m.sender_user_id,
         coalesce(mem.display_name, 'Teammate') as sender_name,
         (m.sender_user_id = _me) as mine,
         m.device_label, m.transport, m.created_at, m.edited_at,
         (select min(r.at) from public.chat_message_receipts r
           where r.message_id = m.id and r.state = 'delivered') as delivered_at,
         (select min(r.at) from public.chat_message_receipts r
           where r.message_id = m.id and r.state = 'read') as read_at,
         m.reply_to_id,
         (select left(p.body, 160) from public.chat_messages p where p.id = m.reply_to_id) as reply_to_body,
         (select coalesce(pm.display_name, 'Teammate') from public.chat_messages p
            left join public.chat_members pm
              on pm.workspace_id = p.workspace_id and pm.user_id = p.sender_user_id
           where p.id = m.reply_to_id) as reply_to_sender,
         m.pinned_at,
         coalesce((
           select jsonb_agg(x order by x->>'emoji')
             from (
               select jsonb_build_object(
                        'emoji', r.emoji,
                        'count', count(*),
                        'mine', bool_or(r.user_id = _me)) as x
                 from public.chat_reactions r
                where r.message_id = m.id
                group by r.emoji) g
         ), '[]'::jsonb) as reactions,
         (select count(*) from public.chat_attachments a
           where a.message_id = m.id and a.state = 'ready') as attachment_count
    from public.chat_messages m
    left join public.chat_members mem
      on mem.workspace_id = m.workspace_id and mem.user_id = m.sender_user_id
   where m.conversation_id = _conv
     and public.chat_in_conversation(_conv, _me)
     and m.deleted_at is null
     and (_before_seq is null or m.seq < _before_seq)
   order by m.seq desc
   limit greatest(1, least(coalesce(_limit,80), 300))
$$;

-- verify: function nayi shape ke saath mojood ho
select routine_name, data_type
  from information_schema.routines
 where routine_schema = 'public' and routine_name = 'chat_messages_page';

commit;
