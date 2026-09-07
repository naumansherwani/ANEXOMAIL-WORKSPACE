-- ============================================================================
-- ANEXOCHAT · PHASE 24 — DECISION LEDGER  +  DECISION IMPACT MAP
--
--   "Migration Friday at 02:00." → Mark as Decision →
--   DECISION: Migration · Friday · 02:00 · Made by Sarah ·
--   Timestamp 13:42 UTC · Source ANEXOChat
--
--   DECISION Migration Friday 02:00 UTC
--     ↓ affects Task: DNS verification
--     ↓ affects Promise: Customer confirmation
--     ↓ affects Cutover: Friday 02:00 UTC
--
-- Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
-- Har naya public table par GRANT pehle, phir RLS, phir policy.
--
-- LOCK (non-negotiable):
--   1. Ek decision hamesha ek ASLI message se banti hai — maker, UTC timestamp,
--      source conversation aur `body_hash` provenance ke saath. Bina message
--      koi decision nahi (`message_required`).
--   2. HISTORY KABHI OVERWRITE NAHI. Har tabdeeli = `chat_decision_versions`
--      mein NAYA row (version+1); purana version hamesha zinda rehta hai.
--      Table par sirf INSERT/SELECT — update/delete trigger se band.
--   3. Impact map sirf ASLI link se banta hai (`chat_decision_links`) — engine
--      khud kabhi dependency invent nahi karti. "Potentially affected" alag
--      khaana hai, saaf label `derived` ke saath, aur woh kabhi link nahi banta.
--   4. Link banana/hatana insaani + 8+ char reason; ledger
--      `chat_decision_impact_log` append-only.
--   5. Amend / supersede / reverse insaani + 12+ char reason. Reverse purani
--      decision ko mitata nahi — nayi state likhta hai.
--   6. Sab kuch DETERMINISTIC — insaani guftagu kisi AI API par nahi jati.
--   7. No duplicate: Phase 3 ka `chat_work_items` (kind='decision') bhi zinda
--      rehta hai; yeh ledger uske OOPAR provenance + versions + impact hai,
--      aur work item se link ho jata hai.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'decision_ledger', false, null, 'ANEXOChat included nahi'),
  ('pro',          'decision_ledger', false, null, 'ANEXOChat included nahi'),
  ('business',     'decision_ledger', true,  null, 'mark decision · versions · append-only ledger'),
  ('business_pro', 'decision_ledger', true,  null, null),
  ('ai_pro',       'decision_ledger', true,  null, null),
  ('ai_business',  'decision_ledger', true,  null, null),
  ('ai_executive', 'decision_ledger', true,  null, null),
  ('founder',      'decision_ledger', true,  null, null),

  ('basic',        'decision_impact', false, null, null),
  ('pro',          'decision_impact', false, null, null),
  ('business',     'decision_impact', false, null, 'impact map Business Pro se'),
  ('business_pro', 'decision_impact', true,  null, 'affected tasks/promises/files + potentially affected'),
  ('ai_pro',       'decision_impact', false, null, null),
  ('ai_business',  'decision_impact', true,  null, null),
  ('ai_executive', 'decision_impact', true,  null, null),
  ('founder',      'decision_impact', true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ---------------------------------------------------------------------------
-- 1) self-healing: purani shape ho to `_legacy` rename
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='chat_decisions')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='chat_decisions'
                and column_name='body_hash') then
    execute 'alter table public.chat_decisions rename to chat_decisions_legacy';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) decision head — current state; poori history versions table mein
