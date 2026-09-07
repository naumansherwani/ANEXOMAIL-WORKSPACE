-- ============================================================================
-- ANEXOVIDEOCALL · PHASE 31A — LIGHT-SPEED CALL PATH (Rust-first, API-free)
--
--   QUIC datagram signaling · pre-warmed ICE · own Rust SFU rooms ·
--   codec ladder + simulcast · audio-first survival · playout tuning ·
--   relay honesty · self-made WebAudio ring (ringtone + ringback)
--
-- Supabase #4 = canonical truth. Idempotent. Phase 10A/10B/31 tables ZINDA
-- rehte hain — yahan koi duplicate nahi banaya.
-- Transport: RUST-FIRST — `/wt/*` QUIC datagrams + `/rpc/call.*` (:3200 / udp
-- 3443) PRIMARY; Bun `/api/chat/call/*` SIRF fallback. Zoom/Agora/Twilio/Daily
-- kabhi nahi — media WebRTC + apna coturn (anexovideocall.anexomail.com).
--
-- LOCK (non-negotiable):
--   1. RING TRUTH: ring · answered · declined · no_answer(45s) — "missed" ka
--      lafz kabhi nahi jab tak asli no-answer row na bane.
--   2. CONNECT MARKS asli browser readings hain (prewarm · gather · signaling
--      RTT · first frame). Koi marketing number nahi — na mile to null.
--   3. SURVIVAL: network gire to audio zinda, video drop — SAME session row,
--      naya call record kabhi nahi.
--   4. SFU room sirf 3+ ke liye; 1:1/2 mesh. Room ka `media_forwarding` flag
--      sach bolta hai — TURN ko SFU kehna mamnu.
--   5. RELAY HONESTY: p2p ya apna relay, jo asal ho wahi row aur wahi badge.
--   6. Calm Mode: sound nahi, sirf visual pulse + haptic — ye choice bhi record.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements — price ke mutabiq (basic/pro = zero access)
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'call_quic_signaling', false, null, 'ANEXOVideoCall included nahi'),
  ('pro',          'call_quic_signaling', false, null, 'ANEXOVideoCall included nahi'),
  ('business',     'call_quic_signaling', true,  null, 'QUIC datagram signaling + pre-warmed ICE'),
  ('business_pro', 'call_quic_signaling', true,  null, null),
  ('ai_pro',       'call_quic_signaling', true,  null, null),
  ('ai_business',  'call_quic_signaling', true,  null, null),
  ('ai_executive', 'call_quic_signaling', true,  null, null),
  ('founder',      'call_quic_signaling', true,  null, null),

  ('basic',        'call_ring',           false, null, null),
  ('pro',          'call_ring',           false, null, null),
  ('business',     'call_ring',           true,  45,   'ring window seconds · self-made WebAudio tone'),
  ('business_pro', 'call_ring',           true,  45,   null),
  ('ai_pro',       'call_ring',           true,  45,   null),
  ('ai_business',  'call_ring',           true,  45,   null),
  ('ai_executive', 'call_ring',           true,  60,   'longer ring window'),
  ('founder',      'call_ring',           true,  60,   null),

  ('basic',        'call_sfu',            false, null, null),
  ('pro',          'call_sfu',            false, null, null),
  ('business',     'call_sfu',            true,  8,    'own Rust SFU room · group 8'),
  ('business_pro', 'call_sfu',            true,  40,   'group 40'),
  ('ai_pro',       'call_sfu',            true,  8,    null),
  ('ai_business',  'call_sfu',            true,  40,   null),
  ('ai_executive', 'call_sfu',            true,  60,   'group 60'),
  ('founder',      'call_sfu',            true,  60,   null),

  ('basic',        'call_survival',       false, null, null),
  ('pro',          'call_survival',       false, null, null),
  ('business',     'call_survival',       true,  null, 'audio-first survival · same call record'),
  ('business_pro', 'call_survival',       true,  null, null),
  ('ai_pro',       'call_survival',       true,  null, null),
  ('ai_business',  'call_survival',       true,  null, null),
  ('ai_executive', 'call_survival',       true,  null, null),
  ('founder',      'call_survival',       true,  null, null),

  ('basic',        'call_connect_report', false, null, null),
  ('pro',          'call_connect_report', false, null, null),
  ('business',     'call_connect_report', true,  null, 'connect timing marks (measured)'),
  ('business_pro', 'call_connect_report', true,  null, 'p50/p95/p99 roll-up'),
  ('ai_pro',       'call_connect_report', true,  null, null),
  ('ai_business',  'call_connect_report', true,  null, null),
  ('ai_executive', 'call_connect_report', true,  null, null),
  ('founder',      'call_connect_report', true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ---------------------------------------------------------------------------
-- 1) RING TRUTH — ringtone/ringback ka asli record
-- ---------------------------------------------------------------------------
create table if not exists public.chat_call_rings (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null references public.chat_call_sessions(id) on delete cascade,
  from_user    uuid not null references auth.users(id) on delete cascade,
  to_user      uuid not null references auth.users(id) on delete cascade,
  -- caller ko ringback, callee ko ringtone — dono alag record
  tone         text not null default 'ringtone' check (tone in ('ringtone','ringback')),
  calm_mode    boolean not null default false,   -- true = sirf visual pulse + haptic
  trigger_path text not null default 'quic' check (trigger_path in ('quic','realtime','rows')),
  window_s     int not null default 45,
  rang_at_ms   bigint not null,
  answered_at_ms  bigint,
  declined_at_ms  bigint,
  no_answer_at_ms bigint,
  at           timestamptz not null default now(),
  unique (session_id, to_user, tone)
);
create index if not exists chat_call_rings_session on public.chat_call_rings (session_id);
grant select, insert, update on public.chat_call_rings to authenticated;
grant all on public.chat_call_rings to service_role;
alter table public.chat_call_rings enable row level security;
drop policy if exists chat_call_rings_read on public.chat_call_rings;
create policy chat_call_rings_read on public.chat_call_rings for select to authenticated
  using (from_user = auth.uid() or to_user = auth.uid());

