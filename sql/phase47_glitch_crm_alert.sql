-- ============================================================
-- ANEXOMAIL — PHASE 47: GLITCH TRUTH + WHATSAPP ALERTS
-- Kahan chale: Supabase #4 -> SQL Editor. Idempotent + self-healing.
--
-- Maqsad: user ko website par koi bhi glitch aaye -> founder ke WhatsApp par
-- 2 minute ke andar. Lekin FAZOOL alert bilkul nahi:
--   - noise rules (browser shor, extension errors, chunk reload) = ignore
--   - same fingerprint = ek hi alert, occurrences count barhta hai
--   - rate cap: 12 alert/hour, uske baad muted (log phir bhi rehta hai)
--   - rage click alert sirf jab 3+ alag session ek hi button par phansein
-- ============================================================

begin;

-- 1) TABLES ----------------------------------------------------------------
create table if not exists public.customer_glitch_logs (
  id             uuid primary key default gen_random_uuid(),
  occurred_at    timestamptz not null default now(),
  kind           text not null,                -- js_error | unhandled_rejection | console_error | api_error | checkout_error | render_error
  severity       text not null default 'error', -- info | warning | error | critical
  route          text,
  message        text not null,
  fingerprint    text not null,
  stack          text,
  user_id        uuid,
  session_id     text,
  recording_url  text,                          -- PostHog session replay link
  meta           jsonb not null default '{}'::jsonb,
  alerted        boolean not null default false,
  created_at     timestamptz not null default now()
);

create table if not exists public.feedback_user_triggers (
  id            uuid primary key default gen_random_uuid(),
  occurred_at   timestamptz not null default now(),
  trigger_type  text not null,                 -- rage_click | dead_click | repeat_error | checkout_stuck | manual_feedback
  route         text,
  target_label  text,
  hit_count     int not null default 1,
  user_id       uuid,
  session_id    text,
  recording_url text,
  meta          jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

create table if not exists public.glitch_noise_rules (
  id            uuid primary key default gen_random_uuid(),
  kind          text,                          -- null = har kind
  message_like  text not null,                 -- ilike pattern
  action        text not null default 'ignore',-- ignore | log_only
  reason        text,
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

create table if not exists public.glitch_alerts (
  id            uuid primary key default gen_random_uuid(),
  fingerprint   text not null,
  summary       text not null,
  severity      text not null default 'error',
  route         text,
  first_seen    timestamptz not null default now(),
  last_seen     timestamptz not null default now(),
  occurrences   int not null default 1,
  sessions      int not null default 1,
  recording_url text,
  status        text not null default 'pending', -- pending | sent | muted | failed
  sent_at       timestamptz,
  channel_ref   text,
  last_error    text,
  created_at    timestamptz not null default now()
);

create index if not exists customer_glitch_logs_fp_idx on public.customer_glitch_logs (fingerprint, occurred_at desc);
create index if not exists customer_glitch_logs_time_idx on public.customer_glitch_logs (occurred_at desc);
create index if not exists feedback_user_triggers_type_idx on public.feedback_user_triggers (trigger_type, occurred_at desc);
create unique index if not exists glitch_alerts_open_fp_idx
  on public.glitch_alerts (fingerprint) where status = 'pending';
create index if not exists glitch_alerts_status_idx on public.glitch_alerts (status, last_seen desc);

-- 2) GRANTS (Data API ke liye lazmi) --------------------------------------
grant select on public.customer_glitch_logs to authenticated;
grant select on public.feedback_user_triggers to authenticated;
grant select on public.glitch_alerts to authenticated;
grant select on public.glitch_noise_rules to authenticated;
grant all on public.customer_glitch_logs to service_role;
grant all on public.feedback_user_triggers to service_role;
grant all on public.glitch_alerts to service_role;
grant all on public.glitch_noise_rules to service_role;

-- 3) RLS: sirf founder padh sakta hai, likhna sirf backend (service_role) --
alter table public.customer_glitch_logs enable row level security;
alter table public.feedback_user_triggers enable row level security;
alter table public.glitch_alerts enable row level security;
alter table public.glitch_noise_rules enable row level security;

do $$
declare t text;
begin
  foreach t in array array['customer_glitch_logs','feedback_user_triggers','glitch_alerts','glitch_noise_rules'] loop
    execute format('drop policy if exists founder_read on public.%I', t);
    if to_regclass('public.founder_accounts') is not null then
      execute format($f$create policy founder_read on public.%I for select to authenticated
        using (exists (select 1 from public.founder_accounts f where f.user_id = auth.uid()))$f$, t);
    else
      execute format($f$create policy founder_read on public.%I for select to authenticated using (false)$f$, t);
    end if;
  end loop;
