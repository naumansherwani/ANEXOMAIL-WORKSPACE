-- ============================================================================
-- ANEXOCHAT · PHASE 25 — CONVERSATION → OUTCOME TIMELINE
--            PHASE 26 — CONVERSATION HEALTH + COMMITMENT COLLISION PREVENTION
--            PHASE 27 — MESSAGE PROVENANCE (sealed hash chain)
--
--   09:12 Customer requested migration      (communication)
--   09:17 Contract received                 (file, evidence-proven)
--   10:03 Migration date decided            (outcome — decision)
--   10:20 Task created                      (outcome)
--   11:22 Promise made                      (outcome)
--   14:40 DNS completed                     (outcome — evidence)
--   16:12 Customer confirmation received    (communication)
--   18:00 Migration completed               (outcome — evidence)
--
--   ABC Contract — 🟡 Waiting · Owner: Sarah · Due: Today
--
--   Sent by john@company.com · Workspace ABC Ltd ·
--   14:32:11.418 UTC · Delivery Confirmed · Integrity Verified
--
-- Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
-- Transport: Rust `/rpc/chat.timeline.*|chat.health.*|chat.provenance.*|
-- chat.collision.*` over WebTransport/QUIC (Caddy HTTP/3) PRIMARY; Bun
-- `/api/chat/*` sirf fallback.
--
-- LOCK (non-negotiable):
--   1. Timeline kuch INVENT nahi karti. Har event ka asli record hai (message ·
--      file evidence · work item · decision version · promise ledger row) aur
--      har event apna `source` aur `evidence` le kar aata hai.
--   2. Communication aur BUSINESS OUTCOME do alag lane hain (`lane`), taake
--      "kya kaha gaya" aur "kya hua" kabhi mix na ho.
--   3. Health sirf sabit cheez se banti hai: khula kaam · overdue promise ·
--      blocked dependency · jawab ka intezar. Har status ke saath `reasons[]`
--      aur uska evidence hota hai. "Completed" sirf tab jab kaam evidence ke
--      saath band ho.
--   4. COLLISION engine dependency KABHI invent nahi karti. Sirf woh rishta
--      dikhati hai jo insaan ne banaya: `chat_work_items.depends_on` ya
--      `chat_decision_links`. Warning ke saath uska evidence hamesha.
--   5. Collision par har amal insaan ka: resolve · change deadline · reassign ·
--      dismiss — 8+ character wajah ke saath, aur ledger append-only.
--   6. Provenance seal: har message ka body_hash + prev_hash → chain_hash
--      (per conversation append-only chain). Chain row kabhi update/delete nahi
--      hoti. Edit hone par asli seal zinda rehta hai aur UI sach bolta hai.
--   7. "Delivery Confirmed" sirf `chat_message_receipts` se; koi anumaan nahi.
--      Lafz "Delivered" UI mein nahi — sirf sabit step.
--   8. No duplicate: Phase 1 ka list-level `chat_conversation_list` health
--      (green/amber/red) zinda rehta hai; yeh uske OOPAR matter-level health,
--      owner/due, timeline aur collision layer hai.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) helper — chat_feature_allowed() jsonb deta hai; boolean shortcut
-- ---------------------------------------------------------------------------
create or replace function public.chat_feature_ok(_user uuid, _feature text)
returns boolean language sql stable security definer
set search_path = public, extensions as $$
  select coalesce((public.chat_feature_allowed(_user, _feature)->>'allowed')::boolean, false)
$$;
grant execute on function public.chat_feature_ok(uuid, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1) plan entitlements
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'conversation_timeline', false, null, 'ANEXOChat included nahi'),
  ('pro',          'conversation_timeline', false, null, 'ANEXOChat included nahi'),
  ('business',     'conversation_timeline', true,  200,  'messages · files · tasks · promises · decisions · important'),
  ('business_pro', 'conversation_timeline', true,  1000, null),
  ('ai_pro',       'conversation_timeline', true,  200,  null),
  ('ai_business',  'conversation_timeline', true,  1000, null),
  ('ai_executive', 'conversation_timeline', true,  2000, null),
  ('founder',      'conversation_timeline', true,  5000, null),

  ('basic',        'conversation_health', false, null, null),
  ('pro',          'conversation_health', false, null, null),
  ('business',     'conversation_health', true,  null, 'healthy · waiting · blocked · completed + owner + due'),
  ('business_pro', 'conversation_health', true,  null, null),
  ('ai_pro',       'conversation_health', true,  null, null),
  ('ai_business',  'conversation_health', true,  null, null),
  ('ai_executive', 'conversation_health', true,  null, null),
  ('founder',      'conversation_health', true,  null, null),

  ('basic',        'message_provenance', false, null, null),
  ('pro',          'message_provenance', false, null, null),
  ('business',     'message_provenance', true,  null, 'sender · workspace · UTC · receipts · integrity'),
  ('business_pro', 'message_provenance', true,  null, null),
  ('ai_pro',       'message_provenance', true,  null, null),
  ('ai_business',  'message_provenance', true,  null, null),
  ('ai_executive', 'message_provenance', true,  null, null),
  ('founder',      'message_provenance', true,  null, null),

  -- poori conversation ka sealed chain audit (Business Pro price ke mutabiq)
  ('basic',        'provenance_chain', false, null, null),
  ('pro',          'provenance_chain', false, null, null),
  ('business',     'provenance_chain', false, null, 'chain audit Business Pro se'),
  ('business_pro', 'provenance_chain', true,  null, 'poori conversation ka tamper-evident chain audit'),
  ('ai_pro',       'provenance_chain', false, null, null),
  ('ai_business',  'provenance_chain', true,  null, null),
  ('ai_executive', 'provenance_chain', true,  null, null),
  ('founder',      'provenance_chain', true,  null, null),

  ('basic',        'commitment_collision', false, null, null),
  ('pro',          'commitment_collision', false, null, null),
  ('business',     'commitment_collision', false, null, 'collision prevention Business Pro se'),
  ('business_pro', 'commitment_collision', true,  null, 'dependent + overdue commitments, evidence ke saath'),
  ('ai_pro',       'commitment_collision', false, null, null),
  ('ai_business',  'commitment_collision', true,  null, null),
  ('ai_executive', 'commitment_collision', true,  null, null),
  ('founder',      'commitment_collision', true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ===========================================================================
-- PHASE 27 — MESSAGE PROVENANCE  (sealed, append-only hash chain)
-- ===========================================================================

-- self-healing: purani shape ho to `_legacy`
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='chat_message_provenance')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='chat_message_provenance'
                and column_name='chain_hash') then
    execute 'alter table public.chat_message_provenance rename to chat_message_provenance_legacy';
  end if;