create table if not exists public.chat_call_ring_log (
  id      bigserial primary key,
  ring_id uuid not null references public.chat_call_rings(id) on delete cascade,
  action  text not null check (action in ('rang','answered','declined','no_answer','calm_mode')),
  actor   uuid references auth.users(id) on delete set null,
  at_ms   bigint not null,
  at      timestamptz not null default now()
);
create index if not exists chat_call_ring_log_ring on public.chat_call_ring_log (ring_id, id);
grant select on public.chat_call_ring_log to authenticated;
grant all on public.chat_call_ring_log to service_role;
grant usage, select on sequence public.chat_call_ring_log_id_seq to service_role;
alter table public.chat_call_ring_log enable row level security;
drop policy if exists chat_call_ring_log_read on public.chat_call_ring_log;
create policy chat_call_ring_log_read on public.chat_call_ring_log for select to authenticated using (true);

create or replace function public.chat_call_ring_log_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'chat_call_ring_log append-only hai';
end $$;
drop trigger if exists chat_call_ring_log_no_change on public.chat_call_ring_log;
create trigger chat_call_ring_log_no_change before update or delete on public.chat_call_ring_log
  for each row execute function public.chat_call_ring_log_immutable();

-- ---------------------------------------------------------------------------
-- 2) CONNECT MARKS — light-speed ka asli sabooot (browser readings)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_call_connect_marks (
  id         bigserial primary key,
  session_id uuid not null references public.chat_call_sessions(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  mark       text not null check (mark in
               ('prewarm_started','prewarm_ready','ice_gather_first','signal_sent',
                'signal_rtt','answer_received','ice_connected','first_remote_frame')),
  value_ms   bigint,                     -- reading na ho to null — guess kabhi nahi
  transport  text check (transport in ('quic','realtime','rows')),
  at_ms      bigint not null,
  at         timestamptz not null default now()
);
create index if not exists chat_call_connect_marks_session
  on public.chat_call_connect_marks (session_id, id);
grant select, insert on public.chat_call_connect_marks to authenticated;
grant all on public.chat_call_connect_marks to service_role;
grant usage, select on sequence public.chat_call_connect_marks_id_seq to service_role;
alter table public.chat_call_connect_marks enable row level security;
drop policy if exists chat_call_connect_marks_read on public.chat_call_connect_marks;
create policy chat_call_connect_marks_read on public.chat_call_connect_marks
  for select to authenticated using (true);
drop policy if exists chat_call_connect_marks_insert on public.chat_call_connect_marks;
create policy chat_call_connect_marks_insert on public.chat_call_connect_marks
  for insert to authenticated with check (user_id = auth.uid());

create or replace function public.chat_call_connect_marks_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'chat_call_connect_marks append-only hai';
end $$;
drop trigger if exists chat_call_connect_marks_no_change on public.chat_call_connect_marks;
create trigger chat_call_connect_marks_no_change before update or delete
  on public.chat_call_connect_marks
  for each row execute function public.chat_call_connect_marks_immutable();

-- ---------------------------------------------------------------------------
-- 3) AUDIO-FIRST SURVIVAL — same call, naya record kabhi nahi
-- ---------------------------------------------------------------------------
create table if not exists public.chat_call_survival (
  id         bigserial primary key,
  session_id uuid not null references public.chat_call_sessions(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  state      text not null check (state in ('video_dropped','audio_only','video_restored','audio_lost')),
  reason     text not null,              -- bandwidth | cpu | ice_failed | packet_loss ...
  rtt_ms     int,
  loss_pct   numeric(5,2),
  at_ms      bigint not null,
  at         timestamptz not null default now()
);
create index if not exists chat_call_survival_session on public.chat_call_survival (session_id, id);
grant select, insert on public.chat_call_survival to authenticated;
grant all on public.chat_call_survival to service_role;
grant usage, select on sequence public.chat_call_survival_id_seq to service_role;
alter table public.chat_call_survival enable row level security;
drop policy if exists chat_call_survival_read on public.chat_call_survival;
create policy chat_call_survival_read on public.chat_call_survival for select to authenticated using (true);
drop policy if exists chat_call_survival_insert on public.chat_call_survival;
create policy chat_call_survival_insert on public.chat_call_survival
  for insert to authenticated with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4) OWN RUST SFU ROOMS — 3+ logon ke liye; mesh sirf 1:1/2