-- ---------------------------------------------------------------------------
create table if not exists public.chat_decisions (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  message_id      uuid not null references public.chat_messages(id) on delete restrict,
  work_item_id    uuid references public.chat_work_items(id) on delete set null,
  title           text not null,
  detail          text,
  decided_at      timestamptz not null,              -- faisla kab hua (UTC)
  made_by         uuid not null references auth.users(id) on delete restrict,
  recorded_by     uuid not null references auth.users(id) on delete restrict,
  source          text not null default 'anexochat'
                  check (source in ('anexochat','anexomail')),
  body_hash       text not null,                     -- provenance: message hide ho to bhi zinda
  version         int  not null default 1,
  state           text not null default 'active'
                  check (state in ('active','superseded','reversed')),
  superseded_by   uuid references public.chat_decisions(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists chat_decisions_ws_idx
  on public.chat_decisions (workspace_id, decided_at desc);
create index if not exists chat_decisions_conv_idx
  on public.chat_decisions (conversation_id, decided_at desc);
create unique index if not exists chat_decisions_message_uidx
  on public.chat_decisions (message_id);

grant select on public.chat_decisions to authenticated;
grant all on public.chat_decisions to service_role;

alter table public.chat_decisions enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='chat_decisions' and policyname='decision read') then
    create policy "decision read" on public.chat_decisions
      for select to authenticated
      using (public.chat_in_conversation(conversation_id, auth.uid()));
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) versions — APPEND ONLY. Ek bhi purana version kabhi nahi badalta.
-- ---------------------------------------------------------------------------
create table if not exists public.chat_decision_versions (
  id          bigserial primary key,
  decision_id uuid not null references public.chat_decisions(id) on delete cascade,
  version     int  not null,
  title       text not null,
  detail      text,
  decided_at  timestamptz not null,
  state       text not null,
  changed_by  uuid references auth.users(id) on delete set null,
  change      text not null check (change in ('recorded','amended','superseded','reversed')),
  reason      text,
  at          timestamptz not null default now(),
  unique (decision_id, version)
);
create index if not exists chat_decision_versions_idx
  on public.chat_decision_versions (decision_id, version desc);

grant select on public.chat_decision_versions to authenticated;
grant all on public.chat_decision_versions to service_role;
grant usage, select on sequence public.chat_decision_versions_id_seq to service_role;

alter table public.chat_decision_versions enable row level security;
do $$
begin
  -- sirf SELECT policy: koi update/delete raasta nahi
  if not exists (select 1 from pg_policies
                  where tablename='chat_decision_versions' and policyname='decision version read') then
    create policy "decision version read" on public.chat_decision_versions
      for select to authenticated using (exists (
        select 1 from public.chat_decisions d
         where d.id = decision_id
           and public.chat_in_conversation(d.conversation_id, auth.uid())));
  end if;
end $$;

create or replace function public.chat_decision_versions_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'decision_history_is_append_only';
end $$;

drop trigger if exists chat_decision_versions_no_update on public.chat_decision_versions;
create trigger chat_decision_versions_no_update
  before update or delete on public.chat_decision_versions
  for each row execute function public.chat_decision_versions_immutable();

-- ---------------------------------------------------------------------------
-- 4) impact map — sirf ASLI links (engine kuch invent nahi karti)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_decision_links (
  id            uuid primary key default gen_random_uuid(),
  decision_id   uuid not null references public.chat_decisions(id) on delete cascade,
  object_type   text not null check (object_type in
                  ('task','promise','decision','conversation','file','message')),
  object_id     uuid not null,
  relation      text not null default 'affects'
                check (relation in ('affects','depends_on','supersedes','evidence')),
  note          text,
  linked_by     uuid not null references auth.users(id) on delete restrict,
  link_reason   text not null,
  created_at    timestamptz not null default now(),
  removed_at    timestamptz,
  removed_by    uuid references auth.users(id) on delete set null,
  remove_reason text
);
create unique index if not exists chat_decision_links_uidx
  on public.chat_decision_links (decision_id, object_type, object_id, relation)
  where removed_at is null;
create index if not exists chat_decision_links_obj_idx
  on public.chat_decision_links (object_type, object_id);

grant select on public.chat_decision_links to authenticated;
grant all on public.chat_decision_links to service_role;

