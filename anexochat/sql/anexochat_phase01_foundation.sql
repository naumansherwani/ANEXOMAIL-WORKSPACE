-- ============================================================================
-- ANEXOChat — PHASE 1 SLICE (Blueprint Phases 1-5 foundation)
-- Supabase #4 · idempotent + self-healing · GRANTs + RLS + plan gate
--
-- FOUNDER LOCK:
--   1. Truth DB mein — UI kabhi state invent nahi karta
--   2. Message states append-only: sending(client) -> sent(db) -> delivered -> read
--   3. Idempotency: unique(conversation_id, client_msg_id) — duplicate send never
--   4. Ordering: per-conversation monotonic seq (no clock trust)
--   5. Gate: chat_access() = founder_accounts OR business/business_pro/AI plan
--      Basic/Pro = ZERO access
--   6. Files: chunk + sha256 checksum rows abhi (resume truth), engine Slice-2
-- ============================================================================

-- ---------- 0) self-heal: purani conflicting tables ko legacy karo ----------
do $$
begin
  if to_regclass('public.chat_messages') is not null
     and not exists (
       select 1 from information_schema.columns
       where table_schema='public' and table_name='chat_messages' and column_name='client_msg_id'
     ) then
    execute 'alter table public.chat_messages rename to chat_messages_legacy';
  end if;
end $$;

-- ---------- 1) workspace + membership ----------
create table if not exists public.chat_workspaces (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null default now()
);

create table if not exists public.chat_members (
  workspace_id uuid not null references public.chat_workspaces(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  display_name text,
  role         text not null default 'member' check (role in ('owner','admin','member')),
  created_at   timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

-- ---------- 2) conversations ----------
create table if not exists public.chat_conversations (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  kind            text not null default 'direct' check (kind in ('direct','group')),
  subject         text,
  created_by      uuid not null references auth.users(id) on delete cascade,
  direct_key      text,
  last_message_at timestamptz,
  next_seq        bigint not null default 1,
  created_at      timestamptz not null default now()
);
create unique index if not exists chat_conversations_direct_uq
  on public.chat_conversations (workspace_id, direct_key)
  where direct_key is not null;

create table if not exists public.chat_participants (
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  last_read_seq   bigint not null default 0,
  last_delivered_seq bigint not null default 0,
  joined_at       timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

-- ---------- 3) messages (durable truth) ----------
create table if not exists public.chat_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  sender_user_id  uuid not null references auth.users(id) on delete cascade,
  client_msg_id   text not null,
  seq             bigint not null,
  body            text not null,
  device_label    text,
  transport       text not null default 'bun' check (transport in ('bun','wt','realtime')),
  created_at      timestamptz not null default now(),
  edited_at       timestamptz,
  deleted_at      timestamptz,
  unique (conversation_id, client_msg_id),
  unique (conversation_id, seq)
);
create index if not exists chat_messages_conv_seq_idx
  on public.chat_messages (conversation_id, seq desc);

-- append-only receipts: delivered / read
create table if not exists public.chat_message_receipts (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  state      text not null check (state in ('delivered','read')),
  at         timestamptz not null default now(),
  primary key (message_id, user_id, state)
);

-- ---------- 4) presence + typing (truth only, never guessed) ----------
create table if not exists public.chat_presence (
  workspace_id uuid not null references public.chat_workspaces(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  device_label text,
  last_seen_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table if not exists public.chat_typing (
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  until           timestamptz not null,
  primary key (conversation_id, user_id)
);

-- ---------- 5) files: resumable chunk + checksum truth ----------
create table if not exists public.chat_files (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  uploader_id     uuid not null references auth.users(id) on delete cascade,
  filename        text not null,
  size_bytes      bigint not null check (size_bytes >= 0 and size_bytes <= 5368709120),
  sha256          text,
  chunk_size      integer not null default 8388608,
  chunks_total    integer not null,
  state           text not null default 'pending'
                  check (state in ('pending','uploading','verifying','complete','failed')),
  created_at      timestamptz not null default now(),
  completed_at    timestamptz
);

create table if not exists public.chat_file_chunks (
  file_id     uuid not null references public.chat_files(id) on delete cascade,
  chunk_index integer not null,
  size_bytes  integer not null,
  sha256      text not null,
  received_at timestamptz not null default now(),
  primary key (file_id, chunk_index)
);

-- ---------- 6) atmosphere: API-FREE (manual only, no weather data ever) ----------
create table if not exists public.chat_atmosphere_prefs (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  -- Dawn/Day/Dusk/Night device clock se aata hai — DB mein store nahi hota.
  effect      text not null default 'none' check (effect in ('none','rain','storm','snow','sunny')),
  calm_mode   boolean not null default false,
  updated_at  timestamptz not null default now()
);