end $$;

-- 4) DEFAULT NOISE RULES (fazool alert ka ilaaj) -------------------------
insert into public.glitch_noise_rules (kind, message_like, action, reason)
select v.kind, v.pat, 'ignore', v.why
from (values
  (null, '%ResizeObserver loop%', 'browser shor'),
  (null, '%Script error.%', 'cross-origin shor, koi detail nahi'),
  (null, '%Failed to fetch dynamically imported module%', 'naya deploy hone par chunk reload — user refresh se theek'),
  (null, '%Loading chunk % failed%', 'deploy chunk reload'),
  (null, '%chrome-extension://%', 'user ki extension'),
  (null, '%moz-extension://%', 'user ki extension'),
  (null, '%The play() request was interrupted%', 'media autoplay shor'),
  (null, '%AbortError%', 'user ne navigate kar diya'),
  (null, '%NetworkError when attempting to fetch resource%', 'user ka internet'),
  ('console_error', '%[vite]%', 'dev tooling')
) as v(kind, pat, why)
where not exists (
  select 1 from public.glitch_noise_rules r where r.message_like = v.pat
);

-- 5) FUNCTIONS ------------------------------------------------------------
create or replace function public.glitch_is_noise(p_kind text, p_message text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.glitch_noise_rules r
    where r.active
      and r.action = 'ignore'
      and (r.kind is null or r.kind = p_kind)
      and coalesce(p_message,'') ilike r.message_like
  )
$$;

