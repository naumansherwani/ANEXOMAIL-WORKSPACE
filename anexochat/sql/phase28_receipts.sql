-- ============================================================================
-- ANEXOCHAT · PHASE 28 — BUSINESS CONVERSATION RECEIPTS (+ ZERO-LOSS HANDOVER)
--
--   Message:     ✓ Sent   ✓ Delivered   ✓ Read
--   Attachment:  ✓ Uploaded  ✓ Scanned  ✓ Verified  ✓ Available
--
--   Core principle: don't just say it happened — SHOW what happened.
--
-- Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
-- Transport: RUST-FIRST — `/rpc/chat.receipt.*` · `/rpc/chat.handover.*`
-- (axum, :3200, WebTransport/QUIC udp 3443) PRIMARY; Bun `/api/chat/*` fallback.
--
-- LOCK (non-negotiable):
--   1. Har step ka asli record: sent = `chat_messages.created_at`,
--      delivered/read = `chat_message_receipts`, file steps = `file_evidence`.
--      Koi step guess nahi hota; jo record nahi hua woh "Not recorded" hai.
--   2. NEGATIVE RECEIPTS: jo nahi hua woh bhi likha jata hai — "Not delivered
--      (recipient offline HH:MM → HH:MM)" — asli presence window ke saath.
--   3. PER-DEVICE RECEIPT TRUTH: sirf 5 coarse signals ki do sifat —
--      platform_class + timezone bucket. Biometric/device fingerprinting MANA.
--   4. RECEIPT CHAIN CERTIFICATE: per-conversation hash-linked certificate
--      Phase 27 ke sealed chain se banta hai; bahar (client/court) verify hota
--      hai bina login — verifier ko sirf hashes chahiye, message body nahi.
--   5. READ-WITHOUT-RESPONSE: padha gaya magar N ghanton tak jawab nahi — yeh
--      evidence hai, ilzaam nahi. Lafz "ignored" kabhi nahi.
--   6. RECEIPT REPLAY: frames sirf receipts/evidence rows se; engine kuch
--      invent nahi karti.
--   7. HANDOVER PACK: har item apna source/provenance le kar aata hai aur
--      status hamesha alag: confirmed_fact · pending · overdue ·
--      historical_decision · open_dependency. Missing context FABRICATE nahi.
--      Assign + complete insaan karta hai, ledger append-only.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'receipt_pack', false, null, 'ANEXOChat included nahi'),
  ('pro',          'receipt_pack', false, null, 'ANEXOChat included nahi'),
  ('business',     'receipt_pack', true,  null, 'sent · delivered · read + file evidence'),
  ('business_pro', 'receipt_pack', true,  null, null),
  ('ai_pro',       'receipt_pack', true,  null, null),
  ('ai_business',  'receipt_pack', true,  null, null),
  ('ai_executive', 'receipt_pack', true,  null, null),
  ('founder',      'receipt_pack', true,  null, null),

  ('basic',        'receipt_certificate', false, null, null),
  ('pro',          'receipt_certificate', false, null, null),
  ('business',     'receipt_certificate', false, null, 'Business Pro / AI Business se'),
  ('business_pro', 'receipt_certificate', true,  null, 'externally verifiable hash chain'),
  ('ai_pro',       'receipt_certificate', false, null, null),
  ('ai_business',  'receipt_certificate', true,  null, null),
  ('ai_executive', 'receipt_certificate', true,  null, null),
  ('founder',      'receipt_certificate', true,  null, null),

  ('basic',        'receipt_replay', false, null, null),
  ('pro',          'receipt_replay', false, null, null),
  ('business',     'receipt_replay', true,  400,  'delivery-state history frames'),
  ('business_pro', 'receipt_replay', true,  2000, null),
  ('ai_pro',       'receipt_replay', true,  400,  null),
  ('ai_business',  'receipt_replay', true,  2000, null),
  ('ai_executive', 'receipt_replay', true,  5000, null),
  ('founder',      'receipt_replay', true,  5000, null),

  ('basic',        'handover_pack', false, null, null),
  ('pro',          'handover_pack', false, null, null),
  ('business',     'handover_pack', true,  null, 'zero-loss handover pack'),
  ('business_pro', 'handover_pack', true,  null, null),
  ('ai_pro',       'handover_pack', true,  null, null),
  ('ai_business',  'handover_pack', true,  null, null),
  ('ai_executive', 'handover_pack', true,  null, null),
  ('founder',      'handover_pack', true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ---------------------------------------------------------------------------
-- 1) per-device receipt truth (sirf coarse: platform class + tz bucket)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_receipt_devices (
  message_id     uuid not null references public.chat_messages(id) on delete cascade,
  user_id        uuid not null references auth.users(id) on delete cascade,
  state          text not null check (state in ('delivered','read')),
  platform_class text not null default 'unknown',   -- desktop | mobile | tablet | unknown
  tz_bucket      text not null default 'unknown',   -- e.g. UTC+05
  at             timestamptz not null default now(),
  primary key (message_id, user_id, state)
);
create index if not exists chat_receipt_devices_msg_idx
  on public.chat_receipt_devices (message_id);