-- ---------- 7) GRANTS (Data API ke liye lazmi) ----------
grant select on public.chat_workspaces, public.chat_members, public.chat_conversations,
  public.chat_participants, public.chat_messages, public.chat_message_receipts,
  public.chat_presence, public.chat_typing, public.chat_files, public.chat_file_chunks
  to authenticated;
grant select, insert, update on public.chat_atmosphere_prefs to authenticated;
grant all on public.chat_workspaces, public.chat_members, public.chat_conversations,
  public.chat_participants, public.chat_messages, public.chat_message_receipts,
  public.chat_presence, public.chat_typing, public.chat_files, public.chat_file_chunks,
  public.chat_atmosphere_prefs to service_role;

-- ---------- 8) plan gate: founder OR business/business_pro/AI ----------
create or replace function public.chat_access(_user_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare ok boolean := false; pl text;
begin
  if _user_id is null then return false; end if;
  -- founder ko hamesha access (FOUNDER 100% ACCESS RULE)
  if to_regclass('public.founder_accounts') is not null then
    execute 'select exists(select 1 from public.founder_accounts where user_id = $1)'
      into ok using _user_id;
    if ok then return true; end if;
  end if;
  if to_regclass('public.entitlement_state') is not null then
    execute 'select plan from public.entitlement_state where user_id = $1
             and (active_until is null or active_until > now())'
      into pl using _user_id;
    return coalesce(pl,'') in ('business','business_pro','ai_pro','ai_business','ai_executive');
  end if;
  return false;
end $$;

create or replace function public.chat_in_conversation(_conv uuid, _user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.chat_participants p
    where p.conversation_id = _conv and p.user_id = _user
  )
$$;

create or replace function public.chat_is_member(_ws uuid, _user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.chat_members m where m.workspace_id = _ws and m.user_id = _user
  )
$$;

-- ---------- 9) RLS: workspace boundary at the database ----------
alter table public.chat_workspaces        enable row level security;
alter table public.chat_members           enable row level security;
alter table public.chat_conversations     enable row level security;
alter table public.chat_participants      enable row level security;
alter table public.chat_messages          enable row level security;
alter table public.chat_message_receipts  enable row level security;
alter table public.chat_presence          enable row level security;
alter table public.chat_typing            enable row level security;
alter table public.chat_files             enable row level security;
alter table public.chat_file_chunks       enable row level security;
alter table public.chat_atmosphere_prefs  enable row level security;

drop policy if exists chat_ws_read on public.chat_workspaces;
create policy chat_ws_read on public.chat_workspaces for select to authenticated
  using (public.chat_access(auth.uid()) and public.chat_is_member(id, auth.uid()));

drop policy if exists chat_members_read on public.chat_members;
create policy chat_members_read on public.chat_members for select to authenticated
  using (public.chat_access(auth.uid()) and public.chat_is_member(workspace_id, auth.uid()));

drop policy if exists chat_conv_read on public.chat_conversations;
create policy chat_conv_read on public.chat_conversations for select to authenticated
  using (public.chat_access(auth.uid()) and public.chat_in_conversation(id, auth.uid()));

drop policy if exists chat_part_read on public.chat_participants;
create policy chat_part_read on public.chat_participants for select to authenticated
  using (public.chat_access(auth.uid()) and public.chat_in_conversation(conversation_id, auth.uid()));

drop policy if exists chat_msg_read on public.chat_messages;
create policy chat_msg_read on public.chat_messages for select to authenticated
  using (public.chat_access(auth.uid()) and public.chat_in_conversation(conversation_id, auth.uid()));

drop policy if exists chat_receipt_read on public.chat_message_receipts;
create policy chat_receipt_read on public.chat_message_receipts for select to authenticated
  using (exists (
    select 1 from public.chat_messages m
    where m.id = message_id and public.chat_in_conversation(m.conversation_id, auth.uid())
  ));

drop policy if exists chat_presence_read on public.chat_presence;
create policy chat_presence_read on public.chat_presence for select to authenticated
  using (public.chat_is_member(workspace_id, auth.uid()));

drop policy if exists chat_typing_read on public.chat_typing;
create policy chat_typing_read on public.chat_typing for select to authenticated
  using (public.chat_in_conversation(conversation_id, auth.uid()));

drop policy if exists chat_files_read on public.chat_files;
create policy chat_files_read on public.chat_files for select to authenticated
  using (public.chat_in_conversation(conversation_id, auth.uid()));

drop policy if exists chat_chunks_read on public.chat_file_chunks;
create policy chat_chunks_read on public.chat_file_chunks for select to authenticated
  using (exists (
    select 1 from public.chat_files f
    where f.id = file_id and public.chat_in_conversation(f.conversation_id, auth.uid())
  ));

