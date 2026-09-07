-- ============================================================================
-- ANEXOCHAT · PHASE 19 + 20 + 21 + 22
--   19 — DEVICE SAFETY VAULT   (signals → normalize → hash → sealed vault)
--   20 — DEVICE TRUST          (lifecycle + one-click revoke, session kill)
--   21 — SAFETY REPORTING      (new → under_review → action → resolved)
--   22 — WORK EXECUTION CHAIN  (message → work object → owner → dependency →
--                               deadline → completion → evidence)
--
-- Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
-- Har naya public table par GRANT pehle, phir RLS, phir policy.
--
-- LOCK (non-negotiable):
--   1. Phase 19 biometric fingerprinting NAHI hai. Sirf minimized coarse
--      signals (platform class, browser class, tz bucket, screen bucket,
--      language). Raw signal kabhi plain column mein nahi — sealed envelope
--      (pgp_sym_encrypt, key sirf engine ke paas). Retention `retain_until`.
--   2. Reviewer ko private message body kabhi apne aap nahi dikhta: report ka
--      evidence sealed hai; kholne par `safety_reveal_log` mein justification
--      ke saath row banti hai (audit ke bina reveal namumkin).
--   3. Report state kood nahi sakti: new → under_review → action → resolved.
--   4. Work object apni source conversation se kabhi nahi tootta: provenance
--      snapshot (conversation, sender, sent_at, body_hash) create ke waqt hi
--      likh diya jata hai — message user ke view se hatne par bhi chain zinda.
--   5. Completion bina evidence mumkin nahi (`chat_work_complete`).
--   6. Task parsing DETERMINISTIC hai (owner = participant naam/mention,
--      deadline = literal phrases). Insaani guftagu kisi AI API par nahi jati.
--   7. No duplicate: Phase 3 ka chat_work_items wahi table hai — yeh layer
--      uske OOPAR chain/evidence hai; Phase 26 security_devices ko replace
--      nahi kiya, vault uske saath hash-linked chalta hai.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements (Phase 19–22) — card features ka DB sach
-- ---------------------------------------------------------------------------
create table if not exists public.chat_phase_entitlements (
  plan     text not null,
  feature  text not null,
  allowed  boolean not null default false,
  limit_value int,
  note     text,
  primary key (plan, feature)
);

insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'device_vault',      true,  2,  'device safety vault, 2 devices'),
  ('pro',          'device_vault',      true,  4,  'device safety vault, 4 devices'),
  ('business',     'device_vault',      true,  10, null),
  ('business_pro', 'device_vault',      true,  50, null),
  ('ai_pro',       'device_vault',      true,  10, null),
  ('ai_business',  'device_vault',      true,  50, null),
  ('ai_executive', 'device_vault',      true,  100, null),
  ('founder',      'device_vault',      true,  500, null),

  ('basic',        'device_trust',      true,  null, 'see + revoke own devices'),
  ('pro',          'device_trust',      true,  null, null),
  ('business',     'device_trust',      true,  null, null),
  ('business_pro', 'device_trust',      true,  null, null),
  ('ai_pro',       'device_trust',      true,  null, null),
  ('ai_business',  'device_trust',      true,  null, null),
  ('ai_executive', 'device_trust',      true,  null, null),
  ('founder',      'device_trust',      true,  null, null),

  ('basic',        'safety_report',     true,  null, 'report abuse (mail surface)'),
  ('pro',          'safety_report',     true,  null, null),
  ('business',     'safety_report',     true,  null, null),
  ('business_pro', 'safety_report',     true,  null, null),
  ('ai_pro',       'safety_report',     true,  null, null),
  ('ai_business',  'safety_report',     true,  null, null),
  ('ai_executive', 'safety_report',     true,  null, null),
  ('founder',      'safety_report',     true,  null, null),

  ('basic',        'safety_review',     false, null, null),
  ('pro',          'safety_review',     false, null, null),
  ('business',     'safety_review',     false, null, 'reports visible, enforcement founder-side'),
  ('business_pro', 'safety_review',     true,  null, 'full review queue + enforcement history'),
  ('ai_pro',       'safety_review',     false, null, null),
  ('ai_business',  'safety_review',     false, null, null),
  ('ai_executive', 'safety_review',     true,  null, null),
  ('founder',      'safety_review',     true,  null, null),

  ('basic',        'work_chain',        false, null, null),
  ('pro',          'work_chain',        false, null, null),
  ('business',     'work_chain',        true,  200, 'open work objects per workspace'),
  ('business_pro', 'work_chain',        true,  5000, null),
  ('ai_pro',       'work_chain',        true,  200, null),
  ('ai_business',  'work_chain',        true,  5000, null),
  ('ai_executive', 'work_chain',        true,  20000, null),
  ('founder',      'work_chain',        true,  100000, null),

  ('basic',        'work_dependency',   false, null, null),
  ('pro',          'work_dependency',   false, null, null),
  ('business',     'work_dependency',   true,  null, null),
  ('business_pro', 'work_dependency',   true,  null, null),
  ('ai_pro',       'work_dependency',   false, null, null),
  ('ai_business',  'work_dependency',   true,  null, null),
  ('ai_executive', 'work_dependency',   true,  null, null),
  ('founder',      'work_dependency',   true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

grant select on public.chat_phase_entitlements to authenticated, anon;
grant all on public.chat_phase_entitlements to service_role;
alter table public.chat_phase_entitlements enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'chat_phase_entitlements' and policyname = 'entitlements readable') then
    create policy "entitlements readable" on public.chat_phase_entitlements
      for select to authenticated, anon using (true);
  end if;
end $$;

create or replace function public.chat_feature_allowed(_user uuid, _feature text)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_plan text; v_row public.chat_phase_entitlements;
begin
  v_plan := (public.file_plan_for(_user)).plan;
  select * into v_row from public.chat_phase_entitlements
   where plan = v_plan and feature = _feature;
  if not found then
    return jsonb_build_object('plan', v_plan, 'feature', _feature, 'allowed', false, 'limit', null);
  end if;
  return jsonb_build_object(
    'plan', v_plan, 'feature', _feature,
    'allowed', v_row.allowed, 'limit', v_row.limit_value, 'note', v_row.note);
end $$;

