-- E112 — FOUNDER INBOX (step 4d, P1): user ki Glitch / Support reports ka asli intake, severity, SLA, duplicate-grouping, hash-chained history.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), security definer RPC (service_role only, search_path + statement_timeout pinned), RLS on, append-only
--             hash-chained history (pgcrypto SHA-256, schema extensions), E102 audit chain, E109 live source, E111 channels. Idempotent (dobara chalana safe).
-- Founder orders: 1 Nov 07:11 "koi feature not connected nahi, her cheeze live working wire" · 07:17 "kaam shuru kero" · 06:45 "SQL kam se kam 800 lines".
-- Design: docs/claude/FOUNDER-CHANNELS-CEO-LIST-01NOV.md (A-H).
--
-- ASAL MASLE
--   Glitch aur Support channels "Not connected" isliye the ke repo mein user ki report ka koi asli source hi nahi tha. Yeh file wo source banati hai.
--   report_submit() sirf service_role (awam backend / Rust intake) bulata hai; browser seedha kabhi nahi. Jab tak awam side button (P4) nahi lagta
--   koi report nahi aati — isliye channels "Not connected" SACH rehte hain; pehli asli report ke baad founder channel ko apni state machine (E111) se connect karta hai.
--
-- FOUNDER KO KYA MILTA HAI (CEO list A-H)
--   A Inbox   founder_inbox_list()      — teeno channel ek list, status/severity/SLA ke saath (message body list mein nahi)
--   B Severity _fr_severity()           — data-driven rules (login/checkout/billing toot = critical), paying customer ek darja upar
--   C SLA      founder_report_sla       — severity -> jawab/hal ke minute; list mein "baaki/der" ginti
--   D Jawab    founder_report_set()     — status badlo (state machine), har badlav hash-chain + E102 audit mein; reply Mail Desk (step 11) se
--   E Dedup    founder_report_groups    — ek hi masla 40 users = 1 group, "40 affected"
--   F Context  plan + MRR snapshot      — paying customer ki report upar
--   G Trend    founder_inbox_stats()    — 7 din ginti, sab se kharab pages, median hal-waqt, SLA breach
--   H Privacy  email/IP/UA kabhi nahi   — reporter sirf ek 64-hex hash; body sirf founder_inbox_get() mein; title/page par email-check; retention prune
--
-- SECTIONS
--   0) Preflight                 1) rules tables (severity, SLA, transitions)          2) founder_report_groups
--   3) founder_reports           4) founder_report_events (append-only chain)          5) helpers
--   6) report_submit             7) founder_report_set + verify                        8) inbox list/get
--   9) stats + trend             10) live source + channel evidence                    11) retention
--  12) grants                    13) selftest (poora rollback) + CHECK_E112.sql

set lock_timeout = '10s';
set statement_timeout = '60s';
set search_path = pg_catalog, public, extensions;

-- ==============================================================================================================================
-- 0) PREFLIGHT — E102 (audit), E109 (live), E111 (channels) pehle honi chahiye. Aadhi table kabhi nahi banti.
-- ==============================================================================================================================
do $$
begin
  if to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then raise exception 'E112: pehle E102 chalayein (founder_audit_append nahi)'; end if;
  if to_regclass('public.founder_live_sources') is null then raise exception 'E112: pehle E109 chalayein (founder_live_sources nahi)'; end if;
  if to_regclass('public.founder_channels') is null then raise exception 'E112: pehle E111 chalayein (founder_channels nahi)'; end if;
  if to_regprocedure('extensions.digest(bytea,text)') is null and to_regprocedure('public.digest(bytea,text)') is null then raise exception 'E112: pgcrypto digest nahi'; end if;
  if to_regclass('public.founder_accounts') is null then raise exception 'E112: founder_accounts nahi (E100)'; end if;
end $$;