end $$;

create table if not exists public.chat_message_provenance (
  message_id      uuid primary key references public.chat_messages(id) on delete cascade,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  seq             bigint not null,
  sender_user_id  uuid not null references auth.users(id) on delete restrict,
  sent_at         timestamptz not null,
  transport       text not null default 'bun',
  device_label    text,
  body_hash       text not null,          -- asli body ka sha256 (seal ke waqt)
  prev_hash       text,                   -- pichle sealed message ka chain_hash
  chain_hash      text not null,          -- sha256(prev_hash || body_hash || seq)
  sealed_at       timestamptz not null default now(),
  unique (conversation_id, seq)
);
create index if not exists chat_message_provenance_conv_idx
  on public.chat_message_provenance (conversation_id, seq desc);

grant select on public.chat_message_provenance to authenticated;
grant all on public.chat_message_provenance to service_role;

alter table public.chat_message_provenance enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='chat_message_provenance' and policyname='prov_read') then
    execute $p$create policy prov_read on public.chat_message_provenance
      for select to authenticated
      using (public.chat_in_conversation(conversation_id, auth.uid()))$p$;
  end if;
end $$;

-- seal kabhi badalta nahi (append-only)
create or replace function public.chat_provenance_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'provenance_is_sealed';
end $$;

drop trigger if exists chat_message_provenance_no_update on public.chat_message_provenance;
create trigger chat_message_provenance_no_update
  before update or delete on public.chat_message_provenance
  for each row execute function public.chat_provenance_immutable();

