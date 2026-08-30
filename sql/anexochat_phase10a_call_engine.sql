-- ============================================================================
-- ANEXOChat · PHASE 10A — ANEXOVIDEOCHAT ULTRA-LOW-LATENCY CALL ENGINE
-- Supabase #4 · idempotent + self-healing · GRANTs + RLS + plan gate
--
-- SQL EDITOR: poori file select karke paste karo
--   (Phase 1 + Phase 3 + Phase 7 pehle chal chuki hain)
--
-- FOUNDER LOCK:
--   1. Signaling PRIMARY = WebTransport -> Supabase Realtime broadcast.
--      Ye rows DURABLE truth + late-join/fallback hain — polling primary nahi.
--   2. Telemetry APPEND-ONLY: chat_call_stats mein update/delete kabhi nahi.
--      "Speed is measured, not marketed" — koi value frontend se claim nahi hoti.
--   3. Gate wahi purana chat_video_allowed(): founder + business_pro. Baki 403.
--   4. TURN credentials kabhi DB/frontend mein store nahi — HMAC se runtime par
--      bante hain (server-side secret). Yahan sirf relay ka FACT log hota hai.
-- ============================================================================

-- ---------- 0) signal kinds: trickle + ICE restart + capability ----------
alter table public.chat_signals drop constraint if exists chat_signals_kind_check;
alter table public.chat_signals add constraint chat_signals_kind_check
  check (kind in ('offer','answer','ice','ice-end','restart','end','ring','stats'));

-- Realtime publication (broadcast + postgres_changes dono ke liye)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.chat_signals;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- ---------- 1) call sessions (one row per call attempt) ----------
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='chat_call_sessions')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='chat_call_sessions'
               and column_name='ice_restarts') then
    execute 'alter table public.chat_call_sessions rename to chat_call_sessions_legacy';
  end if;
end $$;

create table if not exists public.chat_call_sessions (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.chat_conversations(id) on delete cascade,
  workspace_id     uuid,
  caller_id        uuid not null references auth.users(id) on delete cascade,
  peer_id          uuid references auth.users(id) on delete set null,
  role             text not null default 'caller' check (role in ('caller','callee')),
  started_at       timestamptz not null default now(),
  connected_at     timestamptz,
  ended_at         timestamptz,
  setup_ms         integer,
  path             text check (path in ('p2p','relay','unknown')),
  video_codec      text,
  audio_codec      text default 'opus',
  ice_restarts     integer not null default 0,
  end_reason       text,
  signaling        text check (signaling in ('webtransport','realtime','rows'))
);
create index if not exists chat_call_sessions_conv on public.chat_call_sessions (conversation_id, started_at desc);
create index if not exists chat_call_sessions_recent on public.chat_call_sessions (started_at desc);
grant select, insert on public.chat_call_sessions to authenticated;
grant all on public.chat_call_sessions to service_role;
alter table public.chat_call_sessions enable row level security;
drop policy if exists chat_call_sessions_own on public.chat_call_sessions;
create policy chat_call_sessions_own on public.chat_call_sessions for select to authenticated
  using (caller_id = auth.uid() or peer_id = auth.uid());

-- ---------- 2) append-only telemetry samples ----------
create table if not exists public.chat_call_stats (
  id            bigserial primary key,
  session_id    uuid not null references public.chat_call_sessions(id) on delete cascade,
  at            timestamptz not null default now(),
  rtt_ms        integer,
  jitter_ms     integer,
  loss_pct      numeric(5,2),
  bitrate_kbps  integer,
  fps           integer,
  width         integer,
  height        integer,
  path          text check (path in ('p2p','relay','unknown')),
  video_codec   text,
  quality       text check (quality in ('good','fair','poor'))
);
create index if not exists chat_call_stats_session on public.chat_call_stats (session_id, at);
grant select, insert on public.chat_call_stats to authenticated;
grant all on public.chat_call_stats to service_role;
alter table public.chat_call_stats enable row level security;
drop policy if exists chat_call_stats_own on public.chat_call_stats;
create policy chat_call_stats_own on public.chat_call_stats for select to authenticated
  using (exists (select 1 from public.chat_call_sessions s
                 where s.id = session_id and (s.caller_id = auth.uid() or s.peer_id = auth.uid())));
-- APPEND ONLY: koi update/delete policy nahi, aur grant bhi nahi.

-- ---------- 3) RPC: call start ----------
create or replace function public.chat_call_start(
  _conv uuid, _user uuid, _peer uuid, _role text, _signaling text
) returns uuid language plpgsql security definer set search_path = public as $$
declare sid uuid; ws uuid;
begin
  if not public.chat_video_allowed(_user) then raise exception 'video_not_entitled'; end if;
  select workspace_id into ws from public.chat_conversations where id = _conv;
  if ws is null then raise exception 'conversation_not_found'; end if;
  insert into public.chat_call_sessions
    (conversation_id, workspace_id, caller_id, peer_id, role, signaling)
  values (_conv, ws, _user, nullif(_peer, _user),
          coalesce(nullif(_role,''), 'caller'),
          nullif(_signaling,''))
  returning id into sid;
  perform public.chat_log(ws, _user, 'call.start', sid::text,
    jsonb_build_object('conversation', _conv, 'signaling', _signaling));
  return sid;
end $$;
revoke all on function public.chat_call_start(uuid,uuid,uuid,text,text) from public;
grant execute on function public.chat_call_start(uuid,uuid,uuid,text,text) to authenticated, service_role;