-- ==============================================================================================================================
-- 1) RULES (data, code nahi): severity patterns, SLA minutes, status transitions. Badalna = ek INSERT/UPDATE, audit-able.
-- ==============================================================================================================================
do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_inbox:ddl', 0));

  create table if not exists public.founder_report_severity_rules (
    id        smallint generated always as identity primary key,
    kind      text not null check (kind in ('glitch', 'support', 'any')),
    pattern   text not null check (length(pattern) between 2 and 80 and pattern !~ '[[:cntrl:]]'),   -- page ya title mein yeh lafz (case-insensitive substring)
    severity  text not null check (severity in ('low', 'normal', 'high', 'critical')),
    note      text not null check (length(note) between 4 and 120),
    unique (kind, pattern)
  );
  alter table public.founder_report_severity_rules enable row level security;
  revoke all on public.founder_report_severity_rules from public, anon, authenticated;
  grant select on public.founder_report_severity_rules to service_role;
  insert into public.founder_report_severity_rules (kind, pattern, severity, note) values
    ('any',     'checkout', 'critical', 'Payment path broken'),
    ('any',     'billing',  'critical', 'Billing path broken'),
    ('any',     'payment',  'critical', 'Payment path broken'),
    ('any',     'login',    'critical', 'Users cannot sign in'),
    ('any',     'signup',   'critical', 'New users cannot join'),
    ('any',     'security', 'critical', 'Possible security issue'),
    ('glitch',  'mail',     'high',     'Mail sending or reading broken'),
    ('glitch',  'chat',     'high',     'Chat broken'),
    ('glitch',  'upload',   'high',     'File upload broken'),
    ('support', 'refund',   'high',     'Money question'),
    ('support', 'cancel',   'high',     'Cancellation request (churn risk)'),
    ('support', 'invoice',  'high',     'Money question')
  on conflict (kind, pattern) do nothing;

  create table if not exists public.founder_report_sla (
    severity        text primary key check (severity in ('low', 'normal', 'high', 'critical')),
    respond_minutes integer not null check (respond_minutes between 5 and 20160),
    solve_minutes   integer not null check (solve_minutes between 15 and 43200),
    constraint founder_report_sla_order_ck check (solve_minutes >= respond_minutes)
  );
  alter table public.founder_report_sla enable row level security;
  revoke all on public.founder_report_sla from public, anon, authenticated;
  grant select on public.founder_report_sla to service_role;
  insert into public.founder_report_sla (severity, respond_minutes, solve_minutes) values
    ('critical', 30,   240),
    ('high',     240,  1440),
    ('normal',   1440, 4320),
    ('low',      4320, 10080)
  on conflict (severity) do nothing;

  create table if not exists public.founder_report_transitions (
    from_status text not null check (from_status in ('new', 'open', 'waiting', 'solved', 'closed')),
    to_status   text not null check (to_status   in ('new', 'open', 'waiting', 'solved', 'closed')),
    needs_note  boolean not null default false,
    primary key (from_status, to_status),
    constraint founder_report_transitions_diff_ck check (from_status <> to_status)
  );
  alter table public.founder_report_transitions enable row level security;
  revoke all on public.founder_report_transitions from public, anon, authenticated;
  grant select on public.founder_report_transitions to service_role;
  insert into public.founder_report_transitions (from_status, to_status, needs_note) values
    ('new',     'open',    false),
    ('new',     'closed',  true),
    ('open',    'waiting', false),
    ('open',    'solved',  true),
    ('open',    'closed',  true),
    ('waiting', 'open',    false),
    ('waiting', 'solved',  true),
    ('waiting', 'closed',  true),
    ('solved',  'open',    true),
    ('closed',  'open',    true)
  on conflict do nothing;

  -- ============================================================================================================================
  -- 2) GROUPS — ek hi masla, bohat users. fingerprint = sha256(kind | normalised page | title signature)
  -- ============================================================================================================================
  create table if not exists public.founder_report_groups (
    id           bigint generated always as identity primary key,
    fingerprint  text not null unique check (fingerprint ~ '^[0-9a-f]{64}$'),
    kind         text not null check (kind in ('glitch', 'support')),
    page         text not null check (length(page) between 1 and 120 and page !~ '[[:cntrl:]]'),
    title        text not null check (length(btrim(title)) between 3 and 120 and title !~ '[[:cntrl:]]'
                                      and title !~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'),
    severity     text not null check (severity in ('low', 'normal', 'high', 'critical')),
    status       text not null default 'new' check (status in ('new', 'open', 'waiting', 'solved', 'closed')),
    affected     integer not null default 1 check (affected between 1 and 10000000),
    first_seen   timestamptz not null default now(),
    last_seen    timestamptz not null default now(),
    constraint founder_report_groups_time_ck check (last_seen >= first_seen)
  );
  create index if not exists founder_report_groups_open_idx on public.founder_report_groups (status, severity, last_seen desc);
  alter table public.founder_report_groups enable row level security;
  revoke all on public.founder_report_groups from public, anon, authenticated;
  grant select, insert, update on public.founder_report_groups to service_role;
  revoke delete, truncate, references, trigger on public.founder_report_groups from service_role;

  -- ============================================================================================================================
  -- 3) REPORTS — har user ki ek report. body sirf founder_inbox_get() se; reporter ek hash (email/IP/UA kabhi nahi).
  -- ============================================================================================================================
  create table if not exists public.founder_reports (
    id             bigint generated always as identity primary key,
    group_id       bigint not null references public.founder_report_groups (id),
    kind           text not null check (kind in ('glitch', 'support')),
    severity       text not null check (severity in ('low', 'normal', 'high', 'critical')),
    status         text not null default 'new' check (status in ('new', 'open', 'waiting', 'solved', 'closed')),
    page           text not null check (length(page) between 1 and 120 and page !~ '[[:cntrl:]]'),
    body           text not null check (length(btrim(body)) between 5 and 4000),
    reporter_hash  text not null check (reporter_hash ~ '^[0-9a-f]{64}$'),
    plan           text check (plan is null or plan in ('free', 'trial', 'starter', 'pro', 'business', 'enterprise', 'other')),
    mrr_gbp        numeric(12, 2) check (mrr_gbp is null or mrr_gbp between 0 and 10000000),
    ua_class       text check (ua_class is null or ua_class in ('desktop', 'mobile', 'tablet', 'bot', 'other')),
    created_at     timestamptz not null default now(),
    first_response_at timestamptz,
    solved_at      timestamptz,
    respond_due_at timestamptz not null,
    solve_due_at   timestamptz not null,
    updated_at     timestamptz not null default now(),
    constraint founder_reports_due_ck check (solve_due_at >= respond_due_at and respond_due_at >= created_at),
    constraint founder_reports_solved_ck check ((status in ('solved', 'closed')) = (solved_at is not null) or status = 'closed')
  );
  create index if not exists founder_reports_inbox_idx on public.founder_reports (status, severity, created_at desc);
  create index if not exists founder_reports_group_idx on public.founder_reports (group_id, id desc);
  create index if not exists founder_reports_reporter_idx on public.founder_reports (reporter_hash, created_at desc);
  alter table public.founder_reports enable row level security;
  revoke all on public.founder_reports from public, anon, authenticated;
  grant select, insert, update on public.founder_reports to service_role;
  revoke delete, truncate, references, trigger on public.founder_reports from service_role;

  -- ============================================================================================================================
  -- 4) HISTORY — append-only, hash-chained (har badlav pichle ka hash rakhta hai). actor null = system (jaise report aayi).
  -- ============================================================================================================================
  create table if not exists public.founder_report_events (
    id         bigint generated always as identity primary key,
    ts         timestamptz not null default now(),
    report_id  bigint not null references public.founder_reports (id),
    actor      uuid,
    from_status text not null,
    to_status  text not null,
    note       text check (note is null or (length(note) <= 240 and note !~ '[[:cntrl:]]' and note !~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}')),
    audit_seq  bigint,
    prev_hash  text not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash       text not null check (hash ~ '^[0-9a-f]{64}$'),
    unique (hash)
  );
  create index if not exists founder_report_events_rep_idx on public.founder_report_events (report_id, id desc);
  alter table public.founder_report_events enable row level security;
  revoke all on public.founder_report_events from public, anon, authenticated;
  grant select, insert on public.founder_report_events to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_report_events from service_role;
end $$;

-- Append-only guard: history kabhi badalti/hatti nahi (retention sirf reports par; chain ki history poori rehti hai).
create or replace function public._founder_report_events_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  raise exception 'founder_report_events append-only: % not allowed', tg_op using errcode = '42501';
end $$;

-- Reports ke wo columns jo kabhi nahi badalte (body/reporter/page/created_at/kind/group) — status/severity/waqt hi badlte hain.
-- Sirf ek istithna: retention (founder_inbox_prune) `founder.inbox_redact=on` ke saath body ko "[removed by retention]" aur reporter ko zero-hash kar sakta hai.
create or replace function public._founder_reports_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare red boolean := coalesce(current_setting('founder.inbox_redact', true), 'off') = 'on';
begin
  if (new.id, new.kind, new.group_id, new.page, new.created_at) is distinct from (old.id, old.kind, old.group_id, old.page, old.created_at) then
    raise exception 'founder_reports: yeh columns badal nahi sakte' using errcode = '42501';
  end if;
  if (new.body, new.reporter_hash) is distinct from (old.body, old.reporter_hash) then
    if not (red and new.body = '[removed by retention]' and new.reporter_hash = repeat('0', 64) and old.status in ('solved', 'closed')) then
      raise exception 'founder_reports: body/reporter badal nahi sakte' using errcode = '42501';
    end if;
  end if;
  if new.status is distinct from old.status or new.severity is distinct from old.severity or new.solved_at is distinct from old.solved_at
     or new.first_response_at is distinct from old.first_response_at then new.updated_at := now(); end if;
  return new;
end $$;

do $$
begin
  if to_regclass('public.founder_report_events') is not null then
    if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_report_events'::regclass and tgname = 'founder_report_events_no_upd_del') then
      create trigger founder_report_events_no_upd_del before update or delete on public.founder_report_events for each row execute function public._founder_report_events_guard();
    end if;
    if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_report_events'::regclass and tgname = 'founder_report_events_no_trunc') then
      create trigger founder_report_events_no_trunc before truncate on public.founder_report_events for each statement execute function public._founder_report_events_guard();
    end if;
  end if;
  if to_regclass('public.founder_reports') is not null and not exists (select 1 from pg_trigger where tgrelid = 'public.founder_reports'::regclass and tgname = 'founder_reports_guard') then
    create trigger founder_reports_guard before update on public.founder_reports for each row execute function public._founder_reports_guard();
  end if;
end $$;

-- ==============================================================================================================================
-- 5) HELPERS
-- ==============================================================================================================================
-- Page ka naam saaf: query/fragment hata, chhote harf, lambe numbers/uuid ":id", lambai 120 tak. Sirf path rakhta hai (user data nahi).
create or replace function public._fr_norm_page(p text) returns text
language sql immutable set search_path = pg_catalog, public as $$
  select left(coalesce(nullif(regexp_replace(regexp_replace(regexp_replace(lower(btrim(coalesce(p, ''))),
           '[?#].*$', ''), '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', ':id', 'g'), '/[0-9]{3,}', '/:id', 'g'), ''), '/'), 120)
$$;

-- Title/free text: trim, control nahi, email nahi (page/title list mein dikhte hain), lambai ki had. NULL = khali.
create or replace function public._fr_clean(p text, p_max integer) returns text
language plpgsql immutable set search_path = pg_catalog, public as $$
declare t text := regexp_replace(btrim(coalesce(p, '')), '\s+', ' ', 'g');
begin
  if t = '' then return null; end if;
  if t ~ '[[:cntrl:]]' then raise exception 'text mein control character' using errcode = '22023'; end if;
  if t ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' then raise exception 'text mein email jaisa kuch (privacy)' using errcode = '22023'; end if;
  if length(t) > p_max then raise exception 'text bohat lamba (% tak)', p_max using errcode = '22023'; end if;
  return t;
end $$;