-- ===========================================================================
-- PHASE 19 — DEVICE SAFETY VAULT
-- ===========================================================================
create table if not exists public.device_vault (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  device_hash    text not null,                 -- sha256(canonical || pepper)
  label          text not null default 'Unknown device',
  platform_class text,                          -- Windows | macOS | iPhone | Android | Linux | Unknown
  browser_class  text,                          -- Chrome | Safari | Firefox | Edge | Other
  signal_count   int  not null default 0,       -- kitne signals collect hue (minimization proof)
  sealed_signals text,                          -- pgp_sym_encrypt(minimized json)
  state          text not null default 'pending'
                 check (state in ('trusted','pending','suspicious','revoked','banned')),
  reasons        jsonb not null default '[]'::jsonb,
  registrations  int  not null default 1,
  first_seen_at  timestamptz not null default now(),
  last_seen_at   timestamptz not null default now(),
  retain_until   timestamptz not null default now() + interval '180 days',
  legal_basis    text not null default 'legitimate_interest_abuse_prevention',
  unique (user_id, device_hash)
);
create index if not exists device_vault_user_idx on public.device_vault(user_id, last_seen_at desc);
create index if not exists device_vault_hash_idx on public.device_vault(device_hash);

create table if not exists public.device_bans (
  device_hash text primary key,
  reason      text not null,
  banned_by   uuid references auth.users(id) on delete set null,
  banned_at   timestamptz not null default now(),
  expires_at  timestamptz
);

create table if not exists public.device_vault_policy (
  id           int primary key default 1 check (id = 1),
  retain_days  int  not null default 180,
  signals_collected text[] not null default
    array['platform_class','browser_class','timezone_bucket','screen_bucket','language'],
  legal_basis  text not null default 'legitimate_interest_abuse_prevention',
  purpose      text not null default 'abuse prevention · banned-device detection · suspicious registration detection',
  purged_at    timestamptz
);
insert into public.device_vault_policy (id) values (1) on conflict (id) do nothing;

create table if not exists public.device_trust_events (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  device_hash text not null,
  event       text not null check (event in
                ('registered','seen','trusted','suspicious','revoked','banned','purged')),
  actor       text not null default 'engine',
  detail      jsonb not null default '{}'::jsonb,
  at          timestamptz not null default now()
);
create index if not exists device_trust_events_idx on public.device_trust_events(user_id, id desc);

grant select on public.device_vault, public.device_vault_policy, public.device_trust_events to authenticated;
grant all on public.device_vault, public.device_bans, public.device_vault_policy,
  public.device_trust_events to service_role;
grant usage, select on sequence public.device_trust_events_id_seq to service_role;

alter table public.device_vault         enable row level security;
alter table public.device_bans          enable row level security;
alter table public.device_vault_policy  enable row level security;
alter table public.device_trust_events  enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename='device_vault' and policyname='own vault read') then
    create policy "own vault read" on public.device_vault
      for select to authenticated using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='device_trust_events' and policyname='own trust events') then
    create policy "own trust events" on public.device_trust_events
      for select to authenticated using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='device_vault_policy' and policyname='policy readable') then
    create policy "policy readable" on public.device_vault_policy
      for select to authenticated using (true);
  end if;
end $$;

-- coarse normalization: kabhi raw UA store nahi, sirf class
create or replace function public.device_signal_class(_ua text, _kind text)
returns text language sql immutable set search_path = public as $$
  select case when _kind = 'platform' then
      case when _ua ilike '%iphone%' then 'iPhone'
           when _ua ilike '%ipad%' then 'iPad'
           when _ua ilike '%android%' then 'Android'
           when _ua ilike '%windows%' then 'Windows'
           when _ua ilike '%mac os%' or _ua ilike '%macintosh%' then 'macOS'
           when _ua ilike '%linux%' then 'Linux'
           else 'Unknown' end
    else
      case when _ua ilike '%edg/%' then 'Edge'
           when _ua ilike '%chrome%' and _ua not ilike '%edg/%' then 'Chrome'
           when _ua ilike '%safari%' and _ua not ilike '%chrome%' then 'Safari'
           when _ua ilike '%firefox%' then 'Firefox'
           else 'Other' end
    end
$$;

