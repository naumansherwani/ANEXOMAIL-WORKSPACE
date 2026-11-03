-- ============================================================================
-- ANEXOCHAT · PHASE 31 — FILE CONTEXT (business context, diff, dedupe, graph)
--
--   File → Uploader → Conversation → Related Work → Related Email → Decision/Promise
--   Misal: Contract.pdf — Shared by John · Conversation: ABC Renewal ·
--          Related: Contract Approval · Status: Pending
--
-- Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
-- Transport: RUST-FIRST — `/rpc/file.context.*` (axum, :3200, QUIC/WT) PRIMARY;
-- Bun `/api/chat/file/context*` sirf fallback.
--
-- LOCK (non-negotiable):
--   1. CONTEXT CARD sirf asli rows se — uploader (chat_file_versions.created_by),
--      conversation (chat_files.conversation_id), related work/decision/promise/
--      email SIRF insaani links (`chat_file_links`). Engine link kabhi invent
--      nahi karti; jo record nahi hua woh "Not recorded" likha jata hai.
--   2. VERSION DIFF deterministic hai — line-presence diff SQL mein, koi AI API
--      nahi. Diff sirf un versions par jinka text `chat_file_version_text` mein
--      seal hua (Rust ne likha); warna "text not captured".
--   3. DUPLICATE-BY-HASH sirf sha256 par — same hash doosri jagah mile to dono
--      jagah ka link dikhta hai, andaza nahi.
--   4. STALE-FILE WARNING: decision ka version file ke current version se aage
--      ho to red flag + evidence (decision version, file version, waqt).
--   5. RELATIONSHIP GRAPH edges SIRF recorded links se (file ↔ person ↔ company
--      ↔ decision). Koi derived edge "potentially related" ke ishaare se aage
--      nahi jata.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements (Basic/Pro = zero ANEXOChat access)
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'file_context',      false, null, 'ANEXOChat included nahi'),
  ('pro',          'file_context',      false, null, 'ANEXOChat included nahi'),
  ('business',     'file_context',      true,  null, 'uploader · conversation · work · email · decision'),
  ('business_pro', 'file_context',      true,  null, null),
  ('ai_pro',       'file_context',      true,  null, null),
  ('ai_business',  'file_context',      true,  null, null),
  ('ai_executive', 'file_context',      true,  null, null),
  ('founder',      'file_context',      true,  null, null),

  ('basic',        'file_version_diff', false, null, null),
  ('pro',          'file_version_diff', false, null, null),
  ('business',     'file_version_diff', true,  20,   'diff lines per request'),
  ('business_pro', 'file_version_diff', true,  2000, null),
  ('ai_pro',       'file_version_diff', true,  200,  null),
  ('ai_business',  'file_version_diff', true,  2000, null),
  ('ai_executive', 'file_version_diff', true,  5000, null),
  ('founder',      'file_version_diff', true,  20000, null),

  ('basic',        'file_dedupe',       false, null, null),
  ('pro',          'file_dedupe',       false, null, null),
  ('business',     'file_dedupe',       true,  null, 'same sha256 across workspace'),
  ('business_pro', 'file_dedupe',       true,  null, null),
  ('ai_pro',       'file_dedupe',       true,  null, null),
  ('ai_business',  'file_dedupe',       true,  null, null),
  ('ai_executive', 'file_dedupe',       true,  null, null),
  ('founder',      'file_dedupe',       true,  null, null),

  ('basic',        'relationship_graph', false, null, null),
  ('pro',          'relationship_graph', false, null, null),
  ('business',     'relationship_graph', false, null, 'Business Pro / AI Business se'),
  ('business_pro', 'relationship_graph', true,  null, 'file ↔ person ↔ company ↔ decision'),
  ('ai_pro',       'relationship_graph', false, null, null),
  ('ai_business',  'relationship_graph', true,  null, null),
  ('ai_executive', 'relationship_graph', true,  null, null),
  ('founder',      'relationship_graph', true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ---------------------------------------------------------------------------
-- 1) human-recorded links (engine kabhi insert nahi karti apni marzi se)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_file_links (
  id           uuid primary key default gen_random_uuid(),
  file_id      uuid not null references public.chat_files(id) on delete cascade,
  object_type  text not null check (object_type in
                 ('work_item','decision','promise','mail_thread','message','person','company')),
  object_id    text not null,
  label        text,
  reason       text not null check (char_length(btrim(reason)) >= 8),
  linked_by    uuid not null references auth.users(id) on delete restrict,
  linked_at    timestamptz not null default now(),
  removed_at   timestamptz,
  removed_by   uuid references auth.users(id) on delete set null,
  remove_reason text
);
create unique index if not exists chat_file_links_once
  on public.chat_file_links (file_id, object_type, object_id) where removed_at is null;
