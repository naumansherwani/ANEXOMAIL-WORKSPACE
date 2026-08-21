-- ============================================================================
-- ANEXOCHAT · PHASE 10B — ADAPTIVE 8K VIDEO TELEMETRY (Supabase #4)
-- Idempotent + self-healing. Truth rule: sirf asli readings store hoti hain.
-- Phase 10A ke chat_call_* tables ke upar sirf naye columns + views.
-- ============================================================================

-- 1) call sessions par asli capture/encode/decode truth ------------------------
do $$
begin
  if to_regclass('public.chat_call_sessions') is null then
    raise notice 'chat_call_sessions missing — run sql/anexochat_phase10a_call_engine.sql first';
    return;
  end if;

  alter table public.chat_call_sessions
    add column if not exists capture_width int,
    add column if not exists capture_height int,
    add column if not exists capture_native_8k boolean not null default false,
    add column if not exists max_encoded_width int,
    add column if not exists max_encoded_height int,
    add column if not exists max_decoded_width int,
    add column if not exists max_decoded_height int,
    add column if not exists top_rung text,
    add column if not exists codec_negotiated text,
    add column if not exists hw_accelerated boolean,
    add column if not exists downgrades int not null default 0,
    add column if not exists upgrades int not null default 0;
end $$;

-- 2) per-sample ladder truth ---------------------------------------------------
do $$
begin
  if to_regclass('public.chat_call_samples') is null then
    raise notice 'chat_call_samples missing — run Phase 10A SQL first';
    return;
  end if;

  alter table public.chat_call_samples
    add column if not exists capture_width int,
    add column if not exists capture_height int,
    add column if not exists encoded_width int,
    add column if not exists encoded_height int,
    add column if not exists decoded_width int,
    add column if not exists decoded_height int,
    add column if not exists rung text,
    add column if not exists quality_limitation text,
    add column if not exists available_out_kbps int,
    add column if not exists frames_dropped int,
    add column if not exists power_efficient boolean;
end $$;

-- 3) sample writer ko naye fields samajhne do ---------------------------------
create or replace function public.chat_call_stat(
  _session uuid,
  _user uuid,
  _sample jsonb
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv uuid;
begin
  select conversation_id into v_conv
  from public.chat_call_sessions
  where id = _session;

  if v_conv is null then
    return false;
  end if;

  insert into public.chat_call_samples (
    session_id, user_id, rtt_ms, jitter_ms, loss_pct, bitrate_kbps, fps,
    width, height, path, video_codec, audio_codec, quality,
    capture_width, capture_height, encoded_width, encoded_height,
    decoded_width, decoded_height, rung, quality_limitation,
    available_out_kbps, frames_dropped, power_efficient
  ) values (
    _session, _user,
    nullif((_sample->>'rtt_ms'), '')::int,
    nullif((_sample->>'jitter_ms'), '')::int,
    nullif((_sample->>'loss_pct'), '')::numeric,
    nullif((_sample->>'bitrate_kbps'), '')::int,
    nullif((_sample->>'fps'), '')::int,
    nullif((_sample->>'width'), '')::int,
    nullif((_sample->>'height'), '')::int,
    nullif((_sample->>'path'), ''),
    nullif((_sample->>'video_codec'), ''),
    nullif((_sample->>'audio_codec'), ''),
    nullif((_sample->>'quality'), ''),
    nullif((_sample->>'capture_width'), '')::int,
    nullif((_sample->>'capture_height'), '')::int,
    nullif((_sample->>'encoded_width'), '')::int,
    nullif((_sample->>'encoded_height'), '')::int,
    nullif((_sample->>'decoded_width'), '')::int,
    nullif((_sample->>'decoded_height'), '')::int,
    nullif((_sample->>'rung'), ''),
    nullif((_sample->>'quality_limitation'), ''),
    nullif((_sample->>'available_out_kbps'), '')::int,
    nullif((_sample->>'frames_dropped'), '')::int,
    case when _sample ? 'power_efficient'
         then (_sample->>'power_efficient')::boolean end
  );

  update public.chat_call_sessions s set
    capture_width      = coalesce(nullif((_sample->>'capture_width'), '')::int, s.capture_width),
    capture_height     = coalesce(nullif((_sample->>'capture_height'), '')::int, s.capture_height),
    capture_native_8k  = s.capture_native_8k
                         or coalesce(nullif((_sample->>'capture_width'), '')::int, 0) >= 7680,
    max_encoded_width  = greatest(coalesce(s.max_encoded_width, 0),
                                  coalesce(nullif((_sample->>'encoded_width'), '')::int, 0)),
    max_encoded_height = greatest(coalesce(s.max_encoded_height, 0),
                                  coalesce(nullif((_sample->>'encoded_height'), '')::int, 0)),
    max_decoded_width  = greatest(coalesce(s.max_decoded_width, 0),
                                  coalesce(nullif((_sample->>'decoded_width'), '')::int, 0)),
    max_decoded_height = greatest(coalesce(s.max_decoded_height, 0),
                                  coalesce(nullif((_sample->>'decoded_height'), '')::int, 0)),
    top_rung           = coalesce(nullif((_sample->>'rung'), ''), s.top_rung),
    codec_negotiated   = coalesce(nullif((_sample->>'video_codec'), ''), s.codec_negotiated),
    hw_accelerated     = coalesce(case when _sample ? 'power_efficient'
                                       then (_sample->>'power_efficient')::boolean end,
                                  s.hw_accelerated)
  where s.id = _session;

  return true;
end $$;

grant execute on function public.chat_call_stat(uuid, uuid, jsonb) to authenticated, service_role;

-- 4) founder view: 8K asal mein kitni baar chala (marketing nahi, measurement)
create or replace view public.chat_call_resolution_truth as
select
  date_trunc('day', s.started_at)                             as day,
  count(*)                                                    as calls,
  count(*) filter (where s.capture_native_8k)                  as native_8k_capture,
  count(*) filter (where s.max_encoded_width >= 7680)          as encoded_8k,
  count(*) filter (where s.max_decoded_width >= 7680)          as decoded_8k,
  count(*) filter (where s.max_encoded_width >= 3840
                     and s.max_encoded_width < 7680)           as encoded_4k,
  count(*) filter (where s.codec_negotiated ilike 'av1%')      as av1_calls,
  count(*) filter (where s.codec_negotiated ilike 'vp9%')      as vp9_calls,
  count(*) filter (where s.codec_negotiated ilike 'h264%')     as h264_calls,
  sum(s.downgrades)                                            as downgrades,
  sum(s.upgrades)                                              as upgrades
from public.chat_call_sessions s
group by 1
order by 1 desc;

grant select on public.chat_call_resolution_truth to service_role;