-- Register: signals → normalized identifier → cryptographic hash → sealed vault
create or replace function public.device_vault_register(
  _user uuid, _signals jsonb, _key text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_ua        text := coalesce(_signals->>'ua', '');
  v_platform  text := coalesce(nullif(_signals->>'platform_class',''), public.device_signal_class(v_ua,'platform'));
  v_browser   text := coalesce(nullif(_signals->>'browser_class',''), public.device_signal_class(v_ua,'browser'));
  v_tz        int  := coalesce((_signals->>'tz_offset_minutes')::int, 0) / 60;   -- hour bucket
  v_screen    text := coalesce(_signals->>'screen_bucket', 'unknown');
  v_lang      text := lower(left(coalesce(_signals->>'language','xx'), 2));
  v_minimized jsonb;
  v_canon     text;
  v_hash      text;
  v_row       public.device_vault;
  v_reasons   jsonb := '[]'::jsonb;
  v_state     text := 'pending';
  v_users     int;
  v_recent    int;
  v_retain    int;
  v_limit     jsonb;
  v_count     int;
begin
  if _user is null then raise exception 'user_required'; end if;

  -- MINIMIZATION: sirf yeh 5 coarse signals, koi canvas/audio/font fingerprint nahi
  v_minimized := jsonb_build_object(
    'platform_class', v_platform, 'browser_class', v_browser,
    'timezone_bucket', v_tz, 'screen_bucket', v_screen, 'language', v_lang);

  v_canon := concat_ws('|', v_platform, v_browser, v_tz::text, v_screen, v_lang);
  v_hash  := encode(digest(v_canon || '|' || coalesce(_key, 'no-pepper'), 'sha256'), 'hex');

  select retain_days into v_retain from public.device_vault_policy where id = 1;

  -- banned device?
  if exists (select 1 from public.device_bans b
              where b.device_hash = v_hash and (b.expires_at is null or b.expires_at > now())) then
    v_state := 'banned';
    v_reasons := v_reasons || jsonb_build_array('device is on the banned list');
  end if;

  -- same hash multiple accounts = suspicious registration
  select count(distinct user_id) into v_users from public.device_vault where device_hash = v_hash;
  if v_users >= 3 and v_state <> 'banned' then
    v_state := 'suspicious';
    v_reasons := v_reasons || jsonb_build_array('this device shape registered on ' || v_users || ' accounts');
  end if;

  -- burst registrations from one device in 24h
  select count(*) into v_recent from public.device_trust_events
   where device_hash = v_hash and event = 'registered' and at > now() - interval '24 hours';
  if v_recent >= 3 and v_state = 'pending' then
    v_state := 'suspicious';
    v_reasons := v_reasons || jsonb_build_array(v_recent || ' registrations from this device in 24h');
  end if;

  -- plan cap on vault size (naya device add karne se pehle)
  v_limit := public.chat_feature_allowed(_user, 'device_vault');
  select count(*) into v_count from public.device_vault where user_id = _user;
  if not exists (select 1 from public.device_vault where user_id = _user and device_hash = v_hash)
     and (v_limit->>'limit') is not null and v_count >= (v_limit->>'limit')::int then
    return jsonb_build_object('ok', false, 'error', 'device_limit_reached',
      'plan', v_limit->>'plan', 'limit', (v_limit->>'limit')::int);
  end if;

  insert into public.device_vault as d (
    user_id, device_hash, label, platform_class, browser_class, signal_count,
    sealed_signals, state, reasons, retain_until)
  values (
    _user, v_hash, v_browser || ' · ' || v_platform, v_platform, v_browser,
    5, pgp_sym_encrypt(v_minimized::text, coalesce(_key, 'no-pepper')),
    v_state, v_reasons, now() + make_interval(days => coalesce(v_retain, 180)))
  on conflict (user_id, device_hash) do update
    set last_seen_at = now(),
        registrations = d.registrations + 1,
        label = excluded.label,
        state = case when d.state = 'revoked' then 'revoked'
                     when excluded.state in ('banned','suspicious') then excluded.state
                     else d.state end,
        reasons = excluded.reasons,
        retain_until = now() + make_interval(days => coalesce(v_retain, 180))
  returning * into v_row;

  insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
  values (_user, v_hash,
          case when v_row.registrations = 1 then 'registered' else 'seen' end,
          'engine', jsonb_build_object('state', v_row.state, 'reasons', v_row.reasons));

  return jsonb_build_object(
    'ok', v_row.state not in ('banned','revoked'),
    'device_hash', v_hash,
    'label', v_row.label,
    'state', v_row.state,
    'reasons', v_row.reasons,
    'signals_collected', 5,
    'retain_until', v_row.retain_until,
    'legal_basis', v_row.legal_basis);
end $$;

-- ===========================================================================
-- PHASE 20 — DEVICE TRUST (list · trust · revoke, ek click)
-- ===========================================================================
create or replace function public.device_trust_list(_user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_devices jsonb; v_policy public.device_vault_policy;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
      'device_hash', d.device_hash,
      'label', d.label,
      'platform_class', d.platform_class,
      'browser_class', d.browser_class,
      'state', d.state,
      'reasons', d.reasons,
      'registrations', d.registrations,
      'first_seen_at', d.first_seen_at,
      'last_seen_at', d.last_seen_at,
      'retain_until', d.retain_until
    ) order by d.last_seen_at desc), '[]'::jsonb)
    into v_devices
    from public.device_vault d where d.user_id = _user;

  select * into v_policy from public.device_vault_policy where id = 1;

  return jsonb_build_object(
    'devices', v_devices,
    'policy', jsonb_build_object(
      'retain_days', v_policy.retain_days,
      'signals_collected', v_policy.signals_collected,
      'legal_basis', v_policy.legal_basis,
      'purpose', v_policy.purpose,
      'biometric', false,
      'purged_at', v_policy.purged_at));
end $$;

create or replace function public.device_trust_set(
  _user uuid, _device_hash text, _state text, _actor text default 'user')
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_row public.device_vault; v_killed int := 0;
begin
  if _state not in ('trusted','suspicious','revoked') then raise exception 'bad_state'; end if;

  update public.device_vault set state = _state, last_seen_at = last_seen_at
   where user_id = _user and device_hash = _device_hash
   returning * into v_row;
  if not found then raise exception 'device_not_found'; end if;

  -- Revoke = access marta hai: har live session bhi mar jati hai
  if _state = 'revoked' then
    if to_regclass('public.security_sessions') is not null then
      execute 'delete from public.security_sessions where user_id = $1 and device_label = $2'
        using _user, v_row.label;
      get diagnostics v_killed = row_count;
    end if;
    if to_regclass('public.security_devices') is not null then
      execute 'update public.security_devices set state = ''blocked'' where user_id = $1 and label = $2'
        using _user, v_row.label;
    end if;
  end if;

  insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
  values (_user, _device_hash,
          case _state when 'trusted' then 'trusted'
                      when 'revoked' then 'revoked' else 'suspicious' end,
          _actor, jsonb_build_object('sessions_killed', v_killed));

  return jsonb_build_object('ok', true, 'device_hash', _device_hash,
                            'state', _state, 'sessions_killed', v_killed);
end $$;

-- Retention purge (cron/worker se) — vault kabhi hamesha ke liye nahi rehta
create or replace function public.device_vault_purge()
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_gone int;
begin
  delete from public.device_vault where retain_until < now() and state <> 'banned';
  get diagnostics v_gone = row_count;
  delete from public.device_trust_events where at < now() - interval '400 days';
  update public.device_vault_policy set purged_at = now() where id = 1;
  return jsonb_build_object('purged', v_gone, 'at', now());
end $$;

