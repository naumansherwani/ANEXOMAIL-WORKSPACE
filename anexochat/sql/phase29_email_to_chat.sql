-- ============================================================================
-- ANEXOCHAT · PHASE 29 — EMAIL → CHAT (bridge, formal record stays in mail)
--
--   ANEXOMAIL thread → "Discuss in ANEXOChat" → relevant conversation.
--   Email = FORMAL RECORD. Chat = INSTANT COMMUNICATION LAYER.
--
-- Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
-- Transport: RUST-FIRST — `/rpc/chat.bridge.*` (axum, :3200, QUIC/WT) PRIMARY;
-- Bun `/api/chat/bridge/*` sirf fallback.
--
-- LOCK (non-negotiable):
--   1. BIDIRECTIONAL STITCHING: email thread aur chat conversation ka ek hi
--      permanent link row. Duplicate link kabhi nahi (unique index), aur ek hi
--      work object dono taraf.
--   2. FORMALITY BOUNDARY: chat mein khula email context hamesha likhta hai
--      "Formal record lives in ANEXOMAIL" + mail message id. Chat kabhi apne
--      aap ko formal record nahi kehta.
--   3. QUOTE-WITH-PROVENANCE: email ka hissa quote karte waqt asli body ka
--      SHA256 saath jata hai. Baad mein farq ho to UI sach bolta hai.
--   4. PRESENCE: sirf asli `chat_presence` rows. Jo user account mein nahi hai
--      uske liye "no ANEXOChat account on record" — invite guess nahi.
--   5. SILENT-THREAD RESCUE: conversation + owner + due date sirf insaan ke
--      confirm par bante hain; engine khud kabhi owner ya deadline nahi chunti.
--   6. mail_* tables ANEXOMAIL ke hain — yeh file unhe defensive tarah se
--      padhti hai (to_regclass), aur na milne par sach likhti hai.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'email_chat_bridge', false, null, 'ANEXOChat included nahi'),
  ('pro',          'email_chat_bridge', false, null, 'ANEXOChat included nahi'),
  ('business',     'email_chat_bridge', true,  null, 'Discuss in ANEXOChat + stitched thread'),
  ('business_pro', 'email_chat_bridge', true,  null, null),
  ('ai_pro',       'email_chat_bridge', true,  null, null),
  ('ai_business',  'email_chat_bridge', true,  null, null),
  ('ai_executive', 'email_chat_bridge', true,  null, null),
  ('founder',      'email_chat_bridge', true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ---------------------------------------------------------------------------
-- 1) helper — mail thread ka subject (mail_* na ho to sach bolo)
-- ---------------------------------------------------------------------------
create or replace function public.mail_thread_subject_safe(_thread uuid)
returns text language plpgsql stable security definer
set search_path = public, extensions as $$
declare v text;
begin
  if to_regclass('public.mail_threads') is null then return null; end if;
  begin
    execute 'select subject from public.mail_threads where id = $1' into v using _thread;
  exception when others then
    return null;
  end;
  return v;
end $$;

-- ---------------------------------------------------------------------------
-- 2) permanent two-way link (email thread ↔ chat conversation)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_email_links (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  mail_thread_id  uuid not null,
  mail_message_id uuid,
  work_item_id    uuid references public.chat_work_items(id) on delete set null,
  origin          text not null default 'email_to_chat'
                  check (origin in ('email_to_chat','chat_to_email')),
  subject_snapshot text,
  created_by      uuid not null references auth.users(id) on delete restrict,
  created_at      timestamptz not null default now(),
  removed_at      timestamptz,
  removed_by      uuid references auth.users(id) on delete set null,
  removed_reason  text
);
create unique index if not exists chat_email_links_uq
  on public.chat_email_links (mail_thread_id, conversation_id)
  where removed_at is null;
create index if not exists chat_email_links_conv_idx
  on public.chat_email_links (conversation_id, created_at desc);