-- ek message ko seal karo (idempotent — dobara seal nahi hota)
create or replace function public.chat_provenance_seal(_message uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare m record; v_prev text; v_body text; v_chain text;
begin
  select * into m from public.chat_messages where id = _message;
  if m.id is null then return jsonb_build_object('ok', false, 'error', 'message_not_found'); end if;
  if exists (select 1 from public.chat_message_provenance where message_id = _message) then
    return jsonb_build_object('ok', true, 'already_sealed', true);
  end if;

  select p.chain_hash into v_prev
    from public.chat_message_provenance p
   where p.conversation_id = m.conversation_id and p.seq < m.seq
   order by p.seq desc limit 1;

  v_body  := encode(digest(coalesce(m.body, ''), 'sha256'), 'hex');
  v_chain := encode(digest(coalesce(v_prev, '') || v_body || m.seq::text, 'sha256'), 'hex');

  insert into public.chat_message_provenance
    (message_id, conversation_id, workspace_id, seq, sender_user_id, sent_at,
     transport, device_label, body_hash, prev_hash, chain_hash)
  values (m.id, m.conversation_id, m.workspace_id, m.seq, m.sender_user_id, m.created_at,
          coalesce(m.transport, 'bun'), m.device_label, v_body, v_prev, v_chain)
  on conflict (message_id) do nothing;

  return jsonb_build_object('ok', true, 'body_hash', v_body, 'chain_hash', v_chain);
end $$;

-- har naya message khud seal hota hai
create or replace function public.chat_provenance_on_message()
returns trigger language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform public.chat_provenance_seal(new.id);
  return new;
end $$;

drop trigger if exists chat_messages_seal_provenance on public.chat_messages;
create trigger chat_messages_seal_provenance
  after insert on public.chat_messages
  for each row execute function public.chat_provenance_on_message();

-- purane messages ke liye backfill (chronological — chain sahi bane)
create or replace function public.chat_provenance_backfill(_conversation uuid default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare r record; n int := 0;
begin
  for r in
    select m.id from public.chat_messages m
     where (_conversation is null or m.conversation_id = _conversation)
       and not exists (select 1 from public.chat_message_provenance p where p.message_id = m.id)
     order by m.conversation_id, m.seq
  loop
    perform public.chat_provenance_seal(r.id);
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'sealed', n);
end $$;

-- ek message ka poora sach
create or replace function public.message_provenance(_message uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare m record; p record; v_now text; v_recipients int; v_delivered int; v_read int;
begin
  select * into m from public.chat_messages where id = _message;
  if m.id is null then return jsonb_build_object('error', 'message_not_found'); end if;
  if not public.chat_in_conversation(m.conversation_id, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'message_provenance') then
    return jsonb_build_object('error', 'plan_not_allowed');
  end if;

  select * into p from public.chat_message_provenance where message_id = _message;
  v_now := encode(digest(coalesce(m.body, ''), 'sha256'), 'hex');

  select count(*) into v_recipients from public.chat_participants
   where conversation_id = m.conversation_id and user_id <> m.sender_user_id;
  select count(*) into v_delivered from public.chat_message_receipts
   where message_id = _message and state = 'delivered';
  select count(*) into v_read from public.chat_message_receipts
   where message_id = _message and state = 'read';

  return jsonb_build_object(
    'message_id', m.id,
    'conversation_id', m.conversation_id,
    'seq', m.seq,
    'sent_by', (select u.email from auth.users u where u.id = m.sender_user_id),
    'sent_by_id', m.sender_user_id,
    'workspace', (select w.name from public.chat_workspaces w where w.id = m.workspace_id),
    -- millisecond-exact UTC (14:32:11.418 UTC)
    'sent_at_utc', to_char(m.created_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS.MS') || ' UTC',
    'sent_at', m.created_at,
    'transport', coalesce(m.transport, 'bun'),
    'transport_label', case coalesce(m.transport, 'bun')
      when 'wt' then 'WebTransport / QUIC (Rust engine)'
      when 'realtime' then 'Realtime channel'
      else 'HTTP fallback' end,
    'device_label', m.device_label,
    'recipients', v_recipients,
    'delivery_confirmed', (v_recipients > 0 and v_delivered >= v_recipients),
    'delivery_count', v_delivered,
    'read_count', v_read,
    'receipts', coalesce((
      select jsonb_agg(jsonb_build_object('user_id', r.user_id, 'state', r.state, 'at', r.at)
             order by r.at)
        from public.chat_message_receipts r where r.message_id = _message), '[]'::jsonb),
    'sealed', p.message_id is not null,
    'seal_hash', p.body_hash,
    'chain_hash', p.chain_hash,
    'prev_hash', p.prev_hash,
    'sealed_at', p.sealed_at,
    'current_hash', v_now,
    'integrity_verified', (p.message_id is not null and p.body_hash = v_now),
    'edited', m.edited_at is not null,
    'edited_at', m.edited_at,
    'visible', m.deleted_at is null,
    'integrity_note', case
      when p.message_id is null then 'Not sealed yet — this message was written before sealing began.'
      when p.body_hash = v_now then 'Integrity verified against the sealed record.'
      when m.edited_at is not null then 'Edited after sending. The original seal is still on record.'
      else 'Text no longer matches the sealed record.' end,
    'important', exists (select 1 from public.chat_message_important i
                          where i.message_id = _message and i.removed_at is null));
end $$;

-- poori conversation ka tamper-evident chain audit
create or replace function public.conversation_chain_verify(_conversation uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare r record; v_prev text; v_expect text; v_break jsonb := null; n int := 0; v_edited int := 0;
begin
  if not public.chat_in_conversation(_conversation, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'provenance_chain') then
    return jsonb_build_object('error', 'plan_not_allowed');
  end if;

  for r in
    select p.*, m.body, m.edited_at from public.chat_message_provenance p
      join public.chat_messages m on m.id = p.message_id
     where p.conversation_id = _conversation
     order by p.seq
  loop
    n := n + 1;
    if r.edited_at is not null then v_edited := v_edited + 1; end if;
    v_expect := encode(digest(coalesce(v_prev, '') || r.body_hash || r.seq::text, 'sha256'), 'hex');
    if v_break is null and (v_expect <> r.chain_hash or coalesce(r.prev_hash,'') <> coalesce(v_prev,'')) then
      v_break := jsonb_build_object('message_id', r.message_id, 'seq', r.seq,
        'expected', v_expect, 'sealed', r.chain_hash);
    end if;
    v_prev := r.chain_hash;
  end loop;

  return jsonb_build_object(
    'conversation_id', _conversation,
    'sealed_messages', n,
    'unsealed_messages', (select count(*) from public.chat_messages m
                           where m.conversation_id = _conversation
                             and not exists (select 1 from public.chat_message_provenance p
                                              where p.message_id = m.id)),
    'edited_after_sealing', v_edited,
    'chain_intact', v_break is null,
    'first_break', v_break,
    'head_hash', v_prev);
end $$;

-- ===========================================================================
-- PHASE 25 — IMPORTANT MARK + CONVERSATION → OUTCOME TIMELINE
-- ===========================================================================

create table if not exists public.chat_message_important (
  id          uuid primary key default gen_random_uuid(),
  message_id  uuid not null references public.chat_messages(id) on delete cascade,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  marked_by   uuid not null references auth.users(id) on delete cascade,
  reason      text,
  at          timestamptz not null default now(),
  removed_at  timestamptz,
  removed_by  uuid references auth.users(id) on delete set null
);
create unique index if not exists chat_message_important_live
  on public.chat_message_important (message_id) where removed_at is null;

grant select, insert, update on public.chat_message_important to authenticated;
grant all on public.chat_message_important to service_role;

alter table public.chat_message_important enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='chat_message_important' and policyname='important_read') then
    execute $p$create policy important_read on public.chat_message_important
      for select to authenticated
      using (public.chat_in_conversation(conversation_id, auth.uid()))$p$;
  end if;
end $$;

create or replace function public.message_mark_important(
  _message uuid, _user uuid, _reason text default null, _important boolean default true)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare m record; v_id uuid;
begin
  select * into m from public.chat_messages where id = _message;
  if m.id is null then return jsonb_build_object('ok', false, 'error', 'message_not_found'); end if;
  if not public.chat_in_conversation(m.conversation_id, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'conversation_timeline') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;

  if _important then
    insert into public.chat_message_important (message_id, conversation_id, marked_by, reason)
    values (_message, m.conversation_id, _user, nullif(btrim(coalesce(_reason,'')), ''))
    on conflict do nothing
    returning id into v_id;
    return jsonb_build_object('ok', true, 'important', true, 'id', v_id);
  end if;

  update public.chat_message_important
     set removed_at = now(), removed_by = _user
   where message_id = _message and removed_at is null;
  return jsonb_build_object('ok', true, 'important', false);
end $$;

/*
 * conversation_timeline — communication AUR business outcome ek hi lakeer par,
 * magar do alag lane mein. Har event ka asli record hai; kuch invent nahi hota.
 *   lane = 'communication' | 'outcome'
 *   lens = 'all' | 'messages' | 'files' | 'tasks' | 'promises' | 'decisions' | 'important' | 'outcome'
 */
create or replace function public.conversation_timeline(
  _conversation uuid, _user uuid, _lens text default 'all', _limit int default null)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_cap int; v_lens text := coalesce(nullif(btrim(coalesce(_lens,'')),''), 'all');
begin
  if not public.chat_in_conversation(_conversation, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'conversation_timeline') then
    return jsonb_build_object('error', 'plan_not_allowed');
  end if;

  v_cap := least(
    coalesce(_limit, 300),
    coalesce((public.chat_feature_allowed(_user,'conversation_timeline')->>'limit')::int, 300));

  return jsonb_build_object(
    'conversation_id', _conversation,
    'title', (select coalesce(c.subject, 'Conversation') from public.chat_conversations c
               where c.id = _conversation),
    'lens', v_lens,
    'events', coalesce((
      select jsonb_agg(e order by e->>'at')
        from (
          select to_jsonb(x) as e from (

            -- COMMUNICATION: messages (important hamesha; lens='messages' par sab)
            select m.created_at as at, 'communication' as lane, 'message' as kind,
                   case when i.id is not null then 'Important message' else 'Message' end as label,
                   left(regexp_replace(coalesce(m.body,''), '\s+', ' ', 'g'), 200) as detail,
                   (select u.email from auth.users u where u.id = m.sender_user_id) as actor,
                   m.id as object_id, 'message' as object_type,
                   (i.id is not null) as important,
                   jsonb_build_object('seq', m.seq, 'sealed',
                     exists (select 1 from public.chat_message_provenance p where p.message_id = m.id),
                     'transport', m.transport) as evidence
              from public.chat_messages m
              left join public.chat_message_important i
                on i.message_id = m.id and i.removed_at is null
             where m.conversation_id = _conversation
               and m.deleted_at is null
               and (v_lens in ('all','messages')
                    or (v_lens = 'important' and i.id is not null))
               and (v_lens <> 'all' or i.id is not null
                    or exists (select 1 from public.chat_work_items w where w.message_id = m.id)
                    or exists (select 1 from public.chat_decisions d where d.message_id = m.id)
                    or m.seq = (select min(z.seq) from public.chat_messages z
                                 where z.conversation_id = _conversation and z.deleted_at is null)
                    or m.seq = (select max(z.seq) from public.chat_messages z
                                 where z.conversation_id = _conversation and z.deleted_at is null))

            union all

            -- OUTCOME: file received (evidence chain se sabit)
            select ev.at, 'outcome', 'file',
                   case ev.state when 'available' then 'File received and verified'
                                 when 'verified'  then 'File verified'
                                 when 'uploaded'  then 'File received'
                                 when 'blocked'   then 'File blocked by safety'
                                 else 'File ' || ev.state end,
                   f.name, (select u.email from auth.users u where u.id = ev.user_id),
                   f.id, 'file', false,
                   jsonb_build_object('state', ev.state, 'actor', ev.actor,
                                      'version', fv.version, 'bytes', fv.bytes,
                                      'sha256', fv.file_sha256)
              from public.file_evidence ev
              join public.chat_file_versions fv on fv.id = ev.version_id
              join public.chat_files f on f.id = fv.file_id
             where f.conversation_id = _conversation
               and ev.state in ('uploaded','verified','available','blocked')
               and v_lens in ('all','files','outcome')

            union all

            -- OUTCOME: task / promise created
            select w.created_at, 'outcome',
                   w.kind,
                   case w.kind when 'promise' then 'Promise made'
                               when 'task' then 'Task created'
                               else 'Decision recorded' end,
                   w.title, (select u.email from auth.users u where u.id = w.created_by),
                   w.id, w.kind, false,
                   jsonb_build_object('owner', (select u.email from auth.users u where u.id = w.owner_user_id),
                     'due_at', w.due_at, 'state', w.state, 'depends_on', w.depends_on,
                     'from_message', w.message_id, 'body_hash', w.provenance->>'body_hash')
              from public.chat_work_items w
             where w.conversation_id = _conversation
               and (v_lens in ('all','outcome')
                    or (v_lens = 'tasks' and w.kind = 'task')
                    or (v_lens = 'promises' and w.kind = 'promise')
                    or (v_lens = 'decisions' and w.kind = 'decision'))

            union all

            -- OUTCOME: work completed (evidence ke saath — warna band hi nahi hota)
            select w.completed_at, 'outcome', 'completed',
                   case w.kind when 'promise' then 'Promise kept' else 'Completed' end,
                   w.title, (select u.email from auth.users u where u.id = w.completed_by),
                   w.id, w.kind, false,
                   jsonb_build_object('evidence_count',
                     (select count(*) from public.chat_work_evidence e where e.item_id = w.id),
                     'due_at', w.due_at, 'original_due_at', w.original_due_at)
              from public.chat_work_items w
             where w.conversation_id = _conversation
               and w.state = 'done' and w.completed_at is not null
               and v_lens in ('all','outcome','tasks','promises')

            union all

            -- OUTCOME: decision recorded / changed (versions se, kabhi overwrite nahi)
            select v.at, 'outcome', 'decision',
                   case v.change when 'recorded' then 'Decision recorded'
                                 when 'amended' then 'Decision changed (new version)'
                                 when 'superseded' then 'Decision replaced'
                                 else 'Decision reversed' end,
                   v.title, (select u.email from auth.users u where u.id = v.changed_by),
                   d.id, 'decision', false,
                   jsonb_build_object('version', v.version, 'reason', v.reason,
                     'decided_at', v.decided_at, 'body_hash', d.body_hash,
                     'from_message', d.message_id)
              from public.chat_decision_versions v
              join public.chat_decisions d on d.id = v.decision_id
             where d.conversation_id = _conversation
               and v_lens in ('all','outcome','decisions')

          ) x
          order by (x.at) asc
          limit v_cap
        ) y), '[]'::jsonb),
    'lanes', jsonb_build_object(
      'communication', 'What was said',
      'outcome', 'What actually resulted'),
    'engine_invents_nothing', true);
end $$;

-- ===========================================================================
-- PHASE 26 — CONVERSATION HEALTH  (matter-level, evidence ke saath)
-- ===========================================================================
create or replace function public.conversation_health(_conversation uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare c record; last_msg record; v_open int; v_blocked int; v_overdue int; v_total int;
        v_owner text; v_due timestamptz; v_state text; v_reasons jsonb := '[]'::jsonb;
        v_waiting boolean := false;
begin
  if not public.chat_in_conversation(_conversation, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'conversation_health') then
    return jsonb_build_object('error', 'plan_not_allowed');
  end if;

  select * into c from public.chat_conversations where id = _conversation;

  select m.* into last_msg from public.chat_messages m
   where m.conversation_id = _conversation and m.deleted_at is null
   order by m.seq desc limit 1;

  select count(*) filter (where w.state in ('open','blocked')),
         count(*) filter (where w.state = 'blocked'),
         count(*) filter (where w.state in ('open','blocked')
                            and w.due_at is not null and w.due_at < now()),
         count(*)
    into v_open, v_blocked, v_overdue, v_total
    from public.chat_work_items w where w.conversation_id = _conversation;

  -- next commitment = sabse pehli khuli deadline
  select (select u.email from auth.users u where u.id = w.owner_user_id), w.due_at
    into v_owner, v_due
    from public.chat_work_items w
   where w.conversation_id = _conversation and w.state in ('open','blocked')
   order by (w.due_at is null), w.due_at
   limit 1;

  -- jawab ka intezar: aakhri message mera tha aur doosre ne padha nahi
  if last_msg.id is not null then
    v_waiting := exists (
      select 1 from public.chat_participants p
       where p.conversation_id = _conversation
         and p.user_id <> last_msg.sender_user_id
         and coalesce(p.last_read_seq, 0) < last_msg.seq);
  end if;

  if v_blocked > 0 or v_overdue > 0 then
    v_state := 'blocked';
  elsif v_open > 0 and v_waiting then
    v_state := 'waiting';
  elsif v_open > 0 then
    v_state := 'healthy';
  elsif v_total > 0 then
    v_state := 'completed';
  elsif v_waiting then
    v_state := 'waiting';
  else
    v_state := 'healthy';
  end if;

  if v_blocked > 0 then
    v_reasons := v_reasons || jsonb_build_array(jsonb_build_object(
      'reason', v_blocked || ' item(s) blocked by a dependency someone recorded',
      'evidence', 'chat_work_items.depends_on'));
  end if;
  if v_overdue > 0 then
    v_reasons := v_reasons || jsonb_build_array(jsonb_build_object(
      'reason', v_overdue || ' commitment(s) past their deadline',
      'evidence', 'chat_work_items.due_at'));
  end if;
  if v_waiting then
    v_reasons := v_reasons || jsonb_build_array(jsonb_build_object(
      'reason', 'The last message has not been read by everyone yet',
      'evidence', 'chat_participants.last_read_seq'));
  end if;
  if v_state = 'completed' then
    v_reasons := v_reasons || jsonb_build_array(jsonb_build_object(
      'reason', 'Every recorded commitment here closed with evidence',
      'evidence', 'chat_work_evidence'));
  end if;

  return jsonb_build_object(
    'conversation_id', _conversation,
    'title', coalesce(c.subject, 'Conversation'),
    'state', v_state,                       -- healthy | waiting | blocked | completed
    'owner', v_owner,
    'due_at', v_due,
    'open_items', v_open,
    'blocked_items', v_blocked,
    'overdue_items', v_overdue,
    'total_items', v_total,
    'last_message_at', last_msg.created_at,
    'reasons', v_reasons,
    'chain', case when public.chat_feature_ok(_user,'provenance_chain')
                  then public.conversation_chain_verify(_conversation, _user)
                  else null end);
end $$;

create or replace function public.conversation_health_board(_user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from public.chat_members where user_id = _user limit 1;
  if v_ws is null or not public.chat_feature_ok(_user, 'conversation_health') then
    return jsonb_build_object('plan', public.chat_feature_ok(_user,'conversation_health'),
      'timeline', public.chat_feature_ok(_user,'conversation_timeline'),
      'collision', public.chat_feature_ok(_user,'commitment_collision'),
      'conversations', '[]'::jsonb);
  end if;

  return jsonb_build_object(
    'plan', true,
    'timeline', public.chat_feature_ok(_user,'conversation_timeline'),
    'collision', public.chat_feature_ok(_user,'commitment_collision'),
    'conversations', coalesce((
      select jsonb_agg(h order by
               case h->>'state' when 'blocked' then 0 when 'waiting' then 1
                                when 'healthy' then 2 else 3 end,
               h->>'due_at')
        from (
          select public.conversation_health(c.id, _user) as h
            from public.chat_conversations c
           where c.workspace_id = v_ws
             and public.chat_in_conversation(c.id, _user)
           order by c.created_at desc
           limit 100) t), '[]'::jsonb));
end $$;

-- ===========================================================================
-- PHASE 26 — COMMITMENT COLLISION PREVENTION
--   Sirf ASLI rishta: chat_work_items.depends_on (insaan ne set kiya) ya
--   chat_decision_links. Engine dependency KABHI invent nahi karti.
-- ===========================================================================
create table if not exists public.commitment_collisions (
  id            uuid primary key default gen_random_uuid(),
  workspace_id  uuid not null references public.chat_workspaces(id) on delete cascade,
  item_id       uuid not null references public.chat_work_items(id) on delete cascade,
  blocker_id    uuid not null references public.chat_work_items(id) on delete cascade,
  relation      text not null default 'depends_on'
                check (relation in ('depends_on','decision_link')),
  severity      text not null default 'warning' check (severity in ('warning','critical')),
  evidence      jsonb not null default '{}'::jsonb,
  downstream    text,
  state         text not null default 'open'
                check (state in ('open','resolved','dismissed')),
  detected_at   timestamptz not null default now(),
  closed_at     timestamptz,
  closed_by     uuid references auth.users(id) on delete set null,
  close_reason  text,
  unique (item_id, blocker_id, relation)
);
create index if not exists commitment_collisions_ws_idx
  on public.commitment_collisions (workspace_id, state, detected_at desc);

grant select on public.commitment_collisions to authenticated;
grant all on public.commitment_collisions to service_role;

alter table public.commitment_collisions enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='commitment_collisions' and policyname='collision_read') then
    execute $p$create policy collision_read on public.commitment_collisions
      for select to authenticated
      using (exists (select 1 from public.chat_work_items w
                      where w.id = item_id
                        and public.chat_in_conversation(w.conversation_id, auth.uid())))$p$;
  end if;
end $$;

create table if not exists public.commitment_collision_events (
  id           bigserial primary key,
  collision_id uuid not null references public.commitment_collisions(id) on delete cascade,
  actor_id     uuid references auth.users(id) on delete set null,
  action       text not null check (action in
                 ('detected','viewed_source','resolve_dependency','change_deadline',
                  'reassign','dismiss','reopened')),
  reason       text,
  detail       jsonb not null default '{}'::jsonb,
  at           timestamptz not null default now()
);
create index if not exists commitment_collision_events_idx
  on public.commitment_collision_events (collision_id, id desc);

grant select on public.commitment_collision_events to authenticated;
grant all on public.commitment_collision_events to service_role;
grant usage, select on sequence public.commitment_collision_events_id_seq to service_role;

alter table public.commitment_collision_events enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='commitment_collision_events' and policyname='collision_log_read') then
    execute $p$create policy collision_log_read on public.commitment_collision_events
      for select to authenticated
      using (exists (select 1 from public.commitment_collisions x
                      join public.chat_work_items w on w.id = x.item_id
                     where x.id = collision_id
                       and public.chat_in_conversation(w.conversation_id, auth.uid())))$p$;
  end if;
end $$;

-- ledger append-only
create or replace function public.collision_log_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'collision_ledger_is_append_only';
end $$;

drop trigger if exists commitment_collision_events_immutable on public.commitment_collision_events;
create trigger commitment_collision_events_immutable
  before update or delete on public.commitment_collision_events
  for each row execute function public.collision_log_immutable();

/*
 * Detect: sirf woh jodi jahan insaan ne rishta likha ho AUR blocker khatra ho
 * (overdue ya blocker ki deadline dependent ke baad). Engine flag karti hai,
 * faisla insaan karta hai.
 */
create or replace function public.commitment_collision_scan(
  _user uuid, _conversation uuid default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_ws uuid; r record; n int := 0; v_id uuid;
begin
  if not public.chat_feature_ok(_user, 'commitment_collision') then
    return jsonb_build_object('plan', false, 'collisions', '[]'::jsonb);
  end if;
  select workspace_id into v_ws from public.chat_members where user_id = _user limit 1;
  if v_ws is null then
    return jsonb_build_object('plan', true, 'collisions', '[]'::jsonb);
  end if;

  for r in
    select w.id as item_id, w.title as item_title, w.due_at as item_due,
           w.owner_user_id as item_owner, w.conversation_id,
           b.id as blocker_id, b.title as blocker_title, b.due_at as blocker_due,
           b.owner_user_id as blocker_owner, b.state as blocker_state,
           b.kind as blocker_kind, b.original_due_at as blocker_original_due
      from public.chat_work_items w
      join public.chat_work_items b on b.id = w.depends_on
     where w.workspace_id = v_ws
       and w.state in ('open','blocked')
       and b.state in ('open','blocked')
       and (_conversation is null or w.conversation_id = _conversation)
       and public.chat_in_conversation(w.conversation_id, _user)
       and (
         (b.due_at is not null and b.due_at < now())                       -- blocker overdue
         or (w.due_at is not null and b.due_at is not null and b.due_at >= w.due_at)
         or (w.due_at is not null and b.due_at is null)                    -- blocker bina deadline
       )
  loop
    insert into public.commitment_collisions
      (workspace_id, item_id, blocker_id, relation, severity, downstream, evidence)
    values (v_ws, r.item_id, r.blocker_id, 'depends_on',
      case when r.blocker_due is not null and r.blocker_due < now() then 'critical' else 'warning' end,
      r.item_title,
      jsonb_build_object(
        'link', 'human_recorded_dependency',
        'item', jsonb_build_object('id', r.item_id, 'title', r.item_title, 'due_at', r.item_due,
          'owner', (select u.email from auth.users u where u.id = r.item_owner)),
        'blocker', jsonb_build_object('id', r.blocker_id, 'title', r.blocker_title,
          'kind', r.blocker_kind, 'state', r.blocker_state, 'due_at', r.blocker_due,
          'original_due_at', r.blocker_original_due,
          'owner', (select u.email from auth.users u where u.id = r.blocker_owner)),
        'why', case
          when r.blocker_due is not null and r.blocker_due < now()
            then 'The commitment this one depends on is already past its deadline.'
          when r.blocker_due is null
            then 'The commitment this one depends on has no deadline at all.'
          else 'The commitment this one depends on is due at or after this deadline.' end))
    on conflict (item_id, blocker_id, relation) do update
      set severity = excluded.severity,
          evidence = excluded.evidence,
          state = case when commitment_collisions.state = 'dismissed'
                       then 'dismissed' else 'open' end
    returning id into v_id;

    if v_id is not null then
      n := n + 1;
      insert into public.commitment_collision_events (collision_id, actor_id, action, detail)
      select v_id, null, 'detected', jsonb_build_object('scanned_by', _user)
       where not exists (select 1 from public.commitment_collision_events
                          where collision_id = v_id and action = 'detected');
    end if;
  end loop;

  return jsonb_build_object(
    'plan', true,
    'engine_invents_dependencies', false,
    'scanned', n,
    'collisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', x.id, 'state', x.state, 'severity', x.severity, 'relation', x.relation,
        'downstream', x.downstream, 'evidence', x.evidence, 'detected_at', x.detected_at,
        'item_id', x.item_id, 'blocker_id', x.blocker_id,
        'conversation_id', (select w.conversation_id from public.chat_work_items w where w.id = x.item_id),
        'source_message', (select w.message_id from public.chat_work_items w where w.id = x.blocker_id),
        'log', coalesce((select jsonb_agg(jsonb_build_object('action', e.action, 'reason', e.reason,
                  'at', e.at) order by e.id desc)
                  from public.commitment_collision_events e where e.collision_id = x.id), '[]'::jsonb))
        order by case x.severity when 'critical' then 0 else 1 end, x.detected_at desc)
        from public.commitment_collisions x
        join public.chat_work_items w on w.id = x.item_id
       where x.workspace_id = v_ws
         and x.state <> 'resolved'
         and (_conversation is null or w.conversation_id = _conversation)
         and public.chat_in_conversation(w.conversation_id, _user)), '[]'::jsonb));
