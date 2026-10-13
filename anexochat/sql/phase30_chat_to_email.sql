-- ============================================================================
-- ANEXOCHAT · PHASE 30 — CHAT → EMAIL (formal email, provenance preserved)
--
--   ANEXOChat → Create formal email → Recipients → Subject → Attachments → Send
--   NO accidental replacement of email.
--
-- Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
-- Transport: RUST-FIRST — `/rpc/chat.email.*` (axum, :3200, QUIC/WT) PRIMARY;
-- Bun `/api/chat/email/*` sirf fallback.
--
-- LOCK (non-negotiable):
--   1. CITATIONS: draft ki har line ke saath us chat message ka provenance
--      footnote — sender · millisecond UTC · body_hash (Phase 27 seal se).
--      Jo message quote nahi hua uska citation kabhi nahi banta.
--   2. CONSENT GATE: jin logon ke messages quote ho rahe hain unko notice jata
--      hai; objection append-only log mein rehta hai aur draft par nazar aata
--      hai. Objection draft ko chupata nahi — insaan faisla karta hai.
--   3. ATTACHMENT LINEAGE: chat file ka evidence chain (uploaded · scanning ·
--      verified · available) email attachment ke saath travel karta hai.
--      Jo step record nahi hua woh "Not recorded" likha jata hai.
--   4. NO-ACCIDENTAL-REPLACEMENT: email bante hi chat message par permanent
--      "escalated to email" marker (append-only, dono taraf), aur draft par
--      formal_record = ANEXOMAIL. Chat kabhi email ki jagah nahi leta.
--   5. DECISION → EMAIL: Phase 24 decision seedha formal body banti hai, apne
--      version number aur body_hash ke saath. Text engine ka anumaan nahi —
--      asli decision row se.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'chat_to_email', false, null, 'ANEXOChat included nahi'),
  ('pro',          'chat_to_email', false, null, 'ANEXOChat included nahi'),
  ('business',     'chat_to_email', true,  20,   'formal email drafts per conversation'),
  ('business_pro', 'chat_to_email', true,  200,  null),
  ('ai_pro',       'chat_to_email', true,  20,   null),
  ('ai_business',  'chat_to_email', true,  200,  null),
  ('ai_executive', 'chat_to_email', true,  500,  null),
  ('founder',      'chat_to_email', true,  1000, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ---------------------------------------------------------------------------
-- 1) formal email draft (chat se bana)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_email_drafts (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  created_by      uuid not null references auth.users(id) on delete restrict,
  subject         text not null,
  recipients      text[] not null default '{}'::text[],
  body            text not null,
  decision_id     uuid references public.chat_decisions(id) on delete set null,
  state           text not null default 'draft'
                  check (state in ('draft','awaiting_consent','sent','discarded')),
  mail_message_id uuid,
  sent_at         timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists chat_email_drafts_conv_idx
  on public.chat_email_drafts (conversation_id, created_at desc);

create table if not exists public.chat_email_draft_citations (
  id          uuid primary key default gen_random_uuid(),
  draft_id    uuid not null references public.chat_email_drafts(id) on delete cascade,
  line_no     int not null,
  message_id  uuid not null references public.chat_messages(id) on delete restrict,
  sender_id   uuid not null references auth.users(id) on delete restrict,
  sender      text not null,
  sent_at_ms  text not null,               -- millisecond UTC (asli row se)
  body_hash   text not null,               -- Phase 27 seal, warna live sha256
  seal_source text not null default 'chat_message_provenance',
  unique (draft_id, message_id)
);
create index if not exists chat_email_draft_citations_draft_idx
  on public.chat_email_draft_citations (draft_id, line_no);

create table if not exists public.chat_email_consent (
  id         bigserial primary key,
  draft_id   uuid not null references public.chat_email_drafts(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  state      text not null check (state in ('notified','acknowledged','objected')),
  reason     text,
  at         timestamptz not null default now()
);
create index if not exists chat_email_consent_draft_idx
  on public.chat_email_consent (draft_id, id desc);

create table if not exists public.chat_message_escalations (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  draft_id   uuid not null references public.chat_email_drafts(id) on delete cascade,
  by_user    uuid not null references auth.users(id) on delete restrict,
  at         timestamptz not null default now(),
  primary key (message_id, draft_id)
);

grant select on public.chat_email_drafts, public.chat_email_draft_citations,
               public.chat_email_consent, public.chat_message_escalations to authenticated;
grant all on public.chat_email_drafts, public.chat_email_draft_citations,
             public.chat_email_consent, public.chat_message_escalations to service_role;
grant usage, select on sequence public.chat_email_consent_id_seq to service_role;

alter table public.chat_email_drafts enable row level security;
alter table public.chat_email_draft_citations enable row level security;
alter table public.chat_email_consent enable row level security;
alter table public.chat_message_escalations enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename='chat_email_drafts' and policyname='email_draft_read') then
    create policy "email_draft_read" on public.chat_email_drafts
      for select to authenticated using (
        exists (select 1 from public.chat_participants p
                 where p.conversation_id = chat_email_drafts.conversation_id
                   and p.user_id = auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where tablename='chat_email_draft_citations' and policyname='email_citation_read') then
    create policy "email_citation_read" on public.chat_email_draft_citations
      for select to authenticated using (
        exists (select 1 from public.chat_email_drafts d
                 join public.chat_participants p on p.conversation_id = d.conversation_id
                where d.id = chat_email_draft_citations.draft_id and p.user_id = auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where tablename='chat_email_consent' and policyname='email_consent_read') then
    create policy "email_consent_read" on public.chat_email_consent
      for select to authenticated using (
        user_id = auth.uid()
        or exists (select 1 from public.chat_email_drafts d
                    where d.id = chat_email_consent.draft_id and d.created_by = auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where tablename='chat_message_escalations' and policyname='escalation_read') then
    create policy "escalation_read" on public.chat_message_escalations
      for select to authenticated using (
        exists (select 1 from public.chat_messages m
                 join public.chat_participants p on p.conversation_id = m.conversation_id
                where m.id = chat_message_escalations.message_id and p.user_id = auth.uid()));
  end if;
end $$;

-- consent + escalation + citation: append-only
create or replace function public.chat_email_appendonly()
returns trigger language plpgsql as $$
begin
  raise exception 'this record is append-only';
end $$;
drop trigger if exists chat_email_consent_no_change on public.chat_email_consent;
create trigger chat_email_consent_no_change
  before update or delete on public.chat_email_consent
  for each row execute function public.chat_email_appendonly();
drop trigger if exists chat_message_escalations_no_change on public.chat_message_escalations;
create trigger chat_message_escalations_no_change
  before update or delete on public.chat_message_escalations
  for each row execute function public.chat_email_appendonly();

-- ---------------------------------------------------------------------------
-- 2) DRAFT CREATE — citations asli messages se, consent notices bhejta hai
-- ---------------------------------------------------------------------------
create or replace function public.chat_email_draft_create(
  _user uuid, _conversation uuid, _subject text, _recipients text[],
  _message_ids uuid[], _intro text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_ws uuid; v_draft uuid; r record; v_line int := 0; v_body text := '';
  v_hash text; v_sender text; v_count int; v_limit int;
begin
  if not public.chat_in_conversation(_conversation, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'chat_to_email') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;
  if coalesce(length(trim(coalesce(_subject, ''))), 0) < 3 then
    return jsonb_build_object('ok', false, 'error', 'subject_required');
  end if;
  if coalesce(array_length(_recipients, 1), 0) = 0 then
    return jsonb_build_object('ok', false, 'error', 'recipients_required');
  end if;
  if coalesce(array_length(_message_ids, 1), 0) = 0 then
    return jsonb_build_object('ok', false, 'error', 'at_least_one_message_required',
      'note', 'A formal email built from chat must cite the chat it came from.');
  end if;

  select workspace_id into v_ws from public.chat_conversations where id = _conversation;
  v_limit := coalesce((public.chat_feature_allowed(_user, 'chat_to_email')->>'limit')::int, 20);
  select count(*) into v_count from public.chat_email_drafts
   where conversation_id = _conversation and state <> 'discarded';
  if v_count >= v_limit then
    return jsonb_build_object('ok', false, 'error', 'draft_limit_reached', 'limit', v_limit);
  end if;

  v_body := coalesce(nullif(trim(coalesce(_intro, '')), '') || E'\n\n', '');

  insert into public.chat_email_drafts (workspace_id, conversation_id, created_by,
    subject, recipients, body, state)
  values (v_ws, _conversation, _user, trim(_subject), _recipients, '', 'awaiting_consent')
  returning id into v_draft;

  for r in
    select m.id, m.body, m.created_at, m.sender_user_id, u.email,
           p.body_hash as sealed_hash
      from public.chat_messages m
      join auth.users u on u.id = m.sender_user_id
      left join public.chat_message_provenance p on p.message_id = m.id
     where m.conversation_id = _conversation
       and m.id = any(_message_ids)
       and m.deleted_at is null
     order by m.seq
  loop
    v_line := v_line + 1;
    v_sender := r.email;
    v_hash := coalesce(r.sealed_hash, encode(digest(r.body, 'sha256'), 'hex'));

    v_body := v_body || v_line || '. ' || r.body || E'\n' ||
      '   [' || v_sender || ' · ' ||
      to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD HH24:MI:SS.MS') || ' UTC · ' ||
      substring(v_hash, 1, 16) || ']' || E'\n\n';

    insert into public.chat_email_draft_citations (draft_id, line_no, message_id,
      sender_id, sender, sent_at_ms, body_hash, seal_source)
    values (v_draft, v_line, r.id, r.sender_user_id, v_sender,
      to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'), v_hash,
      case when r.sealed_hash is null then 'live sha256 (not sealed yet)'
           else 'chat_message_provenance' end)
    on conflict (draft_id, message_id) do nothing;

    -- consent notice: sirf doosre logon ko, ek hi dafa
    if r.sender_user_id <> _user
       and not exists (select 1 from public.chat_email_consent c
                        where c.draft_id = v_draft and c.user_id = r.sender_user_id) then
      insert into public.chat_email_consent (draft_id, user_id, state, reason)
      values (v_draft, r.sender_user_id, 'notified',
        'Your chat message is quoted in a formal email draft.');
    end if;

    -- no accidental replacement: dono taraf permanent marker
    insert into public.chat_message_escalations (message_id, draft_id, by_user)
    values (r.id, v_draft, _user) on conflict do nothing;
  end loop;

  if v_line = 0 then
    delete from public.chat_email_drafts where id = v_draft;
    return jsonb_build_object('ok', false, 'error', 'no_quotable_messages_found');
  end if;

  update public.chat_email_drafts
     set body = v_body ||
       '---' || E'\n' ||
       'Formal record: ANEXOMAIL. Source: ANEXOChat conversation ' || _conversation || '.' || E'\n' ||
       'Each numbered line above carries the sender, the exact UTC time and the sealed hash of the original chat message.',
         updated_at = now()
   where id = v_draft;

  return jsonb_build_object('ok', true, 'draft_id', v_draft, 'citations', v_line,
    'state', 'awaiting_consent', 'formal_record', 'ANEXOMAIL',
    'replaces_email', false);
end $$;

-- ---------------------------------------------------------------------------
-- 3) DRAFT GET — citations + consent + attachment lineage
-- ---------------------------------------------------------------------------
create or replace function public.chat_email_draft_get(_draft uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare d record; v_cites jsonb; v_consent jsonb; v_files jsonb;
begin
  select * into d from public.chat_email_drafts where id = _draft;
  if not found then return jsonb_build_object('error', 'draft_not_found'); end if;
  if not public.chat_in_conversation(d.conversation_id, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'line_no', c.line_no, 'message_id', c.message_id, 'sender', c.sender,
           'sent_at_ms', c.sent_at_ms, 'body_hash', c.body_hash,
           'seal_source', c.seal_source) order by c.line_no), '[]'::jsonb)
    into v_cites from public.chat_email_draft_citations c where c.draft_id = _draft;

  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', c.user_id, 'person', u.email, 'state', c.state,
           'reason', c.reason, 'at', c.at) order by c.id), '[]'::jsonb)
    into v_consent from public.chat_email_consent c
    join auth.users u on u.id = c.user_id where c.draft_id = _draft;

  -- attachment lineage: chat file ka evidence chain email ke saath jata hai
  select coalesce(jsonb_agg(jsonb_build_object(
           'version_id', v.id, 'filename', f.name, 'bytes', v.bytes,
           'version_state', v.state,
           'lineage', (
             select jsonb_agg(jsonb_build_object(
                      'step', s.state, 'recorded', e.at is not null,
                      'at', e.at, 'evidence',
                      case when e.at is null then 'Not recorded' else 'file_evidence' end)
                      order by s.ord)
               from (values ('uploaded',1),('scanning',2),('verified',3),('available',4)) as s(state, ord)
               left join public.file_evidence e on e.version_id = v.id and e.state = s.state))),
         '[]'::jsonb)
    into v_files
    from public.chat_email_draft_citations c
    join public.chat_message_files mf on mf.message_id = c.message_id
    join public.chat_file_versions v on v.id = mf.version_id
    join public.chat_files f on f.id = v.file_id
   where c.draft_id = _draft;

  return jsonb_build_object(
    'draft_id', d.id, 'conversation_id', d.conversation_id, 'state', d.state,
    'subject', d.subject, 'recipients', d.recipients, 'body', d.body,
    'decision_id', d.decision_id, 'mail_message_id', d.mail_message_id,
    'sent_at', d.sent_at, 'created_at', d.created_at,
    'citations', v_cites, 'consent', v_consent, 'attachments', v_files,
    'objections', (select count(*) from public.chat_email_consent
                    where draft_id = _draft and state = 'objected'),
    'formal_record', 'ANEXOMAIL', 'replaces_email', false);