create index if not exists chat_file_links_file on public.chat_file_links (file_id, linked_at desc);
create index if not exists chat_file_links_object on public.chat_file_links (object_type, object_id);

grant select, insert on public.chat_file_links to authenticated;
grant all on public.chat_file_links to service_role;
alter table public.chat_file_links enable row level security;
drop policy if exists chat_file_links_read on public.chat_file_links;
create policy chat_file_links_read on public.chat_file_links for select to authenticated using (true);

-- append-only ledger (link/unlink dono record)
create table if not exists public.chat_file_link_log (
  id        bigserial primary key,
  file_id   uuid not null,
  link_id   uuid,
  action    text not null check (action in ('linked','unlinked','stale_flagged','viewed_duplicate')),
  actor_id  uuid not null references auth.users(id) on delete restrict,
  reason    text,
  detail    jsonb not null default '{}'::jsonb,
  at        timestamptz not null default now()
);
create index if not exists chat_file_link_log_file on public.chat_file_link_log (file_id, id desc);
grant select on public.chat_file_link_log to authenticated;
grant all on public.chat_file_link_log to service_role;
grant usage, select on sequence public.chat_file_link_log_id_seq to service_role;
alter table public.chat_file_link_log enable row level security;
drop policy if exists chat_file_link_log_read on public.chat_file_link_log;
create policy chat_file_link_log_read on public.chat_file_link_log for select to authenticated using (true);

create or replace function public.chat_file_link_log_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'chat_file_link_log append-only hai';
end $$;
drop trigger if exists chat_file_link_log_no_change on public.chat_file_link_log;
create trigger chat_file_link_log_no_change before update or delete on public.chat_file_link_log
  for each row execute function public.chat_file_link_log_immutable();

-- ---------------------------------------------------------------------------
-- 2) text-like version content (Rust likhta hai; diff isi par hota hai)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_file_version_text (
  version_id  uuid primary key references public.chat_file_versions(id) on delete cascade,
  file_id     uuid not null references public.chat_files(id) on delete cascade,
  message_id  uuid references public.chat_messages(id) on delete set null,
  lines       text[] not null,
  line_count  int not null,
  text_sha256 text not null,
  captured_by text not null default 'rust' check (captured_by in ('rust','bun')),
  captured_at timestamptz not null default now()
);
create index if not exists chat_file_version_text_file on public.chat_file_version_text (file_id);
grant select on public.chat_file_version_text to authenticated;
grant all on public.chat_file_version_text to service_role;
alter table public.chat_file_version_text enable row level security;
drop policy if exists chat_file_version_text_read on public.chat_file_version_text;
create policy chat_file_version_text_read on public.chat_file_version_text
  for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 3) context card — sab asli rows se
