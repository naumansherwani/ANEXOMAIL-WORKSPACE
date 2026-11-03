-- ============================================================================
-- ANEXOCHAT · PHASE 10B — ADAPTIVE 8K VIDEO TELEMETRY (Supabase #4)
-- Idempotent + self-healing. Phase 10A (`anexochat_phase10a_call_engine.sql`)
-- ke chat_call_sessions / chat_call_stats ke upar sirf naye columns + view.
-- TRUTH RULE: "8K" tab hi likha jata hai jab asli 7680x4320 measure hua ho.
-- ============================================================================

-- 0) SELF-HEALING: agar Phase 10A nahi chali to base tables khud bana do -------
do $$
begin
  if to_regclass('public.chat_call_sessions') is null then
    create table public.chat_call_sessions (
      id               uuid primary key default gen_random_uuid(),
      conversation_id  uuid not null,
      workspace_id     uuid,
      caller_id        uuid not null,
      peer_id          uuid,
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
    create index chat_call_sessions_conv   on public.chat_call_sessions (conversation_id, started_at desc);
    create index chat_call_sessions_recent on public.chat_call_sessions (started_at desc);
    grant select, insert on public.chat_call_sessions to authenticated;
    grant all on public.chat_call_sessions to service_role;
    alter table public.chat_call_sessions enable row level security;
    create policy chat_call_sessions_own on public.chat_call_sessions for select to authenticated
      using (caller_id = auth.uid() or peer_id = auth.uid());
  end if;

  if to_regclass('public.chat_call_stats') is null then
    create table public.chat_call_stats (
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
    create index chat_call_stats_session on public.chat_call_stats (session_id, at);
    grant select, insert on public.chat_call_stats to authenticated;
    grant all on public.chat_call_stats to service_role;
    alter table public.chat_call_stats enable row level security;
    create policy chat_call_stats_own on public.chat_call_stats for select to authenticated
      using (exists (select 1 from public.chat_call_sessions s
                     where s.id = session_id and (s.caller_id = auth.uid() or s.peer_id = auth.uid())));
  end if;
end $$;

-- 1) session par asli capture / encode / decode truth --------------------------
do $$
begin
  if to_regclass('public.chat_call_sessions') is null then
    raise notice 'chat_call_sessions missing — pehle sql/anexochat_phase10a_call_engine.sql chalao';
    return;
  end if;

  alter table public.chat_call_sessions
    add column if not exists capture_width      integer,
    add column if not exists capture_height     integer,
    add column if not exists capture_native_8k  boolean not null default false,
    add column if not exists max_encoded_width  integer,
    add column if not exists max_encoded_height integer,
    add column if not exists max_decoded_width  integer,
    add column if not exists max_decoded_height integer,
    add column if not exists top_rung           text,
    add column if not exists hw_accelerated     boolean,
    add column if not exists downgrades         integer not null default 0,
    add column if not exists upgrades           integer not null default 0;
end $$;

-- 2) per-sample ladder truth (append-only table) ------------------------------
do $$
begin
  if to_regclass('public.chat_call_stats') is null then
    raise notice 'chat_call_stats missing — pehle Phase 10A SQL chalao';
    return;
  end if;

  alter table public.chat_call_stats
    add column if not exists capture_width       integer,
    add column if not exists capture_height      integer,
    add column if not exists encoded_width       integer,
    add column if not exists encoded_height      integer,
    add column if not exists decoded_width       integer,
    add column if not exists decoded_height      integer,
    add column if not exists rung                text,
    add column if not exists quality_limitation  text,
    add column if not exists available_out_kbps  integer,
    add column if not exists frames_dropped      integer,
    add column if not exists power_efficient     boolean,
    add column if not exists audio_codec         text;
end $$;