end $$;

create or replace function public.chat_email_draft_board(_user uuid, _conversation uuid default null)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_rows jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
           'draft_id', d.id, 'conversation_id', d.conversation_id,
           'title', coalesce(c.subject, 'Direct conversation'),
           'subject', d.subject, 'state', d.state, 'recipients', d.recipients,
           'citations', (select count(*) from public.chat_email_draft_citations x where x.draft_id = d.id),
           'objections', (select count(*) from public.chat_email_consent x
                           where x.draft_id = d.id and x.state = 'objected'),
           'sent_at', d.sent_at, 'created_at', d.created_at)
           order by d.created_at desc), '[]'::jsonb)
    into v_rows
    from public.chat_email_drafts d
    join public.chat_conversations c on c.id = d.conversation_id
    join public.chat_participants p on p.conversation_id = d.conversation_id and p.user_id = _user
   where (_conversation is null or d.conversation_id = _conversation)
     and d.state <> 'discarded';

  return jsonb_build_object('drafts', v_rows,
    'allowed', public.chat_feature_ok(_user, 'chat_to_email'),
    'formal_record', 'ANEXOMAIL');
end $$;

-- ---------------------------------------------------------------------------
-- 4) CONSENT — acknowledge / objection (append-only, chupta nahi)
-- ---------------------------------------------------------------------------
create or replace function public.chat_email_draft_consent(
  _user uuid, _draft uuid, _state text, _reason text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare d record;
begin
  if _state not in ('acknowledged','objected') then
    return jsonb_build_object('ok', false, 'error', 'state_must_be_acknowledged_or_objected');
  end if;
  select * into d from public.chat_email_drafts where id = _draft;
  if not found then return jsonb_build_object('ok', false, 'error', 'draft_not_found'); end if;
  if not exists (select 1 from public.chat_email_draft_citations
                  where draft_id = _draft and sender_id = _user) then
    return jsonb_build_object('ok', false, 'error', 'your_message_is_not_quoted');
  end if;
  if _state = 'objected' and coalesce(length(trim(coalesce(_reason, ''))), 0) < 8 then
    return jsonb_build_object('ok', false, 'error', '8_char_reason_required');
  end if;

  insert into public.chat_email_consent (draft_id, user_id, state, reason)
  values (_draft, _user, _state, _reason);

  return jsonb_build_object('ok', true, 'draft_id', _draft, 'state', _state,
    'objections', (select count(*) from public.chat_email_consent
                    where draft_id = _draft and state = 'objected'),
    'note', 'Recorded. Objections stay visible on the draft; the sender decides.');
end $$;

-- ---------------------------------------------------------------------------
-- 5) SEND — mail_message_id asli ANEXOMAIL row se aata hai
-- ---------------------------------------------------------------------------
create or replace function public.chat_email_draft_send(
  _user uuid, _draft uuid, _mail_message uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare d record; v_obj int;
begin
  select * into d from public.chat_email_drafts where id = _draft;
  if not found then return jsonb_build_object('ok', false, 'error', 'draft_not_found'); end if;
  if d.created_by <> _user then
    return jsonb_build_object('ok', false, 'error', 'only_the_author_can_send');
  end if;
  if d.state = 'sent' then
    return jsonb_build_object('ok', true, 'draft_id', _draft, 'state', 'sent',
      'mail_message_id', d.mail_message_id, 'already_sent', true);
  end if;
  if _mail_message is null then
    return jsonb_build_object('ok', false, 'error', 'mail_message_id_required',
      'note', 'The formal record must exist in ANEXOMAIL before this is marked sent.');
  end if;

  select count(*) into v_obj from public.chat_email_consent
   where draft_id = _draft and state = 'objected';

  update public.chat_email_drafts
     set state = 'sent', mail_message_id = _mail_message, sent_at = now(), updated_at = now()
   where id = _draft;

  -- dono taraf permanent link (Phase 29 stitching ke saath)
  insert into public.chat_email_links (workspace_id, conversation_id, mail_thread_id,
    mail_message_id, origin, subject_snapshot, created_by)
  values (d.workspace_id, d.conversation_id, _mail_message, _mail_message,
          'chat_to_email', d.subject, _user)
  on conflict do nothing;

  return jsonb_build_object('ok', true, 'draft_id', _draft, 'state', 'sent',
    'mail_message_id', _mail_message, 'objections_at_send', v_obj,
    'formal_record', 'ANEXOMAIL', 'chat_message_marked', 'escalated to email');
end $$;

-- ---------------------------------------------------------------------------
-- 6) DECISION → FORMAL EMAIL (Phase 24 row se, version ke saath)
-- ---------------------------------------------------------------------------
create or replace function public.decision_to_email(_user uuid, _decision uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare d record; v_draft uuid; v_body text; v_ws uuid; v_maker text; v_line int := 1;
begin
  select dd.*, u.email as maker_email into d
    from public.chat_decisions dd join auth.users u on u.id = dd.made_by
   where dd.id = _decision;
  if not found then return jsonb_build_object('ok', false, 'error', 'decision_not_found'); end if;
  if not public.chat_in_conversation(d.conversation_id, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'chat_to_email') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;

  v_maker := d.maker_email;
  v_body :=
    'DECISION: ' || d.title || E'\n' ||
    coalesce('Detail: ' || d.detail || E'\n', '') ||
    'Decided: ' || to_char(d.decided_at at time zone 'utc', 'YYYY-MM-DD HH24:MI:SS') || ' UTC' || E'\n' ||
    'Made by: ' || v_maker || E'\n' ||
    'Source: ' || d.source || E'\n' ||
    'Version: ' || d.version || ' · State: ' || d.state || E'\n' ||
    'Record hash: ' || substring(d.body_hash, 1, 16) || E'\n\n' ||
    '---' || E'\n' ||
    'Formal record: ANEXOMAIL. This decision was recorded in ANEXOChat from a real message; ' ||
    'its history is versioned and never overwritten.';

  select workspace_id into v_ws from public.chat_conversations where id = d.conversation_id;

  insert into public.chat_email_drafts (workspace_id, conversation_id, created_by,
    subject, recipients, body, decision_id, state)
  values (v_ws, d.conversation_id, _user,
    'Decision: ' || d.title || ' (v' || d.version || ')', '{}'::text[], v_body, d.id, 'draft')
  returning id into v_draft;

  insert into public.chat_email_draft_citations (draft_id, line_no, message_id,
    sender_id, sender, sent_at_ms, body_hash, seal_source)
  select v_draft, v_line, d.message_id, d.made_by, v_maker,
         to_char(d.decided_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
         d.body_hash, 'chat_decisions.body_hash'
  on conflict (draft_id, message_id) do nothing;

  insert into public.chat_message_escalations (message_id, draft_id, by_user)
  values (d.message_id, v_draft, _user) on conflict do nothing;

  return jsonb_build_object('ok', true, 'draft_id', v_draft, 'decision_id', d.id,
    'version', d.version, 'state', 'draft', 'formal_record', 'ANEXOMAIL',
    'recipients_required_before_send', true);
end $$;

-- message par escalation marker (chat side badge)
create or replace function public.message_escalations(_message uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_conv uuid; v_rows jsonb;
begin
  select conversation_id into v_conv from public.chat_messages where id = _message;
  if v_conv is null then return jsonb_build_object('error', 'message_not_found'); end if;
  if not public.chat_in_conversation(v_conv, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'draft_id', e.draft_id, 'at', e.at, 'state', d.state,
           'subject', d.subject, 'mail_message_id', d.mail_message_id)
           order by e.at desc), '[]'::jsonb)
    into v_rows from public.chat_message_escalations e
    join public.chat_email_drafts d on d.id = e.draft_id
   where e.message_id = _message;

  return jsonb_build_object('message_id', _message, 'escalations', v_rows,
    'label', case when jsonb_array_length(v_rows) = 0 then null
                  else 'Escalated to email' end,
    'formal_record', 'ANEXOMAIL');
end $$;

-- ---------------------------------------------------------------------------
-- grants
-- ---------------------------------------------------------------------------
grant execute on function
  public.chat_email_draft_create(uuid, uuid, text, text[], uuid[], text),
  public.chat_email_draft_get(uuid, uuid),
  public.chat_email_draft_board(uuid, uuid),
  public.chat_email_draft_consent(uuid, uuid, text, text),
  public.chat_email_draft_send(uuid, uuid, uuid),
  public.decision_to_email(uuid, uuid),
  public.message_escalations(uuid, uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- VERIFY
-- ---------------------------------------------------------------------------
-- select count(*) from information_schema.tables where table_schema='public'
--   and table_name in ('chat_email_drafts','chat_email_draft_citations',
--                      'chat_email_consent','chat_message_escalations');   -- 4
-- select public.chat_email_draft_board('3e3a60ea-1580-4443-94f6-b758de732dce');