-- Body: newline/tab theek, baqi control nahi. Email body mein ho sakti hai (sirf founder padhta hai) — list/stats mein kabhi nahi aati.
create or replace function public._fr_clean_body(p text) returns text
language plpgsql immutable set search_path = pg_catalog, public as $$
declare t text := btrim(coalesce(p, ''));
begin
  if length(t) < 5 then raise exception 'report bohat chhoti (kam az kam 5 akshar)' using errcode = '22023'; end if;
  if length(t) > 4000 then raise exception 'report bohat lambi (4000 tak)' using errcode = '22023'; end if;
  if t ~ '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' then raise exception 'report mein control character' using errcode = '22023'; end if;
  return t;
end $$;

create or replace function public._fr_hash(p_prev text, p_report bigint, p_actor uuid, p_from text, p_to text, p_note text, p_ts text) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(digest(convert_to(concat_ws('|', length(p_prev)::text || ':' || p_prev, p_report::text, coalesce(p_actor::text, 'system'),
         length(p_from)::text || ':' || p_from, length(p_to)::text || ':' || p_to, length(coalesce(p_note, ''))::text || ':' || coalesce(p_note, ''),
         length(p_ts)::text || ':' || p_ts), 'UTF8'), 'sha256'), 'hex')
$$;

create or replace function public._fr_rank(p_sev text) returns integer
language sql immutable set search_path = pg_catalog, public as $$
  select case p_sev when 'critical' then 4 when 'high' then 3 when 'normal' then 2 when 'low' then 1 else 0 end
$$;
create or replace function public._fr_bump(p_sev text) returns text
language sql immutable set search_path = pg_catalog, public as $$
  select case p_sev when 'low' then 'normal' when 'normal' then 'high' when 'high' then 'critical' else p_sev end
$$;

-- Severity: rules table ka sab se oonchha match (page + title mein substring); koi match nahi => 'normal'. Support ko 'low' nahi gira'ta.
create or replace function public._fr_severity(p_kind text, p_page text, p_title text) returns text
language sql stable set search_path = pg_catalog, public as $$
  select coalesce((select r.severity from public.founder_report_severity_rules r
                    where r.kind in (p_kind, 'any') and (lower(coalesce(p_page, '')) like '%' || lower(r.pattern) || '%' or lower(coalesce(p_title, '')) like '%' || lower(r.pattern) || '%')
                    order by public._fr_rank(r.severity) desc limit 1), 'normal')
$$;

-- Dedup fingerprint: kind | page | title (chhote harf, spaces ek, ginti '#' — "error 404" aur "error 500" ek masla na samjhe jaayen isliye ginti sirf '#' nahi, poora rakhte hain)
create or replace function public._fr_fingerprint(p_kind text, p_page text, p_title text) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(digest(convert_to(p_kind || '|' || p_page || '|' || regexp_replace(lower(btrim(p_title)), '\s+', ' ', 'g'), 'UTF8'), 'sha256'), 'hex')
$$;

-- Ek group ka status uski reports se (sab se "zyada kaam baaki" wali halat)
create or replace function public._fr_group_status(p_group bigint) returns text
language sql stable set search_path = pg_catalog, public as $$
  select case when bool_or(status = 'new') then 'new' when bool_or(status = 'open') then 'open' when bool_or(status = 'waiting') then 'waiting'
              when bool_or(status = 'solved') then 'solved' else 'closed' end
    from public.founder_reports where group_id = p_group
$$;

create or replace function public._fr_needs_note(p_from text, p_to text) returns boolean
language sql stable set search_path = pg_catalog, public as $$
  select needs_note from public.founder_report_transitions where from_status = p_from and to_status = p_to
$$;