end $$;

/*
 * Amal: resolve_dependency · change_deadline · reassign · dismiss.
 * Har ek insaan ka, 8+ character wajah ke saath, ledger append-only.
 * Deadline/owner ki tabdeeli Phase 23 ke promise_recover se hoti hai — wahan
 * original_due_at kabhi overwrite nahi hota.
 */
create or replace function public.commitment_collision_act(
  _collision uuid, _user uuid, _action text, _reason text,
  _new_due timestamptz default null, _new_owner uuid default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare x record; w record; v_res jsonb;
begin
  if not public.chat_feature_ok(_user, 'commitment_collision') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;
  if _action not in ('resolve_dependency','change_deadline','reassign','dismiss','viewed_source') then
    return jsonb_build_object('ok', false, 'error', 'bad_action');
  end if;
  select * into x from public.commitment_collisions where id = _collision;
  if x.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  select * into w from public.chat_work_items where id = x.item_id;
  if not public.chat_in_conversation(w.conversation_id, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;

  if _action = 'viewed_source' then
    insert into public.commitment_collision_events (collision_id, actor_id, action)
    values (_collision, _user, 'viewed_source');
    return jsonb_build_object('ok', true, 'message_id', w.message_id,
      'conversation_id', w.conversation_id);
  end if;

  if _reason is null or length(btrim(_reason)) < 8 then
    return jsonb_build_object('ok', false, 'error', 'reason_required',
      'message', 'Har amal 8+ character wajah ke saath likha jata hai.');
  end if;

  if _action = 'change_deadline' then
    if _new_due is null then return jsonb_build_object('ok', false, 'error', 'due_required'); end if;
    v_res := public.promise_recover(x.item_id, _user, 'deadline', btrim(_reason), _new_due, null);
    if coalesce((v_res->>'ok')::boolean, false) is not true then return v_res; end if;
  elsif _action = 'reassign' then
    if _new_owner is null then return jsonb_build_object('ok', false, 'error', 'owner_required'); end if;
    v_res := public.promise_recover(x.item_id, _user, 'reassign', btrim(_reason), null, _new_owner);
    if coalesce((v_res->>'ok')::boolean, false) is not true then return v_res; end if;
  elsif _action = 'resolve_dependency' then
    -- rishta khatam karna bhi insaani faisla hai; kaam ki tareekh nahi badalti
    update public.chat_work_items
       set depends_on = null,
           state = case when state = 'blocked' then 'open' else state end
     where id = x.item_id;
  end if;

  update public.commitment_collisions
     set state = case _action when 'dismiss' then 'dismissed' else 'resolved' end,
         closed_at = now(), closed_by = _user, close_reason = btrim(_reason)
   where id = _collision;

  insert into public.commitment_collision_events (collision_id, actor_id, action, reason, detail)
  values (_collision, _user, _action, btrim(_reason),
    jsonb_build_object('new_due', _new_due, 'new_owner', _new_owner, 'result', v_res));

  return jsonb_build_object('ok', true, 'collision_id', _collision, 'action', _action,
    'result', v_res);
end $$;

-- ---------------------------------------------------------------------------
-- grants
-- ---------------------------------------------------------------------------
grant execute on function public.chat_provenance_seal(uuid) to authenticated, service_role;
grant execute on function public.chat_provenance_backfill(uuid) to service_role;
grant execute on function public.message_provenance(uuid, uuid) to authenticated, service_role;
grant execute on function public.conversation_chain_verify(uuid, uuid) to authenticated, service_role;
grant execute on function public.message_mark_important(uuid, uuid, text, boolean) to authenticated, service_role;
grant execute on function public.conversation_timeline(uuid, uuid, text, int) to authenticated, service_role;
grant execute on function public.conversation_health(uuid, uuid) to authenticated, service_role;
grant execute on function public.conversation_health_board(uuid) to authenticated, service_role;
grant execute on function public.commitment_collision_scan(uuid, uuid) to authenticated, service_role;
grant execute on function public.commitment_collision_act(uuid, uuid, text, text, timestamptz, uuid) to authenticated, service_role;

-- purane messages seal karo (ek dafa; dobara chalane par kuch nahi hota)
select public.chat_provenance_backfill(null);

-- ============================================================================
-- PHASE 25/26/27 LOCKED:
--   timeline kuch invent nahi karti (communication ≠ outcome, dono ka record) ·
--   health sirf sabit cheez se (reasons + evidence) · collision sirf insaani
--   dependency par, har amal 8+ char wajah ke saath append-only ledger mein ·
--   provenance per-conversation sealed hash chain (append-only, tamper-evident).
-- ============================================================================