-- 3) sample writer: 10A ka ownership check + 10B ke naye fields ----------------
create or replace function public.chat_call_stat(
  _session uuid, _user uuid, _sample jsonb
) returns boolean language plpgsql security definer set search_path = public as $$
declare owns boolean;
begin
  select true into owns from public.chat_call_sessions
   where id = _session and (caller_id = _user or peer_id = _user);
  if owns is not true then raise exception 'not_your_call'; end if;

  insert into public.chat_call_stats (
    session_id, rtt_ms, jitter_ms, loss_pct, bitrate_kbps, fps, width, height,
    path, video_codec, audio_codec, quality,
    capture_width, capture_height, encoded_width, encoded_height,
    decoded_width, decoded_height, rung, quality_limitation,
    available_out_kbps, frames_dropped, power_efficient
  ) values (
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
    nullif((_sample->>'audio_codec'),''),
    nullif((_sample->>'quality'),''),
    nullif((_sample->>'capture_width'),'')::int,
    nullif((_sample->>'capture_height'),'')::int,
    nullif((_sample->>'encoded_width'),'')::int,
    nullif((_sample->>'encoded_height'),'')::int,
    nullif((_sample->>'decoded_width'),'')::int,
    nullif((_sample->>'decoded_height'),'')::int,
    nullif((_sample->>'rung'),''),
    nullif((_sample->>'quality_limitation'),''),
    nullif((_sample->>'available_out_kbps'),'')::int,
    nullif((_sample->>'frames_dropped'),'')::int,
    case when _sample ? 'power_efficient' then (_sample->>'power_efficient')::boolean end
  );

  update public.chat_call_sessions s set
    capture_width      = coalesce(nullif((_sample->>'capture_width'),'')::int, s.capture_width),
    capture_height     = coalesce(nullif((_sample->>'capture_height'),'')::int, s.capture_height),
    capture_native_8k  = s.capture_native_8k
                          or coalesce(nullif((_sample->>'capture_width'),'')::int, 0) >= 7680,
    max_encoded_width  = greatest(coalesce(s.max_encoded_width, 0),
                                  coalesce(nullif((_sample->>'encoded_width'),'')::int, 0)),
    max_encoded_height = greatest(coalesce(s.max_encoded_height, 0),
                                  coalesce(nullif((_sample->>'encoded_height'),'')::int, 0)),
    max_decoded_width  = greatest(coalesce(s.max_decoded_width, 0),
                                  coalesce(nullif((_sample->>'decoded_width'),'')::int, 0)),
    max_decoded_height = greatest(coalesce(s.max_decoded_height, 0),
                                  coalesce(nullif((_sample->>'decoded_height'),'')::int, 0)),
    top_rung           = coalesce(nullif((_sample->>'rung'),''), s.top_rung),
    video_codec        = coalesce(nullif((_sample->>'video_codec'),''), s.video_codec),
    hw_accelerated     = coalesce(
                           case when _sample ? 'power_efficient'
                                then (_sample->>'power_efficient')::boolean end,
                           s.hw_accelerated),
    downgrades         = s.downgrades + coalesce(nullif((_sample->>'downgrade'),'')::int, 0),
    upgrades           = s.upgrades   + coalesce(nullif((_sample->>'upgrade'),'')::int, 0)
  where s.id = _session;

  return true;
end $$;

revoke all on function public.chat_call_stat(uuid, uuid, jsonb) from public;
grant execute on function public.chat_call_stat(uuid, uuid, jsonb) to authenticated, service_role;

-- 4) founder view: 8K asal mein kitni baar chala (measured, not marketed) ------
create or replace view public.chat_call_resolution_truth as
select
  date_trunc('day', s.started_at)                                as day,
  count(*)                                                       as calls,
  count(*) filter (where s.capture_native_8k)                     as native_8k_capture,
  count(*) filter (where coalesce(s.max_encoded_width,0) >= 7680) as encoded_8k,
  count(*) filter (where coalesce(s.max_decoded_width,0) >= 7680) as decoded_8k,
  count(*) filter (where coalesce(s.max_encoded_width,0) >= 3840
                     and coalesce(s.max_encoded_width,0) <  7680) as encoded_4k,
  count(*) filter (where s.video_codec ilike 'av1%')              as av1_calls,
  count(*) filter (where s.video_codec ilike 'vp9%')              as vp9_calls,
  count(*) filter (where s.video_codec ilike 'h264%')             as h264_calls,
  sum(s.downgrades)                                               as downgrades,
  sum(s.upgrades)                                                 as upgrades
from public.chat_call_sessions s
group by 1
order by 1 desc;

grant select on public.chat_call_resolution_truth to service_role;