grant select on public.chat_email_links to authenticated;
grant all on public.chat_email_links to service_role;
alter table public.chat_email_links enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'chat_email_links' and policyname = 'email_link_read') then
    create policy "email_link_read" on public.chat_email_links
      for select to authenticated using (
        exists (select 1 from public.chat_participants p
                 where p.conversation_id = chat_email_links.conversation_id
                   and p.user_id = auth.uid()));
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) quote-with-provenance (email ka hissa chat mein)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_email_quotes (
  id              uuid primary key default gen_random_uuid(),
  message_id      uuid not null references public.chat_messages(id) on delete cascade,
  mail_thread_id  uuid not null,
  mail_message_id uuid,
  quoted_text     text not null,
  quoted_hash     text not null,          -- sha256(asli email body ka hissa)
  quoted_by       uuid not null references auth.users(id) on delete restrict,
  at              timestamptz not null default now()
);
create index if not exists chat_email_quotes_msg_idx
  on public.chat_email_quotes (message_id);

grant select on public.chat_email_quotes to authenticated;
grant all on public.chat_email_quotes to service_role;
alter table public.chat_email_quotes enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'chat_email_quotes' and policyname = 'email_quote_read') then
    create policy "email_quote_read" on public.chat_email_quotes
      for select to authenticated using (
        exists (select 1 from public.chat_messages m
                 join public.chat_participants p on p.conversation_id = m.conversation_id
                where m.id = chat_email_quotes.message_id and p.user_id = auth.uid()));
  end if;
end $$;

create or replace function public.chat_email_quotes_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'chat_email_quotes is append-only';
end $$;
drop trigger if exists chat_email_quotes_no_change on public.chat_email_quotes;
create trigger chat_email_quotes_no_change
  before update or delete on public.chat_email_quotes
  for each row execute function public.chat_email_quotes_immutable();

-- ---------------------------------------------------------------------------
-- 4) DISCUSS IN ANEXOCHAT — email thread se conversation kholna/jodna
-- ---------------------------------------------------------------------------
create or replace function public.email_discuss_in_chat(
  _user uuid, _mail_thread uuid, _mail_message uuid default null,
  _conversation uuid default null, _subject text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_ws uuid; v_link record; v_conv uuid; v_subject text; v_created boolean := false;
begin
  if not public.chat_feature_ok(_user, 'email_chat_bridge') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;
  if _mail_thread is null then
    return jsonb_build_object('ok', false, 'error', 'mail_thread_required');
  end if;
  select workspace_id into v_ws from public.chat_members where user_id = _user limit 1;
  if v_ws is null then return jsonb_build_object('ok', false, 'error', 'no_workspace'); end if;

  -- pehle se link hai? duplicate kabhi nahi
  select * into v_link from public.chat_email_links
   where mail_thread_id = _mail_thread and removed_at is null
   order by created_at limit 1;

  if found then
    v_conv := v_link.conversation_id;
  else
    v_subject := coalesce(nullif(trim(coalesce(_subject, '')), ''),
                          public.mail_thread_subject_safe(_mail_thread),
                          'Email discussion');
    if _conversation is not null then
      if not public.chat_in_conversation(_conversation, _user) then
        return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
      end if;
      v_conv := _conversation;
    else
      insert into public.chat_conversations (workspace_id, kind, subject, created_by)
      values (v_ws, 'group', v_subject, _user)
      returning id into v_conv;
      insert into public.chat_participants (conversation_id, user_id)
      values (v_conv, _user) on conflict do nothing;
      v_created := true;
    end if;

    insert into public.chat_email_links (workspace_id, conversation_id, mail_thread_id,
      mail_message_id, origin, subject_snapshot, created_by)
    values (v_ws, v_conv, _mail_thread, _mail_message, 'email_to_chat', v_subject, _user)
    on conflict do nothing;

    select * into v_link from public.chat_email_links
     where mail_thread_id = _mail_thread and conversation_id = v_conv and removed_at is null
     limit 1;
  end if;

  return jsonb_build_object('ok', true,
    'conversation_id', v_conv,
    'conversation_created', v_created,
    'link_id', v_link.id,
    'mail_thread_id', _mail_thread,
    'mail_message_id', coalesce(_mail_message, v_link.mail_message_id),
    'formal_record', 'ANEXOMAIL',
    'badge', 'Formal record lives in ANEXOMAIL',
    'chat_role', 'instant communication layer');
end $$;

-- conversation ka email context (formality boundary badge)
create or replace function public.email_chat_context(_conversation uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_links jsonb; v_quotes jsonb;
begin
  if not public.chat_in_conversation(_conversation, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'link_id', l.id, 'mail_thread_id', l.mail_thread_id,
           'mail_message_id', l.mail_message_id, 'origin', l.origin,
           'subject', coalesce(public.mail_thread_subject_safe(l.mail_thread_id), l.subject_snapshot),
           'subject_source', case when public.mail_thread_subject_safe(l.mail_thread_id) is null
                                  then 'snapshot at link time' else 'live mail record' end,
           'work_item_id', l.work_item_id,
           'created_at', l.created_at) order by l.created_at), '[]'::jsonb)
    into v_links from public.chat_email_links l
   where l.conversation_id = _conversation and l.removed_at is null;

  select coalesce(jsonb_agg(jsonb_build_object(
           'quote_id', q.id, 'message_id', q.message_id,
           'mail_message_id', q.mail_message_id, 'quoted_hash', q.quoted_hash,
           'at', q.at) order by q.at desc), '[]'::jsonb)
    into v_quotes from public.chat_email_quotes q
    join public.chat_messages m on m.id = q.message_id
   where m.conversation_id = _conversation;

  return jsonb_build_object(
    'conversation_id', _conversation,
    'links', v_links,
    'quotes', v_quotes,
    'formal_record', 'ANEXOMAIL',
    'badge', 'Formal record lives in ANEXOMAIL',
    'chat_is_formal_record', false);