-- ==============================================================================================================================
-- 6) report_submit — user ki report ka EK darwaza (sirf service_role; awam backend / Rust intake). Rate limit, dedup, severity, SLA, chain.
-- ==============================================================================================================================
create or replace function public.report_submit(
  p_kind text, p_page text, p_title text, p_body text, p_reporter_hash text,
  p_plan text default null, p_mrr_gbp numeric default null, p_ua_class text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare
  v_page text; v_title text; v_body text; v_fp text; v_sev text; g public.founder_report_groups%rowtype; v_new_group boolean := false; v_id bigint;
  v_recent integer; v_ts timestamptz := clock_timestamp(); sla public.founder_report_sla%rowtype; v_prev text; v_hash text; v_dup boolean; v_paid boolean;
begin
  if coalesce(p_kind, '') not in ('glitch', 'support') then raise exception 'kind galat' using errcode = '22023'; end if;
  if coalesce(p_reporter_hash, '') !~ '^[0-9a-f]{64}$' then raise exception 'reporter hash galat (64 hex)' using errcode = '22023'; end if;
  v_page := public._fr_norm_page(p_page);
  v_title := coalesce(public._fr_clean(p_title, 120), case p_kind when 'glitch' then 'Problem on ' || v_page else 'Support request' end);
  if length(v_title) < 3 then raise exception 'title bohat chhota' using errcode = '22023'; end if;
  v_body := public._fr_clean_body(p_body);
  if p_plan is not null and p_plan not in ('free', 'trial', 'starter', 'pro', 'business', 'enterprise', 'other') then raise exception 'plan galat' using errcode = '22023'; end if;
  if p_ua_class is not null and p_ua_class not in ('desktop', 'mobile', 'tablet', 'bot', 'other') then raise exception 'ua_class galat' using errcode = '22023'; end if;
  if p_mrr_gbp is not null and (p_mrr_gbp < 0 or p_mrr_gbp > 10000000) then raise exception 'mrr galat' using errcode = '22023'; end if;

  -- ek reporter 10 minute mein 5 se zyada nahi (spam/loop se inbox na bhare)
  select count(*) into v_recent from public.founder_reports where reporter_hash = p_reporter_hash and created_at > now() - interval '10 minutes';
  if v_recent >= 5 then raise exception 'bohat reports (10 minute mein 5 se zyada)' using errcode = '54000'; end if;

  v_fp := public._fr_fingerprint(p_kind, v_page, v_title);
  perform pg_advisory_xact_lock(hashtextextended('founder_inbox:group:' || v_fp, 0));
  v_paid := coalesce(p_mrr_gbp, 0) > 0 or coalesce(p_plan, 'free') in ('starter', 'pro', 'business', 'enterprise');
  v_sev := public._fr_severity(p_kind, v_page, v_title);
  if v_paid then v_sev := public._fr_bump(v_sev); end if;

  select * into g from public.founder_report_groups where fingerprint = v_fp for update;
  if not found then
    insert into public.founder_report_groups (fingerprint, kind, page, title, severity) values (v_fp, p_kind, v_page, v_title, v_sev) returning * into g;
    v_new_group := true;
  else
    -- wahi user dobara likhe to "affected" nahi badhta; naya user ho to badhta hai
    v_dup := exists (select 1 from public.founder_reports where group_id = g.id and reporter_hash = p_reporter_hash);
    update public.founder_report_groups set affected = affected + case when v_dup then 0 else 1 end, last_seen = greatest(last_seen, v_ts),
           severity = case when public._fr_rank(v_sev) > public._fr_rank(severity) then v_sev else severity end,
           status = case when status in ('solved', 'closed') then 'new' else status end   -- hal ho chuka masla wapas aaya: regression => dobara new
     where id = g.id returning * into g;
    v_sev := g.severity;
  end if;

  select * into sla from public.founder_report_sla where severity = v_sev;
  insert into public.founder_reports (group_id, kind, severity, page, body, reporter_hash, plan, mrr_gbp, ua_class, created_at, respond_due_at, solve_due_at)
    values (g.id, p_kind, v_sev, v_page, v_body, p_reporter_hash, p_plan, p_mrr_gbp, p_ua_class, v_ts,
            v_ts + make_interval(mins => sla.respond_minutes), v_ts + make_interval(mins => sla.solve_minutes)) returning id into v_id;

  perform pg_advisory_xact_lock(hashtextextended('founder_inbox:chain', 0));
  select hash into v_prev from public.founder_report_events order by id desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  v_hash := public._fr_hash(v_prev, v_id, null, 'none', 'new', null, to_char(v_ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'));
  insert into public.founder_report_events (ts, report_id, actor, from_status, to_status, note, prev_hash, hash) values (v_ts, v_id, null, 'none', 'new', null, v_prev, v_hash);
  return jsonb_build_object('ok', true, 'report_id', v_id, 'group_id', g.id, 'severity', v_sev, 'new_group', v_new_group, 'affected', g.affected,
                            'respond_due_at', v_ts + make_interval(mins => sla.respond_minutes));
end $$;

-- ==============================================================================================================================
-- 7) founder_report_set (ek report) + founder_group_set (poora masla) + verify
-- ==============================================================================================================================
create or replace function public.founder_report_set(p_uid uuid, p_id bigint, p_to text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare r public.founder_reports%rowtype; v_note text; v_need boolean; v_prev text; v_hash text; v_ts timestamptz := clock_timestamp(); a jsonb; v_recent integer;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_inbox:report:' || coalesce(p_id, 0), 0));
  select * into r from public.founder_reports where id = p_id for update;
  if not found then raise exception 'report nahi mili: %', p_id using errcode = 'P0002'; end if;
  v_note := public._fr_clean(p_note, 240);
  if p_to = r.status then raise exception 'report pehle se % hai', p_to using errcode = '22023'; end if;
  v_need := public._fr_needs_note(r.status, p_to);
  if v_need is null then raise exception 'transition manzoor nahi: % -> %', r.status, p_to using errcode = '22023'; end if;
  if v_need and (v_note is null or length(v_note) < 8) then raise exception 'is transition ke liye note (kam az kam 8 akshar) lazmi hai' using errcode = '22023'; end if;
  select count(*) into v_recent from public.founder_report_events where report_id = p_id and ts > now() - interval '10 minutes';
  if v_recent >= 10 then raise exception 'is report par bohat badlav' using errcode = '54000'; end if;

  perform pg_advisory_xact_lock(hashtextextended('founder_inbox:chain', 0));
  select hash into v_prev from public.founder_report_events order by id desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  v_hash := public._fr_hash(v_prev, p_id, p_uid, r.status, p_to, v_note, to_char(v_ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'));
  a := public.founder_audit_append(p_uid, 'inbox.' || p_to, 'report:' || p_id, coalesce(v_note, 'status ' || r.status || ' -> ' || p_to), jsonb_build_object('from', r.status, 'to', p_to, 'group', r.group_id));
  insert into public.founder_report_events (ts, report_id, actor, from_status, to_status, note, audit_seq, prev_hash, hash)
    values (v_ts, p_id, p_uid, r.status, p_to, v_note, (a ->> 'seq')::bigint, v_prev, v_hash);
  update public.founder_reports set status = p_to,
         first_response_at = case when first_response_at is null and r.status = 'new' then v_ts else first_response_at end,
         solved_at = case when p_to = 'solved' then v_ts when p_to in ('open', 'waiting', 'new') then null else solved_at end
   where id = p_id;
  update public.founder_report_groups set status = public._fr_group_status(r.group_id) where id = r.group_id;
  return jsonb_build_object('ok', true, 'report_id', p_id, 'from', r.status, 'to', p_to, 'hash', v_hash, 'audit_seq', (a ->> 'seq')::bigint);
end $$;

-- Poora masla ek baar: group ki saari "baaki" reports ko ek saath (har ek ki apni history + audit). Kitni badli wapas aati hai.
create or replace function public.founder_group_set(p_uid uuid, p_group bigint, p_to text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r record; n integer := 0; skipped integer := 0;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if not exists (select 1 from public.founder_report_groups where id = p_group) then raise exception 'group nahi mila: %', p_group using errcode = 'P0002'; end if;
  for r in select id, status from public.founder_reports where group_id = p_group and status <> p_to order by id loop
    if public._fr_needs_note(r.status, p_to) is null then skipped := skipped + 1; continue; end if;   -- jo report us halat tak ja hi nahi sakti, chhod do (chhupao nahi: ginti wapas)
    perform public.founder_report_set(p_uid, r.id, p_to, p_note);
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'group_id', p_group, 'to', p_to, 'changed', n, 'skipped', skipped);
end $$;

-- Chain dobara hisab: pehli kharab row ka id ya null (saaf).
create or replace function public.founder_report_verify(p_from bigint default 1) returns bigint
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare r record; prev text; first boolean := true;
begin
  for r in select * from public.founder_report_events where id >= greatest(coalesce(p_from, 1), 1) order by id loop
    if first then
      select hash into prev from public.founder_report_events where id < r.id order by id desc limit 1;
      prev := coalesce(prev, repeat('0', 64)); first := false;
    end if;
    if r.prev_hash <> prev then return r.id; end if;
    if r.hash <> public._fr_hash(r.prev_hash, r.report_id, r.actor, r.from_status, r.to_status, r.note, to_char(r.ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')) then return r.id; end if;
    prev := r.hash;
  end loop;
  return null;
end $$;

-- ==============================================================================================================================
-- 8) INBOX — list (masle/groups, body nahi, reporter nahi) aur get (ek masle ki poori tafseel, body sirf yahan)
-- ==============================================================================================================================
-- SLA ki halat ek report/group ke liye: 'done' (jawab mil chuka / hal), 'ok', 'due_soon' (baaki <25%), 'breached'. minutes_left manfi = der.
create or replace function public._fr_sla_state(p_due timestamptz, p_created timestamptz) returns jsonb
language sql stable set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'minutes_left', round(extract(epoch from (p_due - now())) / 60.0)::integer,
    'state', case when now() > p_due then 'breached'
                  when extract(epoch from (p_due - now())) < 0.25 * extract(epoch from (p_due - p_created)) then 'due_soon' else 'ok' end)
$$;

create or replace function public.founder_inbox_list(p_status text default 'active', p_kind text default null, p_limit integer default 50, p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 200); v_off integer := least(greatest(coalesce(p_offset, 0), 0), 10000); out jsonb; total bigint;
begin
  if coalesce(p_status, 'active') not in ('active', 'new', 'open', 'waiting', 'solved', 'closed', 'all') then raise exception 'status galat' using errcode = '22023'; end if;
  if p_kind is not null and p_kind not in ('glitch', 'support') then raise exception 'kind galat' using errcode = '22023'; end if;
  with g as (
    select g.*, (select count(*) from public.founder_reports r where r.group_id = g.id and r.status in ('new', 'open', 'waiting')) as open_reports,
           (select max(r.mrr_gbp) from public.founder_reports r where r.group_id = g.id) as top_mrr,
           (select min(r.respond_due_at) from public.founder_reports r where r.group_id = g.id and r.first_response_at is null and r.status = 'new') as respond_due,
           (select min(r.solve_due_at) from public.founder_reports r where r.group_id = g.id and r.status in ('new', 'open', 'waiting')) as solve_due,
           (select min(r.created_at) from public.founder_reports r where r.group_id = g.id and r.status in ('new', 'open', 'waiting')) as oldest_open
      from public.founder_report_groups g
     where (coalesce(p_status, 'active') = 'all' or (coalesce(p_status, 'active') = 'active' and g.status in ('new', 'open', 'waiting')) or g.status = p_status)
       and (p_kind is null or g.kind = p_kind)
  ), ordered as (
    select * from g order by (case when status in ('new', 'open', 'waiting') then 0 else 1 end), public._fr_rank(severity) desc, coalesce(top_mrr, 0) desc, last_seen desc limit v_lim offset v_off
  )
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'id', id, 'kind', kind, 'title', title, 'page', page, 'severity', severity, 'status', status, 'affected', affected, 'open_reports', open_reports,
      'first_seen', first_seen, 'last_seen', last_seen, 'paying', coalesce(top_mrr, 0) > 0,
      'respond', case when respond_due is not null then public._fr_sla_state(respond_due, first_seen) end,
      'solve', case when solve_due is not null then public._fr_sla_state(solve_due, first_seen) end,
      'oldest_open_minutes', case when oldest_open is not null then round(extract(epoch from (now() - oldest_open)) / 60.0)::integer end))), '[]'::jsonb)
    into out from ordered;
  select count(*) into total from public.founder_report_groups g
   where (coalesce(p_status, 'active') = 'all' or (coalesce(p_status, 'active') = 'active' and g.status in ('new', 'open', 'waiting')) or g.status = p_status) and (p_kind is null or g.kind = p_kind);
  return jsonb_build_object('total', total, 'limit', v_lim, 'offset', v_off, 'groups', out);
end $$;

create or replace function public.founder_inbox_get(p_group bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare g public.founder_report_groups%rowtype; reps jsonb; evs jsonb;
begin
  select * into g from public.founder_report_groups where id = p_group;
  if not found then raise exception 'group nahi mila: %', p_group using errcode = 'P0002'; end if;
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('id', id, 'status', status, 'severity', severity, 'body', body, 'plan', plan, 'mrr_gbp', mrr_gbp, 'ua_class', ua_class,
           'created_at', created_at, 'first_response_at', first_response_at, 'solved_at', solved_at,
           'respond', case when first_response_at is null and status = 'new' then public._fr_sla_state(respond_due_at, created_at) end,
           'solve', case when status in ('new', 'open', 'waiting') then public._fr_sla_state(solve_due_at, created_at) end)) order by id desc), '[]'::jsonb)
    into reps from (select * from public.founder_reports where group_id = p_group order by id desc limit 50) q;
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'ts', e.ts, 'report_id', e.report_id, 'from', e.from_status, 'to', e.to_status, 'note', e.note, 'by_founder', e.actor is not null) order by e.id desc), '[]'::jsonb)
    into evs from (select e.* from public.founder_report_events e join public.founder_reports r on r.id = e.report_id where r.group_id = p_group order by e.id desc limit 50) e;
  return jsonb_build_object('group', jsonb_build_object('id', g.id, 'kind', g.kind, 'title', g.title, 'page', g.page, 'severity', g.severity, 'status', g.status,
           'affected', g.affected, 'first_seen', g.first_seen, 'last_seen', g.last_seen), 'reports', reps, 'events', evs);
