-- ANEXOMAIL · ANEXOChat — PHASE 12: CROSS-DEVICE CONTINUITY (RESUME ANYWHERE)
-- Supabase #4 SQL editor mein poora block chalao. Idempotent + self-healing.
--
-- FOUNDER LOCK:
--   1. Server-side state AUTHORITATIVE hai. Device sirf sync + reconcile karta hai.
--   2. Device change se conversation context, unread, draft, attachment ya
--      position kabhi reset nahi hota.
--   3. Conflict = revision (rev) se hal hota hai — purani rev nayi ko kabhi
--      overwrite nahi karti; server jeeta hua row wapas deta hai.
--   4. Koi fake state nahi — jo row hai wahi sach hai.
--   5. Poori history hamesha available + searchable (trigram index, keyset paging).
--   6. Gate wahi purana: public.chat_access(user) — Basic/Pro = access nahi.

-- ─────────────────────────────────────────────────────────────────
-- 0) trigram (search) — Supabase par extensions schema mein
-- ─────────────────────────────────────────────────────────────────
create extension if not exists pg_trgm with schema extensions;

-- ─────────────────────────────────────────────────────────────────
-- 1) self-heal: purani conflicting tables legacy kar do
-- ─────────────────────────────────────────────────────────────────
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='chat_drafts')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='chat_drafts' and column_name='rev') then
    execute 'alter table public.chat_drafts rename to chat_drafts_legacy';
  end if;
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='chat_positions')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='chat_positions' and column_name='anchor_seq') then
    execute 'alter table public.chat_positions rename to chat_positions_legacy';
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 2) devices: har surface ki pehchaan (desktop / laptop / tablet / PWA)
-- ─────────────────────────────────────────────────────────────────
create table if not exists public.chat_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_label text not null default 'Unknown device',
  kind text not null default 'desktop' check (kind in ('desktop','laptop','tablet','phone','pwa','unknown')),
  platform text,
  installed boolean not null default false,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, device_id)
);
create index if not exists chat_devices_user_idx on public.chat_devices (user_id, last_seen_at desc);

-- ─────────────────────────────────────────────────────────────────
-- 3) drafts: server-authoritative, per user + conversation
-- ─────────────────────────────────────────────────────────────────
create table if not exists public.chat_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  body text not null default '',
  reply_to_id uuid,
  caret integer not null default 0,
  attachment_ids uuid[] not null default '{}',
  rev bigint not null default 1,
  device_id text,
  device_label text,
  updated_at timestamptz not null default now(),
  unique (user_id, conversation_id)
);
create index if not exists chat_drafts_user_idx on public.chat_drafts (user_id, updated_at desc);

-- ─────────────────────────────────────────────────────────────────
-- 4) positions: user ki relevant jagah (anchor message seq)
-- ─────────────────────────────────────────────────────────────────
create table if not exists public.chat_positions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  anchor_seq bigint not null default 0,
  at_bottom boolean not null default true,
  rev bigint not null default 1,
  device_id text,
  device_label text,
  updated_at timestamptz not null default now(),
  unique (user_id, conversation_id)
);
create index if not exists chat_positions_user_idx on public.chat_positions (user_id, updated_at desc);

-- ─────────────────────────────────────────────────────────────────
-- 5) long-history search: trigram index (koi bhi lambhi chat searchable)
-- ─────────────────────────────────────────────────────────────────
create index if not exists chat_messages_body_trgm_idx
  on public.chat_messages using gin (body extensions.gin_trgm_ops);
create index if not exists chat_messages_conv_seq_idx
  on public.chat_messages (conversation_id, seq desc);

-- ─────────────────────────────────────────────────────────────────
-- 6) grants
-- ─────────────────────────────────────────────────────────────────
grant select, insert, update, delete on public.chat_devices to authenticated;
grant select, insert, update, delete on public.chat_drafts to authenticated;
grant select, insert, update, delete on public.chat_positions to authenticated;
grant all on public.chat_devices to service_role;
grant all on public.chat_drafts to service_role;
grant all on public.chat_positions to service_role;

-- ─────────────────────────────────────────────────────────────────
-- 7) RLS: sirf apna data
-- ─────────────────────────────────────────────────────────────────
alter table public.chat_devices enable row level security;
alter table public.chat_drafts enable row level security;
alter table public.chat_positions enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public'
                 and tablename='chat_devices' and policyname='chat_devices_own') then
    create policy chat_devices_own on public.chat_devices for all to authenticated
      using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public'
                 and tablename='chat_drafts' and policyname='chat_drafts_own') then
    create policy chat_drafts_own on public.chat_drafts for all to authenticated
      using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public'
                 and tablename='chat_positions' and policyname='chat_positions_own') then
    create policy chat_positions_own on public.chat_positions for all to authenticated
      using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 8) device heartbeat