grant select on public.chat_receipt_devices to authenticated;
grant all on public.chat_receipt_devices to service_role;
alter table public.chat_receipt_devices enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'chat_receipt_devices' and policyname = 'receipt_device_read') then
    create policy "receipt_device_read" on public.chat_receipt_devices
      for select to authenticated using (
        exists (select 1 from public.chat_messages m
                 join public.chat_participants p on p.conversation_id = m.conversation_id
                where m.id = chat_receipt_devices.message_id and p.user_id = auth.uid()));
  end if;
end $$;

-- append-only: device receipt row kabhi badalti nahi
create or replace function public.chat_receipt_devices_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'chat_receipt_devices is append-only';
end $$;
drop trigger if exists chat_receipt_devices_no_change on public.chat_receipt_devices;
create trigger chat_receipt_devices_no_change
  before update or delete on public.chat_receipt_devices
  for each row execute function public.chat_receipt_devices_immutable();

-- ---------------------------------------------------------------------------
-- 2) message ↔ file link (attachment receipts ka asli rishta)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_message_files (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  version_id uuid not null references public.chat_file_versions(id) on delete cascade,
  linked_by  uuid not null references auth.users(id) on delete cascade,
  at         timestamptz not null default now(),
  primary key (message_id, version_id)
);
grant select on public.chat_message_files to authenticated;
grant all on public.chat_message_files to service_role;
alter table public.chat_message_files enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'chat_message_files' and policyname = 'message_files_read') then
    create policy "message_files_read" on public.chat_message_files
      for select to authenticated using (
        exists (select 1 from public.chat_messages m
                 join public.chat_participants p on p.conversation_id = m.conversation_id
                where m.id = chat_message_files.message_id and p.user_id = auth.uid()));
  end if;
end $$;

