-- ============================================================================
-- ANEXOChat · PHASE 7-10  (Core UI · Messenger parity · States · Edit/Delete)
--   + ANEXOVideoChat signalling (Business Pro only)
-- Supabase #4 · idempotent + self-healing · GRANTs + RLS + plan gate
--
-- SQL EDITOR: poori file select karke paste karo (Phase 1 + Phase 3 pehle chal chuki hain)
--
-- FOUNDER LOCK:
--   1. Edit window = 5 minute (DB enforce). Uske baad 'edit_window_closed'.
--   2. Delete for everyone = 1 ghanta (DB enforce) -> tombstone, hard delete nahi.
--   3. Delete for me = sirf us user ki nazar se hide (audit intact).
--   4. Video call = chat_video_allowed(): founder + business_pro. Baki 403.
--   5. Sending/Sent/Delivered/Read kabhi merge nahi — receipts hi sach hain.
-- ============================================================================

-- ---------- 1) message columns: reply / pin ----------
alter table public.chat_messages add column if not exists reply_to_id uuid
  references public.chat_messages(id) on delete set null;
alter table public.chat_messages add column if not exists pinned_at timestamptz;
alter table public.chat_messages add column if not exists pinned_by uuid;

-- ---------- 2) participant prefs: mute / archive ----------
alter table public.chat_participants add column if not exists muted_until timestamptz;
alter table public.chat_participants add column if not exists archived_at timestamptz;

-- ---------- 3) delete for me (per-user hide) ----------
create table if not exists public.chat_message_hidden (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  at         timestamptz not null default now(),
  primary key (message_id, user_id)
);
grant select, insert, delete on public.chat_message_hidden to authenticated;
grant all on public.chat_message_hidden to service_role;
alter table public.chat_message_hidden enable row level security;
drop policy if exists chat_hidden_own on public.chat_message_hidden;
create policy chat_hidden_own on public.chat_message_hidden for select to authenticated
  using (user_id = auth.uid());

-- ---------- 4) ANEXOVideoChat signalling (WebRTC P2P, Business Pro) ----------
create table if not exists public.chat_signals (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  from_user       uuid not null references auth.users(id) on delete cascade,
  to_user         uuid not null references auth.users(id) on delete cascade,
  kind            text not null check (kind in ('offer','answer','ice','end','ring')),
  payload         jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  consumed_at     timestamptz
);
create index if not exists chat_signals_inbox on public.chat_signals (to_user, consumed_at, created_at);
grant select on public.chat_signals to authenticated;
grant all on public.chat_signals to service_role;
alter table public.chat_signals enable row level security;
drop policy if exists chat_signals_own on public.chat_signals;
create policy chat_signals_own on public.chat_signals for select to authenticated
  using (to_user = auth.uid() or from_user = auth.uid());