-- ---------- 4) RPC: telemetry sample (append-only) ----------
create or replace function public.chat_call_stat(
  _session uuid, _user uuid, _sample jsonb
) returns boolean language plpgsql security definer set search_path = public as $$
declare owns boolean;
begin
  select true into owns from public.chat_call_sessions
   where id = _session and (caller_id = _user or peer_id = _user);
  if owns is not true then raise exception 'not_your_call'; end if;

  insert into public.chat_call_stats
    (session_id, rtt_ms, jitter_ms, loss_pct, bitrate_kbps, fps, width, height, path, video_codec, quality)
  values (
    _session,
    nullif((_sample->>'rtt_ms'),'')::int,
    nullif((_sample->>'jitter_ms'),'')::int,
    nullif((_sample->>'loss_pct'),'')::numeric,
    nullif((_sample->>'bitrate_kbps'),'')::int,
    nullif((_sample->>'fps'),'')::int,
    nullif((_sample->>'width'),'')::int,
    nullif((_sample->>'height'),'')::int,
    nullif((_sample->>'path'),''),
    nullif((_sample->>'video_codec'),''),
    nullif((_sample->>'quality'),'')
  );

  -- pehla connected sample = asli setup time (measured, claimed nahi)
  update public.chat_call_sessions s
     set connected_at = coalesce(s.connected_at, now()),
         setup_ms = coalesce(s.setup_ms,
                     greatest(0, (extract(epoch from (now() - s.started_at)) * 1000)::int)),
         path = coalesce(nullif(_sample->>'path',''), s.path),
         video_codec = coalesce(nullif(_sample->>'video_codec',''), s.video_codec),
         ice_restarts = greatest(s.ice_restarts,
                          coalesce(nullif(_sample->>'ice_restarts','')::int, 0))
   where s.id = _session;
  return true;
end $$;
revoke all on function public.chat_call_stat(uuid,uuid,jsonb) from public;
grant execute on function public.chat_call_stat(uuid,uuid,jsonb) to authenticated, service_role;

-- ---------- 5) RPC: call end ----------
create or replace function public.chat_call_end(
  _session uuid, _user uuid, _reason text
) returns boolean language plpgsql security definer set search_path = public as $$
begin
  update public.chat_call_sessions
     set ended_at = coalesce(ended_at, now()),
         end_reason = coalesce(end_reason, nullif(_reason,''))
   where id = _session and (caller_id = _user or peer_id = _user);
  return true;
end $$;
revoke all on function public.chat_call_end(uuid,uuid,text) from public;
grant execute on function public.chat_call_end(uuid,uuid,text) to authenticated, service_role;

-- ---------- 6) FOUNDER founder view: measured aggregates ----------
create or replace function public.chat_is_founder(_user uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare found boolean := false;
begin
  if _user is null then return false; end if;
  if to_regclass('public.founder_accounts') is not null then
    execute 'select exists(select 1 from public.founder_accounts where user_id = $1)'
      into found using _user;
  end if;
  return coalesce(found, false);
end $$;
revoke all on function public.chat_is_founder(uuid) from public;
grant execute on function public.chat_is_founder(uuid) to authenticated, service_role;

create or replace function public.chat_call_health(_user uuid, _days int default 7)
returns jsonb language plpgsql security definer set search_path = public as $$
declare out jsonb;
begin
  if not public.chat_is_founder(_user) then raise exception 'founder_only'; end if;
  select jsonb_build_object(
    'window_days', _days,
    'calls', count(*),
    'connected', count(*) filter (where connected_at is not null),
    'setup_p50_ms', percentile_disc(0.5) within group (order by setup_ms) filter (where setup_ms is not null),
    'setup_p95_ms', percentile_disc(0.95) within group (order by setup_ms) filter (where setup_ms is not null),
    'relay_pct', round(100.0 * count(*) filter (where path = 'relay')
                  / greatest(1, count(*) filter (where path is not null)), 1),
    'reconnect_rate', round(1.0 * sum(ice_restarts) / greatest(1, count(*)), 2)
  ) into out
  from public.chat_call_sessions
  where started_at > now() - make_interval(days => _days);
  return coalesce(out, '{}'::jsonb);
end $$;
revoke all on function public.chat_call_health(uuid,int) from public;
grant execute on function public.chat_call_health(uuid,int) to authenticated, service_role;

create or replace function public.chat_call_recent(_user uuid, _limit int default 40)
returns setof jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.chat_is_founder(_user) then raise exception 'founder_only'; end if;
  return query
  select jsonb_build_object(
    'id', s.id, 'started_at', s.started_at, 'setup_ms', s.setup_ms,
    'path', s.path, 'signaling', s.signaling, 'video_codec', s.video_codec,
    'ice_restarts', s.ice_restarts, 'end_reason', s.end_reason,
    'connected', s.connected_at is not null,
    'rtt_ms', st.rtt_ms, 'jitter_ms', st.jitter_ms, 'loss_pct', st.loss_pct,
    'bitrate_kbps', st.bitrate_kbps, 'fps', st.fps,
    'resolution', case when st.width is null then null else st.width || 'x' || st.height end
  )
  from public.chat_call_sessions s
  left join lateral (
    select * from public.chat_call_stats x where x.session_id = s.id order by x.at desc limit 1
  ) st on true
  order by s.started_at desc
  limit greatest(1, least(_limit, 200));
end $$;
revoke all on function public.chat_call_recent(uuid,int) from public;
grant execute on function public.chat_call_recent(uuid,int) to authenticated, service_role;

-- ---------- VERIFY ----------
-- select count(*) from public.chat_call_sessions;
-- select public.chat_call_health('3e3a60ea-1580-4443-94f6-b758de732dce', 7);