end $$;

-- ---------------------------------------------------------------------------
-- 5) QUOTE-WITH-PROVENANCE
-- ---------------------------------------------------------------------------
create or replace function public.email_quote_to_chat(
  _user uuid, _message uuid, _mail_thread uuid, _quoted_text text,
  _mail_message uuid default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_conv uuid; v_hash text; v_id uuid;
begin
  select conversation_id into v_conv from public.chat_messages where id = _message;
  if v_conv is null then return jsonb_build_object('ok', false, 'error', 'message_not_found'); end if;
  if not public.chat_in_conversation(v_conv, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;
  if coalesce(length(trim(coalesce(_quoted_text, ''))), 0) = 0 then
    return jsonb_build_object('ok', false, 'error', 'quoted_text_required');
  end if;

  v_hash := encode(digest(_quoted_text, 'sha256'), 'hex');
  insert into public.chat_email_quotes (message_id, mail_thread_id, mail_message_id,
    quoted_text, quoted_hash, quoted_by)
  values (_message, _mail_thread, _mail_message, _quoted_text, v_hash, _user)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'quote_id', v_id, 'quoted_hash', v_hash,
    'formal_record', 'ANEXOMAIL', 'mail_message_id', _mail_message);
end $$;

-- quote aaj bhi asli email body se match karta hai? (caller asli body deta hai)
create or replace function public.email_quote_verify(_quote uuid, _current_text text)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare q record; v_now text;
begin
  select * into q from public.chat_email_quotes where id = _quote;
  if not found then return jsonb_build_object('error', 'quote_not_found'); end if;
  if _current_text is null then
    return jsonb_build_object('quote_id', _quote, 'quoted_hash', q.quoted_hash,
      'match', null, 'note', 'No current text supplied to compare.');
  end if;
  v_now := encode(digest(_current_text, 'sha256'), 'hex');
  return jsonb_build_object('quote_id', _quote, 'quoted_hash', q.quoted_hash,
    'current_hash', v_now, 'match', v_now = q.quoted_hash,
    'note', case when v_now = q.quoted_hash
                 then 'Quote still matches the recorded email text.'
                 else 'The email text no longer matches what was quoted here.' end);
end $$;

-- ---------------------------------------------------------------------------
-- 6) DISCUSS-IN-CHAT PRESENCE — sirf asli presence rows
-- ---------------------------------------------------------------------------
create or replace function public.email_discuss_presence(_user uuid, _emails text[])
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_ws uuid; v_rows jsonb;
begin
  if not public.chat_feature_ok(_user, 'email_chat_bridge') then
    return jsonb_build_object('error', 'plan_not_allowed');
  end if;
  select workspace_id into v_ws from public.chat_members where user_id = _user limit 1;
  if v_ws is null then return jsonb_build_object('error', 'no_workspace'); end if;

  select coalesce(jsonb_agg(x order by x->>'email'), '[]'::jsonb) into v_rows from (
    select jsonb_build_object(
             'email', e.email,
             'user_id', u.id,
             'has_anexochat_account', u.id is not null,
             'in_workspace', m.user_id is not null,
             'last_seen_at', pr.last_seen_at,
             'presence', case
               when u.id is null then 'no ANEXOChat account on record'
               when m.user_id is null then 'not a member of this workspace'
               when pr.last_seen_at is null then 'no presence recorded'
               when pr.last_seen_at > now() - interval '2 minutes' then 'online'
               else 'last seen ' || to_char(pr.last_seen_at at time zone 'utc', 'HH24:MI') || ' UTC'
             end) as x
      from unnest(coalesce(_emails, '{}'::text[])) as e(email)
      left join auth.users u on lower(u.email) = lower(e.email)
      left join public.chat_members m on m.user_id = u.id and m.workspace_id = v_ws
      left join public.chat_presence pr on pr.user_id = u.id and pr.workspace_id = v_ws) t;

  return jsonb_build_object('people', v_rows, 'invites_guessed', false);