end $$;

-- ==============================================================================================================================
-- 9) STATS + TREND — Dashboard ka ek jawab: "kuch jal raha hai? kya der ho gayi? pichhle hafte kaisa raha?"
-- ==============================================================================================================================
create or replace function public.founder_inbox_stats() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare
  v_active bigint; v_new bigint; v_crit bigint; v_resp_late bigint; v_solve_late bigint; v_oldest integer; v_med numeric; v_total bigint; v_breach numeric;
  by_kind jsonb; by_sev jsonb; daily jsonb; pages jsonb; v_last timestamptz; v_solved30 bigint; v_late30 bigint; level text;
begin
  select count(*) filter (where status in ('new', 'open', 'waiting')), count(*) filter (where status = 'new'),
         count(*) filter (where status in ('new', 'open', 'waiting') and severity = 'critical'), count(*), max(last_seen)
    into v_active, v_new, v_crit, v_total, v_last from public.founder_report_groups;
  select count(*) into v_resp_late from public.founder_reports where status = 'new' and first_response_at is null and respond_due_at < now();
  select count(*) into v_solve_late from public.founder_reports where status in ('new', 'open', 'waiting') and solve_due_at < now();
  select round(extract(epoch from (now() - min(created_at))) / 60.0)::integer into v_oldest from public.founder_reports where status = 'new';
  select coalesce(jsonb_object_agg(kind, n), '{}'::jsonb) into by_kind from (select kind, count(*) n from public.founder_report_groups where status in ('new', 'open', 'waiting') group by 1) q;
  select coalesce(jsonb_object_agg(severity, n), '{}'::jsonb) into by_sev from (select severity, count(*) n from public.founder_report_groups where status in ('new', 'open', 'waiting') group by 1) q;
  select percentile_cont(0.5) within group (order by extract(epoch from (solved_at - created_at)) / 60.0), count(*), count(*) filter (where solved_at > solve_due_at)
    into v_med, v_solved30, v_late30 from public.founder_reports where solved_at is not null and solved_at > now() - interval '30 days';
  v_breach := case when v_solved30 > 0 then round(100.0 * v_late30 / v_solved30, 1) end;
  with days as (select (date_trunc('day', now() at time zone 'UTC') - make_interval(days => g))::date as d from generate_series(0, 6) g)
  select coalesce(jsonb_agg(jsonb_build_object('day', days.d, 'glitch', coalesce(c.gl, 0), 'support', coalesce(c.su, 0)) order by days.d), '[]'::jsonb) into daily
    from days left join (select (created_at at time zone 'UTC')::date as d, count(*) filter (where kind = 'glitch') gl, count(*) filter (where kind = 'support') su
                           from public.founder_reports where created_at > now() - interval '8 days' group by 1) c on c.d = days.d;
  select coalesce(jsonb_agg(jsonb_build_object('page', page, 'reports', n) order by n desc, page), '[]'::jsonb) into pages
    from (select page, count(*) n from public.founder_reports where kind = 'glitch' and created_at > now() - interval '7 days' group by 1 order by n desc, page limit 5) q;
  -- Dashboard rang: critical khula ya jawab ki der = fail; SLA breach ya zyada purani 'new' = warn; kuch nahi = ok; koi report hi nahi = unknown (andaza nahi)
  level := case when v_total = 0 then 'unknown' when v_crit > 0 or v_resp_late > 0 then 'fail' when v_solve_late > 0 or coalesce(v_oldest, 0) > 1440 then 'warn' else 'ok' end;
  return jsonb_strip_nulls(jsonb_build_object(
    'level', level, 'total_groups', v_total, 'active', v_active, 'new', v_new, 'critical_open', v_crit, 'respond_late', v_resp_late, 'solve_late', v_solve_late,
    'oldest_new_minutes', v_oldest, 'median_solve_minutes', round(v_med), 'solved_30d', v_solved30, 'sla_breach_pct_30d', v_breach, 'last_report_at', v_last,
    'active_by_kind', by_kind, 'active_by_severity', by_sev, 'daily_7d', daily, 'worst_pages_7d', pages,
    'reasons', (select coalesce(jsonb_agg(x), '[]'::jsonb) from unnest(array[
        case when v_crit > 0 then format('%s critical issue(s) open', v_crit) end,
        case when v_resp_late > 0 then format('%s report(s) waiting past the reply time', v_resp_late) end,
        case when v_solve_late > 0 then format('%s report(s) past the fix time', v_solve_late) end]) x where x is not null)));
end $$;

-- ==============================================================================================================================
-- 10) LIVE SOURCE + CHANNEL EVIDENCE — founder_reports E109 ka live source banta hai (Recent changes mein "Reports +1"); channels ka saboot yahin se.
-- ==============================================================================================================================
do $$
begin
  insert into public.founder_live_sources (key, label, relation, ts_candidates, ts_unit, owner, expect_max_age_secs, sort)
    values ('user_reports', 'User reports', 'public.founder_reports', array['updated_at', 'created_at'], 'timestamptz', 'founder', null, 130)
  on conflict (key) do nothing;
end $$;

-- Har channel ke liye asli ginti: kab pehli/aakhri report aayi. UI "pehli report aa chuki, channel connect kar sakte hain" isi se kehta hai.
create or replace function public.founder_inbox_channels() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select jsonb_build_object(
    'glitch',  (select jsonb_strip_nulls(jsonb_build_object('reports', count(*), 'first_at', min(created_at), 'last_at', max(created_at))) from public.founder_reports where kind = 'glitch'),
    'support', (select jsonb_strip_nulls(jsonb_build_object('reports', count(*), 'first_at', min(created_at), 'last_at', max(created_at))) from public.founder_reports where kind = 'support'))
$$;