-- ek glitch record + (zaroorat ho to) alert queue. Return: kya hua, aur kyun.
create or replace function public.glitch_log(
  p_kind text,
  p_message text,
  p_severity text default 'error',
  p_route text default null,
  p_fingerprint text default null,
  p_stack text default null,
  p_session_id text default null,
  p_recording_url text default null,
  p_user_id uuid default null,
  p_meta jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_fp text := coalesce(nullif(p_fingerprint,''), p_kind || '|' || left(coalesce(p_message,'unknown'), 120));
  v_sev text := case when p_severity in ('info','warning','error','critical') then p_severity else 'error' end;
  v_recent int;
  v_alert uuid;
  v_id uuid;
begin
  if public.glitch_is_noise(p_kind, p_message) then
    return jsonb_build_object('stored', false, 'alert', false, 'reason', 'noise_rule');
  end if;

  insert into public.customer_glitch_logs
    (kind, severity, route, message, fingerprint, stack, user_id, session_id, recording_url, meta)
  values (p_kind, v_sev, p_route, left(coalesce(p_message,'unknown'), 2000), v_fp,
          left(coalesce(p_stack,''), 6000), p_user_id, p_session_id, p_recording_url,
          coalesce(p_meta, '{}'::jsonb))
  returning id into v_id;

  -- alert sirf error/critical par
  if v_sev not in ('error','critical') then
    return jsonb_build_object('stored', true, 'id', v_id, 'alert', false, 'reason', 'severity_below_alert');
  end if;

  -- rate cap: pichle 1 ghante mein 12 se zyada alert nahi
  select count(*) into v_recent
  from public.glitch_alerts
  where created_at > now() - interval '1 hour' and status in ('pending','sent');
  if v_recent >= 12 then
    insert into public.glitch_alerts (fingerprint, summary, severity, route, recording_url, status)
    values (v_fp, left(coalesce(p_message,'unknown'), 300), v_sev, p_route, p_recording_url, 'muted')
    on conflict do nothing;
    return jsonb_build_object('stored', true, 'id', v_id, 'alert', false, 'reason', 'hourly_cap');
  end if;

  -- same fingerprint = ek hi alert, sirf counter barhta hai
  insert into public.glitch_alerts (fingerprint, summary, severity, route, recording_url)
  values (v_fp, left(coalesce(p_message,'unknown'), 300), v_sev, p_route, p_recording_url)
  on conflict (fingerprint) where status = 'pending'
  do update set occurrences = public.glitch_alerts.occurrences + 1,
                last_seen = now(),
                sessions = public.glitch_alerts.sessions
                  + case when p_session_id is null then 0 else 1 end,
                severity = greatest_severity(public.glitch_alerts.severity, v_sev)
  returning id into v_alert;

  update public.customer_glitch_logs set alerted = true where id = v_id;
  return jsonb_build_object('stored', true, 'id', v_id, 'alert', true, 'alert_id', v_alert);
end $$;

create or replace function public.greatest_severity(a text, b text)
returns text language sql immutable as $$
  select case when 'critical' in (a,b) then 'critical'
              when 'error' in (a,b) then 'error'
              when 'warning' in (a,b) then 'warning'
              else 'info' end
$$;

-- rage click / dead click / manual feedback. Alert sirf jab 3+ alag session
-- 15 min mein ek hi target par phansein — warna sirf log.
create or replace function public.glitch_trigger_log(
  p_trigger_type text,
  p_route text default null,
  p_target_label text default null,
  p_hit_count int default 1,
  p_session_id text default null,
  p_recording_url text default null,
  p_user_id uuid default null,
  p_meta jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_sessions int;
  v_res jsonb;
begin
  insert into public.feedback_user_triggers
    (trigger_type, route, target_label, hit_count, user_id, session_id, recording_url, meta)
  values (p_trigger_type, p_route, left(coalesce(p_target_label,'unknown'), 200),
          greatest(coalesce(p_hit_count,1),1), p_user_id, p_session_id, p_recording_url,
          coalesce(p_meta,'{}'::jsonb));

  select count(distinct coalesce(session_id, id::text)) into v_sessions
  from public.feedback_user_triggers
  where trigger_type = p_trigger_type
    and coalesce(target_label,'') = coalesce(left(coalesce(p_target_label,'unknown'),200),'')
    and occurred_at > now() - interval '15 minutes';

  if v_sessions < 3 then
    return jsonb_build_object('stored', true, 'alert', false, 'reason', 'below_threshold',
                              'sessions', v_sessions);
  end if;

  v_res := public.glitch_log(
    p_kind => p_trigger_type,
    p_message => format('%s x%s on "%s" (%s sessions / 15 min)',
                        p_trigger_type, p_hit_count, coalesce(p_target_label,'unknown'), v_sessions),
    p_severity => 'error',
    p_route => p_route,
    p_fingerprint => p_trigger_type || '|' || coalesce(p_target_label,'unknown'),
    p_session_id => p_session_id,
    p_recording_url => p_recording_url,
    p_user_id => p_user_id,
    p_meta => coalesce(p_meta,'{}'::jsonb) || jsonb_build_object('sessions_15m', v_sessions)
  );
  return v_res || jsonb_build_object('sessions', v_sessions);
end $$;

-- WhatsApp sweep: 20 second batching window (2 min SLA ke andar aaram se)
create or replace function public.glitch_alert_due(p_limit int default 10)
returns setof public.glitch_alerts language sql security definer set search_path = public as $$
  select * from public.glitch_alerts
  where status = 'pending' and last_seen < now() - interval '20 seconds'
  order by severity desc, last_seen asc
  limit greatest(coalesce(p_limit,10), 1)
$$;

create or replace function public.glitch_alert_mark(
  p_id uuid, p_status text, p_ref text default null, p_error text default null
) returns void language sql security definer set search_path = public as $$
  update public.glitch_alerts
  set status = case when p_status in ('sent','failed','muted') then p_status else 'pending' end,
      sent_at = case when p_status = 'sent' then now() else sent_at end,
      channel_ref = coalesce(p_ref, channel_ref),
      last_error = p_error
  where id = p_id
$$;

create or replace function public.glitch_health()
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'logs_24h', (select count(*) from public.customer_glitch_logs where occurred_at > now() - interval '24 hours'),
    'triggers_24h', (select count(*) from public.feedback_user_triggers where occurred_at > now() - interval '24 hours'),
    'alerts_pending', (select count(*) from public.glitch_alerts where status = 'pending'),
    'alerts_sent_24h', (select count(*) from public.glitch_alerts where status = 'sent' and sent_at > now() - interval '24 hours'),
    'alerts_muted_24h', (select count(*) from public.glitch_alerts where status = 'muted' and created_at > now() - interval '24 hours'),
    'top_24h', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select fingerprint, count(*) as hits, max(occurred_at) as last_seen
        from public.customer_glitch_logs
        where occurred_at > now() - interval '24 hours'
        group by fingerprint order by hits desc limit 10) t)
  )
$$;

grant execute on function public.glitch_health() to authenticated;

commit;

-- VERIFY
-- select count(*) from information_schema.tables where table_schema='public'
--   and table_name in ('customer_glitch_logs','feedback_user_triggers','glitch_noise_rules','glitch_alerts');  -- 4
-- select public.glitch_log('js_error','TEST glitch from SQL','error','/plans');
-- select * from public.glitch_alerts order by created_at desc limit 3;