create or replace function public.message_attach_file(_user uuid, _message uuid, _version uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_conv uuid;
begin
  select conversation_id into v_conv from public.chat_messages where id = _message;
  if v_conv is null then return jsonb_build_object('ok', false, 'error', 'message_not_found'); end if;
  if not public.chat_in_conversation(v_conv, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;
  if not exists (select 1 from public.chat_file_versions where id = _version) then
    return jsonb_build_object('ok', false, 'error', 'version_not_found');
  end if;
  insert into public.chat_message_files (message_id, version_id, linked_by)
  values (_message, _version, _user)
  on conflict (message_id, version_id) do nothing;
  return jsonb_build_object('ok', true, 'message_id', _message, 'version_id', _version);
end $$;

-- ---------------------------------------------------------------------------
-- 3) receipt record (per-device) — Rust `chat.receipt.record`
--    Sirf coarse signals; kuch aur store nahi hota.
-- ---------------------------------------------------------------------------
create or replace function public.receipt_device_record(
  _user uuid, _message uuid, _state text,
  _platform_class text default null, _tz_bucket text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_conv uuid;
begin
  if _state not in ('delivered','read') then
    return jsonb_build_object('ok', false, 'error', 'state_must_be_delivered_or_read');
  end if;
  select conversation_id into v_conv from public.chat_messages where id = _message;
  if v_conv is null then return jsonb_build_object('ok', false, 'error', 'message_not_found'); end if;
  if not public.chat_in_conversation(v_conv, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;

  insert into public.chat_message_receipts (message_id, user_id, state)
  values (_message, _user, _state)
  on conflict (message_id, user_id, state) do nothing;

  insert into public.chat_receipt_devices (message_id, user_id, state, platform_class, tz_bucket)
  values (_message, _user, _state,
          coalesce(nullif(lower(_platform_class), ''), 'unknown'),
          coalesce(nullif(_tz_bucket, ''), 'unknown'))
  on conflict (message_id, user_id, state) do nothing;

  return jsonb_build_object('ok', true, 'message_id', _message, 'state', _state,
    'signals_stored', jsonb_build_array('platform_class', 'timezone_bucket'),
    'fingerprinting', false);
end $$;

-- ---------------------------------------------------------------------------
-- 4) RECEIPT PACK — positive + NEGATIVE receipts + attachment evidence chain
-- ---------------------------------------------------------------------------
create or replace function public.message_receipt_pack(_message uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  m record; v_steps jsonb := '[]'::jsonb; v_negative jsonb := '[]'::jsonb;
  v_files jsonb := '[]'::jsonb; r record; v_recipients int; v_delivered int; v_read int;
begin
  select mm.*, c.workspace_id as ws into m
    from public.chat_messages mm
    join public.chat_conversations c on c.id = mm.conversation_id
   where mm.id = _message;
  if not found then return jsonb_build_object('error', 'message_not_found'); end if;
  if not public.chat_in_conversation(m.conversation_id, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'receipt_pack') then
    return jsonb_build_object('error', 'plan_not_allowed');
  end if;

  select count(*) into v_recipients from public.chat_participants
   where conversation_id = m.conversation_id and user_id <> m.sender_user_id;
  select count(distinct user_id) into v_delivered from public.chat_message_receipts
   where message_id = _message and state = 'delivered';
  select count(distinct user_id) into v_read from public.chat_message_receipts
   where message_id = _message and state = 'read';

  -- ✓ Sent — asli row ka waqt (millisecond UTC)
  v_steps := v_steps || jsonb_build_object(
    'step', 'sent', 'recorded', true,
    'at', to_char(m.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'evidence', 'chat_messages.created_at');

  -- ✓ Delivered / ✓ Read — sirf receipts se
  v_steps := v_steps || jsonb_build_object(
    'step', 'delivered', 'recorded', v_delivered > 0,
    'at', (select to_char(min(at) at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
             from public.chat_message_receipts where message_id = _message and state = 'delivered'),
    'people', v_delivered, 'of', v_recipients, 'evidence', 'chat_message_receipts');

  v_steps := v_steps || jsonb_build_object(
    'step', 'read', 'recorded', v_read > 0,
    'at', (select to_char(min(at) at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
             from public.chat_message_receipts where message_id = _message and state = 'read'),
    'people', v_read, 'of', v_recipients, 'evidence', 'chat_message_receipts');

  -- NEGATIVE RECEIPTS — jo hua hi nahi, asli presence window ke saath
  for r in
    select p.user_id, u.email, pr.last_seen_at
      from public.chat_participants p
      join auth.users u on u.id = p.user_id
      left join public.chat_presence pr
             on pr.user_id = p.user_id and pr.workspace_id = m.ws
     where p.conversation_id = m.conversation_id
       and p.user_id <> m.sender_user_id
       and not exists (select 1 from public.chat_message_receipts x
                        where x.message_id = _message and x.user_id = p.user_id
                          and x.state = 'delivered')
  loop
    v_negative := v_negative || jsonb_build_object(
      'user_id', r.user_id, 'person', r.email, 'state', 'not_delivered',
      'window_from', to_char(m.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'window_to', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'last_seen_at', r.last_seen_at,
      'note', case when r.last_seen_at is null
                then 'No presence recorded for this person.'
                else 'Recipient was not present after this message was sent.' end,
      'evidence', 'chat_presence · chat_message_receipts (absent row)');
  end loop;

  -- read but no response (24h) — evidence, ilzaam nahi
  for r in
    select rr.user_id, u.email, rr.at
      from public.chat_message_receipts rr
      join auth.users u on u.id = rr.user_id
     where rr.message_id = _message and rr.state = 'read'
       and not exists (select 1 from public.chat_messages nm
                        where nm.conversation_id = m.conversation_id
                          and nm.sender_user_id = rr.user_id
                          and nm.created_at > rr.at)
       and rr.at < now() - interval '24 hours'
  loop
    v_negative := v_negative || jsonb_build_object(
      'user_id', r.user_id, 'person', r.email, 'state', 'read_without_response',
      'read_at', r.at, 'hours_since', round(extract(epoch from (now() - r.at)) / 3600.0, 1),
      'note', 'Read on record; no reply recorded in this conversation since.',
      'evidence', 'chat_message_receipts · chat_messages (absent reply)');
  end loop;

  -- ATTACHMENT CHAIN — file_evidence se, koi step guess nahi
  for r in
    select v.id as version_id, f.name, v.bytes, v.state as version_state
      from public.chat_message_files mf
      join public.chat_file_versions v on v.id = mf.version_id
      join public.chat_files f on f.id = v.file_id
     where mf.message_id = _message
  loop
    v_files := v_files || jsonb_build_object(
      'version_id', r.version_id, 'filename', r.name, 'bytes', r.bytes,
      'version_state', r.version_state,
      'steps', (
        select jsonb_agg(jsonb_build_object(
                 'step', s.state, 'recorded', e.at is not null, 'at', e.at,
                 'actor', e.actor, 'evidence', case when e.at is null then null else 'file_evidence' end)
                 order by s.ord)
          from (values ('uploaded',1),('scanning',2),('verified',3),('available',4),('downloaded',5)) as s(state, ord)
          left join public.file_evidence e
                 on e.version_id = r.version_id and e.state = s.state));
  end loop;

  return jsonb_build_object(
    'message_id', _message,
    'conversation_id', m.conversation_id,
    'recipients', v_recipients,
    'steps', v_steps,
    'negative_receipts', v_negative,
    'attachments', v_files,
    'engine_invents_nothing', true,
    'note', 'Steps without a record are shown as Not recorded.');
end $$;

-- ---------------------------------------------------------------------------
-- 5) READ-WITHOUT-RESPONSE detector (board) — Rust `chat.receipt.silent`
-- ---------------------------------------------------------------------------
create or replace function public.read_without_response(_user uuid, _hours int default 24)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_rows jsonb; v_h int := greatest(coalesce(_hours, 24), 1);
begin
  if not public.chat_feature_ok(_user, 'receipt_pack') then
    return jsonb_build_object('error', 'plan_not_allowed');
  end if;

  select coalesce(jsonb_agg(x order by x->>'read_at' desc), '[]'::jsonb) into v_rows from (
    select jsonb_build_object(
             'message_id', m.id, 'conversation_id', m.conversation_id,
             'title', coalesce(c.subject, 'Direct conversation'),
             'reader', u.email, 'reader_id', rr.user_id,
             'read_at', rr.at,
             'hours_since', round(extract(epoch from (now() - rr.at)) / 3600.0, 1),
             'evidence', 'chat_message_receipts · chat_messages (absent reply)') as x
      from public.chat_messages m
      join public.chat_conversations c on c.id = m.conversation_id
      join public.chat_message_receipts rr on rr.message_id = m.id and rr.state = 'read'
      join auth.users u on u.id = rr.user_id
     where m.sender_user_id = _user
       and rr.at < now() - make_interval(hours => v_h)
       and not exists (select 1 from public.chat_messages nm
                        where nm.conversation_id = m.conversation_id
                          and nm.sender_user_id = rr.user_id
                          and nm.created_at > rr.at)
     order by rr.at desc
     limit 200) t;

  return jsonb_build_object('hours', v_h, 'items', v_rows,
    'note', 'Measured silence, not intent. This is evidence for follow-up.');
end $$;

-- ---------------------------------------------------------------------------
-- 6) RECEIPT REPLAY — delivery-state history frame-by-frame
-- ---------------------------------------------------------------------------
create or replace function public.receipt_replay(_conversation uuid, _user uuid, _limit int default null)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_limit int; v_frames jsonb;
begin
  if not public.chat_in_conversation(_conversation, _user) then
    return jsonb_build_object('error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'receipt_replay') then
    return jsonb_build_object('error', 'plan_not_allowed');
  end if;
  v_limit := least(coalesce(_limit,
    coalesce((public.chat_feature_allowed(_user, 'receipt_replay')->>'limit')::int, 400)), 5000);

  select coalesce(jsonb_agg(f order by f->>'at'), '[]'::jsonb) into v_frames from (
    select jsonb_build_object('at', m.created_at, 'kind', 'sent',
             'message_id', m.id, 'seq', m.seq, 'actor', u.email,
             'evidence', 'chat_messages') as f
      from public.chat_messages m join auth.users u on u.id = m.sender_user_id
     where m.conversation_id = _conversation
    union all
    select jsonb_build_object('at', rr.at, 'kind', rr.state,
             'message_id', rr.message_id, 'seq', m.seq, 'actor', u.email,
             'device', jsonb_build_object('platform_class', d.platform_class, 'timezone_bucket', d.tz_bucket),
             'evidence', 'chat_message_receipts')
      from public.chat_message_receipts rr
      join public.chat_messages m on m.id = rr.message_id
      join auth.users u on u.id = rr.user_id
      left join public.chat_receipt_devices d
             on d.message_id = rr.message_id and d.user_id = rr.user_id and d.state = rr.state
     where m.conversation_id = _conversation
    order by 1
    limit v_limit) t;

  return jsonb_build_object('conversation_id', _conversation, 'frames', v_frames,
    'engine_invents_nothing', true);
end $$;

-- ---------------------------------------------------------------------------
-- 7) RECEIPT CHAIN CERTIFICATE — bahar verify hone wala hash certificate
--    Body kabhi shamil nahi; sirf hashes + counts + head hash.
-- ---------------------------------------------------------------------------
create table if not exists public.chat_receipt_certificates (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  workspace_id    uuid not null references public.chat_workspaces(id) on delete cascade,
  issued_by       uuid not null references auth.users(id) on delete restrict,
  issued_at       timestamptz not null default now(),
  from_seq        bigint not null,
  to_seq          bigint not null,
  message_count   int not null,
  delivered_count int not null,
  read_count      int not null,
  head_hash       text not null,       -- Phase 27 chain head
  certificate_hash text not null,      -- sha256(head || counts || issued_at)
  verify_token    text not null unique default replace(gen_random_uuid()::text, '-', '')
);
create index if not exists chat_receipt_certificates_conv_idx
  on public.chat_receipt_certificates (conversation_id, issued_at desc);

grant select on public.chat_receipt_certificates to authenticated;
grant all on public.chat_receipt_certificates to service_role;
alter table public.chat_receipt_certificates enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'chat_receipt_certificates' and policyname = 'cert_read') then
    create policy "cert_read" on public.chat_receipt_certificates
      for select to authenticated using (
        exists (select 1 from public.chat_participants p
                 where p.conversation_id = chat_receipt_certificates.conversation_id
                   and p.user_id = auth.uid()));
  end if;
end $$;

create or replace function public.chat_receipt_cert_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'chat_receipt_certificates is append-only';
end $$;
drop trigger if exists chat_receipt_cert_no_change on public.chat_receipt_certificates;
create trigger chat_receipt_cert_no_change
  before update or delete on public.chat_receipt_certificates
  for each row execute function public.chat_receipt_cert_immutable();

create or replace function public.receipt_certificate_issue(_conversation uuid, _user uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_chain jsonb; v_ws uuid; v_from bigint; v_to bigint;
        v_msgs int; v_del int; v_read int; v_id uuid; v_hash text; v_token text; v_head text;
begin
  if not public.chat_in_conversation(_conversation, _user) then
    return jsonb_build_object('ok', false, 'error', 'not_in_conversation');
  end if;
  if not public.chat_feature_ok(_user, 'receipt_certificate') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;

  v_chain := public.conversation_chain_verify(_conversation, _user);
  if v_chain ? 'error' then return jsonb_build_object('ok', false, 'error', v_chain->>'error'); end if;
  if coalesce((v_chain->>'chain_intact')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'error', 'chain_not_intact', 'chain', v_chain);
  end if;
  v_head := v_chain->>'head_hash';
  if v_head is null then return jsonb_build_object('ok', false, 'error', 'nothing_sealed_yet'); end if;

  select workspace_id into v_ws from public.chat_conversations where id = _conversation;
  select min(seq), max(seq), count(*) into v_from, v_to, v_msgs
    from public.chat_messages where conversation_id = _conversation;
  select count(*) into v_del from public.chat_message_receipts rr
    join public.chat_messages m on m.id = rr.message_id
   where m.conversation_id = _conversation and rr.state = 'delivered';
  select count(*) into v_read from public.chat_message_receipts rr
    join public.chat_messages m on m.id = rr.message_id
   where m.conversation_id = _conversation and rr.state = 'read';

  v_hash := encode(digest(v_head || ':' || v_msgs::text || ':' || v_del::text || ':' ||
                          v_read::text || ':' || now()::text, 'sha256'), 'hex');

  insert into public.chat_receipt_certificates (
    conversation_id, workspace_id, issued_by, from_seq, to_seq,
    message_count, delivered_count, read_count, head_hash, certificate_hash)
  values (_conversation, v_ws, _user, coalesce(v_from, 0), coalesce(v_to, 0),
          v_msgs, v_del, v_read, v_head, v_hash)
  returning id, verify_token into v_id, v_token;

  return jsonb_build_object('ok', true, 'certificate_id', v_id, 'verify_token', v_token,
    'certificate_hash', v_hash, 'head_hash', v_head,
    'messages', v_msgs, 'delivered', v_del, 'read', v_read,
    'contains_message_bodies', false,
    'note', 'Anyone holding this token can verify the counts and hash without signing in.');
end $$;

-- bahar se verify: sirf token, koi login nahi, koi body nahi
create or replace function public.receipt_certificate_verify(_token text)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare c record; v_now jsonb; v_intact boolean; v_head text;
begin
  select * into c from public.chat_receipt_certificates
   where verify_token = replace(coalesce(_token, ''), '-', '');
  if not found then return jsonb_build_object('valid', false, 'error', 'certificate_not_found'); end if;

  -- chain aaj bhi wahi hai? (body dekhe bina, sirf seal)
  select coalesce(p.chain_hash = c.head_hash, false) into v_intact
    from public.chat_message_provenance p
   where p.conversation_id = c.conversation_id
   order by p.seq desc limit 1;

  return jsonb_build_object(
    'valid', true,
    'issued_at', c.issued_at,
    'messages', c.message_count,
    'delivered', c.delivered_count,
    'read', c.read_count,
    'from_seq', c.from_seq, 'to_seq', c.to_seq,
    'certificate_hash', c.certificate_hash,
    'head_hash', c.head_hash,
    'still_matches_live_chain', coalesce(v_intact, false),
    'contains_message_bodies', false,
    'note', case when coalesce(v_intact, false)
                 then 'The sealed chain head still matches this certificate.'
                 else 'Newer messages exist or the chain head changed since issue.' end);
end $$;
grant execute on function public.receipt_certificate_verify(text) to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- 8) ZERO-LOSS HANDOVER PACK
-- ---------------------------------------------------------------------------
create table if not exists public.chat_handover_packs (
  id            uuid primary key default gen_random_uuid(),
  workspace_id  uuid not null references public.chat_workspaces(id) on delete cascade,
  outgoing_user uuid not null references auth.users(id) on delete restrict,
  incoming_user uuid references auth.users(id) on delete set null,
  scope         text not null default 'workspace'
                check (scope in ('workspace','conversation','project')),
  scope_ref     uuid,
  state         text not null default 'draft'
                check (state in ('draft','under_review','assigned','completed')),
  built_by      uuid not null references auth.users(id) on delete restrict,
  built_at      timestamptz not null default now(),
  completed_at  timestamptz,
  note          text
);
create index if not exists chat_handover_packs_ws_idx
  on public.chat_handover_packs (workspace_id, built_at desc);

create table if not exists public.chat_handover_items (
  id          uuid primary key default gen_random_uuid(),
  pack_id     uuid not null references public.chat_handover_packs(id) on delete cascade,
  category    text not null check (category in
                ('conversation','task','promise','decision','file','dependency','deadline','risk')),
  status      text not null check (status in
                ('confirmed_fact','pending','overdue','historical_decision','open_dependency')),
  object_type text not null,
  object_id   uuid not null,
  title       text not null,
  detail      text,
  source      text not null,          -- kis table se aaya (provenance)
  evidence    jsonb not null default '{}'::jsonb,
  due_at      timestamptz,
  assigned_to uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  unique (pack_id, object_type, object_id)
);
create index if not exists chat_handover_items_pack_idx
  on public.chat_handover_items (pack_id, category);

create table if not exists public.chat_handover_log (
  id       bigserial primary key,
  pack_id  uuid not null references public.chat_handover_packs(id) on delete cascade,
  item_id  uuid references public.chat_handover_items(id) on delete set null,
  action   text not null check (action in ('built','reviewed','assigned','accepted','exported','completed')),
  actor    text not null default 'user',
  actor_id uuid references auth.users(id) on delete set null,
  reason   text,
  at       timestamptz not null default now()
);

grant select on public.chat_handover_packs, public.chat_handover_items, public.chat_handover_log
  to authenticated;
grant all on public.chat_handover_packs, public.chat_handover_items, public.chat_handover_log
  to service_role;
grant usage, select on sequence public.chat_handover_log_id_seq to service_role;

alter table public.chat_handover_packs enable row level security;
alter table public.chat_handover_items enable row level security;
alter table public.chat_handover_log  enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename='chat_handover_packs' and policyname='handover_read') then
    create policy "handover_read" on public.chat_handover_packs
      for select to authenticated using (
        outgoing_user = auth.uid() or incoming_user = auth.uid() or built_by = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='chat_handover_items' and policyname='handover_items_read') then
    create policy "handover_items_read" on public.chat_handover_items
      for select to authenticated using (
        exists (select 1 from public.chat_handover_packs p
                 where p.id = chat_handover_items.pack_id
                   and (p.outgoing_user = auth.uid() or p.incoming_user = auth.uid()
                        or p.built_by = auth.uid())));
  end if;
  if not exists (select 1 from pg_policies where tablename='chat_handover_log' and policyname='handover_log_read') then
    create policy "handover_log_read" on public.chat_handover_log
      for select to authenticated using (
        exists (select 1 from public.chat_handover_packs p
                 where p.id = chat_handover_log.pack_id
                   and (p.outgoing_user = auth.uid() or p.incoming_user = auth.uid()
                        or p.built_by = auth.uid())));
  end if;
end $$;

create or replace function public.chat_handover_log_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'chat_handover_log is append-only';
end $$;
drop trigger if exists chat_handover_log_no_change on public.chat_handover_log;
create trigger chat_handover_log_no_change
  before update or delete on public.chat_handover_log
  for each row execute function public.chat_handover_log_immutable();

-- pack banao: har item asli record se, status alag, kuch invent nahi
create or replace function public.handover_pack_build(
  _actor uuid, _outgoing uuid, _scope text default 'workspace', _scope_ref uuid default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_ws uuid; v_pack uuid; r record; v_count int := 0;
begin
  if not public.chat_feature_ok(_actor, 'handover_pack') then
    return jsonb_build_object('ok', false, 'error', 'plan_not_allowed');
  end if;
  select workspace_id into v_ws from public.chat_members where user_id = _actor limit 1;
  if v_ws is null then return jsonb_build_object('ok', false, 'error', 'no_workspace'); end if;
  if not exists (select 1 from public.chat_members where user_id = _outgoing and workspace_id = v_ws) then
    return jsonb_build_object('ok', false, 'error', 'outgoing_user_not_in_workspace');
  end if;

  insert into public.chat_handover_packs (workspace_id, outgoing_user, scope, scope_ref, built_by)
  values (v_ws, _outgoing, coalesce(_scope, 'workspace'), _scope_ref, _actor)
  returning id into v_pack;

  -- open conversations (jahan outgoing user participant hai)
  for r in
    select c.id, coalesce(c.subject, 'Direct conversation') as title, c.last_message_at
      from public.chat_conversations c
      join public.chat_participants p on p.conversation_id = c.id and p.user_id = _outgoing
     where c.workspace_id = v_ws
       and (_scope <> 'conversation' or c.id = _scope_ref)
  loop
    insert into public.chat_handover_items (pack_id, category, status, object_type, object_id,
      title, detail, source, evidence)
    values (v_pack, 'conversation', 'pending', 'conversation', r.id, r.title,
      'Active conversation with the outgoing person.', 'chat_conversations',
      jsonb_build_object('last_message_at', r.last_message_at))
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;

  -- open tasks / promises (owner = outgoing)
  for r in
    select w.id, w.kind, w.title, w.due_at, w.conversation_id, w.state
      from public.chat_work_items w
     where w.workspace_id = v_ws and w.owner_user_id = _outgoing and w.state = 'open'
  loop
    insert into public.chat_handover_items (pack_id, category, status, object_type, object_id,
      title, detail, source, evidence, due_at)
    values (v_pack,
      case when r.kind = 'promise' then 'promise' else 'task' end,
      case when r.due_at is not null and r.due_at < now() then 'overdue' else 'pending' end,
      'work_item', r.id, r.title,
      case when r.due_at is null then 'No deadline recorded.' else null end,
      'chat_work_items',
      jsonb_build_object('conversation_id', r.conversation_id, 'kind', r.kind, 'state', r.state),
      r.due_at)
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;

  -- open dependencies (sirf insaani depends_on)
  for r in
    select w.id, w.title, b.id as blocker_id, b.title as blocker_title, b.state as blocker_state
      from public.chat_work_items w
      join public.chat_work_items b on b.id = w.depends_on
     where w.workspace_id = v_ws and w.owner_user_id = _outgoing
       and w.state = 'open' and b.state = 'open'
  loop
    insert into public.chat_handover_items (pack_id, category, status, object_type, object_id,
      title, detail, source, evidence)
    values (v_pack, 'dependency', 'open_dependency', 'work_item', r.id, r.title,
      'Blocked by: ' || r.blocker_title, 'chat_work_items.depends_on',
      jsonb_build_object('blocker_id', r.blocker_id, 'blocker_state', r.blocker_state))
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;

  -- historical decisions (maker = outgoing)
  for r in
    select d.id, d.title, d.decided_at, d.version, d.state, d.conversation_id
      from public.chat_decisions d
     where d.workspace_id = v_ws and d.made_by = _outgoing
  loop
    insert into public.chat_handover_items (pack_id, category, status, object_type, object_id,
      title, detail, source, evidence)
    values (v_pack, 'decision', 'historical_decision', 'decision', r.id, r.title,
      'Version ' || r.version || ' · ' || r.state, 'chat_decisions',
      jsonb_build_object('decided_at', r.decided_at, 'conversation_id', r.conversation_id,
                         'version', r.version, 'state', r.state))
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;

  -- files (uploaded by outgoing, ready version = confirmed fact)
  for r in
    select f.id, f.name, v.id as version_id, v.state, v.ready_at
      from public.chat_files f
      join public.chat_file_versions v on v.file_id = f.id and v.version = f.current_version
     where f.workspace_id = v_ws and f.owner_id = _outgoing and f.deleted_at is null
  loop
    insert into public.chat_handover_items (pack_id, category, status, object_type, object_id,
      title, detail, source, evidence)
    values (v_pack, 'file',
      case when r.state = 'ready' then 'confirmed_fact' else 'pending' end,
      'file', r.id, r.name, 'Version state: ' || r.state, 'chat_file_versions',
      jsonb_build_object('version_id', r.version_id, 'ready_at', r.ready_at))
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;

  insert into public.chat_handover_log (pack_id, action, actor_id, reason)
  values (v_pack, 'built', _actor, 'items: ' || v_count);

  return jsonb_build_object('ok', true, 'pack_id', v_pack, 'items', v_count,
    'fabricates_missing_context', false);
end $$;

create or replace function public.handover_pack_get(_pack uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare p record; v_items jsonb; v_log jsonb;
begin
  select * into p from public.chat_handover_packs where id = _pack;
  if not found then return jsonb_build_object('error', 'pack_not_found'); end if;
  if _user not in (p.built_by, p.outgoing_user, coalesce(p.incoming_user, p.built_by))
     and not public.chat_feature_ok(_user, 'handover_pack') then
    return jsonb_build_object('error', 'not_authorized');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', i.id, 'category', i.category, 'status', i.status,
           'object_type', i.object_type, 'object_id', i.object_id,
           'title', i.title, 'detail', i.detail, 'source', i.source,
           'evidence', i.evidence, 'due_at', i.due_at,
           'assigned_to', i.assigned_to, 'accepted_at', i.accepted_at)
           order by i.category, i.due_at nulls last), '[]'::jsonb)
    into v_items from public.chat_handover_items i where i.pack_id = _pack;

  select coalesce(jsonb_agg(jsonb_build_object('action', l.action, 'at', l.at,
           'reason', l.reason) order by l.id desc), '[]'::jsonb)
    into v_log from public.chat_handover_log l where l.pack_id = _pack;

  return jsonb_build_object('pack_id', p.id, 'state', p.state, 'scope', p.scope,
    'outgoing_user', p.outgoing_user, 'incoming_user', p.incoming_user,
    'built_at', p.built_at, 'completed_at', p.completed_at,
    'items', v_items, 'log', v_log,
    'statuses', jsonb_build_array('confirmed_fact','pending','overdue',
                                  'historical_decision','open_dependency'),
    'fabricates_missing_context', false);
end $$;

create or replace function public.handover_pack_board(_user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_ws uuid; v_rows jsonb;
begin
  select workspace_id into v_ws from public.chat_members where user_id = _user limit 1;
  if v_ws is null then return jsonb_build_object('packs', '[]'::jsonb, 'error', 'no_workspace'); end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'pack_id', p.id, 'state', p.state, 'scope', p.scope,
           'outgoing', uo.email, 'incoming', ui.email, 'built_at', p.built_at,
           'items', (select count(*) from public.chat_handover_items i where i.pack_id = p.id),
           'overdue', (select count(*) from public.chat_handover_items i
                        where i.pack_id = p.id and i.status = 'overdue'))
           order by p.built_at desc), '[]'::jsonb)
    into v_rows
    from public.chat_handover_packs p
    join auth.users uo on uo.id = p.outgoing_user
    left join auth.users ui on ui.id = p.incoming_user
   where p.workspace_id = v_ws
     and (p.built_by = _user or p.outgoing_user = _user or p.incoming_user = _user);

  return jsonb_build_object('packs', v_rows,
    'allowed', public.chat_feature_ok(_user, 'handover_pack'));