-- ---------------------------------------------------------------------------
create or replace function public.file_context_card(_file uuid, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare f record; v record; out jsonb;
begin
  if not public.chat_feature_ok(_user, 'file_context') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;

  select * into f from public.chat_files where id = _file and deleted_at is null;
  if not found then return jsonb_build_object('allowed', true, 'found', false); end if;

  select * into v from public.chat_file_versions
   where file_id = _file order by version desc limit 1;

  out := jsonb_build_object(
    'allowed', true,
    'found', true,
    'engine_invents_nothing', true,
    'file', jsonb_build_object(
      'id', f.id, 'name', f.name, 'content_type', f.content_type,
      'current_version', f.current_version, 'latest_bytes', f.latest_bytes,
      'updated_at', f.updated_at),
    'uploader', (
      select jsonb_build_object('user_id', v.created_by, 'at', v.created_at,
                                'version', v.version, 'sha256', v.file_sha256)
      where v.id is not null),
    'conversation', (
      select jsonb_build_object('id', c.id, 'title', c.title)
        from public.chat_conversations c where c.id = f.conversation_id),
    'evidence', coalesce((
      select jsonb_agg(jsonb_build_object('state', e.state, 'actor', e.actor, 'at', e.at)
                       order by e.id)
        from public.file_evidence e where e.version_id = v.id), '[]'::jsonb),
    'links', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'object_type', l.object_type, 'object_id', l.object_id,
               'label', l.label, 'reason', l.reason, 'linked_by', l.linked_by,
               'linked_at', l.linked_at) order by l.linked_at desc)
        from public.chat_file_links l
       where l.file_id = _file and l.removed_at is null), '[]'::jsonb)
  );

  -- related work status (sirf recorded links se)
  out := out || jsonb_build_object('related_work', coalesce((
    select jsonb_agg(jsonb_build_object(
             'work_id', w.id, 'kind', w.kind, 'title', w.title,
             'status', w.status, 'owner_id', w.owner_id, 'due_at', w.due_at))
      from public.chat_file_links l
      join public.chat_work_items w on w.id::text = l.object_id
     where l.file_id = _file and l.removed_at is null and l.object_type = 'work_item'
  ), '[]'::jsonb));

  return out;
end $$;