-- ==============================================================================================================================
-- 11) RETENTION — solved/closed reports ki body + reporter 365 din baad mita di jati hai (record/history/ginti rehti hai, privacy ka bojh nahi)
-- ==============================================================================================================================
create or replace function public.founder_inbox_prune(p_keep interval default interval '365 days') returns jsonb
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '60s' as $$
declare n bigint;
begin
  if p_keep < interval '30 days' then raise exception 'retention bohat chhoti' using errcode = '22023'; end if;
  perform set_config('founder.inbox_redact', 'on', true);
  with d as (update public.founder_reports set body = '[removed by retention]', reporter_hash = repeat('0', 64)
              where status in ('solved', 'closed') and coalesce(solved_at, updated_at) < now() - p_keep and body <> '[removed by retention]' returning 1)
  select count(*) into n from d;
  perform set_config('founder.inbox_redact', 'off', true);
  return jsonb_build_object('redacted', n);
end $$;


-- ==============================================================================================================================
-- 11b) WATCH + RULES + WEEK — Dashboard "needs a look" ke liye, "yeh critical kyun?" ke jawab ke liye, aur hafta-ba-hafta moazna
-- ==============================================================================================================================
-- Jinki SLA toot chuki ya toot'ne wali hai (sab se bura pehle, max 20). Sirf title/page/ginti — body kabhi nahi.
create or replace function public.founder_inbox_sla_watch(p_limit integer default 20) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
  with w as (
    select g.id, g.kind, g.title, g.page, g.severity, g.affected,
           least(coalesce(min(r.respond_due_at) filter (where r.status = 'new' and r.first_response_at is null), 'infinity'::timestamptz),
                 coalesce(min(r.solve_due_at) filter (where r.status in ('new', 'open', 'waiting')), 'infinity'::timestamptz)) as due
      from public.founder_report_groups g join public.founder_reports r on r.group_id = g.id
     where g.status in ('new', 'open', 'waiting') group by g.id
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'title', title, 'page', page, 'severity', severity, 'affected', affected,
           'minutes_left', round(extract(epoch from (due - now())) / 60.0)::integer, 'state', case when due < now() then 'breached' else 'due_soon' end)
           order by due, public._fr_rank(severity) desc), '[]'::jsonb)
    from (select * from w where due < now() + interval '1 hour' order by due limit least(greatest(coalesce(p_limit, 20), 1), 100)) q
$$;

-- "Yeh critical kyun?" — UI rules dikha sakti hai (data se, code mein chhupa nahi).
create or replace function public.founder_inbox_rules() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select jsonb_build_object(
    'severity', (select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'pattern', pattern, 'severity', severity, 'note', note) order by public._fr_rank(severity) desc, pattern), '[]'::jsonb) from public.founder_report_severity_rules),
    'sla', (select coalesce(jsonb_agg(jsonb_build_object('severity', severity, 'respond_minutes', respond_minutes, 'solve_minutes', solve_minutes) order by public._fr_rank(severity) desc), '[]'::jsonb) from public.founder_report_sla),
    'transitions', (select coalesce(jsonb_agg(jsonb_build_object('from', from_status, 'to', to_status, 'needs_note', needs_note) order by from_status, to_status), '[]'::jsonb) from public.founder_report_transitions))
$$;

-- Is hafte (pichhle 7 din) vs pichhle se pehle hafte: naye masle, hal hue, median hal-waqt. Farq (delta) saath mein — "behtar hua ya bura?"
create or replace function public.founder_inbox_week() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare a_new bigint; b_new bigint; a_sol bigint; b_sol bigint; a_med numeric; b_med numeric;
begin
  select count(*) filter (where first_seen > now() - interval '7 days'), count(*) filter (where first_seen <= now() - interval '7 days' and first_seen > now() - interval '14 days')
    into a_new, b_new from public.founder_report_groups;
  select count(*) filter (where solved_at > now() - interval '7 days'), count(*) filter (where solved_at <= now() - interval '7 days' and solved_at > now() - interval '14 days'),
         percentile_cont(0.5) within group (order by extract(epoch from (solved_at - created_at)) / 60.0) filter (where solved_at > now() - interval '7 days'),
         percentile_cont(0.5) within group (order by extract(epoch from (solved_at - created_at)) / 60.0) filter (where solved_at <= now() - interval '7 days' and solved_at > now() - interval '14 days')
    into a_sol, b_sol, a_med, b_med from public.founder_reports where solved_at > now() - interval '14 days';
  return jsonb_strip_nulls(jsonb_build_object(
    'new_issues', jsonb_build_object('this_week', a_new, 'last_week', b_new, 'delta', a_new - b_new),
    'solved_reports', jsonb_build_object('this_week', a_sol, 'last_week', b_sol, 'delta', a_sol - b_sol),
    'median_solve_minutes', jsonb_build_object('this_week', round(a_med), 'last_week', round(b_med),
                                               'delta', case when a_med is not null and b_med is not null then round(a_med - b_med) end)));
end $$;


-- ==============================================================================================================================
-- 11c) SEARCH + TIMELINE + SNAPSHOT — dhoondna (title/page, body nahi), ek masle ki poori kahani, aur Rust ke liye EK hi jawab (ek round trip)
-- ==============================================================================================================================
-- Title/page mein lafz dhoondo (case-insensitive substring; % _ ko literal mana jata hai). Body mein kabhi nahi: list ki privacy wahi rehti hai.
create or replace function public.founder_inbox_search(p_q text, p_limit integer default 20) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare q text := btrim(coalesce(p_q, '')); pat text;
begin
  if length(q) < 2 or length(q) > 60 or q ~ '[[:cntrl:]]' then raise exception 'search lafz 2 se 60 akshar ka ho' using errcode = '22023'; end if;
  pat := '%' || replace(replace(replace(lower(q), E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_') || '%';
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'title', title, 'page', page, 'severity', severity, 'status', status, 'affected', affected, 'last_seen', last_seen) order by last_seen desc), '[]'::jsonb)
            from (select * from public.founder_report_groups where lower(title) like pat or lower(page) like pat order by last_seen desc limit least(greatest(coalesce(p_limit, 20), 1), 100)) x);
end $$;

-- Ek masle ki kahani waqt ke hisab se: aaya, jawab, hal, dobara khula — sirf events (note + kaun: founder ya system), body nahi.
create or replace function public.founder_inbox_timeline(p_group bigint) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
  select coalesce(jsonb_agg(jsonb_build_object('ts', e.ts, 'report_id', e.report_id, 'from', e.from_status, 'to', e.to_status, 'note', e.note, 'by', case when e.actor is null then 'system' else 'founder' end) order by e.id), '[]'::jsonb)
    from public.founder_report_events e join public.founder_reports r on r.id = e.report_id where r.group_id = p_group
$$;

-- Rust ke liye EK jawab: stats + SLA watch + hafta + channel saboot + chain ki sehat. Ek hissa fail ho to us ki jagah {"error": sqlstate}, baaqi salamat.
create or replace function public.founder_inbox_snapshot() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '15s' as $$
declare st jsonb; wt jsonb; wk jsonb; ch jsonb; bad bigint;
begin
  begin st := public.founder_inbox_stats(); exception when others then st := jsonb_build_object('error', sqlstate); end;
  begin wt := public.founder_inbox_sla_watch(10); exception when others then wt := jsonb_build_object('error', sqlstate); end;
  begin wk := public.founder_inbox_week(); exception when others then wk := jsonb_build_object('error', sqlstate); end;
  begin ch := public.founder_inbox_channels(); exception when others then ch := jsonb_build_object('error', sqlstate); end;
  begin bad := public.founder_report_verify(1); exception when others then bad := -1; end;
  return jsonb_build_object('stats', st, 'watch', wt, 'week', wk, 'channels', ch, 'chain', case when bad is null then jsonb_build_object('ok', true) else jsonb_build_object('ok', false, 'first_bad_id', bad) end);
end $$;