end $$;

-- assign (insaan) + complete (confirmation, evidence ke saath)
create or replace function public.handover_assign(
  _actor uuid, _pack uuid, _incoming uuid, _reason text, _item uuid default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare p record;
begin
  select * into p from public.chat_handover_packs where id = _pack;
  if not found then return jsonb_build_object('ok', false, 'error', 'pack_not_found'); end if;
  if coalesce(length(trim(_reason)), 0) < 8 then
    return jsonb_build_object('ok', false, 'error', '8_char_reason_required');
  end if;
  if not exists (select 1 from public.chat_members
                  where user_id = _incoming and workspace_id = p.workspace_id) then
    return jsonb_build_object('ok', false, 'error', 'incoming_user_not_in_workspace');
  end if;

  if _item is null then
    update public.chat_handover_packs
       set incoming_user = _incoming, state = 'assigned' where id = _pack;
    update public.chat_handover_items set assigned_to = _incoming where pack_id = _pack;
  else
    update public.chat_handover_items set assigned_to = _incoming
     where id = _item and pack_id = _pack;
  end if;

  insert into public.chat_handover_log (pack_id, item_id, action, actor_id, reason)
  values (_pack, _item, 'assigned', _actor, _reason);

  return jsonb_build_object('ok', true, 'pack_id', _pack, 'incoming_user', _incoming);
end $$;

create or replace function public.handover_complete(_actor uuid, _pack uuid, _reason text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare p record; v_unassigned int;
begin
  select * into p from public.chat_handover_packs where id = _pack;
  if not found then return jsonb_build_object('ok', false, 'error', 'pack_not_found'); end if;
  if coalesce(length(trim(_reason)), 0) < 8 then
    return jsonb_build_object('ok', false, 'error', '8_char_reason_required');
  end if;
  select count(*) into v_unassigned from public.chat_handover_items
   where pack_id = _pack and assigned_to is null;
  if v_unassigned > 0 then
    return jsonb_build_object('ok', false, 'error', 'items_without_owner', 'count', v_unassigned);
  end if;

  update public.chat_handover_packs
     set state = 'completed', completed_at = now() where id = _pack;
  update public.chat_handover_items set accepted_at = coalesce(accepted_at, now())
   where pack_id = _pack;
  insert into public.chat_handover_log (pack_id, action, actor_id, reason)
  values (_pack, 'completed', _actor, _reason);

  return jsonb_build_object('ok', true, 'pack_id', _pack, 'state', 'completed');
end $$;

-- ---------------------------------------------------------------------------
-- grants
-- ---------------------------------------------------------------------------
grant execute on function
  public.message_attach_file(uuid, uuid, uuid),
  public.receipt_device_record(uuid, uuid, text, text, text),
  public.message_receipt_pack(uuid, uuid),
  public.read_without_response(uuid, int),
  public.receipt_replay(uuid, uuid, int),
  public.receipt_certificate_issue(uuid, uuid),
  public.handover_pack_build(uuid, uuid, text, uuid),
  public.handover_pack_get(uuid, uuid),
  public.handover_pack_board(uuid),
  public.handover_assign(uuid, uuid, uuid, text, uuid),
  public.handover_complete(uuid, uuid, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- VERIFY
-- ---------------------------------------------------------------------------
-- select count(*) from information_schema.tables
--  where table_schema='public' and table_name in
--  ('chat_receipt_devices','chat_message_files','chat_receipt_certificates',
--   'chat_handover_packs','chat_handover_items','chat_handover_log');   -- 6
-- select public.read_without_response('00000000-0000-0000-0000-000000000000', 24);
