-- ============================================================================
-- ANEXOChat — PHASE 3-6
--   PHASE 3  PostgreSQL message engine (reactions, edits, deletes, work items,
--            conversation state, delivery/read receipts, audit)
--   PHASE 4  SB4 data foundation (workspace_id har object par, isolation)
--   PHASE 5  RLS workspace privacy (DB boundary, frontend par bharosa nahi)
--   PHASE 6  ANEXOMAIL integration (unread truth for sidebar badge)
--
-- SUPABASE #4 SQL EDITOR mein poori file paste karo (idempotent + self-healing).
-- Pre-req: sql/anexochat_phase01_foundation.sql pehle chal chuki ho.
-- ============================================================================

-- ---------- 1) reactions ----------
create table if not exists public.chat_reactions (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  emoji      text not null check (char_length(emoji) between 1 and 16),
  at         timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

-- ---------- 2) edit history (append-only: purana body kabhi gum nahi) ----------
create table if not exists public.chat_message_edits (
  id          uuid primary key default gen_random_uuid(),
  message_id  uuid not null references public.chat_messages(id) on delete cascade,
  editor_id   uuid not null references auth.users(id) on delete cascade,
  old_body    text not null,
  new_body    text not null,
  at          timestamptz not null default now()
);
create index if not exists chat_message_edits_msg_idx on public.chat_message_edits (message_id, at desc);

-- ---------- 3) work objects: task / promise / decision ----------
create table if not exists public.chat_work_items (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  message_id      uuid references public.chat_messages(id) on delete set null,
  kind            text not null check (kind in ('task','promise','decision')),
  title           text not null,
  owner_user_id   uuid references auth.users(id) on delete set null,
  due_at          timestamptz,
  state           text not null default 'open' check (state in ('open','done','cancelled')),
  created_by      uuid not null references auth.users(id) on delete cascade,
  created_at      timestamptz not null default now(),
  closed_at       timestamptz
);
create index if not exists chat_work_items_conv_idx on public.chat_work_items (conversation_id, state, created_at desc);

-- ---------- 4) conversation state (per conversation, workspace-scoped) ----------
create table if not exists public.chat_conversation_state (
  conversation_id uuid primary key references public.chat_conversations(id) on delete cascade,
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  state           text not null default 'active' check (state in ('active','waiting','blocked','closed')),
  note            text,
  set_by          uuid references auth.users(id) on delete set null,
  updated_at      timestamptz not null default now()
);

-- ---------- 5) audit (kaun ne kya kiya — chup chaap kuch nahi) ----------
create table if not exists public.chat_audit (
  id           bigserial primary key,
  workspace_id uuid not null references public.chat_workspaces(id) on delete cascade,
  actor_id     uuid references auth.users(id) on delete set null,
  action       text not null,
  target       text,
  detail       jsonb,
  at           timestamptz not null default now()
);
create index if not exists chat_audit_ws_idx on public.chat_audit (workspace_id, at desc);

-- ---------- 6) GRANTS (Data API ke liye lazmi) ----------
grant select on public.chat_reactions, public.chat_message_edits, public.chat_work_items,
  public.chat_conversation_state, public.chat_audit to authenticated;
grant all on public.chat_reactions, public.chat_message_edits, public.chat_work_items,
  public.chat_conversation_state, public.chat_audit to service_role;

-- ---------- 7) RLS: workspace/participant boundary ----------
alter table public.chat_reactions          enable row level security;
alter table public.chat_message_edits      enable row level security;
alter table public.chat_work_items         enable row level security;
alter table public.chat_conversation_state enable row level security;
alter table public.chat_audit              enable row level security;

drop policy if exists chat_reactions_read on public.chat_reactions;
create policy chat_reactions_read on public.chat_reactions for select to authenticated
  using (exists (select 1 from public.chat_messages m
                 where m.id = message_id and public.chat_in_conversation(m.conversation_id, auth.uid())));

drop policy if exists chat_edits_read on public.chat_message_edits;
create policy chat_edits_read on public.chat_message_edits for select to authenticated
  using (exists (select 1 from public.chat_messages m
                 where m.id = message_id and public.chat_in_conversation(m.conversation_id, auth.uid())));

drop policy if exists chat_work_read on public.chat_work_items;
create policy chat_work_read on public.chat_work_items for select to authenticated
  using (public.chat_access(auth.uid()) and public.chat_in_conversation(conversation_id, auth.uid()));