-- ---------------------------------------------------------------------------
create table if not exists public.chat_call_sfu_rooms (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  opened_by       uuid not null references auth.users(id) on delete restrict,
  -- topology sach bolta hai: mesh (P2P) ya sfu (apna Rust forwarder)
  topology        text not null default 'mesh' check (topology in ('mesh','sfu')),
  -- media forwarding asal mein live hai ya nahi — TURN ko SFU kehna mamnu
  media_forwarding boolean not null default false,
  engine_host     text,
  max_participants int not null default 8,
  opened_at       timestamptz not null default now(),
  closed_at       timestamptz,
  unique (conversation_id, opened_at)
);
create index if not exists chat_call_sfu_rooms_conv
  on public.chat_call_sfu_rooms (conversation_id, opened_at desc);
grant select, insert, update on public.chat_call_sfu_rooms to authenticated;
grant all on public.chat_call_sfu_rooms to service_role;
alter table public.chat_call_sfu_rooms enable row level security;
drop policy if exists chat_call_sfu_rooms_read on public.chat_call_sfu_rooms;
create policy chat_call_sfu_rooms_read on public.chat_call_sfu_rooms
  for select to authenticated using (true);

create table if not exists public.chat_call_sfu_participants (
  room_id   uuid not null references public.chat_call_sfu_rooms(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  layers    int not null default 3,      -- simulcast h/m/l
  codec     text,
  joined_at timestamptz not null default now(),
  left_at   timestamptz,
  primary key (room_id, user_id, joined_at)
);
grant select, insert, update on public.chat_call_sfu_participants to authenticated;
grant all on public.chat_call_sfu_participants to service_role;
alter table public.chat_call_sfu_participants enable row level security;
drop policy if exists chat_call_sfu_participants_read on public.chat_call_sfu_participants;
create policy chat_call_sfu_participants_read on public.chat_call_sfu_participants
  for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 5) functions
-- ---------------------------------------------------------------------------

