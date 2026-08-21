-- ============================================================================
-- ANEXOCHAT · PHASE 11 — ATTACHMENTS + AVATARS (Supabase #4)
-- Idempotent + self-healing. Storage bucket `chat-media` (private, signed URLs).
-- Truth rule: row commit ke baad hi attachment dikhta hai.
-- ============================================================================

-- 0) private bucket ----------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-media', 'chat-media', false, 26214400,
        array['image/png','image/jpeg','image/webp','image/avif'])
on conflict (id) do update
  set public = false,
      file_size_limit = 26214400,
      allowed_mime_types = array['image/png','image/jpeg','image/webp','image/avif'];

-- 1) attachments -------------------------------------------------------------
do $$
begin
  if to_regclass('public.chat_attachments') is not null
     and not exists (
       select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'chat_attachments'
         and column_name = 'storage_path'
     )
  then
    execute 'alter table public.chat_attachments rename to chat_attachments_legacy_'
            || to_char(now(), 'YYYYMMDDHH24MISS');
  end if;
end $$;

create table if not exists public.chat_attachments (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  message_id      uuid references public.chat_messages(id) on delete cascade,
  uploader_id     uuid not null references auth.users(id) on delete cascade,
  filename        text not null,
  content_type    text not null,
  bytes           bigint not null default 0,
  width           int,
  height          int,
  storage_path    text not null,
  thumb_path      text,
  state           text not null default 'pending'
                  check (state in ('pending','ready','failed')),
  created_at      timestamptz not null default now(),
  committed_at    timestamptz
);

create index if not exists chat_attachments_conv_idx
  on public.chat_attachments (conversation_id, created_at desc);
create index if not exists chat_attachments_msg_idx
  on public.chat_attachments (message_id);

grant select, insert, update on public.chat_attachments to authenticated;
grant all on public.chat_attachments to service_role;

alter table public.chat_attachments enable row level security;

drop policy if exists chat_attachments_read on public.chat_attachments;
create policy chat_attachments_read on public.chat_attachments
for select to authenticated
using (
  exists (
    select 1 from public.chat_participants p
    where p.conversation_id = chat_attachments.conversation_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists chat_attachments_write on public.chat_attachments;
create policy chat_attachments_write on public.chat_attachments
for insert to authenticated
with check (
  uploader_id = auth.uid()
  and exists (
    select 1 from public.chat_participants p
    where p.conversation_id = chat_attachments.conversation_id
      and p.user_id = auth.uid()
  )
);

-- 2) avatar column on chat_members -------------------------------------------
do $$
begin
  if to_regclass('public.chat_members') is not null then
    alter table public.chat_members
      add column if not exists avatar_path text,
      add column if not exists avatar_updated_at timestamptz;
  end if;
end $$;

-- 3) RPCs --------------------------------------------------------------------
create or replace function public.chat_attachment_new(
  _user uuid,
  _conv uuid,
  _filename text,
  _content_type text,
  _bytes bigint,
  _width int,
  _height int
) returns table (attachment_id uuid, storage_path text, thumb_path text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := gen_random_uuid();
  v_path text;
  v_thumb text;
begin
  if not exists (
    select 1 from public.chat_participants p
    where p.conversation_id = _conv and p.user_id = _user
  ) then
    raise exception 'not_a_participant';
  end if;

  v_path  := _conv || '/' || v_id || '/original';
  v_thumb := _conv || '/' || v_id || '/thumb.webp';

  insert into public.chat_attachments (
    id, conversation_id, uploader_id, filename, content_type,
    bytes, width, height, storage_path, thumb_path, state
  ) values (
    v_id, _conv, _user, _filename, _content_type,
    coalesce(_bytes, 0), _width, _height, v_path, v_thumb, 'pending'
  );

  return query select v_id, v_path, v_thumb;
end $$;

create or replace function public.chat_attachment_commit(
  _user uuid,
  _attachment uuid,
  _width int,
  _height int
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_attachments
     set state = 'ready',
         committed_at = now(),
         width = coalesce(_width, width),
         height = coalesce(_height, height)
   where id = _attachment
     and uploader_id = _user;
  return found;
end $$;

/** Message ke saath attachments jodna — send ke baad ek call. */
create or replace function public.chat_attachment_attach(
  _user uuid,
  _message uuid,
  _ids uuid[]
) returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update public.chat_attachments
     set message_id = _message
   where id = any(_ids)
     and uploader_id = _user
     and message_id is null;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

create or replace function public.chat_avatar_set(
  _user uuid,
  _path text
) returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_members
     set avatar_path = _path,
         avatar_updated_at = now()
   where user_id = _user;
  return _path;
end $$;

grant execute on function public.chat_attachment_new(uuid, uuid, text, text, bigint, int, int)
  to authenticated, service_role;
grant execute on function public.chat_attachment_commit(uuid, uuid, int, int)
  to authenticated, service_role;
grant execute on function public.chat_attachment_attach(uuid, uuid, uuid[])
  to authenticated, service_role;
grant execute on function public.chat_avatar_set(uuid, text)
  to authenticated, service_role;