-- ---------------------------------------------------------------------------
-- 4) deterministic version diff (line presence, koi AI nahi)
-- ---------------------------------------------------------------------------
create or replace function public.file_version_diff(_file uuid, _from int, _to int, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a record; b record; cap int; added text[]; removed text[]; kept int := 0;
begin
  if not public.chat_feature_ok(_user, 'file_version_diff') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;
  cap := coalesce((select limit_value from public.chat_phase_entitlements e
                    where e.feature = 'file_version_diff'
                      and e.plan = (public.chat_feature_allowed(_user, 'file_version_diff')->>'plan')
                  ), 200);

  select t.* into a from public.chat_file_version_text t
    join public.chat_file_versions v on v.id = t.version_id
   where t.file_id = _file and v.version = _from;
  select t.* into b from public.chat_file_version_text t
    join public.chat_file_versions v on v.id = t.version_id
   where t.file_id = _file and v.version = _to;

  if a.version_id is null or b.version_id is null then
    return jsonb_build_object('allowed', true, 'diff_available', false,
      'reason', 'text not captured for one or both versions',
      'diff_method', 'line_presence');
  end if;

  select array(select l from unnest(b.lines) l except select l from unnest(a.lines) l) into added;
  select array(select l from unnest(a.lines) l except select l from unnest(b.lines) l) into removed;
  select count(*) into kept from (
    select l from unnest(a.lines) l intersect select l from unnest(b.lines) l) k;

  return jsonb_build_object(
    'allowed', true, 'diff_available', true, 'diff_method', 'line_presence',
    'ai_used', false,
    'from', jsonb_build_object('version', _from, 'lines', a.line_count,
                               'sha256', a.text_sha256, 'sent_in_message', a.message_id),
    'to',   jsonb_build_object('version', _to, 'lines', b.line_count,
                               'sha256', b.text_sha256, 'sent_in_message', b.message_id),
    'unchanged_lines', kept,
    'added',   to_jsonb((select array_agg(x) from (select unnest(added) x limit cap) s)),
    'removed', to_jsonb((select array_agg(x) from (select unnest(removed) x limit cap) s)),
    'truncated', (coalesce(array_length(added,1),0) + coalesce(array_length(removed,1),0)) > cap,
    'line_cap', cap);
end $$;

-- ---------------------------------------------------------------------------
-- 5) duplicate-by-hash across workspace
-- ---------------------------------------------------------------------------
create or replace function public.file_duplicates(_file uuid, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare f record; v record;
begin
  if not public.chat_feature_ok(_user, 'file_dedupe') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;
  select * into f from public.chat_files where id = _file and deleted_at is null;
  if not found then return jsonb_build_object('allowed', true, 'found', false); end if;
  select * into v from public.chat_file_versions
   where file_id = _file and state = 'ready' order by version desc limit 1;
  if v.file_sha256 is null then
    return jsonb_build_object('allowed', true, 'found', true, 'sha256', null,
      'reason', 'no sealed hash for the current version', 'duplicates', '[]'::jsonb);
  end if;

  return jsonb_build_object(
    'allowed', true, 'found', true, 'sha256', v.file_sha256, 'match_basis', 'sha256',
    'duplicates', coalesce((
      select jsonb_agg(jsonb_build_object(
               'file_id', o.id, 'name', o.name, 'conversation_id', o.conversation_id,
               'version', ov.version, 'bytes', ov.bytes, 'uploaded_by', ov.created_by,
               'uploaded_at', ov.created_at))
        from public.chat_file_versions ov
        join public.chat_files o on o.id = ov.file_id
       where ov.file_sha256 = v.file_sha256 and ov.state = 'ready'
         and o.workspace_id = f.workspace_id and o.id <> f.id and o.deleted_at is null
    ), '[]'::jsonb),
    'pool_saving_bytes', coalesce((
      select sum(ov.bytes) from public.chat_file_versions ov
        join public.chat_files o on o.id = ov.file_id
       where ov.file_sha256 = v.file_sha256 and ov.state = 'ready'
         and o.workspace_id = f.workspace_id and o.id <> f.id and o.deleted_at is null), 0));
end $$;

-- ---------------------------------------------------------------------------
-- 6) stale-file warning (decision aage, file peeche) — evidence ke saath
-- ---------------------------------------------------------------------------
create or replace function public.file_stale_check(_file uuid, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare f record; v record;
begin
  if not public.chat_feature_ok(_user, 'file_context') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;
  select * into f from public.chat_files where id = _file and deleted_at is null;
  if not found then return jsonb_build_object('allowed', true, 'found', false); end if;
  select * into v from public.chat_file_versions
   where file_id = _file order by version desc limit 1;

  return jsonb_build_object(
    'allowed', true, 'found', true,
    'current_version', f.current_version,
    'current_version_at', v.created_at,
    'flags', coalesce((
      select jsonb_agg(jsonb_build_object(
               'decision_id', d.id, 'decision_title', d.title,
               'decision_version', d.version, 'decided_at', d.decided_at,
               'file_version', f.current_version, 'file_version_at', v.created_at,
               'stale', d.decided_at > v.created_at,
               'evidence', jsonb_build_object(
                 'link_reason', l.reason, 'linked_by', l.linked_by, 'linked_at', l.linked_at,
                 'decision_body_hash', d.body_hash)))
        from public.chat_file_links l
        join public.chat_decisions d on d.id::text = l.object_id
       where l.file_id = _file and l.removed_at is null and l.object_type = 'decision'
         and d.decided_at > v.created_at
    ), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------
-- 7) link / unlink (insaani, 8+ char reason) + relationship graph
-- ---------------------------------------------------------------------------
create or replace function public.file_link(_file uuid, _object_type text, _object_id text,
                                            _label text, _reason text, _user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  if not public.chat_feature_ok(_user, 'file_context') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  if char_length(btrim(coalesce(_reason,''))) < 8 then
    return jsonb_build_object('ok', false, 'reason', 'reason_min_8_chars');
  end if;

  insert into public.chat_file_links (file_id, object_type, object_id, label, reason, linked_by)
  values (_file, _object_type, _object_id, nullif(btrim(coalesce(_label,'')), ''), btrim(_reason), _user)
  on conflict do nothing
  returning id into new_id;

  if new_id is null then
    return jsonb_build_object('ok', false, 'reason', 'already_linked');
  end if;

  insert into public.chat_file_link_log (file_id, link_id, action, actor_id, reason,
    detail) values (_file, new_id, 'linked', _user, btrim(_reason),
    jsonb_build_object('object_type', _object_type, 'object_id', _object_id));

  return jsonb_build_object('ok', true, 'link_id', new_id);
end $$;

create or replace function public.file_unlink(_link uuid, _reason text, _user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare l record;
begin
  if char_length(btrim(coalesce(_reason,''))) < 8 then
    return jsonb_build_object('ok', false, 'reason', 'reason_min_8_chars');
  end if;
  select * into l from public.chat_file_links where id = _link and removed_at is null;
  if not found then return jsonb_build_object('ok', false, 'reason', 'link_not_found'); end if;

  update public.chat_file_links
     set removed_at = now(), removed_by = _user, remove_reason = btrim(_reason)
   where id = _link;

  insert into public.chat_file_link_log (file_id, link_id, action, actor_id, reason)
  values (l.file_id, _link, 'unlinked', _user, btrim(_reason));

  return jsonb_build_object('ok', true, 'removed', true);
end $$;

create or replace function public.file_relationship_graph(_file uuid, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare f record; v record; nodes jsonb := '[]'::jsonb; edges jsonb := '[]'::jsonb;
begin
  if not public.chat_feature_ok(_user, 'relationship_graph') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;
  select * into f from public.chat_files where id = _file and deleted_at is null;
  if not found then return jsonb_build_object('allowed', true, 'found', false); end if;
  select * into v from public.chat_file_versions where file_id = _file order by version desc limit 1;

  nodes := jsonb_build_array(jsonb_build_object('type','file','id',f.id,'label',f.name));
  if v.created_by is not null then
    nodes := nodes || jsonb_build_array(
      jsonb_build_object('type','person','id',v.created_by,'label','uploader'));
    edges := edges || jsonb_build_array(jsonb_build_object(
      'from', f.id, 'to', v.created_by, 'kind', 'uploaded_by',
      'source', 'chat_file_versions.created_by', 'recorded', true));
  end if;

  nodes := nodes || coalesce((
    select jsonb_agg(distinct jsonb_build_object(
             'type', l.object_type, 'id', l.object_id, 'label', coalesce(l.label, l.object_type)))
      from public.chat_file_links l where l.file_id = _file and l.removed_at is null), '[]'::jsonb);
  edges := edges || coalesce((
    select jsonb_agg(jsonb_build_object(
             'from', f.id, 'to', l.object_id, 'kind', l.object_type,
             'reason', l.reason, 'linked_by', l.linked_by, 'recorded', true))
      from public.chat_file_links l where l.file_id = _file and l.removed_at is null), '[]'::jsonb);

  return jsonb_build_object('allowed', true, 'found', true,
    'engine_invents_edges', false, 'nodes', nodes, 'edges', edges);
end $$;

grant execute on function public.file_context_card(uuid, uuid) to authenticated, service_role;
grant execute on function public.file_version_diff(uuid, int, int, uuid) to authenticated, service_role;
grant execute on function public.file_duplicates(uuid, uuid) to authenticated, service_role;
grant execute on function public.file_stale_check(uuid, uuid) to authenticated, service_role;
grant execute on function public.file_link(uuid, text, text, text, text, uuid) to authenticated, service_role;
grant execute on function public.file_unlink(uuid, text, uuid) to authenticated, service_role;
grant execute on function public.file_relationship_graph(uuid, uuid) to authenticated, service_role;