drop policy if exists chat_convstate_read on public.chat_conversation_state;
create policy chat_convstate_read on public.chat_conversation_state for select to authenticated
  using (public.chat_in_conversation(conversation_id, auth.uid()));

drop policy if exists chat_audit_read on public.chat_audit;
create policy chat_audit_read on public.chat_audit for select to authenticated
  using (public.chat_is_member(workspace_id, auth.uid()));

-- ---------- 8) helper: audit likhna ----------
create or replace function public.chat_log(_ws uuid, _actor uuid, _action text, _target text, _detail jsonb)
returns void language sql security definer set search_path = public as $$
  insert into public.chat_audit (workspace_id, actor_id, action, target, detail)
  values (_ws, _actor, _action, _target, _detail);
$$;

-- ---------- 9) reaction toggle ----------
drop function if exists public.chat_react(uuid, uuid, text);
create or replace function public.chat_react(_msg uuid, _user uuid, _emoji text)
returns table (emoji text, count bigint, mine boolean)
language plpgsql security definer set search_path = public as $$
declare conv uuid; ws uuid;
begin
  select m.conversation_id, m.workspace_id into conv, ws from public.chat_messages m where m.id = _msg;
  if conv is null then raise exception 'message_not_found'; end if;
  if not public.chat_in_conversation(conv, _user) then raise exception 'not_participant'; end if;
  if coalesce(btrim(_emoji),'') = '' then raise exception 'emoji_required'; end if;

  if exists (select 1 from public.chat_reactions r
             where r.message_id = _msg and r.user_id = _user and r.emoji = _emoji) then
    delete from public.chat_reactions r
     where r.message_id = _msg and r.user_id = _user and r.emoji = _emoji;
  else
    insert into public.chat_reactions (message_id, user_id, emoji) values (_msg, _user, _emoji);
  end if;

  return query
    select r.emoji, count(*)::bigint, bool_or(r.user_id = _user)
      from public.chat_reactions r where r.message_id = _msg
     group by r.emoji order by 2 desc, 1;
end $$;