alter table public.chat_decision_links enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='chat_decision_links' and policyname='decision link read') then
    create policy "decision link read" on public.chat_decision_links
      for select to authenticated using (exists (
        select 1 from public.chat_decisions d
         where d.id = decision_id
           and public.chat_in_conversation(d.conversation_id, auth.uid())));
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5) append-only impact ledger
-- ---------------------------------------------------------------------------
create table if not exists public.chat_decision_impact_log (
  id          bigserial primary key,
  decision_id uuid not null references public.chat_decisions(id) on delete cascade,
  actor_id    uuid references auth.users(id) on delete set null,
  event       text not null check (event in
                ('recorded','amended','superseded','reversed',
                 'link_added','link_removed','impact_reviewed')),
  reason      text,
  prev        jsonb not null default '{}'::jsonb,
  next        jsonb not null default '{}'::jsonb,
  at          timestamptz not null default now()
);
create index if not exists chat_decision_impact_log_idx
  on public.chat_decision_impact_log (decision_id, id desc);

grant select on public.chat_decision_impact_log to authenticated;
grant all on public.chat_decision_impact_log to service_role;
grant usage, select on sequence public.chat_decision_impact_log_id_seq to service_role;

alter table public.chat_decision_impact_log enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='chat_decision_impact_log' and policyname='decision log read') then
    create policy "decision log read" on public.chat_decision_impact_log
      for select to authenticated using (exists (
        select 1 from public.chat_decisions d
         where d.id = decision_id
           and public.chat_in_conversation(d.conversation_id, auth.uid())));
  end if;
end $$;

create or replace function public.chat_decision_log_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'decision_ledger_is_append_only';
end $$;

drop trigger if exists chat_decision_impact_log_no_update on public.chat_decision_impact_log;
create trigger chat_decision_impact_log_no_update
  before update or delete on public.chat_decision_impact_log
  for each row execute function public.chat_decision_log_immutable();