-- ===========================================================================
-- PHASE 21 — SAFETY REPORTING (report → review → action → resolved)
-- ===========================================================================
create table if not exists public.safety_reports (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid,
  reporter_id     uuid not null references auth.users(id) on delete cascade,
  subject_kind    text not null check (subject_kind in ('message','person','file','conversation')),
  subject_id      text not null,
  conversation_id uuid,
  subject_user_id uuid references auth.users(id) on delete set null,
  reason          text not null check (reason in
                    ('spam','harassment','threat','illegal_content','malware','impersonation','other')),
  note            text,
  severity        int not null default 2 check (severity between 1 and 4),
  state           text not null default 'new' check (state in ('new','under_review','action','resolved')),
  assigned_to     uuid references auth.users(id) on delete set null,
  sealed_evidence text,                -- pgp_sym_encrypt — reviewer ko default nahi
  evidence_hash   text,                -- sha256 of evidence (tamper proof, no content)
  outcome         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  resolved_at     timestamptz
);
create index if not exists safety_reports_state_idx on public.safety_reports(state, created_at desc);
create index if not exists safety_reports_reporter_idx on public.safety_reports(reporter_id, created_at desc);

create table if not exists public.safety_report_events (
  id         bigserial primary key,
  report_id  uuid not null references public.safety_reports(id) on delete cascade,
  actor_id   uuid references auth.users(id) on delete set null,
  from_state text,
  to_state   text not null,
  action     text,
  note       text,
  at         timestamptz not null default now()
);
create index if not exists safety_report_events_idx on public.safety_report_events(report_id, id);

create table if not exists public.safety_enforcement (
  id           uuid primary key default gen_random_uuid(),
  report_id    uuid references public.safety_reports(id) on delete set null,
  subject_user uuid references auth.users(id) on delete cascade,
  device_hash  text,
  action       text not null check (action in ('none','warned','muted','suspended','banned','device_banned')),
  reason       text not null,
  until        timestamptz,
  actor_id     uuid references auth.users(id) on delete set null,
  at           timestamptz not null default now()
);
create index if not exists safety_enforcement_user_idx on public.safety_enforcement(subject_user, at desc);

create table if not exists public.safety_reveal_log (
  id            bigserial primary key,
  report_id     uuid not null references public.safety_reports(id) on delete cascade,
  actor_id      uuid references auth.users(id) on delete set null,
  justification text not null,
  at            timestamptz not null default now()
);

grant select on public.safety_reports, public.safety_report_events,
  public.safety_enforcement, public.safety_reveal_log to authenticated;
grant all on public.safety_reports, public.safety_report_events,
  public.safety_enforcement, public.safety_reveal_log to service_role;
grant usage, select on sequence public.safety_report_events_id_seq to service_role;
grant usage, select on sequence public.safety_reveal_log_id_seq to service_role;

alter table public.safety_reports      enable row level security;
alter table public.safety_report_events enable row level security;
alter table public.safety_enforcement  enable row level security;
alter table public.safety_reveal_log   enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename='safety_reports' and policyname='own reports read') then
    create policy "own reports read" on public.safety_reports
      for select to authenticated using (reporter_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='safety_enforcement' and policyname='own enforcement read') then
    create policy "own enforcement read" on public.safety_enforcement
      for select to authenticated using (subject_user = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='safety_report_events' and policyname='own report events') then
    create policy "own report events" on public.safety_report_events
      for select to authenticated using (exists (
        select 1 from public.safety_reports r where r.id = report_id and r.reporter_id = auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where tablename='safety_reveal_log' and policyname='reveal log service only') then
    create policy "reveal log service only" on public.safety_reveal_log
      for select to authenticated using (false);
  end if;
end $$;

-- reviewer authority: founder ya plan ka safety_review
create or replace function public.safety_can_review(_user uuid)
returns boolean language plpgsql stable security definer
set search_path = public, extensions as $$
declare v boolean := false;
begin
  if to_regclass('public.founder_accounts') is not null then
    execute 'select exists(select 1 from public.founder_accounts where user_id = $1)'
      into v using _user;
    if v then return true; end if;
  end if;
  return coalesce((public.chat_feature_allowed(_user, 'safety_review')->>'allowed')::boolean, false);
end $$;

create or replace function public.safety_report_create(
  _user uuid, _kind text, _subject text, _reason text,
  _note text default null, _key text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_conv uuid; v_subject_user uuid; v_body text; v_ws uuid; v_id uuid;
  v_sev int := 2;
begin
  if _user is null then raise exception 'user_required'; end if;
  if not coalesce((public.chat_feature_allowed(_user,'safety_report')->>'allowed')::boolean,false) then
    return jsonb_build_object('ok', false, 'error', 'not_entitled');
  end if;

  if _kind = 'message' then
    select m.conversation_id, m.sender_user_id, m.body, c.workspace_id
      into v_conv, v_subject_user, v_body, v_ws
      from public.chat_messages m
      join public.chat_conversations c on c.id = m.conversation_id
     where m.id = _subject::uuid;
    if v_conv is null then raise exception 'message_not_found'; end if;
    if not public.chat_in_conversation(v_conv, _user) then raise exception 'not_participant'; end if;
  elsif _kind = 'conversation' then
    v_conv := _subject::uuid;
    if not public.chat_in_conversation(v_conv, _user) then raise exception 'not_participant'; end if;
    select workspace_id into v_ws from public.chat_conversations where id = v_conv;
  elsif _kind = 'person' then
    v_subject_user := _subject::uuid;
  end if;

  if _reason in ('threat','illegal_content','malware') then v_sev := 4;
  elsif _reason in ('harassment','impersonation') then v_sev := 3; end if;

  insert into public.safety_reports (
    workspace_id, reporter_id, subject_kind, subject_id, conversation_id,
    subject_user_id, reason, note, severity,
    sealed_evidence, evidence_hash)
  values (
    v_ws, _user, _kind, _subject, v_conv, v_subject_user, _reason, left(coalesce(_note,''), 1000), v_sev,
    case when v_body is null then null
         else pgp_sym_encrypt(v_body, coalesce(_key, 'no-pepper')) end,
    case when v_body is null then null
         else encode(digest(v_body, 'sha256'), 'hex') end)
  returning id into v_id;

  insert into public.safety_report_events (report_id, actor_id, from_state, to_state, action, note)
  values (v_id, _user, null, 'new', 'reported', _reason);

  return jsonb_build_object('ok', true, 'report_id', v_id, 'state', 'new', 'severity', v_sev,
    'evidence_sealed', v_body is not null,
    'notice', 'Reviewers see metadata only. Opening the sealed evidence is logged.');
end $$;

-- Queue: metadata only. Body kabhi nahi — sirf sealed hai ya nahi.
create or replace function public.safety_queue(_actor uuid, _state text default null)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_rows jsonb;
begin
  if not public.safety_can_review(_actor) then
    return jsonb_build_object('ok', false, 'error', 'not_a_reviewer');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id, 'subject_kind', r.subject_kind, 'reason', r.reason,
      'severity', r.severity, 'state', r.state,
      'conversation_id', r.conversation_id,
      'reporter', left(r.reporter_id::text, 8),
      'subject', left(coalesce(r.subject_user_id::text, r.subject_id), 8),
      'note', r.note,
      'evidence_sealed', r.sealed_evidence is not null,
      'evidence_hash', r.evidence_hash,
      'assigned_to', r.assigned_to,
      'created_at', r.created_at, 'updated_at', r.updated_at,
      'outcome', r.outcome
    ) order by r.severity desc, r.created_at), '[]'::jsonb)
    into v_rows
    from public.safety_reports r
   where (_state is null or r.state = _state);
  return jsonb_build_object('ok', true, 'reports', v_rows,
    'counts', (select jsonb_object_agg(state, c) from
                (select state, count(*) c from public.safety_reports group by state) s));
