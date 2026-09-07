-- ============================================================================
-- ANEXOVIDEOCALL · PHASE 31 — CALL BUSINESS RECORD (Rust-first, API-free)
--
--   Call → participants → join/leave truth → files shared in call →
--   work created → decision recorded
--
-- Supabase #4 = canonical truth. Idempotent. Phase 10A ke `chat_call_sessions`
-- aur `chat_call_stats` ZINDA rehte hain — yahan duplicate nahi banaya, unhi ke
-- upar business record banaya gaya.
-- Transport: RUST-FIRST — `/rpc/call.*` (axum :3200 + WebTransport/QUIC 3443)
-- PRIMARY; Bun `/api/chat/call/*` sirf fallback. Zoom/Daily/Agora/Twilio kabhi
-- nahi — media WebRTC + apna coturn (anexovideocall.anexomail.com).
--
-- LOCK (non-negotiable):
--   1. JOIN TRUTH append-only: invited · ringing · joined · rejoined · left ·
--      never_joined. Negative truth bhi likhi jati hai ("kabhi join nahi kiya").
--   2. Duration ASLI events se hisaab hoti hai — koi "estimated" number nahi.
--   3. IN-CALL FILE wahi Phase 16-18 evidence chain se guzarti hai; call ke
--      andar bhi "Delivered" jaisa lafz nahi — sirf uploaded/scanning/verified/
--      available jo record hua.
--   4. CALL → WORK: task/promise/decision insaan banata hai, provenance
--      call_id + timestamp; engine kuch invent nahi karti.
--   5. RELAY HONESTY: path (p2p | relay) ka har switch apni row ke saath —
--      UI wahi likhta hai jo record hua.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements — video call features price ke mutabiq
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'call_record',  false, null, 'ANEXOVideoCall included nahi'),
  ('pro',          'call_record',  false, null, 'ANEXOVideoCall included nahi'),
  ('business',     'call_record',  true,  8,    'group size 8 · call business record'),
  ('business_pro', 'call_record',  true,  40,   'group size 40'),
  ('ai_pro',       'call_record',  true,  8,    null),
  ('ai_business',  'call_record',  true,  40,   null),
  ('ai_executive', 'call_record',  true,  60,   'group size 60'),
  ('founder',      'call_record',  true,  60,   null),

  ('basic',        'call_work',    false, null, null),
  ('pro',          'call_work',    false, null, null),
  ('business',     'call_work',    true,  null, 'call → task · promise · decision'),
  ('business_pro', 'call_work',    true,  null, null),
  ('ai_pro',       'call_work',    true,  null, null),
  ('ai_business',  'call_work',    true,  null, null),
  ('ai_executive', 'call_work',    true,  null, null),
  ('founder',      'call_work',    true,  null, null),

  ('basic',        'call_file',    false, null, null),
  ('pro',          'call_file',    false, null, null),
  ('business',     'call_file',    true,  null, 'in-call file with evidence chain'),
  ('business_pro', 'call_file',    true,  null, null),
  ('ai_pro',       'call_file',    true,  null, null),
  ('ai_business',  'call_file',    true,  null, null),
  ('ai_executive', 'call_file',    true,  null, null),
  ('founder',      'call_file',    true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ---------------------------------------------------------------------------
-- 1) join truth ledger (append-only)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_call_events (
  id         bigserial primary key,
  session_id uuid not null references public.chat_call_sessions(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  event      text not null check (event in
               ('invited','ringing','joined','rejoined','left','never_joined','declined')),
  at_ms      bigint not null,          -- millisecond UTC, engine se nahi — asli event se
  transport  text check (transport in ('webtransport','rows','realtime')),
  path       text check (path in ('p2p','relay','unknown')),
  detail     jsonb not null default '{}'::jsonb,
  at         timestamptz not null default now()
);
create index if not exists chat_call_events_session on public.chat_call_events (session_id, id);
grant select, insert on public.chat_call_events to authenticated;
grant all on public.chat_call_events to service_role;
grant usage, select on sequence public.chat_call_events_id_seq to service_role;
alter table public.chat_call_events enable row level security;
drop policy if exists chat_call_events_read on public.chat_call_events;
create policy chat_call_events_read on public.chat_call_events for select to authenticated
  using (exists (select 1 from public.chat_call_sessions s
                  where s.id = session_id and (s.caller_id = auth.uid() or s.peer_id = auth.uid()))
         or user_id = auth.uid());
drop policy if exists chat_call_events_insert on public.chat_call_events;
create policy chat_call_events_insert on public.chat_call_events for insert to authenticated
  with check (user_id = auth.uid());

create or replace function public.chat_call_events_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'chat_call_events append-only hai';
end $$;
drop trigger if exists chat_call_events_no_change on public.chat_call_events;
create trigger chat_call_events_no_change before update or delete on public.chat_call_events
  for each row execute function public.chat_call_events_immutable();

-- ---------------------------------------------------------------------------
-- 2) transport / relay honesty switches
-- ---------------------------------------------------------------------------
create table if not exists public.chat_call_transport_events (
  id         bigserial primary key,
  session_id uuid not null references public.chat_call_sessions(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  path       text not null check (path in ('p2p','relay','unknown')),
  relay_host text,
  reason     text,
  at_ms      bigint not null,
  at         timestamptz not null default now()
);
create index if not exists chat_call_transport_session
  on public.chat_call_transport_events (session_id, id);
grant select, insert on public.chat_call_transport_events to authenticated;
grant all on public.chat_call_transport_events to service_role;
grant usage, select on sequence public.chat_call_transport_events_id_seq to service_role;
alter table public.chat_call_transport_events enable row level security;
drop policy if exists chat_call_transport_read on public.chat_call_transport_events;
create policy chat_call_transport_read on public.chat_call_transport_events
  for select to authenticated using (true);
drop policy if exists chat_call_transport_insert on public.chat_call_transport_events;
create policy chat_call_transport_insert on public.chat_call_transport_events
  for insert to authenticated with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3) in-call files (evidence chain wahi Phase 16-18 ka)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_call_files (
  session_id uuid not null references public.chat_call_sessions(id) on delete cascade,
  version_id uuid not null references public.chat_file_versions(id) on delete cascade,
  shared_by  uuid not null references auth.users(id) on delete restrict,
  at_ms      bigint not null,
  at         timestamptz not null default now(),
  primary key (session_id, version_id)
);
grant select, insert on public.chat_call_files to authenticated;
grant all on public.chat_call_files to service_role;
alter table public.chat_call_files enable row level security;
drop policy if exists chat_call_files_read on public.chat_call_files;
create policy chat_call_files_read on public.chat_call_files for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 4) call → work / decision provenance
-- ---------------------------------------------------------------------------
create table if not exists public.chat_call_work (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references public.chat_call_sessions(id) on delete cascade,
  object_type text not null check (object_type in ('work_item','decision')),
  object_id   uuid not null,
  created_by  uuid not null references auth.users(id) on delete restrict,
  note        text,
  at_ms       bigint not null,
  at          timestamptz not null default now(),
  unique (session_id, object_type, object_id)
);
create index if not exists chat_call_work_session on public.chat_call_work (session_id, at desc);
grant select, insert on public.chat_call_work to authenticated;
grant all on public.chat_call_work to service_role;
alter table public.chat_call_work enable row level security;
drop policy if exists chat_call_work_read on public.chat_call_work;
create policy chat_call_work_read on public.chat_call_work for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 5) functions
-- ---------------------------------------------------------------------------
create or replace function public.call_event_record(_session uuid, _user uuid, _event text,
                                                    _at_ms bigint, _transport text,
                                                    _path text, _detail jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare new_id bigint;
begin
  if not public.chat_feature_ok(_user, 'call_record') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  insert into public.chat_call_events (session_id, user_id, event, at_ms, transport, path, detail)
  values (_session, _user, _event, _at_ms,
          nullif(_transport,''), nullif(_path,''), coalesce(_detail, '{}'::jsonb))
  returning id into new_id;
  return jsonb_build_object('ok', true, 'event_id', new_id, 'append_only', true);
end $$;

create or replace function public.call_transport_record(_session uuid, _user uuid, _path text,
                                                        _relay_host text, _reason text, _at_ms bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_feature_ok(_user, 'call_record') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  insert into public.chat_call_transport_events (session_id, user_id, path, relay_host, reason, at_ms)
  values (_session, _user, _path, nullif(_relay_host,''), nullif(_reason,''), _at_ms);
  return jsonb_build_object('ok', true, 'honest_label', _path);
end $$;

create or replace function public.call_file_share(_session uuid, _version uuid, _user uuid, _at_ms bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_feature_ok(_user, 'call_file') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  insert into public.chat_call_files (session_id, version_id, shared_by, at_ms)
  values (_session, _version, _user, _at_ms)
  on conflict (session_id, version_id) do nothing;
  return jsonb_build_object('ok', true,
    'evidence_chain', coalesce((
      select jsonb_agg(jsonb_build_object('state', e.state, 'at', e.at) order by e.id)
        from public.file_evidence e where e.version_id = _version), '[]'::jsonb),
    'no_delivery_wording', true);
end $$;

create or replace function public.call_work_link(_session uuid, _object_type text, _object_id uuid,
                                                 _note text, _user uuid, _at_ms bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_feature_ok(_user, 'call_work') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  insert into public.chat_call_work (session_id, object_type, object_id, created_by, note, at_ms)
  values (_session, _object_type, _object_id, _user, nullif(btrim(coalesce(_note,'')),''), _at_ms)
  on conflict (session_id, object_type, object_id) do nothing;
  return jsonb_build_object('ok', true, 'provenance',
    jsonb_build_object('call_id', _session, 'at_ms', _at_ms, 'written_by', _user,
                       'engine_invented', false));
end $$;

/** Ek call ka poora business record — sab asli rows se. */
create or replace function public.call_record(_session uuid, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s record; joined_ms bigint; left_ms bigint;
begin
  if not public.chat_feature_ok(_user, 'call_record') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;
  select * into s from public.chat_call_sessions where id = _session;
  if not found then return jsonb_build_object('allowed', true, 'found', false); end if;

  select min(at_ms) into joined_ms from public.chat_call_events
   where session_id = _session and event in ('joined','rejoined');
  select max(at_ms) into left_ms from public.chat_call_events
   where session_id = _session and event = 'left';

  return jsonb_build_object(
    'allowed', true, 'found', true, 'measured_not_estimated', true,
    'call', jsonb_build_object('id', s.id, 'conversation_id', s.conversation_id,
      'started_by', s.caller_id, 'started_at', s.started_at, 'ended_at', s.ended_at,
      'setup_ms', s.setup_ms, 'signaling', s.signaling, 'path', s.path,
      'video_codec', s.video_codec, 'ice_restarts', s.ice_restarts,
      'end_reason', s.end_reason),
    'duration_ms', case when joined_ms is not null and left_ms is not null
                        then left_ms - joined_ms else null end,
    'duration_source', 'join/leave events',
    'join_truth', coalesce((
      select jsonb_agg(jsonb_build_object('user_id', e.user_id, 'event', e.event,
               'at_ms', e.at_ms, 'transport', e.transport, 'path', e.path) order by e.id)
        from public.chat_call_events e where e.session_id = _session), '[]'::jsonb),
    'never_joined', coalesce((
      select jsonb_agg(distinct e.user_id) from public.chat_call_events e
       where e.session_id = _session and e.event = 'never_joined'), '[]'::jsonb),
    'transport_switches', coalesce((
      select jsonb_agg(jsonb_build_object('path', t.path, 'relay_host', t.relay_host,
               'reason', t.reason, 'at_ms', t.at_ms) order by t.id)
        from public.chat_call_transport_events t where t.session_id = _session), '[]'::jsonb),
    'files', coalesce((
      select jsonb_agg(jsonb_build_object('version_id', cf.version_id, 'shared_by', cf.shared_by,
               'at_ms', cf.at_ms, 'sha256', v.file_sha256, 'bytes', v.bytes,
               'name', f.name,
               'evidence', coalesce((select jsonb_agg(jsonb_build_object('state', e.state, 'at', e.at)
                                       order by e.id)
                                      from public.file_evidence e where e.version_id = cf.version_id),
                                    '[]'::jsonb)))
        from public.chat_call_files cf
        join public.chat_file_versions v on v.id = cf.version_id
        join public.chat_files f on f.id = v.file_id
       where cf.session_id = _session), '[]'::jsonb),
    'work', coalesce((
      select jsonb_agg(jsonb_build_object('object_type', w.object_type, 'object_id', w.object_id,
               'created_by', w.created_by, 'note', w.note, 'at_ms', w.at_ms))
        from public.chat_call_work w where w.session_id = _session), '[]'::jsonb));
end $$;

/** Conversation ke calls ka board (founder/manager ke liye aggregate-safe). */
create or replace function public.call_record_board(_user uuid, _conversation uuid, _limit int)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.chat_feature_ok(_user, 'call_record') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;
  return jsonb_build_object('allowed', true, 'calls', coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', s.id, 'started_at', s.started_at, 'ended_at', s.ended_at,
             'started_by', s.caller_id, 'path', s.path, 'signaling', s.signaling,
             'joins', (select count(*) from public.chat_call_events e
                        where e.session_id = s.id and e.event in ('joined','rejoined')),
             'never_joined', (select count(*) from public.chat_call_events e
                        where e.session_id = s.id and e.event = 'never_joined'),
             'files', (select count(*) from public.chat_call_files cf where cf.session_id = s.id),
             'work', (select count(*) from public.chat_call_work w where w.session_id = s.id))
           order by s.started_at desc)
      from public.chat_call_sessions s
     where (_conversation is null or s.conversation_id = _conversation)
       and (s.caller_id = _user or s.peer_id = _user)
     limit greatest(coalesce(_limit, 50), 1)), '[]'::jsonb));
end $$;

grant execute on function public.call_event_record(uuid, uuid, text, bigint, text, text, jsonb)
  to authenticated, service_role;
grant execute on function public.call_transport_record(uuid, uuid, text, text, text, bigint)
  to authenticated, service_role;
grant execute on function public.call_file_share(uuid, uuid, uuid, bigint) to authenticated, service_role;
grant execute on function public.call_work_link(uuid, text, uuid, text, uuid, bigint)
  to authenticated, service_role;
grant execute on function public.call_record(uuid, uuid) to authenticated, service_role;
grant execute on function public.call_record_board(uuid, uuid, int) to authenticated, service_role;