-- ---------------------------------------------------------------------------
-- 6) mark as decision — provenance ke saath, ASLI message se
-- ---------------------------------------------------------------------------
create or replace function public.decision_mark(
  _user uuid, _message uuid, _title text default null,
  _detail text default null, _decided_at timestamptz default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  m record; v_id uuid; v_hash text; v_title text; v_when timestamptz; v_work uuid;
begin
  if not public.chat_feature_allowed(_user, 'decision_ledger') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;
  if _message is null then
    return jsonb_build_object('ok', false, 'error', 'message_required',
      'message', 'Ek decision hamesha ek asli message se banti hai.');
  end if;

  select id, conversation_id, workspace_id, sender_user_id, body, created_at
    into m from public.chat_messages where id = _message;
  if m.id is null then
    return jsonb_build_object('ok', false, 'error', 'message_not_found');
  end if;
  if not public.chat_in_conversation(m.conversation_id, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;

  select id into v_id from public.chat_decisions where message_id = _message;
  if v_id is not null then
    return jsonb_build_object('ok', false, 'error', 'already_a_decision', 'decision_id', v_id);
  end if;

  v_title := nullif(btrim(coalesce(_title, '')), '');
  if v_title is null then
    v_title := left(regexp_replace(m.body, '\s+', ' ', 'g'), 180);
  end if;
  v_when := coalesce(_decided_at, m.created_at);
  v_hash := encode(digest(m.body, 'sha256'), 'hex');

  -- Phase 3 work item (kind='decision') bhi banao — no duplicate, sirf link
  begin
    insert into public.chat_work_items
      (workspace_id, conversation_id, message_id, kind, title, owner_user_id, created_by)
    values (m.workspace_id, m.conversation_id, m.id, 'decision', v_title,
            m.sender_user_id, _user)
    returning id into v_work;
  exception when others then v_work := null;
  end;

  insert into public.chat_decisions
    (workspace_id, conversation_id, message_id, work_item_id, title, detail,
     decided_at, made_by, recorded_by, body_hash)
  values (m.workspace_id, m.conversation_id, m.id, v_work, v_title,
          nullif(btrim(coalesce(_detail, '')), ''), v_when, m.sender_user_id, _user, v_hash)
  returning id into v_id;

  insert into public.chat_decision_versions
    (decision_id, version, title, detail, decided_at, state, changed_by, change, reason)
  values (v_id, 1, v_title, nullif(btrim(coalesce(_detail, '')), ''), v_when,
          'active', _user, 'recorded', null);

  insert into public.chat_decision_impact_log (decision_id, actor_id, event, next)
  values (v_id, _user, 'recorded', jsonb_build_object(
    'title', v_title, 'decided_at', v_when, 'made_by', m.sender_user_id,
    'source', 'anexochat', 'body_hash', v_hash));

  return jsonb_build_object('ok', true, 'decision_id', v_id, 'work_item_id', v_work,
    'title', v_title, 'decided_at', v_when, 'made_by', m.sender_user_id, 'body_hash', v_hash);
end $$;

-- ---------------------------------------------------------------------------
-- 7) amend / supersede / reverse — history NAYE row se, purana zinda
-- ---------------------------------------------------------------------------
create or replace function public.decision_amend(
  _decision uuid, _user uuid, _reason text, _change text default 'amended',
  _title text default null, _detail text default null,
  _decided_at timestamptz default null, _superseded_by uuid default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare d record; v_new int; v_title text; v_detail text; v_when timestamptz; v_state text;
begin
  if not public.chat_feature_allowed(_user, 'decision_ledger') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;
  if _change not in ('amended','superseded','reversed') then
    return jsonb_build_object('ok', false, 'error', 'bad_change');
  end if;
  if _reason is null or length(btrim(_reason)) < 12 then
    return jsonb_build_object('ok', false, 'error', 'reason_required',
      'message', 'Har tabdeeli 12+ character wajah ke saath likhi jati hai.');
  end if;

  select * into d from public.chat_decisions where id = _decision;
  if d.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.chat_in_conversation(d.conversation_id, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;

  v_title  := coalesce(nullif(btrim(coalesce(_title, '')), ''), d.title);
  v_detail := coalesce(nullif(btrim(coalesce(_detail, '')), ''), d.detail);
  v_when   := coalesce(_decided_at, d.decided_at);
  v_state  := case _change when 'amended' then 'active'
                           when 'superseded' then 'superseded'
                           else 'reversed' end;
  v_new    := d.version + 1;

  -- history: NAYA row (purana version kabhi overwrite nahi hota)
  insert into public.chat_decision_versions
    (decision_id, version, title, detail, decided_at, state, changed_by, change, reason)
  values (_decision, v_new, v_title, v_detail, v_when, v_state, _user, _change, btrim(_reason));

  update public.chat_decisions
     set title = v_title, detail = v_detail, decided_at = v_when,
         state = v_state, version = v_new,
         superseded_by = coalesce(_superseded_by, superseded_by),
         updated_at = now()
   where id = _decision;

  insert into public.chat_decision_impact_log (decision_id, actor_id, event, reason, prev, next)
  values (_decision, _user, _change, btrim(_reason),
    jsonb_build_object('version', d.version, 'title', d.title, 'detail', d.detail,
                       'decided_at', d.decided_at, 'state', d.state),
    jsonb_build_object('version', v_new, 'title', v_title, 'detail', v_detail,
                       'decided_at', v_when, 'state', v_state));

  return jsonb_build_object('ok', true, 'decision_id', _decision, 'version', v_new,
    'state', v_state, 'previous_version', d.version);
end $$;

-- ---------------------------------------------------------------------------
-- 8) impact links — insaani, reason ke saath, kabhi khud-saakhta nahi
-- ---------------------------------------------------------------------------
create or replace function public.decision_link(
  _decision uuid, _user uuid, _object_type text, _object_id uuid,
  _reason text, _relation text default 'affects', _note text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare d record; v_id uuid;
begin
  if not public.chat_feature_allowed(_user, 'decision_impact') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;
  if _object_type not in ('task','promise','decision','conversation','file','message') then
    return jsonb_build_object('ok', false, 'error', 'bad_object_type');
  end if;
  if _reason is null or length(btrim(_reason)) < 8 then
    return jsonb_build_object('ok', false, 'error', 'reason_required',
      'message', 'Link bina 8+ character wajah ke nahi banta.');
  end if;

  select * into d from public.chat_decisions where id = _decision;
  if d.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.chat_in_conversation(d.conversation_id, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;

  -- object asli hona chahiye
  if _object_type in ('task','promise') then
    if not exists (select 1 from public.chat_work_items w
                    where w.id = _object_id and w.kind = _object_type) then
      return jsonb_build_object('ok', false, 'error', 'object_not_found');
    end if;
  elsif _object_type = 'decision' then
    if not exists (select 1 from public.chat_decisions x where x.id = _object_id) then
      return jsonb_build_object('ok', false, 'error', 'object_not_found');
    end if;
  elsif _object_type = 'conversation' then
    if not exists (select 1 from public.chat_conversations c where c.id = _object_id) then
      return jsonb_build_object('ok', false, 'error', 'object_not_found');
    end if;
  elsif _object_type = 'file' then
    if not exists (select 1 from public.chat_files f where f.id = _object_id) then
      return jsonb_build_object('ok', false, 'error', 'object_not_found');
    end if;
  else
    if not exists (select 1 from public.chat_messages g where g.id = _object_id) then
      return jsonb_build_object('ok', false, 'error', 'object_not_found');
    end if;
  end if;

  insert into public.chat_decision_links
    (decision_id, object_type, object_id, relation, note, linked_by, link_reason)
  values (_decision, _object_type, _object_id, coalesce(_relation, 'affects'),
          nullif(btrim(coalesce(_note, '')), ''), _user, btrim(_reason))
  on conflict do nothing
  returning id into v_id;

  if v_id is null then
    return jsonb_build_object('ok', false, 'error', 'already_linked');
  end if;

  insert into public.chat_decision_impact_log (decision_id, actor_id, event, reason, next)
  values (_decision, _user, 'link_added', btrim(_reason),
    jsonb_build_object('object_type', _object_type, 'object_id', _object_id,
                       'relation', coalesce(_relation, 'affects')));

  return jsonb_build_object('ok', true, 'link_id', v_id);
end $$;

create or replace function public.decision_unlink(
  _link uuid, _user uuid, _reason text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare l record; d record;
begin
  if _reason is null or length(btrim(_reason)) < 8 then
    return jsonb_build_object('ok', false, 'error', 'reason_required');
  end if;
  select * into l from public.chat_decision_links where id = _link;
  if l.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if l.removed_at is not null then
    return jsonb_build_object('ok', false, 'error', 'already_removed');
  end if;
  select * into d from public.chat_decisions where id = l.decision_id;
  if not public.chat_in_conversation(d.conversation_id, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;

  -- link row rehta hai (record kabhi delete nahi) — sirf removed mark hota hai
  update public.chat_decision_links
     set removed_at = now(), removed_by = _user, remove_reason = btrim(_reason)
   where id = _link;

  insert into public.chat_decision_impact_log (decision_id, actor_id, event, reason, prev)
  values (l.decision_id, _user, 'link_removed', btrim(_reason),
    jsonb_build_object('object_type', l.object_type, 'object_id', l.object_id,
                       'relation', l.relation));

  return jsonb_build_object('ok', true, 'link_id', _link);
end $$;

-- ---------------------------------------------------------------------------
-- 9) impact map — asli affects + saaf-labelled "potentially affected"
-- ---------------------------------------------------------------------------
create or replace function public.decision_impact(_decision uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare d record; v_allowed boolean;
begin
  select * into d from public.chat_decisions where id = _decision;
  if d.id is null then return jsonb_build_object('error', 'not_found'); end if;
  if not public.chat_in_conversation(d.conversation_id, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;
  v_allowed := public.chat_feature_allowed(_user, 'decision_impact');

  return jsonb_build_object(
    'decision_id', d.id,
    'title', d.title,
    'state', d.state,
    'version', d.version,
    'decided_at', d.decided_at,
    'impact_allowed', v_allowed,
    'engine_invents_links', false,
    -- ASLI links: kisi insaan ne reason ke saath banaye
    'affects', case when not v_allowed then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
        'link_id', l.id, 'object_type', l.object_type, 'object_id', l.object_id,
        'relation', l.relation, 'note', l.note,
        'link_reason', l.link_reason, 'linked_at', l.created_at,
        'label', case l.object_type
          when 'task'     then (select w.title from public.chat_work_items w where w.id = l.object_id)
          when 'promise'  then (select w.title from public.chat_work_items w where w.id = l.object_id)
          when 'decision' then (select x.title from public.chat_decisions x where x.id = l.object_id)
          when 'file'     then (select f.filename from public.chat_files f where f.id = l.object_id)
          when 'conversation' then (select c.title from public.chat_conversations c where c.id = l.object_id)
          else (select left(g.body, 120) from public.chat_messages g where g.id = l.object_id)
        end,
        'object_state', case l.object_type
          when 'task'    then (select w.state from public.chat_work_items w where w.id = l.object_id)
          when 'promise' then (select public.promise_state_of(w.state, w.due_at, w.completed_at, w.original_due_at)
                                 from public.chat_work_items w where w.id = l.object_id)
          when 'decision' then (select x.state from public.chat_decisions x where x.id = l.object_id)
          when 'file'    then (select f.state from public.chat_files f where f.id = l.object_id)
          else null end,
        'due_at', case when l.object_type in ('task','promise')
          then (select w.due_at from public.chat_work_items w where w.id = l.object_id) else null end)
        order by l.created_at)
        from public.chat_decision_links l
       where l.decision_id = _decision and l.removed_at is null), '[]'::jsonb) end,
    -- POTENTIALLY affected: sirf isi conversation ke khule kaam, koi link nahi bana
    'potentially_affected', case when not v_allowed then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
        'object_type', w.kind, 'object_id', w.id, 'label', w.title,
        'object_state', w.state, 'due_at', w.due_at,
        'derived_from', 'same_conversation', 'linked', false)
        order by (w.due_at is null), w.due_at)
        from public.chat_work_items w
       where w.conversation_id = d.conversation_id
         and w.kind in ('task','promise')
         and w.state not in ('done','cancelled')
         and not exists (select 1 from public.chat_decision_links l
                          where l.decision_id = _decision and l.removed_at is null
                            and l.object_id = w.id)), '[]'::jsonb) end,
    'removed_links', coalesce((
      select jsonb_agg(jsonb_build_object('object_type', l.object_type, 'object_id', l.object_id,
        'remove_reason', l.remove_reason, 'removed_at', l.removed_at) order by l.removed_at desc)
        from public.chat_decision_links l
       where l.decision_id = _decision and l.removed_at is not null), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------
-- 10) ek decision ka poora sach: head + versions + impact + ledger
-- ---------------------------------------------------------------------------
create or replace function public.decision_state(_decision uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare d record;
begin
  select * into d from public.chat_decisions where id = _decision;
  if d.id is null then return jsonb_build_object('error', 'not_found'); end if;
  if not public.chat_in_conversation(d.conversation_id, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;

  return jsonb_build_object(
    'decision', jsonb_build_object(
      'id', d.id, 'title', d.title, 'detail', d.detail, 'state', d.state,
      'version', d.version, 'decided_at', d.decided_at,
      'made_by', d.made_by,
      'made_by_email', (select u.email from auth.users u where u.id = d.made_by),
      'recorded_by', d.recorded_by, 'recorded_at', d.created_at,
      'source', d.source, 'conversation_id', d.conversation_id,
      'message_id', d.message_id, 'work_item_id', d.work_item_id,
      'body_hash', d.body_hash,
      'message_visible', exists (select 1 from public.chat_messages g
                                  where g.id = d.message_id and g.deleted_at is null),
      'superseded_by', d.superseded_by),
    'history', coalesce((
      select jsonb_agg(jsonb_build_object(
        'version', v.version, 'title', v.title, 'detail', v.detail,
        'decided_at', v.decided_at, 'state', v.state, 'change', v.change,
        'reason', v.reason, 'changed_by', v.changed_by, 'at', v.at)
        order by v.version desc)
        from public.chat_decision_versions v where v.decision_id = _decision), '[]'::jsonb),
    'impact', public.decision_impact(_decision, _user),
    'ledger', coalesce((
      select jsonb_agg(jsonb_build_object('event', l.event, 'reason', l.reason,
        'prev', l.prev, 'next', l.next, 'actor_id', l.actor_id, 'at', l.at)
        order by l.id desc)
        from (select * from public.chat_decision_impact_log
               where decision_id = _decision order by id desc limit 50) l), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------
-- 11) decision ledger board (workspace)
-- ---------------------------------------------------------------------------
create or replace function public.decision_board(_user uuid, _conversation uuid default null)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from public.chat_members where user_id = _user limit 1;
  if v_ws is null then
    return jsonb_build_object('plan', public.chat_feature_allowed(_user,'decision_ledger'),
      'impact', public.chat_feature_allowed(_user,'decision_impact'),
      'decisions', '[]'::jsonb, 'summary', '{}'::jsonb);
  end if;

  return jsonb_build_object(
    'plan',   public.chat_feature_allowed(_user, 'decision_ledger'),
    'impact', public.chat_feature_allowed(_user, 'decision_impact'),
    'summary', (
      select jsonb_build_object(
        'total',      count(*),
        'active',     count(*) filter (where d.state = 'active'),
        'superseded', count(*) filter (where d.state = 'superseded'),
        'reversed',   count(*) filter (where d.state = 'reversed'),
        'amended',    count(*) filter (where d.version > 1))
        from public.chat_decisions d
       where d.workspace_id = v_ws
         and (_conversation is null or d.conversation_id = _conversation)),
    'decisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'title', d.title, 'detail', d.detail, 'state', d.state,
        'version', d.version, 'decided_at', d.decided_at,
        'made_by', d.made_by,
        'made_by_email', (select u.email from auth.users u where u.id = d.made_by),
        'recorded_at', d.created_at, 'source', d.source,
        'conversation_id', d.conversation_id, 'message_id', d.message_id,
        'body_hash', d.body_hash,
        'affects_count', (select count(*) from public.chat_decision_links l
                           where l.decision_id = d.id and l.removed_at is null),
        'open_affected', (select count(*) from public.chat_decision_links l
                           join public.chat_work_items w on w.id = l.object_id
                          where l.decision_id = d.id and l.removed_at is null
                            and l.object_type in ('task','promise')
                            and w.state not in ('done','cancelled')))
        order by d.decided_at desc)
        from public.chat_decisions d
       where d.workspace_id = v_ws
         and public.chat_in_conversation(d.conversation_id, _user)
         and (_conversation is null or d.conversation_id = _conversation)
       limit 200), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------
-- 12) grants
-- ---------------------------------------------------------------------------
grant execute on function public.decision_mark(uuid, uuid, text, text, timestamptz) to authenticated, service_role;
grant execute on function public.decision_amend(uuid, uuid, text, text, text, text, timestamptz, uuid) to authenticated, service_role;
grant execute on function public.decision_link(uuid, uuid, text, uuid, text, text, text) to authenticated, service_role;
grant execute on function public.decision_unlink(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.decision_impact(uuid, uuid) to authenticated, service_role;
grant execute on function public.decision_state(uuid, uuid) to authenticated, service_role;
grant execute on function public.decision_board(uuid, uuid) to authenticated, service_role;

-- ============================================================================
-- PHASE 24 LOCKED: decision hamesha asli message se · history kabhi overwrite
-- nahi (naya version row) · impact map sirf insaani link se · engine kabhi
-- dependency invent nahi karti · poora ledger append-only.
-- ============================================================================