-- ─────────────────────────────────────────────────────────────────
create or replace function public.chat_device_seen(
  _user uuid, _device_id text, _label text default null,
  _kind text default 'unknown', _platform text default null, _installed boolean default false
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_access(_user) then raise exception 'chat_not_entitled'; end if;
  insert into public.chat_devices (user_id, device_id, device_label, kind, platform, installed, last_seen_at)
  values (
    _user, _device_id, coalesce(nullif(btrim(_label), ''), 'Unknown device'),
    case when _kind in ('desktop','laptop','tablet','phone','pwa') then _kind else 'unknown' end,
    _platform, coalesce(_installed, false), now()
  )
  on conflict (user_id, device_id) do update
     set device_label = excluded.device_label,
         kind         = excluded.kind,
         platform     = excluded.platform,
         installed    = excluded.installed,
         last_seen_at = now();
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 9) draft save — rev-based reconcile (server authoritative)
--    accepted=false => client ka rev purana tha, server ka row jeeta.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.chat_draft_save(
  _user uuid, _conv uuid, _body text, _reply_to uuid default null,
  _caret integer default 0, _attachment_ids uuid[] default '{}',
  _rev bigint default 0, _device_id text default null, _device_label text default null
) returns table (
  accepted boolean, conversation_id uuid, body text, reply_to_id uuid, caret integer,
  attachment_ids uuid[], rev bigint, device_label text, updated_at timestamptz
) language plpgsql security definer set search_path = public as $$
declare
  cur public.chat_drafts;
  next_rev bigint;
begin
  if not public.chat_access(_user) then raise exception 'chat_not_entitled'; end if;
  if not exists (select 1 from public.chat_participants p
                  where p.conversation_id = _conv and p.user_id = _user) then
    raise exception 'not_a_participant';
  end if;

  select * into cur from public.chat_drafts d
   where d.user_id = _user and d.conversation_id = _conv for update;

  -- purani rev nayi state ko kabhi overwrite nahi karti
  if cur.id is not null and coalesce(_rev, 0) < cur.rev then
    return query
      select false, cur.conversation_id, cur.body, cur.reply_to_id, cur.caret,
             cur.attachment_ids, cur.rev, cur.device_label, cur.updated_at;
    return;
  end if;

  next_rev := greatest(coalesce(cur.rev, 0), coalesce(_rev, 0)) + 1;

  if coalesce(btrim(_body), '') = '' and coalesce(array_length(_attachment_ids, 1), 0) = 0 then
    delete from public.chat_drafts where user_id = _user and conversation_id = _conv;
    return query select true, _conv, ''::text, null::uuid, 0, '{}'::uuid[], next_rev,
                        _device_label, now();
    return;
  end if;

  insert into public.chat_drafts (
    user_id, conversation_id, body, reply_to_id, caret, attachment_ids, rev,
    device_id, device_label, updated_at
  ) values (
    _user, _conv, _body, _reply_to, greatest(coalesce(_caret, 0), 0),
    coalesce(_attachment_ids, '{}'), next_rev, _device_id, _device_label, now()
  )
  on conflict (user_id, conversation_id) do update
     set body = excluded.body, reply_to_id = excluded.reply_to_id, caret = excluded.caret,
         attachment_ids = excluded.attachment_ids, rev = excluded.rev,
         device_id = excluded.device_id, device_label = excluded.device_label,
         updated_at = now();

  return query
    select true, d.conversation_id, d.body, d.reply_to_id, d.caret, d.attachment_ids,
           d.rev, d.device_label, d.updated_at
      from public.chat_drafts d
     where d.user_id = _user and d.conversation_id = _conv;
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 10) position save — same reconcile rule
-- ─────────────────────────────────────────────────────────────────
create or replace function public.chat_position_save(
  _user uuid, _conv uuid, _anchor_seq bigint, _at_bottom boolean default true,
  _rev bigint default 0, _device_id text default null, _device_label text default null
) returns table (accepted boolean, anchor_seq bigint, at_bottom boolean, rev bigint,
                 device_label text, updated_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  cur public.chat_positions;
  next_rev bigint;
begin
  if not public.chat_access(_user) then raise exception 'chat_not_entitled'; end if;
  if not exists (select 1 from public.chat_participants p
                  where p.conversation_id = _conv and p.user_id = _user) then
    raise exception 'not_a_participant';
  end if;

  select * into cur from public.chat_positions p
   where p.user_id = _user and p.conversation_id = _conv for update;

  if cur.id is not null and coalesce(_rev, 0) < cur.rev then
    return query select false, cur.anchor_seq, cur.at_bottom, cur.rev, cur.device_label, cur.updated_at;
    return;
  end if;

  next_rev := greatest(coalesce(cur.rev, 0), coalesce(_rev, 0)) + 1;

  insert into public.chat_positions (
    user_id, conversation_id, anchor_seq, at_bottom, rev, device_id, device_label, updated_at
  ) values (
    _user, _conv, greatest(coalesce(_anchor_seq, 0), 0), coalesce(_at_bottom, true),
    next_rev, _device_id, _device_label, now()
  )
  on conflict (user_id, conversation_id) do update
     set anchor_seq = excluded.anchor_seq, at_bottom = excluded.at_bottom,
         rev = excluded.rev, device_id = excluded.device_id,
         device_label = excluded.device_label, updated_at = now();

  return query select true, p.anchor_seq, p.at_bottom, p.rev, p.device_label, p.updated_at
    from public.chat_positions p
   where p.user_id = _user and p.conversation_id = _conv;
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 11) continuity snapshot — ek call, poora canonical state
-- ─────────────────────────────────────────────────────────────────
create or replace function public.chat_continuity(_user uuid, _device_id text default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'devices', coalesce((
      select jsonb_agg(jsonb_build_object(
               'device_id', d.device_id, 'device_label', d.device_label, 'kind', d.kind,
               'platform', d.platform, 'installed', d.installed,
               'last_seen_at', d.last_seen_at,
               'this_device', (_device_id is not null and d.device_id = _device_id))
               order by d.last_seen_at desc)
        from public.chat_devices d where d.user_id = _user), '[]'::jsonb),
    'drafts', coalesce((
      select jsonb_agg(jsonb_build_object(
               'conversation_id', dr.conversation_id, 'body', dr.body,
               'reply_to_id', dr.reply_to_id, 'caret', dr.caret,
               'attachment_ids', dr.attachment_ids, 'rev', dr.rev,
               'device_label', dr.device_label,
               'from_other_device', (_device_id is null or coalesce(dr.device_id,'') <> _device_id),
               'updated_at', dr.updated_at)
               order by dr.updated_at desc)
        from public.chat_drafts dr where dr.user_id = _user), '[]'::jsonb),
    'positions', coalesce((
      select jsonb_agg(jsonb_build_object(
               'conversation_id', p.conversation_id, 'anchor_seq', p.anchor_seq,
               'at_bottom', p.at_bottom, 'rev', p.rev, 'device_label', p.device_label,
               'from_other_device', (_device_id is null or coalesce(p.device_id,'') <> _device_id),
               'updated_at', p.updated_at)
               order by p.updated_at desc)
        from public.chat_positions p where p.user_id = _user), '[]'::jsonb),
    'server_time', now()
  )
  where public.chat_access(_user);