end $$;

-- State kood nahi sakti: new → under_review → action → resolved
create or replace function public.safety_report_advance(
  _actor uuid, _report uuid, _to text,
  _note text default null, _action text default null,
  _until timestamptz default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_row public.safety_reports; v_order text[] := array['new','under_review','action','resolved'];
        v_from int; v_next int;
begin
  if not public.safety_can_review(_actor) then raise exception 'not_a_reviewer'; end if;
  select * into v_row from public.safety_reports where id = _report;
  if not found then raise exception 'report_not_found'; end if;

  v_from := array_position(v_order, v_row.state);
  v_next := array_position(v_order, _to);
  if v_next is null then raise exception 'bad_state'; end if;
  if v_next <> v_from + 1 then
    raise exception 'step_skip_not_allowed: % -> %', v_row.state, _to;
  end if;

  update public.safety_reports
     set state = _to,
         assigned_to = coalesce(assigned_to, _actor),
         outcome = coalesce(_action, outcome),
         updated_at = now(),
         resolved_at = case when _to = 'resolved' then now() else resolved_at end
   where id = _report;

  insert into public.safety_report_events (report_id, actor_id, from_state, to_state, action, note)
  values (_report, _actor, v_row.state, _to, _action, _note);

  if _to = 'action' then
    insert into public.safety_enforcement (report_id, subject_user, action, reason, until, actor_id)
    values (_report, v_row.subject_user_id, coalesce(_action, 'warned'),
            coalesce(_note, v_row.reason), _until, _actor);

    if coalesce(_action,'') = 'device_banned' then
      insert into public.device_bans (device_hash, reason, banned_by)
      select d.device_hash, 'safety enforcement ' || _report::text, _actor
        from public.device_vault d
       where d.user_id = v_row.subject_user_id
      on conflict (device_hash) do nothing;
      update public.device_vault set state = 'banned' where user_id = v_row.subject_user_id;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'report_id', _report, 'state', _to);
end $$;