drop policy if exists chat_atm_own on public.chat_atmosphere_prefs;
create policy chat_atm_own on public.chat_atmosphere_prefs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- 10) workspace bootstrap ----------
drop function if exists public.chat_ensure_workspace(uuid, text);
create or replace function public.chat_ensure_workspace(_user uuid, _name text default 'Workspace')
returns uuid language plpgsql security definer set search_path = public as $$
declare ws uuid;
begin
  if not public.chat_access(_user) then raise exception 'chat_not_entitled'; end if;
  select workspace_id into ws from public.chat_members where user_id = _user
    order by created_at limit 1;
  if ws is not null then return ws; end if;
  insert into public.chat_workspaces (name, owner_user_id) values (coalesce(_name,'Workspace'), _user)
    returning id into ws;
  insert into public.chat_members (workspace_id, user_id, role) values (ws, _user, 'owner')
    on conflict do nothing;
  return ws;
end $$;

-- ---------- 11) direct conversation (idempotent) ----------
drop function if exists public.chat_direct_conversation(uuid, uuid, uuid);
create or replace function public.chat_direct_conversation(_ws uuid, _me uuid, _other uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare k text; c uuid;
begin
  if not public.chat_is_member(_ws, _me) then raise exception 'not_workspace_member'; end if;
  if not public.chat_is_member(_ws, _other) then raise exception 'other_not_member'; end if;
  k := least(_me::text, _other::text) || ':' || greatest(_me::text, _other::text);
  select id into c from public.chat_conversations where workspace_id = _ws and direct_key = k;
  if c is not null then return c; end if;
  insert into public.chat_conversations (workspace_id, kind, created_by, direct_key)
    values (_ws, 'direct', _me, k) returning id into c;
  insert into public.chat_participants (conversation_id, user_id) values (c, _me), (c, _other)
    on conflict do nothing;
  return c;
end $$;

-- ---------- 12) send: idempotent + ordered ----------
drop function if exists public.chat_send(uuid, uuid, text, text, text);
create or replace function public.chat_send(
  _conv uuid, _sender uuid, _client_msg_id text, _body text, _device text default null
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
      client_msg_id, seq, body, device_label)
    values (_conv, ws, _sender, _client_msg_id, s, _body, _device)
    returning chat_messages.id, chat_messages.seq, chat_messages.created_at
    into m;

  update public.chat_participants p
     set last_read_seq = greatest(p.last_read_seq, s),
         last_delivered_seq = greatest(p.last_delivered_seq, s)
   where p.conversation_id = _conv and p.user_id = _sender;

  return query select m.id, m.seq, m.created_at, false;
end $$;

-- ---------- 13) receipts ----------
drop function if exists public.chat_mark(uuid, uuid, text, bigint);
create or replace function public.chat_mark(_conv uuid, _user uuid, _state text, _upto bigint)
returns bigint language plpgsql security definer set search_path = public as $$
declare n bigint := 0;
begin
  if not public.chat_in_conversation(_conv, _user) then raise exception 'not_participant'; end if;
  if _state not in ('delivered','read') then raise exception 'bad_state'; end if;

  insert into public.chat_message_receipts (message_id, user_id, state)
  select m.id, _user, _state from public.chat_messages m
   where m.conversation_id = _conv and m.seq <= _upto and m.sender_user_id <> _user
  on conflict do nothing;
  get diagnostics n = row_count;

  if _state = 'read' then
    update public.chat_participants p
       set last_read_seq = greatest(p.last_read_seq, _upto),
           last_delivered_seq = greatest(p.last_delivered_seq, _upto)
     where p.conversation_id = _conv and p.user_id = _user;
  else
    update public.chat_participants p
       set last_delivered_seq = greatest(p.last_delivered_seq, _upto)
     where p.conversation_id = _conv and p.user_id = _user;
  end if;
  return n;
end $$;