-- ---------- 5) video plan gate: founder + business_pro only ----------
create or replace function public.chat_video_allowed(_user_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare ok boolean := false; p text;
begin
  if _user_id is null then return false; end if;
  if to_regclass('public.founder_accounts') is not null then
    execute 'select exists(select 1 from public.founder_accounts where user_id = $1)'
      into ok using _user_id;
    if ok then return true; end if;
  end if;
  if to_regclass('public.entitlement_state') is not null then
    execute 'select plan from public.entitlement_state where user_id = $1
             order by updated_at desc nulls last limit 1' into p using _user_id;
    return coalesce(p,'') = 'business_pro';
  end if;
  return false;
end $$;

create or replace function public.chat_signal_send(
  _conv uuid, _from uuid, _to uuid, _kind text, _payload jsonb
) returns uuid language plpgsql security definer set search_path = public as $$
declare ws uuid; sid uuid;
begin
  if not public.chat_video_allowed(_from) then raise exception 'video_not_entitled'; end if;
  if not public.chat_in_conversation(_conv, _from) then raise exception 'not_participant'; end if;
  if not public.chat_in_conversation(_conv, _to) then raise exception 'peer_not_participant'; end if;
  select c.workspace_id into ws from public.chat_conversations c where c.id = _conv;
  insert into public.chat_signals (conversation_id, from_user, to_user, kind, payload)
    values (_conv, _from, _to, _kind, coalesce(_payload, '{}'::jsonb)) returning id into sid;
  perform public.chat_log(ws, _from, 'video.' || _kind, _conv::text, jsonb_build_object('to', _to));
  return sid;
end $$;

create or replace function public.chat_signal_poll(_conv uuid, _user uuid)
returns table (id uuid, from_user uuid, kind text, payload jsonb, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_video_allowed(_user) then raise exception 'video_not_entitled'; end if;
  return query
    update public.chat_signals s set consumed_at = now()
     where s.to_user = _user and s.consumed_at is null
       and (_conv is null or s.conversation_id = _conv)
       and s.created_at > now() - interval '2 minutes'
    returning s.id, s.from_user, s.kind, s.payload, s.created_at;
end $$;

-- ---------- 6) send with reply-to (idempotent, ordered) ----------
drop function if exists public.chat_send(uuid, uuid, text, text, text);
drop function if exists public.chat_send(uuid, uuid, text, text, text, uuid);
create or replace function public.chat_send(
  _conv uuid, _sender uuid, _client_msg_id text, _body text,
  _device text default null, _reply_to uuid default null
) returns table (id uuid, seq bigint, created_at timestamptz, duplicate boolean)
language plpgsql security definer set search_path = public as $$
declare ws uuid; s bigint; m record;
begin
  if not public.chat_in_conversation(_conv, _sender) then raise exception 'not_participant'; end if;
  if coalesce(btrim(_body),'') = '' then raise exception 'empty_body'; end if;
  if coalesce(btrim(_client_msg_id),'') = '' then raise exception 'client_msg_id_required'; end if;

  select mm.id, mm.seq, mm.created_at into m from public.chat_messages mm
   where mm.conversation_id = _conv and mm.client_msg_id = _client_msg_id;
  if m.id is not null then
    return query select m.id, m.seq, m.created_at, true;
    return;
  end if;

  update public.chat_conversations c set next_seq = c.next_seq + 1, last_message_at = now()
    where c.id = _conv returning c.next_seq - 1, c.workspace_id into s, ws;

  insert into public.chat_messages (conversation_id, workspace_id, sender_user_id,
      client_msg_id, seq, body, device_label, reply_to_id)
    values (_conv, ws, _sender, _client_msg_id, s, _body, _device, _reply_to)
    returning chat_messages.id, chat_messages.seq, chat_messages.created_at
    into m;

  update public.chat_participants p
     set last_read_seq = greatest(p.last_read_seq, s),
         last_delivered_seq = greatest(p.last_delivered_seq, s)
   where p.conversation_id = _conv and p.user_id = _sender;

  return query select m.id, m.seq, m.created_at, false;
end $$;

-- ---------- 7) PHASE 10: edit window = 5 minutes ----------
create or replace function public.chat_edit_message(_msg uuid, _user uuid, _body text)
returns table (id uuid, body text, edited_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare m record;
begin
  select * into m from public.chat_messages where chat_messages.id = _msg;
  if m.id is null then raise exception 'message_not_found'; end if;
  if m.sender_user_id <> _user then raise exception 'only_sender_can_edit'; end if;
  if m.deleted_at is not null then raise exception 'message_deleted'; end if;
  if m.created_at < now() - interval '5 minutes' then raise exception 'edit_window_closed'; end if;
  if coalesce(btrim(_body),'') = '' then raise exception 'empty_body'; end if;

  insert into public.chat_message_edits (message_id, editor_id, old_body, new_body)
    values (_msg, _user, m.body, _body);
  update public.chat_messages set body = _body, edited_at = now() where chat_messages.id = _msg;
  perform public.chat_log(m.workspace_id, _user, 'message.edit', _msg::text, jsonb_build_object('seq', m.seq));
  return query select mm.id, mm.body, mm.edited_at from public.chat_messages mm where mm.id = _msg;
end $$;

-- ---------- 8) PHASE 10: delete for everyone = 1 hour window ----------
create or replace function public.chat_delete_message(_msg uuid, _user uuid)
returns table (id uuid, deleted_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare m record;
begin
  select * into m from public.chat_messages where chat_messages.id = _msg;
  if m.id is null then raise exception 'message_not_found'; end if;
  if m.sender_user_id <> _user then raise exception 'only_sender_can_delete'; end if;
  if m.created_at < now() - interval '1 hour' then raise exception 'delete_window_closed'; end if;
  update public.chat_messages
     set deleted_at = now(), body = 'Message deleted by sender'
   where chat_messages.id = _msg;
  perform public.chat_log(m.workspace_id, _user, 'message.delete', _msg::text, jsonb_build_object('seq', m.seq));
  return query select mm.id, mm.deleted_at from public.chat_messages mm where mm.id = _msg;
end $$;

-- ---------- 9) delete for me (view-only hide, audit intact) ----------
create or replace function public.chat_message_hide(_msg uuid, _user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare c uuid;
begin
  select conversation_id into c from public.chat_messages where id = _msg;
  if c is null then raise exception 'message_not_found'; end if;
  if not public.chat_in_conversation(c, _user) then raise exception 'not_participant'; end if;
  insert into public.chat_message_hidden (message_id, user_id) values (_msg, _user)
    on conflict do nothing;
  return true;
end $$;

-- ---------- 10) pin / unpin ----------
create or replace function public.chat_pin_message(_msg uuid, _user uuid, _pin boolean)
returns table (id uuid, pinned_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare m record;
begin
  select * into m from public.chat_messages where chat_messages.id = _msg;
  if m.id is null then raise exception 'message_not_found'; end if;
  if not public.chat_in_conversation(m.conversation_id, _user) then raise exception 'not_participant'; end if;
  update public.chat_messages
     set pinned_at = case when _pin then now() else null end,
         pinned_by = case when _pin then _user else null end
   where chat_messages.id = _msg;
  return query select mm.id, mm.pinned_at from public.chat_messages mm where mm.id = _msg;
end $$;

-- ---------- 11) mute / archive prefs ----------
create or replace function public.chat_conversation_prefs(
  _conv uuid, _user uuid, _mute_minutes integer default null, _archived boolean default null
) returns table (muted_until timestamptz, archived_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_in_conversation(_conv, _user) then raise exception 'not_participant'; end if;
  update public.chat_participants p
     set muted_until = case
           when _mute_minutes is null then p.muted_until
           when _mute_minutes <= 0 then null
           else now() + make_interval(mins => _mute_minutes) end,
         archived_at = case
           when _archived is null then p.archived_at
           when _archived then now() else null end
   where p.conversation_id = _conv and p.user_id = _user;
  return query select p.muted_until, p.archived_at from public.chat_participants p
    where p.conversation_id = _conv and p.user_id = _user;
end $$;

-- ---------- 12) messages page v2: reply + pin + reactions, hidden excluded ----------
drop function if exists public.chat_messages_page(uuid, uuid, bigint, integer);
create or replace function public.chat_messages_page(
  _conv uuid, _me uuid, _before_seq bigint default null, _limit integer default 80
) returns table (
  id uuid, seq bigint, body text, sender_user_id uuid, sender_name text,
  mine boolean, device_label text, transport text,
  created_at timestamptz, edited_at timestamptz,
  delivered_at timestamptz, read_at timestamptz,
  reply_to_id uuid, reply_to_body text, reply_to_sender text,
  pinned_at timestamptz, reactions jsonb
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
         ), '[]'::jsonb) as reactions
    from public.chat_messages m
    left join public.chat_members mem
      on mem.workspace_id = m.workspace_id and mem.user_id = m.sender_user_id
   where m.conversation_id = _conv
     and public.chat_in_conversation(_conv, _me)
     and m.deleted_at is null
     and not exists (select 1 from public.chat_message_hidden h
                      where h.message_id = m.id and h.user_id = _me)
     and (_before_seq is null or m.seq < _before_seq)
   order by m.seq desc
   limit greatest(1, least(coalesce(_limit,80), 300))