-- ==============================================================================================================================
-- 12) GRANTS — sirf service_role (Rust / awam backend). PUBLIC ko default execute milta hai: yahan saaf hataya jata hai.
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public._founder_report_events_guard()', 'public._founder_reports_guard()', 'public._fr_norm_page(text)', 'public._fr_clean(text,integer)',
    'public._fr_clean_body(text)', 'public._fr_hash(text,bigint,uuid,text,text,text,text)', 'public._fr_rank(text)', 'public._fr_bump(text)',
    'public._fr_severity(text,text,text)', 'public._fr_fingerprint(text,text,text)', 'public._fr_group_status(bigint)', 'public._fr_needs_note(text,text)',
    'public._fr_sla_state(timestamptz,timestamptz)', 'public.report_submit(text,text,text,text,text,text,numeric,text)',
    'public.founder_report_set(uuid,bigint,text,text)', 'public.founder_group_set(uuid,bigint,text,text)', 'public.founder_report_verify(bigint)',
    'public.founder_inbox_list(text,text,integer,integer)', 'public.founder_inbox_get(bigint)', 'public.founder_inbox_stats()',
    'public.founder_inbox_channels()', 'public.founder_inbox_prune(interval)', 'public.founder_inbox_sla_watch(integer)',
    'public.founder_inbox_rules()', 'public.founder_inbox_week()', 'public.founder_inbox_search(text,integer)',
    'public.founder_inbox_timeline(bigint)', 'public.founder_inbox_snapshot()'] loop
    if to_regprocedure(f) is null then raise exception 'E112 grant: function nahi bani: %', f; end if;
    execute format('revoke all on function %s from public, anon, authenticated', f);
    if f !~ '_guard' then execute format('grant execute on function %s to service_role', f); end if;
  end loop;
end $$;

-- ==============================================================================================================================
-- 13) SELFTEST — asli behaviour, aakhir mein POORA rollback (kuch persist nahi). Fail ho to saaf wajah ka text wapas.
-- ==============================================================================================================================
create or replace function public.founder_inbox_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_uid uuid; r jsonb; r2 jsonb; r3 jsonb; gid bigint; rid bigint; rid2 bigint; i integer; n integer; sn jsonb; lst jsonb; msg text := 'E112 selftest OK';
  h1 text := repeat('a', 64); h2 text := repeat('b', 64); h3 text := repeat('c', 64); hp text := repeat('d', 64);