$$;

-- ─────────────────────────────────────────────────────────────────
-- 12) deep search — poori history, keyset paging, optional filters
-- ─────────────────────────────────────────────────────────────────
create or replace function public.chat_search_deep(
  _user uuid, _q text, _conv uuid default null, _sender uuid default null,
  _before timestamptz default null, _limit integer default 40
) returns table (
  id uuid, conversation_id uuid, seq bigint, body text,
  sender_user_id uuid, sender_name text, created_at timestamptz, mine boolean
) language sql stable security definer set search_path = public as $$
  select m.id, m.conversation_id, m.seq, m.body, m.sender_user_id,
         coalesce(mem.display_name, 'Teammate'), m.created_at,
         (m.sender_user_id = _user)
    from public.chat_messages m
    join public.chat_participants p
      on p.conversation_id = m.conversation_id and p.user_id = _user
    left join public.chat_members mem
      on mem.workspace_id = m.workspace_id and mem.user_id = m.sender_user_id
   where public.chat_access(_user)
     and m.deleted_at is null
     and coalesce(btrim(_q), '') <> ''
     and m.body ilike '%' || btrim(_q) || '%'
     and (_conv is null or m.conversation_id = _conv)
     and (_sender is null or m.sender_user_id = _sender)
     and (_before is null or m.created_at < _before)
   order by m.created_at desc
   limit greatest(1, least(coalesce(_limit, 40), 100));
$$;

-- ─────────────────────────────────────────────────────────────────
-- 13) verify
-- ─────────────────────────────────────────────────────────────────
select count(*) as phase12_tables from information_schema.tables
 where table_schema='public' and table_name in ('chat_devices','chat_drafts','chat_positions');
select count(*) as phase12_functions from pg_proc
 where proname in ('chat_device_seen','chat_draft_save','chat_position_save',
                   'chat_continuity','chat_search_deep');