end $$;

-- ---------------------------------------------------------------------------
-- 7) SILENT-THREAD RESCUE — insaan confirm karta hai (owner + due lazmi)
-- ---------------------------------------------------------------------------
create or replace function public.silent_thread_rescue(
  _user uuid, _mail_thread uuid, _title text, _owner uuid, _due timestamptz,
  _mail_message uuid default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_open jsonb; v_conv uuid; v_ws uuid; v_item uuid;
begin
  if coalesce(length(trim(coalesce(_title, ''))), 0) < 3 then
    return jsonb_build_object('ok', false, 'error', 'title_required');
  end if;
  if _owner is null or _due is null then
    return jsonb_build_object('ok', false, 'error', 'owner_and_due_required',
      'note', 'Engine never picks an owner or a deadline.');
  end if;

  v_open := public.email_discuss_in_chat(_user, _mail_thread, _mail_message, null, _title);
  if coalesce((v_open->>'ok')::boolean, false) is not true then return v_open; end if;
  v_conv := (v_open->>'conversation_id')::uuid;
  select workspace_id into v_ws from public.chat_conversations where id = v_conv;

  insert into public.chat_participants (conversation_id, user_id)
  values (v_conv, _owner) on conflict do nothing;

  insert into public.chat_work_items (workspace_id, conversation_id, kind, title,
    owner_user_id, due_at, created_by)
  values (v_ws, v_conv, 'task', trim(_title), _owner, _due, _user)
  returning id into v_item;

  update public.chat_email_links set work_item_id = v_item
   where mail_thread_id = _mail_thread and conversation_id = v_conv and removed_at is null
     and work_item_id is null;

  return jsonb_build_object('ok', true, 'conversation_id', v_conv, 'work_item_id', v_item,
    'owner', _owner, 'due_at', _due, 'confirmed_by_human', true,
    'formal_record', 'ANEXOMAIL');
end $$;

-- email thread se conversation dhoondna (ANEXOMAIL side ka "Discuss" button)
create or replace function public.email_thread_conversation(_user uuid, _mail_thread uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare l record;
begin
  select * into l from public.chat_email_links
   where mail_thread_id = _mail_thread and removed_at is null
   order by created_at limit 1;
  if not found then
    return jsonb_build_object('linked', false, 'mail_thread_id', _mail_thread,
      'note', 'No ANEXOChat conversation is linked to this email thread yet.');
  end if;
  return jsonb_build_object('linked', true, 'conversation_id', l.conversation_id,
    'link_id', l.id, 'work_item_id', l.work_item_id,
    'may_open', public.chat_in_conversation(l.conversation_id, _user),
    'formal_record', 'ANEXOMAIL');
end $$;

-- ---------------------------------------------------------------------------
-- grants
-- ---------------------------------------------------------------------------
grant execute on function
  public.mail_thread_subject_safe(uuid),
  public.email_discuss_in_chat(uuid, uuid, uuid, uuid, text),
  public.email_chat_context(uuid, uuid),
  public.email_quote_to_chat(uuid, uuid, uuid, text, uuid),
  public.email_quote_verify(uuid, text),
  public.email_discuss_presence(uuid, text[]),
  public.silent_thread_rescue(uuid, uuid, text, uuid, timestamptz, uuid),
  public.email_thread_conversation(uuid, uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- VERIFY
-- ---------------------------------------------------------------------------
-- select count(*) from information_schema.tables where table_schema='public'
--   and table_name in ('chat_email_links','chat_email_quotes');            -- 2
-- select public.email_discuss_presence('3e3a60ea-1580-4443-94f6-b758de732dce',
--   array['someone@example.com']);