-- ---------- 14) conversation list + truthful health ----------
drop function if exists public.chat_conversation_list(uuid, uuid);
create or replace function public.chat_conversation_list(_ws uuid, _me uuid)
returns table (
  conversation_id uuid, kind text, subject text,
  other_user_id uuid, other_name text,
  last_body text, last_seq bigint, last_at timestamptz, last_mine boolean,
  unread bigint, other_read_seq bigint,
  health text, health_reason text
) language sql stable security definer set search_path = public as $$
  with mine as (
    select p.conversation_id, p.last_read_seq
      from public.chat_participants p where p.user_id = _me
  ),
  conv as (
    select c.* from public.chat_conversations c
     join mine on mine.conversation_id = c.id
     where c.workspace_id = _ws
  ),
  other as (
    select p.conversation_id, p.user_id, p.last_read_seq,
           coalesce(m.display_name, 'Teammate') as name
      from public.chat_participants p
      join conv on conv.id = p.conversation_id
      left join public.chat_members m
        on m.workspace_id = conv.workspace_id and m.user_id = p.user_id
     where p.user_id <> _me
  ),
  last_msg as (
    select distinct on (x.conversation_id) x.conversation_id, x.body, x.seq, x.created_at,
           x.sender_user_id
      from public.chat_messages x
      join conv on conv.id = x.conversation_id
     where x.deleted_at is null
     order by x.conversation_id, x.seq desc
  )
  select conv.id, conv.kind, conv.subject,
         other.user_id, other.name,
         last_msg.body, last_msg.seq, last_msg.created_at,
         (last_msg.sender_user_id = _me) as last_mine,
         (select count(*) from public.chat_messages z
            where z.conversation_id = conv.id and z.sender_user_id <> _me
              and z.seq > mine.last_read_seq and z.deleted_at is null) as unread,
         other.last_read_seq,
         case
           when last_msg.seq is null then 'green'
           when last_msg.sender_user_id = _me
                and coalesce(other.last_read_seq,0) < last_msg.seq
                and last_msg.created_at < now() - interval '24 hours' then 'red'
           when last_msg.sender_user_id = _me
                and coalesce(other.last_read_seq,0) < last_msg.seq then 'amber'
           when last_msg.sender_user_id <> _me and last_msg.seq > mine.last_read_seq then 'amber'
           else 'green'
         end as health,
         case
           when last_msg.seq is null then 'Nothing waiting'
           when last_msg.sender_user_id = _me
                and coalesce(other.last_read_seq,0) < last_msg.seq
                and last_msg.created_at < now() - interval '24 hours'
             then 'No reply for over 24 hours: ' || coalesce(other.name,'teammate')
           when last_msg.sender_user_id = _me
                and coalesce(other.last_read_seq,0) < last_msg.seq
             then 'Waiting: ' || coalesce(other.name,'teammate')
           when last_msg.sender_user_id <> _me and last_msg.seq > mine.last_read_seq
             then 'Waiting on you'
           else 'Nothing waiting'
         end as health_reason
    from conv
    join mine on mine.conversation_id = conv.id
    left join other on other.conversation_id = conv.id
    left join last_msg on last_msg.conversation_id = conv.id
   order by coalesce(last_msg.created_at, conv.created_at) desc
$$;

-- ---------- 15) message page (virtualized paging, newest first) ----------
drop function if exists public.chat_messages_page(uuid, uuid, bigint, integer);
create or replace function public.chat_messages_page(
  _conv uuid, _me uuid, _before_seq bigint default null, _limit integer default 80
) returns table (
  id uuid, seq bigint, body text, sender_user_id uuid, sender_name text,
  mine boolean, device_label text, transport text,
  created_at timestamptz, edited_at timestamptz,
  delivered_at timestamptz, read_at timestamptz
) language sql stable security definer set search_path = public as $$
  select m.id, m.seq, m.body, m.sender_user_id,
         coalesce(mem.display_name, 'Teammate') as sender_name,
         (m.sender_user_id = _me) as mine,
         m.device_label, m.transport, m.created_at, m.edited_at,
         (select min(r.at) from public.chat_message_receipts r
           where r.message_id = m.id and r.state = 'delivered') as delivered_at,
         (select min(r.at) from public.chat_message_receipts r
           where r.message_id = m.id and r.state = 'read') as read_at
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

-- ---------- 16) presence + typing pings (truth only) ----------
drop function if exists public.chat_presence_ping(uuid, uuid, text);
create or replace function public.chat_presence_ping(_ws uuid, _user uuid, _device text default null)
returns void language sql security definer set search_path = public as $$
  insert into public.chat_presence (workspace_id, user_id, device_label, last_seen_at)
  values (_ws, _user, _device, now())
  on conflict (workspace_id, user_id)
    do update set last_seen_at = now(), device_label = coalesce(excluded.device_label, chat_presence.device_label)
$$;

drop function if exists public.chat_typing_ping(uuid, uuid, boolean);
create or replace function public.chat_typing_ping(_conv uuid, _user uuid, _typing boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_in_conversation(_conv, _user) then raise exception 'not_participant'; end if;
  if _typing then
    insert into public.chat_typing (conversation_id, user_id, until)
    values (_conv, _user, now() + interval '6 seconds')
    on conflict (conversation_id, user_id) do update set until = now() + interval '6 seconds';
  else
    delete from public.chat_typing where conversation_id = _conv and user_id = _user;
  end if;
end $$;

-- ---------- 17) verify ----------
select 'chat tables' as check, count(*) as n
  from information_schema.tables
 where table_schema='public' and table_name like 'chat_%';
select 'chat functions' as check, count(*) as n
  from information_schema.routines
 where routine_schema='public' and routine_name like 'chat_%';