-- Reveal: private content sirf justification + audit row ke saath khulta hai
create or replace function public.safety_report_reveal(
  _actor uuid, _report uuid, _justification text, _key text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_row public.safety_reports; v_text text;
begin
  if not public.safety_can_review(_actor) then raise exception 'not_a_reviewer'; end if;
  if coalesce(length(trim(_justification)), 0) < 12 then
    raise exception 'justification_required';
  end if;
  select * into v_row from public.safety_reports where id = _report;
  if not found then raise exception 'report_not_found'; end if;
  if v_row.state = 'new' then raise exception 'open_review_first'; end if;
  if v_row.sealed_evidence is null then
    return jsonb_build_object('ok', true, 'evidence', null, 'note', 'nothing sealed for this report');
  end if;

  v_text := pgp_sym_decrypt(v_row.sealed_evidence::bytea, coalesce(_key, 'no-pepper'));

  insert into public.safety_reveal_log (report_id, actor_id, justification)
  values (_report, _actor, _justification);

  return jsonb_build_object('ok', true, 'evidence', v_text,
    'evidence_hash', v_row.evidence_hash, 'logged', true);
end $$;

create or replace function public.safety_my_standing(_user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
begin
  return jsonb_build_object(
    'reports_filed', (select count(*) from public.safety_reports where reporter_id = _user),
    'open_reports', (select count(*) from public.safety_reports
                      where reporter_id = _user and state <> 'resolved'),
    'enforcement', coalesce((select jsonb_agg(jsonb_build_object(
        'action', action, 'reason', reason, 'until', until, 'at', at) order by at desc)
      from public.safety_enforcement where subject_user = _user), '[]'::jsonb),
    'can_review', public.safety_can_review(_user));
end $$;

-- ===========================================================================
-- PHASE 22 — WORK EXECUTION CHAIN
-- ===========================================================================
alter table public.chat_work_items
  add column if not exists depends_on   uuid references public.chat_work_items(id) on delete set null,
  add column if not exists source_seq   bigint,
  add column if not exists provenance   jsonb not null default '{}'::jsonb,
  add column if not exists completed_by uuid references auth.users(id) on delete set null,
  add column if not exists completed_at timestamptz,
  add column if not exists retention_class text not null default 'business_record',
  add column if not exists parsed       jsonb not null default '{}'::jsonb;

do $$
begin
  if exists (select 1 from pg_constraint where conname = 'chat_work_items_state_check') then
    alter table public.chat_work_items drop constraint chat_work_items_state_check;
  end if;
  alter table public.chat_work_items
    add constraint chat_work_items_state_check
    check (state in ('open','blocked','done','cancelled'));
exception when duplicate_object then null;
end $$;

create table if not exists public.chat_work_evidence (
  id        bigserial primary key,
  item_id   uuid not null references public.chat_work_items(id) on delete cascade,
  kind      text not null check (kind in ('message','file','link','note')),
  ref       text not null,
  sha256    text,
  added_by  uuid references auth.users(id) on delete set null,
  at        timestamptz not null default now()
);
create index if not exists chat_work_evidence_idx on public.chat_work_evidence(item_id, id);

create table if not exists public.chat_work_events (
  id        bigserial primary key,
  item_id   uuid not null references public.chat_work_items(id) on delete cascade,
  actor_id  uuid references auth.users(id) on delete set null,
  from_state text,
  to_state  text,
  action    text not null,
  detail    jsonb not null default '{}'::jsonb,
  at        timestamptz not null default now()
);
create index if not exists chat_work_events_idx on public.chat_work_events(item_id, id);

grant select on public.chat_work_evidence, public.chat_work_events to authenticated;
grant all on public.chat_work_evidence, public.chat_work_events to service_role;
grant usage, select on sequence public.chat_work_evidence_id_seq to service_role;
grant usage, select on sequence public.chat_work_events_id_seq to service_role;

alter table public.chat_work_evidence enable row level security;
alter table public.chat_work_events   enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename='chat_work_evidence' and policyname='work evidence read') then
    create policy "work evidence read" on public.chat_work_evidence
      for select to authenticated using (exists (
        select 1 from public.chat_work_items w
         where w.id = item_id and public.chat_in_conversation(w.conversation_id, auth.uid())));
  end if;
  if not exists (select 1 from pg_policies where tablename='chat_work_events' and policyname='work events read') then
    create policy "work events read" on public.chat_work_events
      for select to authenticated using (exists (
        select 1 from public.chat_work_items w
         where w.id = item_id and public.chat_in_conversation(w.conversation_id, auth.uid())));
  end if;
end $$;

-- Deterministic deadline parse — koi AI nahi, sirf literal phrases
create or replace function public.chat_work_parse_due(_body text, _now timestamptz default now())
returns jsonb language plpgsql immutable set search_path = public as $$
declare b text := lower(coalesce(_body,'')); n int; dow int; target date;
begin
  if b ~ 'tomorrow|kal' then
    return jsonb_build_object('due', (date_trunc('day', _now) + interval '1 day 17 hours'), 'phrase', 'tomorrow');
  end if;
  if b ~ 'today|aaj|tonight' then
    return jsonb_build_object('due', (date_trunc('day', _now) + interval '18 hours'), 'phrase', 'today');
  end if;
  if b ~ 'next week' then
    return jsonb_build_object('due', (date_trunc('week', _now) + interval '1 week 4 days 17 hours'), 'phrase', 'next week');
  end if;
  n := nullif(substring(b from 'in ([0-9]{1,2}) day'), '')::int;
  if n is not null then
    return jsonb_build_object('due', _now + make_interval(days => n), 'phrase', 'in ' || n || ' days');
  end if;
  n := nullif(substring(b from 'in ([0-9]{1,2}) hour'), '')::int;
  if n is not null then
    return jsonb_build_object('due', _now + make_interval(hours => n), 'phrase', 'in ' || n || ' hours');
  end if;
  dow := case
    when b ~ 'monday'    then 1 when b ~ 'tuesday'  then 2
    when b ~ 'wednesday' then 3 when b ~ 'thursday' then 4
    when b ~ 'friday'    then 5 when b ~ 'saturday' then 6
    when b ~ 'sunday'    then 7 else null end;
  if dow is not null then
    target := (_now)::date + ((dow - extract(isodow from _now)::int + 7) % 7);
    if target = _now::date then target := target + 1; end if;
    return jsonb_build_object('due', target::timestamptz + interval '17 hours', 'phrase', 'weekday');
  end if;
  return jsonb_build_object('due', null, 'phrase', null);
end $$;

-- Preview (kuch likhta nahi): "Create Task" dialog ka prefill
create or replace function public.chat_work_suggest(_msg uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  v_conv uuid; v_body text; v_sender uuid; v_due jsonb; v_owner uuid; v_owner_name text;
  v_title text; r record;
begin
  select m.conversation_id, m.body, m.sender_user_id into v_conv, v_body, v_sender
    from public.chat_messages m where m.id = _msg;
  if v_conv is null then raise exception 'message_not_found'; end if;
  if not public.chat_in_conversation(v_conv, _user) then raise exception 'not_participant'; end if;

  v_due := public.chat_work_parse_due(v_body);

  -- owner = conversation participant jiska naam message mein literal aaya
  for r in
    select cm.user_id, coalesce(mem.display_name, '') as name
      from public.chat_participants cm
      left join public.chat_members mem on mem.user_id = cm.user_id
     where cm.conversation_id = v_conv
  loop
    if coalesce(r.name,'') <> '' and lower(v_body) like '%' || lower(split_part(r.name,' ',1)) || '%' then
      v_owner := r.user_id; v_owner_name := r.name; exit;
    end if;
  end loop;

  v_title := trim(regexp_replace(left(coalesce(v_body,''), 120), '^[^a-zA-Z0-9]*', ''));
  if position(',' in v_title) > 0 and v_owner is not null then
    v_title := trim(substring(v_title from position(',' in v_title) + 1));
  end if;
  v_title := left(initcap(left(v_title,1)) || substring(v_title from 2), 120);

  return jsonb_build_object(
    'message_id', _msg, 'conversation_id', v_conv,
    'kind', case when lower(coalesce(v_body,'')) ~ 'i will|main karunga|promise' then 'promise'
                 when lower(coalesce(v_body,'')) ~ 'decided|decision|final' then 'decision'
                 else 'task' end,
    'title', v_title,
    'owner_user_id', coalesce(v_owner, v_sender),
    'owner_name', v_owner_name,
    'due_at', v_due->'due',
    'due_phrase', v_due->>'phrase',
    'source', 'ANEXOChat',
    'deterministic', true);
end $$;

-- Message → work object (provenance snapshot lazmi)
create or replace function public.chat_work_from_message(
  _msg uuid, _user uuid, _kind text default null, _title text default null,
  _owner uuid default null, _due timestamptz default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_s jsonb; v_conv uuid; v_ws uuid; v_id uuid; v_body text; v_seq bigint;
  v_sender uuid; v_sent timestamptz; v_gate jsonb; v_open int;
begin
  v_gate := public.chat_feature_allowed(_user, 'work_chain');
  if not coalesce((v_gate->>'allowed')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'not_entitled', 'plan', v_gate->>'plan');
  end if;

  v_s := public.chat_work_suggest(_msg, _user);
  v_conv := (v_s->>'conversation_id')::uuid;

  select m.body, m.seq, m.sender_user_id, m.created_at, c.workspace_id
    into v_body, v_seq, v_sender, v_sent, v_ws
    from public.chat_messages m join public.chat_conversations c on c.id = m.conversation_id
   where m.id = _msg;

  select count(*) into v_open from public.chat_work_items
   where workspace_id = v_ws and state in ('open','blocked');
  if (v_gate->>'limit') is not null and v_open >= (v_gate->>'limit')::int then
    return jsonb_build_object('ok', false, 'error', 'work_limit_reached', 'limit', (v_gate->>'limit')::int);
  end if;

  insert into public.chat_work_items (
    workspace_id, conversation_id, message_id, kind, title, owner_user_id,
    due_at, created_by, source_seq, parsed, provenance)
  values (
    v_ws, v_conv, _msg,
    coalesce(_kind, v_s->>'kind'),
    coalesce(nullif(trim(coalesce(_title,'')),''), v_s->>'title'),
    coalesce(_owner, (v_s->>'owner_user_id')::uuid),
    coalesce(_due, nullif(v_s->>'due_at','')::timestamptz),
    _user, v_seq, v_s,
    jsonb_build_object(
      'conversation_id', v_conv, 'message_id', _msg, 'message_seq', v_seq,
      'sender_id', v_sender, 'sent_at', v_sent,
      'body_hash', encode(digest(coalesce(v_body,''), 'sha256'), 'hex'),
      'source', 'ANEXOChat', 'captured_at', now()))
  returning id into v_id;

  insert into public.chat_work_evidence (item_id, kind, ref, sha256, added_by)
  values (v_id, 'message', _msg::text, encode(digest(coalesce(v_body,''),'sha256'),'hex'), _user);

  insert into public.chat_work_events (item_id, actor_id, from_state, to_state, action, detail)
  values (v_id, _user, null, 'open', 'created_from_message', v_s);

  perform public.chat_log(v_ws, _user, 'work.from_message', v_id::text, v_s);

  return jsonb_build_object('ok', true, 'item_id', v_id, 'parsed', v_s);
end $$;

-- Dependency (cycle mumkin nahi)
create or replace function public.chat_work_depend(_item uuid, _depends_on uuid, _user uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_conv uuid; v_cursor uuid; v_hops int := 0;
begin
  if _item = _depends_on then raise exception 'self_dependency'; end if;
  if not coalesce((public.chat_feature_allowed(_user,'work_dependency')->>'allowed')::boolean,false) then
    return jsonb_build_object('ok', false, 'error', 'not_entitled');
  end if;
  select conversation_id into v_conv from public.chat_work_items where id = _item;
  if v_conv is null then raise exception 'item_not_found'; end if;
  if not public.chat_in_conversation(v_conv, _user) then raise exception 'not_participant'; end if;

  v_cursor := _depends_on;
  while v_cursor is not null and v_hops < 32 loop
    if v_cursor = _item then raise exception 'dependency_cycle'; end if;
    select depends_on into v_cursor from public.chat_work_items where id = v_cursor;
    v_hops := v_hops + 1;
  end loop;

  update public.chat_work_items
     set depends_on = _depends_on,
         state = case when state = 'open'
                       and exists (select 1 from public.chat_work_items d
                                    where d.id = _depends_on and d.state <> 'done')
                      then 'blocked' else state end
   where id = _item;

  insert into public.chat_work_events (item_id, actor_id, action, detail)
  values (_item, _user, 'dependency_set', jsonb_build_object('depends_on', _depends_on));

  return jsonb_build_object('ok', true, 'item_id', _item, 'depends_on', _depends_on);
end $$;

-- Completion: evidence ke bina 'done' namumkin
create or replace function public.chat_work_complete(
  _item uuid, _user uuid, _evidence jsonb default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_row public.chat_work_items; v_have int; v_kind text; v_ref text;
begin
  select * into v_row from public.chat_work_items where id = _item;
  if not found then raise exception 'item_not_found'; end if;
  if not public.chat_in_conversation(v_row.conversation_id, _user) then raise exception 'not_participant'; end if;
  if v_row.depends_on is not null
     and exists (select 1 from public.chat_work_items d where d.id = v_row.depends_on and d.state <> 'done') then
    return jsonb_build_object('ok', false, 'error', 'blocked_by_dependency', 'depends_on', v_row.depends_on);
  end if;

  if _evidence is not null and coalesce(_evidence->>'ref','') <> '' then
    v_kind := coalesce(_evidence->>'kind', 'note');
    v_ref  := _evidence->>'ref';
    insert into public.chat_work_evidence (item_id, kind, ref, sha256, added_by)
    values (_item, v_kind, v_ref, encode(digest(v_ref, 'sha256'), 'hex'), _user);
  end if;

  select count(*) into v_have from public.chat_work_evidence
   where item_id = _item and kind <> 'message';
  if v_have = 0 then
    return jsonb_build_object('ok', false, 'error', 'evidence_required',
      'message', 'Completion needs evidence: a file, a link, a message or a written note.');
  end if;

  update public.chat_work_items
     set state = 'done', completed_by = _user, completed_at = now(), closed_at = now()
   where id = _item;

  update public.chat_work_items
     set state = 'open'
   where depends_on = _item and state = 'blocked';

  insert into public.chat_work_events (item_id, actor_id, from_state, to_state, action, detail)
  values (_item, _user, v_row.state, 'done', 'completed', jsonb_build_object('evidence_count', v_have));

  return jsonb_build_object('ok', true, 'item_id', _item, 'state', 'done', 'evidence_count', v_have);
end $$;

-- Poori chain: message → work → owner → dependency → deadline → completion → evidence
create or replace function public.chat_work_chain(_item uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_row public.chat_work_items; v_msg jsonb;
begin
  select * into v_row from public.chat_work_items where id = _item;
  if not found then raise exception 'item_not_found'; end if;
  if not public.chat_in_conversation(v_row.conversation_id, _user) then raise exception 'not_participant'; end if;

  select jsonb_build_object(
      'id', m.id, 'seq', m.seq, 'sender_id', m.sender_user_id, 'sent_at', m.created_at,
      'visible', m.deleted_at is null,
      'body', case when m.deleted_at is null then m.body else null end)
    into v_msg
    from public.chat_messages m where m.id = v_row.message_id;

  return jsonb_build_object(
    'item', jsonb_build_object(
      'id', v_row.id, 'kind', v_row.kind, 'title', v_row.title, 'state', v_row.state,
      'owner_user_id', v_row.owner_user_id, 'created_by', v_row.created_by,
      'created_at', v_row.created_at, 'due_at', v_row.due_at,
      'depends_on', v_row.depends_on,
      'completed_by', v_row.completed_by, 'completed_at', v_row.completed_at,
      'retention_class', v_row.retention_class),
    'source_message', coalesce(v_msg, jsonb_build_object('visible', false, 'body', null)),
    'provenance', v_row.provenance,
    'parsed', v_row.parsed,
    'dependency', (select jsonb_build_object('id', d.id, 'title', d.title, 'state', d.state)
                     from public.chat_work_items d where d.id = v_row.depends_on),
    'evidence', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', e.kind, 'ref', e.ref, 'sha256', e.sha256, 'at', e.at) order by e.id)
      from public.chat_work_evidence e where e.item_id = _item), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
        'action', ev.action, 'from_state', ev.from_state, 'to_state', ev.to_state, 'at', ev.at) order by ev.id)
      from public.chat_work_events ev where ev.item_id = _item), '[]'::jsonb),
    'chain_intact', v_row.provenance ? 'body_hash');
end $$;

-- Workspace-level execution board (owner + deadline + dependency truth)
create or replace function public.chat_work_board(_user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from public.chat_members where user_id = _user limit 1;
  if v_ws is null then return jsonb_build_object('items', '[]'::jsonb); end if;
  return jsonb_build_object(
    'plan', public.chat_feature_allowed(_user, 'work_chain'),
    'items', coalesce((select jsonb_agg(jsonb_build_object(
        'id', w.id, 'kind', w.kind, 'title', w.title, 'state', w.state,
        'owner_user_id', w.owner_user_id, 'due_at', w.due_at,
        'depends_on', w.depends_on, 'conversation_id', w.conversation_id,
        'message_id', w.message_id, 'completed_at', w.completed_at,
        'overdue', w.due_at is not null and w.state in ('open','blocked') and w.due_at < now(),
        'evidence_count', (select count(*) from public.chat_work_evidence e
                            where e.item_id = w.id and e.kind <> 'message'))
      order by (w.due_at is null), w.due_at)
      from public.chat_work_items w
     where w.workspace_id = v_ws and w.state in ('open','blocked')), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------
-- LOOPHOLE FIX — messenger basics jo missing thay: forward + star
-- ---------------------------------------------------------------------------
create table if not exists public.chat_message_stars (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  at         timestamptz not null default now(),
  primary key (message_id, user_id)
);
grant select on public.chat_message_stars to authenticated;
grant all on public.chat_message_stars to service_role;
alter table public.chat_message_stars enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename='chat_message_stars' and policyname='own stars') then
    create policy "own stars" on public.chat_message_stars
      for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

create or replace function public.chat_message_star(_msg uuid, _user uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_conv uuid; v_starred boolean;
begin
  select conversation_id into v_conv from public.chat_messages where id = _msg;
  if v_conv is null then raise exception 'message_not_found'; end if;
  if not public.chat_in_conversation(v_conv, _user) then raise exception 'not_participant'; end if;
  if exists (select 1 from public.chat_message_stars where message_id = _msg and user_id = _user) then
    delete from public.chat_message_stars where message_id = _msg and user_id = _user;
    v_starred := false;
  else
    insert into public.chat_message_stars (message_id, user_id) values (_msg, _user);
    v_starred := true;
  end if;
  return jsonb_build_object('ok', true, 'message_id', _msg, 'starred', v_starred);
end $$;

create or replace function public.chat_message_forward(_msg uuid, _to_conv uuid, _user uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_from uuid; v_body text; v_new jsonb;
begin
  select conversation_id, body into v_from, v_body from public.chat_messages where id = _msg;
  if v_from is null then raise exception 'message_not_found'; end if;
  if not public.chat_in_conversation(v_from, _user) then raise exception 'not_participant_source'; end if;
  if not public.chat_in_conversation(_to_conv, _user) then raise exception 'not_participant_target'; end if;

  select to_jsonb(t) into v_new from public.chat_send(
    _to_conv, _user, gen_random_uuid()::text, v_body, 'forward') t;

  insert into public.chat_work_events (item_id, actor_id, action, detail)
  select w.id, _user, 'forwarded', jsonb_build_object('to_conversation', _to_conv)
    from public.chat_work_items w where w.message_id = _msg;

  return jsonb_build_object('ok', true, 'forwarded_from', _msg, 'to_conversation', _to_conv, 'message', v_new);
end $$;

-- ---------------------------------------------------------------------------
-- EXECUTE grants
-- ---------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'public.chat_feature_allowed(uuid,text)',
    'public.device_vault_register(uuid,jsonb,text)',
    'public.device_trust_list(uuid)',
    'public.device_trust_set(uuid,text,text,text)',
    'public.device_vault_purge()',
    'public.safety_can_review(uuid)',
    'public.safety_report_create(uuid,text,text,text,text,text)',
    'public.safety_queue(uuid,text)',
    'public.safety_report_advance(uuid,uuid,text,text,text,timestamptz)',
    'public.safety_report_reveal(uuid,uuid,text,text)',
    'public.safety_my_standing(uuid)',
    'public.chat_work_suggest(uuid,uuid)',
    'public.chat_work_from_message(uuid,uuid,text,text,uuid,timestamptz)',
    'public.chat_work_depend(uuid,uuid,uuid)',
    'public.chat_work_complete(uuid,uuid,jsonb)',
    'public.chat_work_chain(uuid,uuid)',
    'public.chat_work_board(uuid)',
    'public.chat_message_star(uuid,uuid)',
    'public.chat_message_forward(uuid,uuid,uuid)'
  ]
  loop
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ============================================================================
-- PHASE 19-22 GREEN CHECK (Supabase editor mein last query):
--   select public.device_trust_list(auth.uid());
--   select public.safety_my_standing(auth.uid());
--   select public.chat_work_board(auth.uid());
-- ============================================================================