begin
  if to_regclass('public.founder_reports') is null then return 'E112 selftest SKIP: E112 chalayein'; end if;
  select user_id into v_uid from public.founder_accounts limit 1;
  begin
    -- ---------- A) helpers ----------
    if public._fr_norm_page('/Billing/Checkout?x=1#top') <> '/billing/checkout' then raise exception 'norm_page query/fragment/case galat'; end if;
    if public._fr_norm_page('/orders/12345/view') <> '/orders/:id/view' then raise exception 'norm_page ginti ":id" nahi'; end if;
    if public._fr_norm_page('/u/123e4567-e89b-12d3-a456-426614174000') <> '/u/:id' then raise exception 'norm_page uuid ":id" nahi'; end if;
    if public._fr_norm_page('   ') <> '/' then raise exception 'norm_page khali "/" nahi'; end if;
    begin perform public._fr_clean('mail a@b.com', 50); raise exception 'clean email par ruka nahi'; exception when sqlstate '22023' then null; end;
    begin perform public._fr_clean(repeat('x', 200), 50); raise exception 'clean lambai par ruka nahi'; exception when sqlstate '22023' then null; end;
    begin perform public._fr_clean_body('abc'); raise exception 'chhoti body chal gayi'; exception when sqlstate '22023' then null; end;
    begin perform public._fr_clean_body('hello' || chr(1) || 'world'); raise exception 'control char body chal gayi'; exception when sqlstate '22023' then null; end;
    if public._fr_clean_body('mera mail a@b.com hai, login nahi chal raha') is null then raise exception 'body mein email theek honi chahiye (sirf founder padhta hai)'; end if;
    if public._fr_bump('low') <> 'normal' or public._fr_bump('high') <> 'critical' or public._fr_bump('critical') <> 'critical' then raise exception 'bump galat'; end if;
    if public._fr_severity('glitch', '/checkout', 'button dead') <> 'critical' then raise exception 'checkout critical nahi'; end if;
    if public._fr_severity('support', '/help', 'I want a refund') <> 'high' then raise exception 'refund high nahi'; end if;
    if public._fr_severity('support', '/help', 'how do I change theme') <> 'normal' then raise exception 'aam sawal normal nahi'; end if;
    if public._fr_severity('glitch', '/mail', 'x y z') <> 'high' then raise exception 'glitch mail high nahi'; end if;
    if public._fr_severity('support', '/mail', 'x y z') <> 'normal' then raise exception 'glitch-only rule support par lag gaya'; end if;

    -- ---------- B) submit: validation ----------
    begin perform public.report_submit('bogus', '/x', 'title here', 'body text here', h1); raise exception 'galat kind chal gayi'; exception when sqlstate '22023' then null; end;
    begin perform public.report_submit('glitch', '/x', 'title here', 'body text here', 'short'); raise exception 'galat hash chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.report_submit('glitch', '/x', 'a@b.com broke', 'body text here', h1); raise exception 'title mein email chal gayi'; exception when sqlstate '22023' then null; end;
    begin perform public.report_submit('glitch', '/x', 'title here', 'body text here', h1, 'galaxy'); raise exception 'galat plan chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.report_submit('glitch', '/x', 'title here', 'body text here', h1, null, -5); raise exception 'manfi mrr chal gayi'; exception when sqlstate '22023' then null; end;

    -- ---------- C) submit: dedup + severity + SLA ----------
    r := public.report_submit('glitch', '/Checkout?a=1', 'Pay button dead', 'Pay button does nothing when I click it', h1, 'free');
    if r ->> 'severity' <> 'critical' or (r ->> 'new_group')::boolean is not true or (r ->> 'affected')::int <> 1 then raise exception 'pehli report galat: %', r; end if;
    gid := (r ->> 'group_id')::bigint; rid := (r ->> 'report_id')::bigint;
    if (select respond_due_at - created_at from public.founder_reports where id = rid) <> interval '30 minutes' then raise exception 'critical respond SLA 30 minute nahi'; end if;
    if (select solve_due_at - created_at from public.founder_reports where id = rid) <> interval '240 minutes' then raise exception 'critical solve SLA 240 minute nahi'; end if;
    r2 := public.report_submit('glitch', '/checkout', 'pay  BUTTON dead', 'Same here, nothing happens on pay', h2, 'pro', 49);
    if (r2 ->> 'group_id')::bigint <> gid or (r2 ->> 'new_group')::boolean is not false or (r2 ->> 'affected')::int <> 2 then raise exception 'dedup nahi hua (naya user): %', r2; end if;
    rid2 := (r2 ->> 'report_id')::bigint;
    r3 := public.report_submit('glitch', '/checkout', 'Pay button dead', 'I tried again and it is still dead for me', h1);
    if (r3 ->> 'affected')::int <> 2 then raise exception 'wahi user dobara: affected nahi badhna chahiye: %', r3; end if;
    r3 := public.report_submit('support', '/help', 'Question about theme', 'How do I change the theme colour please', h3, 'pro', 49);
    if r3 ->> 'severity' <> 'high' then raise exception 'paying + normal => high hona chahiye (bump): %', r3; end if;
    if (select count(*) from public.founder_report_groups where id = gid) <> 1 then raise exception 'group ek hona chahiye'; end if;
    if (select count(*) from public.founder_report_events where report_id in (rid, rid2)) <> 2 then raise exception 'har report ka "created" event hona chahiye'; end if;

    -- ---------- D) rate limit (10 minute mein 5) ----------
    for i in 1..4 loop perform public.report_submit('support', '/help', 'Spam test ' || i, 'spam spam spam ' || i, hp); end loop;
    perform public.report_submit('support', '/help', 'Spam test 5', 'spam spam spam five', hp);
    begin perform public.report_submit('support', '/help', 'Spam test 6', 'spam spam spam six', hp); raise exception 'rate limit nahi laga';
    exception when sqlstate '54000' then null; end;

    -- ---------- E) chain ----------
    if public.founder_report_verify(1) is not null then raise exception 'chain saaf honi chahiye'; end if;
    begin update public.founder_report_events set note = 'tamper note here' where report_id = rid; raise exception 'history UPDATE chal gaya'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_report_events where report_id = rid; raise exception 'history DELETE chal gaya'; exception when sqlstate '42501' then null; end;
    begin truncate public.founder_report_events; raise exception 'history TRUNCATE chal gaya'; exception when sqlstate '42501' then null; end;
    begin update public.founder_reports set body = 'badli hui body yahan' where id = rid; raise exception 'body UPDATE chal gaya'; exception when sqlstate '42501' then null; end;
    begin update public.founder_reports set reporter_hash = h3 where id = rid; raise exception 'reporter UPDATE chal gaya'; exception when sqlstate '42501' then null; end;

    -- ---------- F) founder badlav + group_set ----------
    begin perform public.founder_report_set('00000000-0000-0000-0000-000000000000', rid, 'open', null); raise exception 'bina founder ke chal gaya'; exception when sqlstate '42501' then null; end;
    if v_uid is not null then
      begin perform public.founder_report_set(v_uid, rid, 'solved', 'fixed it'); raise exception 'new -> solved najaiz hai'; exception when sqlstate '22023' then null; end;
      r := public.founder_report_set(v_uid, rid, 'open', null);
      if (select first_response_at from public.founder_reports where id = rid) is null then raise exception 'first_response_at likha nahi'; end if;
      begin perform public.founder_report_set(v_uid, rid, 'open', null); raise exception 'same-status chal gaya'; exception when sqlstate '22023' then null; end;
      begin perform public.founder_report_set(v_uid, rid, 'solved', 'short'); raise exception 'chhota note chal gaya'; exception when sqlstate '22023' then null; end;
      r := public.founder_report_set(v_uid, rid, 'solved', 'Pay button fixed in release');
      if (select solved_at from public.founder_reports where id = rid) is null then raise exception 'solved_at likha nahi'; end if;
      r := public.founder_report_set(v_uid, rid, 'open', 'reopened: still failing for one user');
      if (select solved_at from public.founder_reports where id = rid) is not null then raise exception 'reopen par solved_at saaf nahi hua'; end if;
      r := public.founder_group_set(v_uid, gid, 'open', null);
      if (r ->> 'changed')::int <> 2 then raise exception 'group_set: 2 baaki thi (dusri aur teesri new): %', r; end if;
      r := public.founder_group_set(v_uid, gid, 'solved', 'Fixed for everyone in release 42');
      if (r ->> 'changed')::int <> 3 or (select status from public.founder_report_groups where id = gid) <> 'solved' then raise exception 'group solved nahi hua: %', r; end if;
      if (select count(*) from public.founder_report_groups where id = gid and status = 'solved') <> 1 then raise exception 'group status derive galat'; end if;
      if public.founder_report_verify(1) is not null then raise exception 'founder badlav ke baad chain saaf honi chahiye'; end if;
      -- regression: solved masle par naya user => group dobara new
      r := public.report_submit('glitch', '/checkout', 'Pay button dead', 'It is broken again after the update', repeat('e', 64), null);
      if (select status from public.founder_report_groups where id = gid) <> 'new' or (r ->> 'affected')::int <> 3 then raise exception 'regression par group dobara new + affected 3 hona chahiye: %', r; end if;
    end if;

    -- ---------- G) list / get / stats ----------
    lst := public.founder_inbox_list('active', null, 50, 0);
    if lst::text ~ '(reporter|body|aaaaaaaa)' then raise exception 'list mein body/reporter nahi aana chahiye'; end if;
    if (lst ->> 'total')::int < 1 then raise exception 'list khali'; end if;
    if lst -> 'groups' -> 0 ->> 'severity' <> 'critical' and v_uid is null then raise exception 'critical sab se upar nahi'; end if;
    begin perform public.founder_inbox_list('bogus'); raise exception 'galat status chal gaya'; exception when sqlstate '22023' then null; end;
    sn := public.founder_inbox_get(gid);
    if (sn -> 'reports' -> 0 ->> 'body') is null then raise exception 'get mein body honi chahiye (sirf yahan)'; end if;
    if sn::text ~ 'reporter_hash' then raise exception 'get mein reporter_hash nahi aana chahiye'; end if;
    begin perform public.founder_inbox_get(-1); raise exception 'galat group chal gaya'; exception when sqlstate 'P0002' then null; end;
    sn := public.founder_inbox_stats();
    if not (sn ? 'level' and sn ? 'daily_7d' and sn ? 'worst_pages_7d' and sn ? 'active') then raise exception 'stats keys kam: %', sn; end if;
    if jsonb_array_length(sn -> 'daily_7d') <> 7 then raise exception 'daily 7 din nahi'; end if;
    if (public.founder_inbox_channels() -> 'glitch' ->> 'reports')::int < 3 then raise exception 'channel evidence ginti galat'; end if;
    if not exists (select 1 from public.founder_live_sources where key = 'user_reports') then raise exception 'live source register nahi'; end if;

    -- ---------- G2) watch / rules / week ----------
    if jsonb_typeof(public.founder_inbox_sla_watch(5)) <> 'array' then raise exception 'sla_watch array nahi'; end if;
    if jsonb_array_length(public.founder_inbox_rules() -> 'sla') <> 4 then raise exception 'rules mein 4 SLA hone chahiye'; end if;
    if (public.founder_inbox_week() -> 'new_issues' ->> 'this_week')::int < 1 then raise exception 'week: is hafte ke naye masle >= 1'; end if;

    -- ---------- G3) search / timeline / snapshot ----------
    if jsonb_array_length(public.founder_inbox_search('pay button', 10)) < 1 then raise exception 'search ne title nahi dhoondha'; end if;
    if jsonb_array_length(public.founder_inbox_search('100%_zzz', 10)) <> 0 then raise exception 'search percent underscore literal nahi'; end if;
    if jsonb_array_length(public.founder_inbox_search('mera mail', 10)) <> 0 then raise exception 'search ne body mein dhoonda (privacy)'; end if;
    begin perform public.founder_inbox_search('x'); raise exception 'chhota search chal gaya'; exception when sqlstate '22023' then null; end;
    if jsonb_array_length(public.founder_inbox_timeline(gid)) < 3 then raise exception 'timeline mein events kam'; end if;
    sn := public.founder_inbox_snapshot();
    if not (sn ? 'stats' and sn ? 'watch' and sn ? 'week' and sn ? 'channels' and sn -> 'chain' ->> 'ok' = 'true') then raise exception 'snapshot keys/chain galat: %', sn; end if;

    -- ---------- H) retention ----------
    if v_uid is not null then
      update public.founder_reports set solved_at = now() - interval '400 days' where id = rid2 and status = 'solved';
      r := public.founder_inbox_prune(interval '365 days');
      if (r ->> 'redacted')::int < 1 then raise exception 'prune ne purani solved body nahi mitai: %', r; end if;
      if (select body from public.founder_reports where id = rid2) <> '[removed by retention]' then raise exception 'body redact nahi hui'; end if;
      if (select reporter_hash from public.founder_reports where id = rid2) <> repeat('0', 64) then raise exception 'reporter redact nahi hua'; end if;
      begin perform public.founder_inbox_prune(interval '1 day'); raise exception 'chhoti retention chal gayi'; exception when sqlstate '22023' then null; end;
    end if;

    raise exception 'E112_ROLLBACK_OK';
  exception when others then
    if sqlerrm = 'E112_ROLLBACK_OK' then msg := 'E112 selftest OK' || case when v_uid is null then ' (founder nahi mila: founder-badlav hissa SKIP)' else '' end;
    else msg := 'E112 selftest FAIL: ' || sqlerrm; end if;
  end;
  return msg;
end $$;
revoke all on function public.founder_inbox_selftest() from public, anon, authenticated;
grant execute on function public.founder_inbox_selftest() to service_role;

do $$ begin raise notice 'E112 founder inbox tayyar. Chalao: CHECK_E112.sql'; end $$;