$$;

-- ---------- 13) search (workspace-wide, membership enforced) ----------
create or replace function public.chat_search_messages(_user uuid, _q text, _limit integer default 40)
returns table (
  id uuid, conversation_id uuid, seq bigint, body text,
  sender_name text, created_at timestamptz
) language sql stable security definer set search_path = public as $$
  select m.id, m.conversation_id, m.seq, m.body,
         coalesce(mem.display_name, 'Teammate'), m.created_at
    from public.chat_messages m
    join public.chat_participants p
      on p.conversation_id = m.conversation_id and p.user_id = _user
    left join public.chat_members mem
      on mem.workspace_id = m.workspace_id and mem.user_id = m.sender_user_id
   where public.chat_access(_user)
     and m.deleted_at is null
     and coalesce(btrim(_q),'') <> ''
     and m.body ilike '%' || btrim(_q) || '%'
     and not exists (select 1 from public.chat_message_hidden h
                      where h.message_id = m.id and h.user_id = _user)
   order by m.created_at desc
   limit greatest(1, least(coalesce(_limit,40), 200))
$$;

-- ---------- verify ----------
-- select count(*) from information_schema.tables
--  where table_schema='public' and table_name like 'chat\_%';                 -- 18
-- select count(*) from information_schema.routines
--  where routine_schema='public' and routine_name like 'chat\_%';             -- 27
-- select public.chat_video_allowed('<founder-uuid>');                          -- true