/** Ring shuru — callee ko ringtone, caller ko ringback. Jhoota "missed" nahi. */
create or replace function public.call_ring_start(_session uuid, _from uuid, _to uuid,
                                                  _tone text, _calm boolean,
                                                  _trigger text, _at_ms bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare win int; ring_id uuid;
begin
  if not public.chat_feature_ok(_from, 'call_ring') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  win := coalesce((public.chat_feature_allowed(_from, 'call_ring')->>'limit')::int, 45);

  insert into public.chat_call_rings (session_id, from_user, to_user, tone, calm_mode,
                                      trigger_path, window_s, rang_at_ms)
  values (_session, _from, _to, coalesce(nullif(_tone,''),'ringtone'), coalesce(_calm,false),
          coalesce(nullif(_trigger,''),'quic'), win, _at_ms)
  on conflict (session_id, to_user, tone) do update
    set rang_at_ms = excluded.rang_at_ms, calm_mode = excluded.calm_mode,
        trigger_path = excluded.trigger_path
  returning id into ring_id;

  insert into public.chat_call_ring_log (ring_id, action, actor, at_ms)
  values (ring_id, 'rang', _from, _at_ms);
  if coalesce(_calm, false) then
    insert into public.chat_call_ring_log (ring_id, action, actor, at_ms)
    values (ring_id, 'calm_mode', _from, _at_ms);
  end if;

  return jsonb_build_object('ok', true, 'ring_id', ring_id, 'window_s', win,
    'sound', case when coalesce(_calm,false) then 'muted — visual pulse + haptic only'
                  else 'self-made WebAudio chime (no CDN, no library)' end);
end $$;

/** answered | declined | no_answer — teenon apna waqt le kar aate hain. */
create or replace function public.call_ring_settle(_ring uuid, _user uuid, _action text, _at_ms bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r record;
begin
  select * into r from public.chat_call_rings where id = _ring;
  if not found then return jsonb_build_object('ok', false, 'reason', 'ring_not_found'); end if;
  if _user not in (r.from_user, r.to_user) then
    return jsonb_build_object('ok', false, 'reason', 'not_a_participant');
  end if;
  if _action not in ('answered','declined','no_answer') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_action');
  end if;

  update public.chat_call_rings set
    answered_at_ms  = case when _action = 'answered'  then coalesce(answered_at_ms, _at_ms)  else answered_at_ms end,
    declined_at_ms  = case when _action = 'declined'  then coalesce(declined_at_ms, _at_ms)  else declined_at_ms end,
    no_answer_at_ms = case when _action = 'no_answer' then coalesce(no_answer_at_ms, _at_ms) else no_answer_at_ms end
   where id = _ring;

  insert into public.chat_call_ring_log (ring_id, action, actor, at_ms)
  values (_ring, _action, _user, _at_ms);

  return jsonb_build_object('ok', true, 'recorded', _action,
    'ring_to_answer_ms', case when _action = 'answered' then _at_ms - r.rang_at_ms else null end,
    'no_false_missed', true);
end $$;

/** Ring state — UI wahi likhta hai jo yahan record hai. */
create or replace function public.call_ring_state(_session uuid, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  return jsonb_build_object('rings', coalesce((
    select jsonb_agg(jsonb_build_object('ring_id', r.id, 'to_user', r.to_user, 'tone', r.tone,
             'calm_mode', r.calm_mode, 'trigger_path', r.trigger_path, 'window_s', r.window_s,
             'rang_at_ms', r.rang_at_ms, 'answered_at_ms', r.answered_at_ms,
             'declined_at_ms', r.declined_at_ms, 'no_answer_at_ms', r.no_answer_at_ms,
             'state', case when r.answered_at_ms is not null then 'answered'
                           when r.declined_at_ms is not null then 'declined'
                           when r.no_answer_at_ms is not null then 'no answer'
                           else 'ringing' end)
             order by r.at)
      from public.chat_call_rings r
     where r.session_id = _session and (r.from_user = _user or r.to_user = _user)), '[]'::jsonb));
end $$;

/** Connect mark — asli reading, warna null. */
create or replace function public.call_connect_mark(_session uuid, _user uuid, _mark text,
                                                    _value_ms bigint, _transport text, _at_ms bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_feature_ok(_user, 'call_connect_report') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  insert into public.chat_call_connect_marks (session_id, user_id, mark, value_ms, transport, at_ms)
  values (_session, _user, _mark, _value_ms, nullif(_transport,''), _at_ms);
  return jsonb_build_object('ok', true, 'measured_not_marketed', true);
end $$;

/** Ek call ka connect report — ring se pehli tasveer tak, sab measured. */
create or replace function public.call_connect_report(_session uuid, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare m jsonb;
begin
  if not public.chat_feature_ok(_user, 'call_connect_report') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;
  select coalesce(jsonb_object_agg(mark, value_ms), '{}'::jsonb) into m
    from (select mark, min(value_ms) as value_ms
            from public.chat_call_connect_marks
           where session_id = _session group by mark) t;
  return jsonb_build_object('allowed', true, 'marks', m,
    'signaling_transport', (select transport from public.chat_call_connect_marks
                             where session_id = _session and transport is not null
                             order by id desc limit 1),
    'survival', coalesce((
      select jsonb_agg(jsonb_build_object('state', s.state, 'reason', s.reason,
               'rtt_ms', s.rtt_ms, 'loss_pct', s.loss_pct, 'at_ms', s.at_ms) order by s.id)
        from public.chat_call_survival s where s.session_id = _session), '[]'::jsonb),
    'same_call_record', true,
    'nothing_estimated', true);
end $$;

/** Company-wide connect health — aggregate only (Business Pro+). */
create or replace function public.call_connect_health(_user uuid, _days int)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare d int := greatest(coalesce(_days, 7), 1);
begin
  if not public.chat_feature_ok(_user, 'call_connect_report') then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled');
  end if;
  return (
    select jsonb_build_object('allowed', true, 'window_days', d,
      'samples', count(*),
      'ring_to_frame_p50', percentile_disc(0.5) within group (order by value_ms),
      'ring_to_frame_p95', percentile_disc(0.95) within group (order by value_ms),
      'ring_to_frame_p99', percentile_disc(0.99) within group (order by value_ms),
      'source', 'browser first_remote_frame marks')
      from public.chat_call_connect_marks
     where mark = 'first_remote_frame' and value_ms is not null
       and at > now() - make_interval(days => d));
end $$;

/** SFU room: 3+ par apna Rust forwarder, 1:1/2 par mesh — label sach. */
create or replace function public.call_sfu_room_ensure(_conversation uuid, _user uuid,
                                                       _participants int, _engine_host text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare cap int; room record; want text; fwd boolean;
begin
  if not public.chat_feature_ok(_user, 'call_sfu') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  select coalesce(e.limit_value, 8) into cap
    from public.chat_phase_entitlements e
    join public.chat_plan_of(_user) p on true
   where e.feature = 'call_sfu' and e.plan = p limit 1;
  cap := coalesce(cap, 8);
  if coalesce(_participants, 2) > cap then
    return jsonb_build_object('ok', false, 'reason', 'group_size_over_plan', 'max_participants', cap);
  end if;

  want := case when coalesce(_participants, 2) >= 3 then 'sfu' else 'mesh' end;
  -- media_forwarding SIRF tab true jab engine host asal mein bataya gaya ho
  fwd := want = 'sfu' and coalesce(nullif(_engine_host,''), '') <> '';

  select * into room from public.chat_call_sfu_rooms
   where conversation_id = _conversation and closed_at is null
   order by opened_at desc limit 1;

  if not found then
    insert into public.chat_call_sfu_rooms (conversation_id, opened_by, topology,
                                            media_forwarding, engine_host, max_participants)
    values (_conversation, _user, want, fwd, nullif(_engine_host,''), cap)
    returning * into room;
  else
    update public.chat_call_sfu_rooms
       set topology = want, media_forwarding = fwd,
           engine_host = coalesce(nullif(_engine_host,''), engine_host),
           max_participants = cap
     where id = room.id returning * into room;
  end if;

  return jsonb_build_object('ok', true, 'room_id', room.id, 'topology', room.topology,
    'media_forwarding', room.media_forwarding, 'engine_host', room.engine_host,
    'max_participants', room.max_participants,
    'honest_label', case when room.topology = 'mesh' then 'Direct mesh (1:1 or 2 people)'
                         when room.media_forwarding then 'Our own Rust SFU is forwarding this call'
                         else 'Group room open — SFU forwarding not reported by the engine yet' end,
    'turn_is_not_sfu', true);
end $$;

create or replace function public.call_sfu_join(_room uuid, _user uuid, _layers int, _codec text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare live int; cap int;
begin
  if not public.chat_feature_ok(_user, 'call_sfu') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  select max_participants into cap from public.chat_call_sfu_rooms where id = _room;
  if cap is null then return jsonb_build_object('ok', false, 'reason', 'room_not_found'); end if;
  select count(*) into live from public.chat_call_sfu_participants
   where room_id = _room and left_at is null;
  if live >= cap then
    return jsonb_build_object('ok', false, 'reason', 'room_full', 'max_participants', cap);
  end if;
  insert into public.chat_call_sfu_participants (room_id, user_id, layers, codec)
  values (_room, _user, coalesce(_layers, 3), nullif(_codec,''));
  return jsonb_build_object('ok', true, 'room_id', _room, 'simulcast_layers', coalesce(_layers, 3));
end $$;

create or replace function public.call_sfu_leave(_room uuid, _user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.chat_call_sfu_participants set left_at = now()
   where room_id = _room and user_id = _user and left_at is null;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.call_sfu_state(_conversation uuid, _user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare room record;
begin
  select * into room from public.chat_call_sfu_rooms
   where conversation_id = _conversation and closed_at is null
   order by opened_at desc limit 1;
  if not found then
    return jsonb_build_object('open', false, 'topology', 'mesh',
      'honest_label', 'No group room open — direct mesh');
  end if;
  return jsonb_build_object('open', true, 'room_id', room.id, 'topology', room.topology,
    'media_forwarding', room.media_forwarding, 'engine_host', room.engine_host,
    'max_participants', room.max_participants,
    'participants', coalesce((
      select jsonb_agg(jsonb_build_object('user_id', p.user_id, 'layers', p.layers,
               'codec', p.codec, 'joined_at', p.joined_at, 'left_at', p.left_at)
               order by p.joined_at)
        from public.chat_call_sfu_participants p where p.room_id = room.id), '[]'::jsonb));
end $$;

/** Audio-first survival — video gira, call zinda; SAME session row. */
create or replace function public.call_survival_record(_session uuid, _user uuid, _state text,
                                                       _reason text, _rtt int, _loss numeric,
                                                       _at_ms bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_feature_ok(_user, 'call_survival') then
    return jsonb_build_object('ok', false, 'reason', 'plan_not_entitled');
  end if;
  if length(btrim(coalesce(_reason,''))) < 3 then
    return jsonb_build_object('ok', false, 'reason', 'reason_required');
  end if;
  insert into public.chat_call_survival (session_id, user_id, state, reason, rtt_ms, loss_pct, at_ms)
  values (_session, _user, _state, btrim(_reason), _rtt, _loss, _at_ms);
  return jsonb_build_object('ok', true, 'same_call_record', true, 'new_call_created', false);
end $$;

grant execute on function public.call_ring_start(uuid, uuid, uuid, text, boolean, text, bigint)
  to authenticated, service_role;
grant execute on function public.call_ring_settle(uuid, uuid, text, bigint) to authenticated, service_role;
grant execute on function public.call_ring_state(uuid, uuid) to authenticated, service_role;
grant execute on function public.call_connect_mark(uuid, uuid, text, bigint, text, bigint)
  to authenticated, service_role;
grant execute on function public.call_connect_report(uuid, uuid) to authenticated, service_role;
grant execute on function public.call_connect_health(uuid, int) to authenticated, service_role;
grant execute on function public.call_sfu_room_ensure(uuid, uuid, int, text) to authenticated, service_role;
grant execute on function public.call_sfu_join(uuid, uuid, int, text) to authenticated, service_role;
grant execute on function public.call_sfu_leave(uuid, uuid) to authenticated, service_role;
grant execute on function public.call_sfu_state(uuid, uuid) to authenticated, service_role;
grant execute on function public.call_survival_record(uuid, uuid, text, text, int, numeric, bigint)
  to authenticated, service_role;