-- ---------- 10) edit (sirf sender, history hamesha) ----------
drop function if exists public.chat_edit_message(uuid, uuid, text);
create or replace function public.chat_edit_message(_msg uuid, _user uuid, _body text)
returns table (id uuid, body text, edited_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare m record;
begin
  select * into m from public.chat_messages where chat_messages.id = _msg;
  if m.id is null then raise exception 'message_not_found'; end if;
  if m.sender_user_id <> _user then raise exception 'only_sender_can_edit'; end if;
  if m.deleted_at is not null then raise exception 'message_deleted'; end if;
  if coalesce(btrim(_body),'') = '' then raise exception 'empty_body'; end if;

  insert into public.chat_message_edits (message_id, editor_id, old_body, new_body)
    values (_msg, _user, m.body, _body);
  update public.chat_messages set body = _body, edited_at = now() where chat_messages.id = _msg;
  perform public.chat_log(m.workspace_id, _user, 'message.edit', _msg::text, jsonb_build_object('seq', m.seq));

  return query select mm.id, mm.body, mm.edited_at from public.chat_messages mm where mm.id = _msg;
end $$;

-- ---------- 11) delete (soft, tombstone — jhoot nahi) ----------
drop function if exists public.chat_delete_message(uuid, uuid);
create or replace function public.chat_delete_message(_msg uuid, _user uuid)
returns table (id uuid, deleted_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare m record;
begin
  select * into m from public.chat_messages where chat_messages.id = _msg;
  if m.id is null then raise exception 'message_not_found'; end if;
  if m.sender_user_id <> _user then raise exception 'only_sender_can_delete'; end if;
  update public.chat_messages
     set deleted_at = now(), body = 'Message deleted by sender'
   where chat_messages.id = _msg;
  perform public.chat_log(m.workspace_id, _user, 'message.delete', _msg::text, jsonb_build_object('seq', m.seq));
  return query select mm.id, mm.deleted_at from public.chat_messages mm where mm.id = _msg;
end $$;

-- ---------- 12) work items: create / list / close ----------
drop function if exists public.chat_work_create(uuid, uuid, uuid, text, text, timestamptz);
create or replace function public.chat_work_create(
  _conv uuid, _user uuid, _msg uuid, _kind text, _title text, _due timestamptz default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare ws uuid; id uuid;
begin
  if not public.chat_in_conversation(_conv, _user) then raise exception 'not_participant'; end if;
  if _kind not in ('task','promise','decision') then raise exception 'bad_kind'; end if;
  if coalesce(btrim(_title),'') = '' then raise exception 'title_required'; end if;
  select c.workspace_id into ws from public.chat_conversations c where c.id = _conv;
  insert into public.chat_work_items (workspace_id, conversation_id, message_id, kind, title, owner_user_id, due_at, created_by)
    values (ws, _conv, _msg, _kind, _title, _user, _due, _user)
    returning chat_work_items.id into id;
  perform public.chat_log(ws, _user, 'work.create', id::text, jsonb_build_object('kind', _kind));
  return id;
end $$;

drop function if exists public.chat_work_list(uuid, uuid);
create or replace function public.chat_work_list(_conv uuid, _user uuid)
returns table (id uuid, kind text, title text, state text, due_at timestamptz,
               owner_user_id uuid, message_id uuid, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_in_conversation(_conv, _user) then raise exception 'not_participant'; end if;
  return query
    select w.id, w.kind, w.title, w.state, w.due_at, w.owner_user_id, w.message_id, w.created_at
      from public.chat_work_items w
     where w.conversation_id = _conv
     order by (w.state = 'open') desc, w.created_at desc;
end $$;

drop function if exists public.chat_work_set_state(uuid, uuid, text);
create or replace function public.chat_work_set_state(_item uuid, _user uuid, _state text)
returns boolean language plpgsql security definer set search_path = public as $$
declare w record;
begin
  select * into w from public.chat_work_items where chat_work_items.id = _item;
  if w.id is null then raise exception 'item_not_found'; end if;
  if not public.chat_in_conversation(w.conversation_id, _user) then raise exception 'not_participant'; end if;
  if _state not in ('open','done','cancelled') then raise exception 'bad_state'; end if;
  update public.chat_work_items
     set state = _state, closed_at = case when _state = 'open' then null else now() end
   where chat_work_items.id = _item;
  perform public.chat_log(w.workspace_id, _user, 'work.state', _item::text, jsonb_build_object('state', _state));
  return true;
end $$;

-- ---------- 13) conversation state ----------
drop function if exists public.chat_conversation_set_state(uuid, uuid, text, text);
create or replace function public.chat_conversation_set_state(_conv uuid, _user uuid, _state text, _note text default null)
returns table (state text, note text, updated_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare ws uuid;
begin
  if not public.chat_in_conversation(_conv, _user) then raise exception 'not_participant'; end if;
  if _state not in ('active','waiting','blocked','closed') then raise exception 'bad_state'; end if;
  select c.workspace_id into ws from public.chat_conversations c where c.id = _conv;
  insert into public.chat_conversation_state (conversation_id, workspace_id, state, note, set_by, updated_at)
    values (_conv, ws, _state, _note, _user, now())
  on conflict (conversation_id) do update
    set state = excluded.state, note = excluded.note, set_by = excluded.set_by, updated_at = now();
  perform public.chat_log(ws, _user, 'conversation.state', _conv::text, jsonb_build_object('state', _state));
  return query select s.state, s.note, s.updated_at
    from public.chat_conversation_state s where s.conversation_id = _conv;
end $$;

-- ---------- 14) PHASE 6: unread truth for the ANEXOMAIL sidebar badge ----------
drop function if exists public.chat_unread_total(uuid);
create or replace function public.chat_unread_total(_user uuid)
returns table (unread bigint, conversations bigint)
language sql security definer set search_path = public as $$
  with mine as (
    select p.conversation_id, p.last_read_seq
      from public.chat_participants p
     where p.user_id = _user
  ), counted as (
    select mine.conversation_id,
           count(m.id) filter (
             where m.seq > mine.last_read_seq
               and m.sender_user_id <> _user
               and m.deleted_at is null
           ) as n
      from mine
      left join public.chat_messages m on m.conversation_id = mine.conversation_id
     group by mine.conversation_id
  )
  select coalesce(sum(n),0)::bigint, count(*) filter (where n > 0)::bigint from counted;
$$;

-- ---------- VERIFY ----------
-- tables (expect 16):
--   select count(*) from information_schema.tables
--    where table_schema='public' and table_name like 'chat\_%';
-- functions (expect 19):
--   select count(*) from information_schema.routines
--    where routine_schema='public' and routine_name like 'chat\_%';
