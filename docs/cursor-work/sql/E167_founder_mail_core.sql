
-- E167 - FOUNDER MAILBOX CORE (phase Q1a): the database of the founder mailbox. Advanced level: closed lists, state machines, blind indexes, sealed bodies,
-- an append-only SHA-256 hash-chained ledger anchored into the founder audit chain, keyset pagination, RLS forced, selftest that rolls itself back.
-- ---------------------------------------------------------------------------------------------------------------------------------------------------
-- Founder word 13 Nov 2026 ("founder ke sql super advance, kam se kam 800 lines"): founder mailbox = the awam mailbox moulded for the founder on advanced
-- technology. NOTHING of the awam tables is touched or read (CORE FREEZE + separation law): every object here is fmail_* / fmail_..167.
--
-- WHAT THE DATABASE NEVER HOLDS: a plain body, a plain subject, a plain address list, a plain attachment name. The Rust engine (Tokio) seals them first:
--   * body / subject / headers / snippet / attachment name = AES-256-GCM ciphertext (bytea) + 96-bit nonce + key id + the per-message key WRAPPED
--     (seal_mode 'recipient_pq' = wrapped to the founder's ML-KEM-768 + X25519 public key, the server can NOT open it again; 'vault' = wrapped to the vault
--     master key, the server can open it, needed only where server side search is switched on by him).
--   * what the server must still sort and thread by = BLIND INDEXES (HMAC-SHA-256 with a vault key, computed by Rust): subject_blind, sender_blind,
--     msgid_blind. The database sees equality, never the text.
--   * plain facts that are safe and needed: sizes, times, flags, folder, authentication verdicts (SPF / DKIM / DMARC), scan state, sender DOMAIN.
--
-- OBJECTS (all RLS ENABLED + FORCED, no policy for anon/authenticated = service_role only, like every founder table):
--   fmail_policy              1 row of limits (undo seconds, caps, chunk size, parallel streams), CHECK ranges, every change goes to the ledger
--   fmail_mailboxes           one row per address the founder reads (closed brand list: anexomail | nexatect), status, seal mode
--   fmail_folders             system folders (closed list) + custom ones
--   fmail_threads             conversation counters, kept by trigger (never by the application)
--   fmail_messages            sealed message + blind indexes + verdicts + flags
--   fmail_labels / _message_labels
--   fmail_drafts / fmail_draft_versions   (versions append-only)
--   fmail_outbox              send state machine queued -> scheduled -> sending -> sent | failed | cancelled | undone, transitions enforced by trigger
--   fmail_attachments / fmail_att_chunks   sealed chunk map for the WebTransport upload (1 MiB chunks, resumable), scan verdict, quarantine
--   fmail_ledger              append-only hash chain of every send / delete / export / key / policy event (+ anchor row into founder_audit)
--   functions: counts, keyset thread list, inbound delivery, folder move, flags, snooze + wake, outbox enqueue / advance / undo, attachment begin / put /
--              complete, ledger append + verify, posture, selftest (rolls itself back)
-- Run again any time: create ... if not exists / create or replace; the policy row and the ledger keep their data.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = pg_catalog, public, extensions;

-- ===============================================================================================================================================
-- 0) PREFLIGHT: what this file stands on (E100 founder_accounts, E102 founder_audit_append, a sha256 / hmac provider)
-- ===============================================================================================================================================
do $$
begin
  if to_regclass('public.founder_accounts') is null then raise exception 'E167: founder_accounts missing (run E100 first)'; end if;
  if to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then raise exception 'E167: founder_audit_append missing (run E102 first)'; end if;
  if to_regprocedure('extensions.digest(bytea,text)') is null and to_regprocedure('public.digest(bytea,text)') is null then raise exception 'E167: pgcrypto digest() missing'; end if;
end $$;

-- helper: sha256 of bytea -> lowercase hex (one place, so the ledger and the checks can never disagree)
create or replace function public.fmail_sha256_167(p bytea) returns text language sql immutable parallel safe set search_path = pg_catalog, public, extensions as $$
  select encode(digest(p, 'sha256'), 'hex');
$$;
-- helper: length-prefixed field (the same trick as founder _fa_lp): a field can never run into the next one, so a hash input has ONE reading
create or replace function public.fmail_lp_167(p text) returns bytea language sql immutable parallel safe set search_path = pg_catalog as $$
  select convert_to(length(coalesce(p, ''))::text || ':' || coalesce(p, ''), 'UTF8');
$$;
-- ===============================================================================================================================================
-- 1) POLICY (one row, the limits the Rust engine reads; a CHECK keeps every number in a sane range)
-- ===============================================================================================================================================
create table if not exists public.fmail_policy (
  id                     smallint primary key default 1 check (id = 1),
  undo_seconds           int     not null default 30     check (undo_seconds between 5 and 120),
  max_message_bytes      bigint  not null default 26214400 check (max_message_bytes between 1048576 and 104857600),      -- 25 MiB body+headers cap
  max_attachment_bytes   bigint  not null default 2147483648 check (max_attachment_bytes between 1048576 and 10737418240), -- 2 GiB per file
  max_attachments        int     not null default 25     check (max_attachments between 1 and 100),
  chunk_bytes            int     not null default 1048576 check (chunk_bytes in (262144, 524288, 1048576, 2097152, 4194304)),
  parallel_streams       int     not null default 8      check (parallel_streams between 1 and 16),
  send_per_hour          int     not null default 120    check (send_per_hour between 1 and 5000),
  send_per_day           int     not null default 1000   check (send_per_day between 1 and 50000),
  recipients_per_message int     not null default 100    check (recipients_per_message between 1 and 500),
  schedule_max_days      int     not null default 60     check (schedule_max_days between 1 and 365),
  quarantine_days        int     not null default 30     check (quarantine_days between 1 and 365),
  require_touch_send     boolean not null default true,    -- passkey touch to send as the company
  require_touch_delete   boolean not null default true,    -- passkey touch to delete for good
  require_touch_export   boolean not null default true,    -- passkey touch to export
  default_seal_mode      text    not null default 'recipient_pq' check (default_seal_mode in ('recipient_pq', 'vault')),
  updated_at             timestamptz not null default now(),
  check (send_per_hour <= send_per_day),
  check (max_attachment_bytes >= max_message_bytes)
);
insert into public.fmail_policy (id) values (1) on conflict (id) do nothing;
alter table public.fmail_policy enable row level security;
alter table public.fmail_policy force row level security;
revoke all on public.fmail_policy from public, anon, authenticated;
grant select, update on public.fmail_policy to service_role;

-- ===============================================================================================================================================
-- 2) MAILBOXES (the addresses the founder mailbox shows). brand is a closed list: the product is ANEXOMAIL, the parent company is NEXATECT.
--    The nexatect boxes are founder-internal and are never shown on an awam-facing surface (his word 13 Nov: Nexatect is not shown to awam yet).
-- ===============================================================================================================================================
create table if not exists public.fmail_mailboxes (
  id            uuid primary key default gen_random_uuid(),
  owner         uuid not null references public.founder_accounts (user_id) on delete restrict,
  address       text not null,
  display_name  text not null default '' check (length(display_name) <= 120 and display_name !~ '[[:cntrl:]]'),
  brand         text not null default 'anexomail' check (brand in ('anexomail', 'nexatect')),
  status        text not null default 'active' check (status in ('active', 'paused', 'locked', 'retired')),
  seal_mode     text not null default 'recipient_pq' check (seal_mode in ('recipient_pq', 'vault')),
  recipient_key_id text,                      -- id of the founder public key (ML-KEM-768 + X25519) the messages are sealed to
  vault_key_id  text,                         -- id of the vault key used for blind indexes (and for 'vault' seal mode)
  dkim_selector text check (dkim_selector is null or dkim_selector ~ '^[a-z0-9][a-z0-9-]{0,62}$'),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint fmail_mailboxes_address_ck check (
    address = lower(address) and length(address) between 6 and 254
    and address ~ '^[a-z0-9][a-z0-9._+-]{0,63}@[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'),
  constraint fmail_mailboxes_pq_key_ck check (seal_mode <> 'recipient_pq' or status = 'retired' or recipient_key_id is not null or status = 'paused')
);
create unique index if not exists fmail_mailboxes_address_uq on public.fmail_mailboxes (address);
create index if not exists fmail_mailboxes_owner_ix on public.fmail_mailboxes (owner, status);
alter table public.fmail_mailboxes enable row level security;
alter table public.fmail_mailboxes force row level security;
revoke all on public.fmail_mailboxes from public, anon, authenticated;
grant select, insert, update on public.fmail_mailboxes to service_role;

-- updated_at touch (one trigger function for every table that has the column)
create or replace function public.fmail_touch_167() returns trigger language plpgsql set search_path = pg_catalog as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists fmail_policy_touch on public.fmail_policy;
create trigger fmail_policy_touch before update on public.fmail_policy for each row execute function public.fmail_touch_167();
drop trigger if exists fmail_mailboxes_touch on public.fmail_mailboxes;
create trigger fmail_mailboxes_touch before update on public.fmail_mailboxes for each row execute function public.fmail_touch_167();

-- ===============================================================================================================================================
-- 3) FOLDERS (closed system list + custom). System folders cannot be renamed or removed; custom names are plain text the founder typed
--    (they are labels of HIS own organisation, not message content), still length- and control-char-checked.
-- ===============================================================================================================================================
create table if not exists public.fmail_folders (
  id          uuid primary key default gen_random_uuid(),
  mailbox_id  uuid not null references public.fmail_mailboxes (id) on delete cascade,
  kind        text not null check (kind in ('inbox', 'sent', 'drafts', 'outbox', 'archive', 'spam', 'trash', 'quarantine', 'snoozed', 'custom')),
  name        text not null check (length(name) between 1 and 60 and name !~ '[[:cntrl:]]'),
  sort_order  int  not null default 100 check (sort_order between 0 and 10000),
  created_at  timestamptz not null default now(),
  constraint fmail_folders_system_name_ck check (kind = 'custom' or name = kind)
);
create unique index if not exists fmail_folders_system_uq on public.fmail_folders (mailbox_id, kind) where kind <> 'custom';
create unique index if not exists fmail_folders_custom_uq on public.fmail_folders (mailbox_id, lower(name)) where kind = 'custom';
alter table public.fmail_folders enable row level security;
alter table public.fmail_folders force row level security;
revoke all on public.fmail_folders from public, anon, authenticated;
grant select, insert, update, delete on public.fmail_folders to service_role;

create or replace function public.fmail_folders_guard_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' and old.kind <> 'custom' and exists (select 1 from public.fmail_mailboxes m where m.id = old.mailbox_id) then
    raise exception 'E167: system folder % cannot be removed', old.kind using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and old.kind <> 'custom' and (new.kind <> old.kind or new.name <> old.name) then
    raise exception 'E167: system folder % cannot be renamed or retyped', old.kind using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
drop trigger if exists fmail_folders_guard on public.fmail_folders;
create trigger fmail_folders_guard before update or delete on public.fmail_folders for each row execute function public.fmail_folders_guard_167();

-- every new mailbox gets its nine system folders at once (the application never has to remember)
create or replace function public.fmail_mailbox_folders_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare k text; i int := 0;
begin
  foreach k in array array['inbox','sent','drafts','outbox','archive','spam','trash','quarantine','snoozed'] loop
    i := i + 10;
    insert into public.fmail_folders (mailbox_id, kind, name, sort_order) values (new.id, k, k, i) on conflict do nothing;
  end loop;
  return new;
end $$;
drop trigger if exists fmail_mailboxes_folders on public.fmail_mailboxes;
create trigger fmail_mailboxes_folders after insert on public.fmail_mailboxes for each row execute function public.fmail_mailbox_folders_167();

-- ===============================================================================================================================================
-- 4) THREADS (conversation = rows of messages sharing a thread). The counters are kept ONLY by trigger on fmail_messages: the app cannot drift them.
--    A thread is found by blind indexes (msgid / references / subject_blind), never by text.
-- ===============================================================================================================================================
create table if not exists public.fmail_threads (
  id            uuid primary key default gen_random_uuid(),
  mailbox_id    uuid not null references public.fmail_mailboxes (id) on delete cascade,
  subject_blind bytea check (subject_blind is null or octet_length(subject_blind) = 32),     -- HMAC-SHA-256 of the normalised subject
  msg_count     int  not null default 0 check (msg_count >= 0),
  unread_count  int  not null default 0 check (unread_count >= 0 and unread_count <= msg_count),
  has_attach    boolean not null default false,
  starred       boolean not null default false,
  first_at      timestamptz,
  last_at       timestamptz,
  snoozed_until timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (first_at is null or last_at is null or first_at <= last_at)
);
create index if not exists fmail_threads_list_ix on public.fmail_threads (mailbox_id, last_at desc, id desc);
create index if not exists fmail_threads_subject_ix on public.fmail_threads (mailbox_id, subject_blind) where subject_blind is not null;
create index if not exists fmail_threads_snooze_ix on public.fmail_threads (snoozed_until) where snoozed_until is not null;
alter table public.fmail_threads enable row level security;
alter table public.fmail_threads force row level security;
revoke all on public.fmail_threads from public, anon, authenticated;
grant select, insert, update, delete on public.fmail_threads to service_role;
drop trigger if exists fmail_threads_touch on public.fmail_threads;
create trigger fmail_threads_touch before update on public.fmail_threads for each row execute function public.fmail_touch_167();

-- ===============================================================================================================================================
-- 5) MESSAGES. Sealed content + blind indexes + verdicts. Plain columns are only what is safe and needed to run the mailbox.
-- ===============================================================================================================================================
create table if not exists public.fmail_messages (
  id              uuid primary key default gen_random_uuid(),
  mailbox_id      uuid not null references public.fmail_mailboxes (id) on delete cascade,
  thread_id       uuid not null references public.fmail_threads (id) on delete cascade,
  folder_id       uuid not null references public.fmail_folders (id) on delete restrict,
  direction       text not null check (direction in ('in', 'out')),
  -- sealed content (AES-256-GCM), produced by the Rust engine; the database never sees the plain text
  seal_mode       text not null check (seal_mode in ('recipient_pq', 'vault')),
  sealed_body     bytea not null check (octet_length(sealed_body) between 17 and 104857600),     -- >= 16 byte GCM tag + 1
  sealed_meta     bytea not null check (octet_length(sealed_meta) between 17 and 1048576),       -- subject, from, to, cc, snippet, headers, as one sealed blob
  nonce_body      bytea not null check (octet_length(nonce_body) = 12),
  nonce_meta      bytea not null check (octet_length(nonce_meta) = 12),
  key_id          text  not null check (key_id ~ '^[A-Za-z0-9._:-]{4,96}$'),
  key_wrap        bytea not null check (octet_length(key_wrap) between 32 and 8192),             -- message key wrapped (ML-KEM-768 + X25519 hybrid, or vault)
  aad_hash        bytea not null check (octet_length(aad_hash) = 32),                            -- sha256 of the AAD (mailbox id | message id | direction | ts) bound to the seal
  -- blind indexes (HMAC-SHA-256 with a vault key): equality only
  msgid_blind     bytea check (msgid_blind is null or octet_length(msgid_blind) = 32),
  parent_blind    bytea check (parent_blind is null or octet_length(parent_blind) = 32),          -- In-Reply-To blind index
  subject_blind   bytea check (subject_blind is null or octet_length(subject_blind) = 32),
  sender_blind    bytea check (sender_blind is null or octet_length(sender_blind) = 32),
  sender_domain   text check (sender_domain is null or (sender_domain = lower(sender_domain) and length(sender_domain) <= 253 and sender_domain ~ '^[a-z0-9.-]+$')),
  -- plain, safe facts
  received_at     timestamptz not null default now(),
  sent_at         timestamptz,
  size_bytes      bigint not null check (size_bytes between 0 and 104857600),
  attach_count    int not null default 0 check (attach_count between 0 and 100),
  is_read         boolean not null default false,
  is_starred      boolean not null default false,
  is_draft        boolean not null default false,
  -- authentication and safety verdicts of the INBOUND check (closed lists; 'none' = not checked, never a guessed pass)
  spf             text not null default 'none' check (spf in ('none', 'pass', 'fail', 'softfail', 'neutral', 'temperror', 'permerror')),
  dkim            text not null default 'none' check (dkim in ('none', 'pass', 'fail', 'neutral', 'temperror', 'permerror')),
  dmarc           text not null default 'none' check (dmarc in ('none', 'pass', 'fail', 'temperror', 'permerror')),
  arc             text not null default 'none' check (arc in ('none', 'pass', 'fail')),
  lookalike       boolean not null default false,
  spam_score      numeric(5,2) check (spam_score is null or spam_score between -50 and 100),
  scan_state      text not null default 'pending' check (scan_state in ('pending', 'clean', 'infected', 'error', 'skipped')),
  tls_in          text check (tls_in is null or tls_in in ('none', 'tls12', 'tls13', 'tls13_pq')),
  created_at      timestamptz not null default now(),
  constraint fmail_messages_sent_ck check (direction = 'in' or is_draft or sent_at is not null),
  constraint fmail_messages_draft_dir_ck check (not is_draft or direction = 'out')
);
create unique index if not exists fmail_messages_msgid_uq on public.fmail_messages (mailbox_id, msgid_blind) where msgid_blind is not null;
create index if not exists fmail_messages_folder_ix on public.fmail_messages (mailbox_id, folder_id, received_at desc, id desc);
create index if not exists fmail_messages_thread_ix on public.fmail_messages (thread_id, received_at, id);
create index if not exists fmail_messages_sender_ix on public.fmail_messages (mailbox_id, sender_blind) where sender_blind is not null;
create index if not exists fmail_messages_unread_ix on public.fmail_messages (mailbox_id, folder_id) where not is_read;
create index if not exists fmail_messages_parent_ix on public.fmail_messages (mailbox_id, parent_blind) where parent_blind is not null;
alter table public.fmail_messages enable row level security;
alter table public.fmail_messages force row level security;
revoke all on public.fmail_messages from public, anon, authenticated;
grant select, insert, update, delete on public.fmail_messages to service_role;

-- the folder must belong to the same mailbox as the message, the thread too (a message can never leak into another mailbox's folder)
create or replace function public.fmail_messages_same_box_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare f uuid; t uuid;
begin
  select mailbox_id into f from public.fmail_folders where id = new.folder_id;
  select mailbox_id into t from public.fmail_threads where id = new.thread_id;
  if f is distinct from new.mailbox_id or t is distinct from new.mailbox_id then
    raise exception 'E167: folder and thread must belong to the message mailbox' using errcode = '23514';
  end if;
  return new;
end $$;
drop trigger if exists fmail_messages_same_box on public.fmail_messages;
create trigger fmail_messages_same_box before insert or update of folder_id, thread_id, mailbox_id on public.fmail_messages for each row execute function public.fmail_messages_same_box_167();

-- the sealed content is IMMUTABLE after insert (a changed ciphertext = tampering); only flags, folder, thread and scan/verdict facts may move
create or replace function public.fmail_messages_immutable_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if new.sealed_body is distinct from old.sealed_body or new.sealed_meta is distinct from old.sealed_meta
     or new.nonce_body is distinct from old.nonce_body or new.nonce_meta is distinct from old.nonce_meta
     or new.key_wrap is distinct from old.key_wrap or new.key_id is distinct from old.key_id or new.aad_hash is distinct from old.aad_hash
     or new.seal_mode is distinct from old.seal_mode or new.mailbox_id is distinct from old.mailbox_id or new.direction is distinct from old.direction then
    raise exception 'E167: sealed content of a message is immutable' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists fmail_messages_immutable on public.fmail_messages;
create trigger fmail_messages_immutable before update on public.fmail_messages for each row execute function public.fmail_messages_immutable_167();

-- thread counters: recomputed from the rows of that thread inside the same transaction (cheap, exact, never drifting)
create or replace function public.fmail_thread_recount_167(p_thread uuid) returns void language plpgsql set search_path = pg_catalog, public as $$
declare r record;
begin
  select count(*) as n, count(*) filter (where not is_read and not is_draft) as u, coalesce(bool_or(attach_count > 0), false) as a,
         coalesce(bool_or(is_starred), false) as s, min(received_at) as f, max(received_at) as l
    into r from public.fmail_messages where thread_id = p_thread;
  update public.fmail_threads set msg_count = r.n, unread_count = least(r.u, r.n), has_attach = r.a, starred = r.s, first_at = r.f, last_at = r.l where id = p_thread;
end $$;
create or replace function public.fmail_messages_counts_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then perform public.fmail_thread_recount_167(new.thread_id); end if;
  if tg_op = 'DELETE' then perform public.fmail_thread_recount_167(old.thread_id); end if;
  if tg_op = 'UPDATE' and new.thread_id is distinct from old.thread_id then perform public.fmail_thread_recount_167(old.thread_id); end if;
  return null;
end $$;
drop trigger if exists fmail_messages_counts on public.fmail_messages;
create trigger fmail_messages_counts after insert or update of is_read, is_starred, is_draft, attach_count, thread_id or delete on public.fmail_messages for each row execute function public.fmail_messages_counts_167();

-- ===============================================================================================================================================
-- 6) LABELS (the founder's own tags; the names are his organisation words, checked, not message content)
-- ===============================================================================================================================================
create table if not exists public.fmail_labels (
  id          uuid primary key default gen_random_uuid(),
  mailbox_id  uuid not null references public.fmail_mailboxes (id) on delete cascade,
  name        text not null check (length(name) between 1 and 40 and name !~ '[[:cntrl:]]'),
  colour      text not null default 'blue' check (colour in ('blue', 'green', 'amber', 'red', 'violet', 'teal', 'grey')),
  created_at  timestamptz not null default now()
);
create unique index if not exists fmail_labels_name_uq on public.fmail_labels (mailbox_id, lower(name));
create table if not exists public.fmail_message_labels (
  message_id  uuid not null references public.fmail_messages (id) on delete cascade,
  label_id    uuid not null references public.fmail_labels (id) on delete cascade,
  added_at    timestamptz not null default now(),
  primary key (message_id, label_id)
);
create index if not exists fmail_message_labels_label_ix on public.fmail_message_labels (label_id, message_id);
alter table public.fmail_labels enable row level security;           alter table public.fmail_labels force row level security;
alter table public.fmail_message_labels enable row level security;   alter table public.fmail_message_labels force row level security;
revoke all on public.fmail_labels, public.fmail_message_labels from public, anon, authenticated;
grant select, insert, update, delete on public.fmail_labels, public.fmail_message_labels to service_role;

-- a label may only be put on a message of the SAME mailbox
create or replace function public.fmail_label_same_box_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare a uuid; b uuid;
begin
  select mailbox_id into a from public.fmail_messages where id = new.message_id;
  select mailbox_id into b from public.fmail_labels where id = new.label_id;
  if a is distinct from b then raise exception 'E167: label and message must belong to the same mailbox' using errcode = '23514'; end if;
  return new;
end $$;
drop trigger if exists fmail_label_same_box on public.fmail_message_labels;
create trigger fmail_label_same_box before insert on public.fmail_message_labels for each row execute function public.fmail_label_same_box_167();

-- ===============================================================================================================================================
-- 7) DRAFTS + VERSIONS. A draft is sealed like a message. Versions are APPEND-ONLY (version history; "restore" = a new version).
-- ===============================================================================================================================================
create table if not exists public.fmail_drafts (
  id          uuid primary key default gen_random_uuid(),
  mailbox_id  uuid not null references public.fmail_mailboxes (id) on delete cascade,
  reply_to    uuid references public.fmail_messages (id) on delete set null,
  head_version int not null default 0 check (head_version >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  discarded_at timestamptz
);
create index if not exists fmail_drafts_box_ix on public.fmail_drafts (mailbox_id, updated_at desc) where discarded_at is null;
create table if not exists public.fmail_draft_versions (
  draft_id    uuid not null references public.fmail_drafts (id) on delete cascade,
  version     int  not null check (version >= 1),
  sealed      bytea not null check (octet_length(sealed) between 17 and 33554432),
  nonce       bytea not null check (octet_length(nonce) = 12),
  key_id      text  not null check (key_id ~ '^[A-Za-z0-9._:-]{4,96}$'),
  key_wrap    bytea not null check (octet_length(key_wrap) between 32 and 8192),
  created_at  timestamptz not null default now(),
  primary key (draft_id, version)
);
alter table public.fmail_drafts enable row level security;          alter table public.fmail_drafts force row level security;
alter table public.fmail_draft_versions enable row level security;  alter table public.fmail_draft_versions force row level security;
revoke all on public.fmail_drafts, public.fmail_draft_versions from public, anon, authenticated;
grant select, insert, update on public.fmail_drafts to service_role;
grant select, insert on public.fmail_draft_versions to service_role;
drop trigger if exists fmail_drafts_touch on public.fmail_drafts;
create trigger fmail_drafts_touch before update on public.fmail_drafts for each row execute function public.fmail_touch_167();

create or replace function public.fmail_append_only_167() returns trigger language plpgsql set search_path = pg_catalog as $$
begin raise exception 'E167: % is append-only (% refused)', tg_table_name, tg_op using errcode = '42501'; end $$;
drop trigger if exists fmail_draft_versions_ro on public.fmail_draft_versions;
create trigger fmail_draft_versions_ro before update or delete on public.fmail_draft_versions for each row execute function public.fmail_append_only_167();
drop trigger if exists fmail_draft_versions_ro_t on public.fmail_draft_versions;
create trigger fmail_draft_versions_ro_t before truncate on public.fmail_draft_versions for each statement execute function public.fmail_append_only_167();

-- a new version must be head_version + 1 (no gaps, no rewriting), and it moves the draft head in the same statement
create or replace function public.fmail_draft_version_next_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare h int;
begin
  select head_version into h from public.fmail_drafts where id = new.draft_id for update;
  if h is null then raise exception 'E167: unknown draft' using errcode = '23503'; end if;
  if new.version <> h + 1 then raise exception 'E167: draft version must be % (got %)', h + 1, new.version using errcode = '23514'; end if;
  update public.fmail_drafts set head_version = new.version where id = new.draft_id;
  return new;
end $$;
drop trigger if exists fmail_draft_version_next on public.fmail_draft_versions;
create trigger fmail_draft_version_next before insert on public.fmail_draft_versions for each row execute function public.fmail_draft_version_next_167();

-- ===============================================================================================================================================
-- 8) LEDGER: append-only SHA-256 hash chain of every security-relevant event (send, delete for good, export, key event, policy change, quarantine, undo).
--    seq 1.. with NO gaps; row_hash = sha256( prev_hash | seq | ts_ms | actor | action | target | reason | meta ) with length-prefixed fields.
--    Update / delete / truncate are refused by trigger. Every row can also be anchored into the founder audit chain (E102) in the same transaction, so
--    the existing Merkle checkpoints (E107) cover the mailbox too.
-- ===============================================================================================================================================
create table if not exists public.fmail_ledger (
  seq        bigint primary key check (seq >= 1),
  ts_ms      bigint not null check (ts_ms > 0),
  actor      uuid   not null references public.founder_accounts (user_id) on delete restrict,
  mailbox_id uuid   references public.fmail_mailboxes (id) on delete set null,
  action     text   not null check (action in (
               'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
               'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
               'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
               'inbound_reject','panic_lock')),
  target     text   not null default '' check (length(target) <= 200 and target !~ '[[:cntrl:]]'),
  reason     text   not null check (length(btrim(reason)) between 8 and 300 and reason !~ '[[:cntrl:]]'),
  meta       jsonb  not null default '{}'::jsonb check (jsonb_typeof(meta) = 'object' and octet_length(meta::text) <= 4000),
  prev_hash  text   not null check (prev_hash ~ '^[0-9a-f]{64}$'),
  row_hash   text   not null check (row_hash ~ '^[0-9a-f]{64}$'),
  audit_seq  bigint,                                   -- founder_audit seq of the anchor row (null when no anchor was requested)
  unique (row_hash)
);
create index if not exists fmail_ledger_box_ix on public.fmail_ledger (mailbox_id, seq desc);
create index if not exists fmail_ledger_action_ix on public.fmail_ledger (action, seq desc);
alter table public.fmail_ledger enable row level security;
alter table public.fmail_ledger force row level security;
revoke all on public.fmail_ledger from public, anon, authenticated;
grant select, insert on public.fmail_ledger to service_role;
drop trigger if exists fmail_ledger_ro on public.fmail_ledger;
create trigger fmail_ledger_ro before update or delete on public.fmail_ledger for each row execute function public.fmail_append_only_167();
drop trigger if exists fmail_ledger_ro_t on public.fmail_ledger;
create trigger fmail_ledger_ro_t before truncate on public.fmail_ledger for each statement execute function public.fmail_append_only_167();

-- the one hash formula (v1). Kept in ONE function so the writer, the verifier and the Rust engine's own check all use the same bytes.
create or replace function public.fmail_ledger_hash_167(p_prev text, p_seq bigint, p_ts bigint, p_actor uuid, p_action text, p_target text, p_reason text, p_meta jsonb)
returns text language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(digest(
       public.fmail_lp_167('fmail-ledger-v1') || public.fmail_lp_167(p_prev) || public.fmail_lp_167(p_seq::text) || public.fmail_lp_167(p_ts::text)
    || public.fmail_lp_167(p_actor::text) || public.fmail_lp_167(p_action) || public.fmail_lp_167(p_target) || public.fmail_lp_167(p_reason)
    || public.fmail_lp_167(p_meta::text), 'sha256'), 'hex');
$$;

-- THE ONLY WAY TO WRITE THE LEDGER. advisory lock = one writer at a time = no fork. p_anchor = also write a founder_audit row (E102) and keep its seq.
create or replace function public.fmail_ledger_append(p_actor uuid, p_mailbox uuid, p_action text, p_target text, p_reason text,
                                                        p_meta jsonb default '{}'::jsonb, p_anchor boolean default false)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_prev text; v_seq bigint; v_ts bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_hash text; v_meta jsonb := coalesce(p_meta, '{}'::jsonb); v_aud bigint; v_a jsonb;
begin
  if p_actor is null or not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'E167: actor is not a founder' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtext('fmail_ledger_chain'));
  select row_hash, seq into v_prev, v_seq from public.fmail_ledger order by seq desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64)); v_seq := coalesce(v_seq, 0) + 1;
  v_hash := public.fmail_ledger_hash_167(v_prev, v_seq, v_ts, p_actor, p_action, coalesce(p_target, ''), btrim(p_reason), v_meta);
  if p_anchor then
    v_a := public.founder_audit_append(p_actor, 'fmail_' || p_action, coalesce(p_target, ''), btrim(p_reason), jsonb_build_object('fmail_seq', v_seq, 'fmail_hash', v_hash));
    v_aud := (v_a ->> 'seq')::bigint;
  end if;
  insert into public.fmail_ledger (seq, ts_ms, actor, mailbox_id, action, target, reason, meta, prev_hash, row_hash, audit_seq)
    values (v_seq, v_ts, p_actor, p_mailbox, p_action, coalesce(p_target, ''), btrim(p_reason), v_meta, v_prev, v_hash, v_aud);
  return jsonb_build_object('seq', v_seq, 'hash', v_hash, 'prev_hash', v_prev, 'ts_ms', v_ts, 'audit_seq', v_aud);
end $$;
revoke all on function public.fmail_ledger_append(uuid, uuid, text, text, text, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.fmail_ledger_append(uuid, uuid, text, text, text, jsonb, boolean) to service_role;

-- verify the chain from p_from: returns the last good seq, or raises with the FIRST bad one (gap, wrong prev, wrong hash)
create or replace function public.fmail_ledger_verify(p_from bigint default 1)
returns bigint language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare r record; v_prev text; v_expect bigint; v_first boolean := true; v_last bigint := 0;
begin
  for r in select * from public.fmail_ledger where seq >= greatest(p_from, 1) order by seq loop
    if v_first then
      v_first := false;
      if r.seq = 1 then v_prev := repeat('0', 64);
      else select row_hash into v_prev from public.fmail_ledger where seq = r.seq - 1; if v_prev is null then raise exception 'E167 ledger: seq % has no predecessor', r.seq using errcode = 'XX001'; end if; end if;
      v_expect := r.seq;
    end if;
    if r.seq <> v_expect then raise exception 'E167 ledger: gap before seq % (expected %)', r.seq, v_expect using errcode = 'XX001'; end if;
    if r.prev_hash <> v_prev then raise exception 'E167 ledger: wrong prev_hash at seq %', r.seq using errcode = 'XX001'; end if;
    if r.row_hash <> public.fmail_ledger_hash_167(r.prev_hash, r.seq, r.ts_ms, r.actor, r.action, r.target, r.reason, r.meta) then
      raise exception 'E167 ledger: row hash mismatch at seq %', r.seq using errcode = 'XX001'; end if;
    v_prev := r.row_hash; v_expect := r.seq + 1; v_last := r.seq;
  end loop;
  return v_last;
end $$;
revoke all on function public.fmail_ledger_verify(bigint) from public, anon, authenticated;
grant execute on function public.fmail_ledger_verify(bigint) to service_role;

-- a policy change is ALWAYS in the ledger: the trigger refuses an update that was not announced by the ledger in the same transaction
create or replace function public.fmail_policy_audit_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if to_jsonb(new) - 'updated_at' is distinct from to_jsonb(old) - 'updated_at'
     and coalesce(current_setting('fmail.policy_announced', true), '') <> 'on' then
    raise exception 'E167: change the policy through fmail_policy_set (it writes the ledger)' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists fmail_policy_audit on public.fmail_policy;
create trigger fmail_policy_audit before update on public.fmail_policy for each row execute function public.fmail_policy_audit_167();

-- the single door for policy changes: whitelist of keys, ledger row with the old and new value, anchored
create or replace function public.fmail_policy_set(p_actor uuid, p_key text, p_value text, p_reason text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_old text; v_keys text[] := array['undo_seconds','max_message_bytes','max_attachment_bytes','max_attachments','chunk_bytes','parallel_streams','send_per_hour',
      'send_per_day','recipients_per_message','schedule_max_days','quarantine_days','require_touch_send','require_touch_delete','require_touch_export','default_seal_mode'];
begin
  if p_key is null or not (p_key = any (v_keys)) then raise exception 'E167: unknown policy key' using errcode = '22023'; end if;
  execute format('select %I::text from public.fmail_policy where id = 1', p_key) into v_old;
  perform set_config('fmail.policy_announced', 'on', true);
  if p_key in ('require_touch_send','require_touch_delete','require_touch_export') then
    execute format('update public.fmail_policy set %I = $1::boolean where id = 1', p_key) using p_value;
  elsif p_key = 'default_seal_mode' then
    execute format('update public.fmail_policy set %I = $1 where id = 1', p_key) using p_value;
  else
    execute format('update public.fmail_policy set %I = $1::bigint where id = 1', p_key) using p_value;
  end if;
  perform set_config('fmail.policy_announced', 'off', true);
  return public.fmail_ledger_append(p_actor, null, 'policy_change', p_key, p_reason, jsonb_build_object('old', v_old, 'new', p_value), true);
end $$;
revoke all on function public.fmail_policy_set(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.fmail_policy_set(uuid, text, text, text) to service_role;

-- ===============================================================================================================================================
-- 9) OUTBOX: the send state machine. queued -> scheduled | sending ; sending -> sent | failed ; queued/scheduled -> cancelled ; queued/scheduled(within the
--    undo window) -> undone ; failed -> queued (retry). Anything else is refused by trigger. The message body lives in fmail_messages (direction out).
-- ===============================================================================================================================================
create table if not exists public.fmail_outbox (
  id             uuid primary key default gen_random_uuid(),
  mailbox_id     uuid not null references public.fmail_mailboxes (id) on delete cascade,
  message_id     uuid not null references public.fmail_messages (id) on delete restrict,
  state          text not null default 'queued' check (state in ('queued', 'scheduled', 'sending', 'sent', 'failed', 'cancelled', 'undone')),
  rcpt_count     int  not null check (rcpt_count between 1 and 500),
  rcpt_blind     bytea[] not null default '{}'::bytea[],        -- blind indexes of the recipients (rate / duplicate checks), never the addresses
  not_before     timestamptz not null default now(),             -- schedule send; equal to created_at + undo window for an immediate send
  undo_until     timestamptz not null,
  attempts       int  not null default 0 check (attempts between 0 and 12),
  next_attempt   timestamptz,
  last_error     text check (last_error is null or (length(last_error) <= 300 and last_error !~ '[[:cntrl:]]')),
  smtp_reply     text check (smtp_reply is null or (length(smtp_reply) <= 300 and smtp_reply !~ '[[:cntrl:]]')),
  tls_out        text check (tls_out is null or tls_out in ('none', 'tls12', 'tls13', 'tls13_pq')),
  dkim_signed    boolean not null default false,
  touch_hash     text check (touch_hash is null or touch_hash ~ '^[0-9a-f]{64}$'),   -- sha256 of the passkey assertion that allowed the send (never the assertion)
  ledger_seq     bigint,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  finished_at    timestamptz,
  check (undo_until >= created_at),
  check (state <> 'sent' or (finished_at is not null and dkim_signed)),
  check (state not in ('sent', 'failed', 'cancelled', 'undone') or finished_at is not null)
);
create unique index if not exists fmail_outbox_message_uq on public.fmail_outbox (message_id);
create index if not exists fmail_outbox_due_ix on public.fmail_outbox (state, not_before) where state in ('queued', 'scheduled', 'failed');
create index if not exists fmail_outbox_box_ix on public.fmail_outbox (mailbox_id, created_at desc);
alter table public.fmail_outbox enable row level security;
alter table public.fmail_outbox force row level security;
revoke all on public.fmail_outbox from public, anon, authenticated;
grant select, insert, update on public.fmail_outbox to service_role;
drop trigger if exists fmail_outbox_touch on public.fmail_outbox;
create trigger fmail_outbox_touch before update on public.fmail_outbox for each row execute function public.fmail_touch_167();

create or replace function public.fmail_outbox_transition_ok_167(p_from text, p_to text) returns boolean language sql immutable as $$
  select (p_from, p_to) in (('queued','scheduled'), ('queued','sending'), ('scheduled','sending'), ('sending','sent'), ('sending','failed'),
                            ('queued','cancelled'), ('scheduled','cancelled'), ('queued','undone'), ('scheduled','undone'), ('failed','queued'), ('failed','cancelled'));
$$;
create or replace function public.fmail_outbox_guard_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'UPDATE' and new.state is distinct from old.state then
    if not public.fmail_outbox_transition_ok_167(old.state, new.state) then
      raise exception 'E167: outbox transition % -> % is not allowed', old.state, new.state using errcode = '23514'; end if;
    if new.state = 'undone' and now() > old.undo_until then raise exception 'E167: the undo window has closed' using errcode = '23514'; end if;
    if new.state = 'sending' and now() < old.not_before then raise exception 'E167: not due yet (not_before)' using errcode = '23514'; end if;
    if new.state = 'sending' then new.attempts := old.attempts + 1; end if;
    if new.state in ('sent', 'failed', 'cancelled', 'undone') then new.finished_at := coalesce(new.finished_at, now()); end if;
  end if;
  if tg_op = 'UPDATE' and old.state in ('sent', 'cancelled', 'undone') and (new.message_id <> old.message_id or new.mailbox_id <> old.mailbox_id or new.rcpt_count <> old.rcpt_count) then
    raise exception 'E167: a finished outbox row is frozen' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists fmail_outbox_guard on public.fmail_outbox;
create trigger fmail_outbox_guard before update on public.fmail_outbox for each row execute function public.fmail_outbox_guard_167();

-- ===============================================================================================================================================
-- 10) ATTACHMENTS + CHUNKS (Q2 / Q3: Tokio + Rust + WebTransport). The file is cut into chunks (policy.chunk_bytes, default 1 MiB); each chunk is AES-256-GCM
--     sealed IN THE BROWSER (kernel stream@1, nonce = counter, AAD = file id + index + total). The Storage Box holds ciphertext only. This table is the
--     resumable chunk map: a chunk row exists only after the server has stored and hashed its ciphertext.
-- ===============================================================================================================================================
create table if not exists public.fmail_attachments (
  id            uuid primary key default gen_random_uuid(),
  mailbox_id    uuid not null references public.fmail_mailboxes (id) on delete cascade,
  message_id    uuid references public.fmail_messages (id) on delete cascade,        -- null while the upload is not yet attached to a message
  direction     text not null check (direction in ('in', 'out')),
  state         text not null default 'uploading' check (state in ('uploading', 'sealed', 'scanning', 'clean', 'infected', 'quarantined', 'failed', 'deleted')),
  sealed_name   bytea not null check (octet_length(sealed_name) between 17 and 4096),   -- file name + media type, sealed (a name can leak)
  nonce_name    bytea not null check (octet_length(nonce_name) = 12),
  key_id        text  not null check (key_id ~ '^[A-Za-z0-9._:-]{4,96}$'),
  key_wrap      bytea not null check (octet_length(key_wrap) between 32 and 8192),    -- file key wrapped (ML-KEM-768 + X25519 hybrid)
  total_bytes   bigint not null check (total_bytes between 1 and 10737418240),         -- plain size
  chunk_bytes   int    not null check (chunk_bytes in (262144, 524288, 1048576, 2097152, 4194304)),
  chunk_count   int    not null check (chunk_count between 1 and 40960),
  cipher_bytes  bigint,                                                                -- sum of stored ciphertext sizes (set at completion)
  ext_class     text not null default 'other' check (ext_class in ('document', 'image', 'archive', 'media', 'code', 'other', 'blocked')),
  scan_verdict  text not null default 'pending' check (scan_verdict in ('pending', 'clean', 'infected', 'error', 'skipped')),
  scan_sig      text check (scan_sig is null or (length(scan_sig) <= 120 and scan_sig !~ '[[:cntrl:]]')),   -- ClamAV signature name, never file content
  storage_root  text not null default 'storagebox' check (storage_root in ('storagebox')),
  manifest_hash text check (manifest_hash is null or manifest_hash ~ '^[0-9a-f]{64}$'),   -- sha256 over the ordered chunk hashes (tamper / reorder check)
  created_at    timestamptz not null default now(),
  completed_at  timestamptz,
  quarantined_at timestamptz,
  check (chunk_count = ((total_bytes + chunk_bytes - 1) / chunk_bytes)),                -- the chunk count is not a claim, it is arithmetic
  check (state not in ('sealed', 'scanning', 'clean') or (completed_at is not null and manifest_hash is not null and cipher_bytes is not null)),
  check (state <> 'infected' or scan_verdict = 'infected'),
  check (state <> 'quarantined' or quarantined_at is not null),
  check (state <> 'clean' or scan_verdict in ('clean', 'skipped'))
);
create index if not exists fmail_att_message_ix on public.fmail_attachments (message_id) where message_id is not null;
create index if not exists fmail_att_state_ix on public.fmail_attachments (mailbox_id, state, created_at);
create table if not exists public.fmail_att_chunks (
  attachment_id uuid not null references public.fmail_attachments (id) on delete cascade,
  idx           int  not null check (idx >= 0),
  cipher_bytes  int  not null check (cipher_bytes between 17 and 4194304 + 16),
  cipher_sha256 text not null check (cipher_sha256 ~ '^[0-9a-f]{64}$'),
  storage_path  text not null check (storage_path ~ '^[A-Za-z0-9/_.-]{8,200}$' and storage_path !~ '\.\.'),   -- relative, no traversal (the same rule as attach_core rel_path_valid)
  stored_at     timestamptz not null default now(),
  primary key (attachment_id, idx)
);
alter table public.fmail_attachments enable row level security;  alter table public.fmail_attachments force row level security;
alter table public.fmail_att_chunks enable row level security;   alter table public.fmail_att_chunks force row level security;
revoke all on public.fmail_attachments, public.fmail_att_chunks from public, anon, authenticated;
grant select, insert, update, delete on public.fmail_attachments, public.fmail_att_chunks to service_role;

-- a chunk index must be inside the file; once the upload is complete the chunk map is frozen (a re-ordered or swapped chunk = refused)
create or replace function public.fmail_att_chunk_guard_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare a record;
begin
  select * into a from public.fmail_attachments where id = coalesce(new.attachment_id, old.attachment_id);
  if a.id is null then raise exception 'E167: unknown attachment' using errcode = '23503'; end if;
  if tg_op = 'INSERT' then
    if a.state <> 'uploading' then raise exception 'E167: attachment is not uploading (%)', a.state using errcode = '23514'; end if;
    if new.idx >= a.chunk_count then raise exception 'E167: chunk index % is outside the file (% chunks)', new.idx, a.chunk_count using errcode = '23514'; end if;
    if new.idx < a.chunk_count - 1 and new.cipher_bytes <> a.chunk_bytes + 16 then raise exception 'E167: chunk % must be % bytes (got %)', new.idx, a.chunk_bytes + 16, new.cipher_bytes using errcode = '23514'; end if;
    return new;
  end if;
  if a.state <> 'uploading' then raise exception 'E167: chunk map is frozen after completion' using errcode = '42501'; end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
drop trigger if exists fmail_att_chunk_guard on public.fmail_att_chunks;
create trigger fmail_att_chunk_guard before insert or update or delete on public.fmail_att_chunks for each row execute function public.fmail_att_chunk_guard_167();

-- the legal state moves of an attachment
create or replace function public.fmail_att_transition_ok_167(p_from text, p_to text) returns boolean language sql immutable as $$
  select p_from = p_to or (p_from, p_to) in (('uploading','sealed'), ('uploading','failed'), ('sealed','scanning'), ('scanning','clean'), ('scanning','infected'), ('scanning','failed'),
        ('infected','quarantined'), ('quarantined','deleted'), ('clean','deleted'), ('sealed','deleted'), ('failed','deleted'), ('quarantined','clean'));
$$;
create or replace function public.fmail_att_guard_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if new.state is distinct from old.state and not public.fmail_att_transition_ok_167(old.state, new.state) then
    raise exception 'E167: attachment transition % -> % is not allowed', old.state, new.state using errcode = '23514'; end if;
  if new.total_bytes <> old.total_bytes or new.chunk_bytes <> old.chunk_bytes or new.chunk_count <> old.chunk_count or new.key_wrap <> old.key_wrap or new.mailbox_id <> old.mailbox_id then
    raise exception 'E167: attachment shape and key are immutable' using errcode = '42501'; end if;
  if old.state in ('sealed', 'scanning', 'clean', 'infected', 'quarantined') and new.manifest_hash is distinct from old.manifest_hash then
    raise exception 'E167: manifest hash is immutable after sealing' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists fmail_att_guard on public.fmail_attachments;
create trigger fmail_att_guard before update on public.fmail_attachments for each row execute function public.fmail_att_guard_167();

-- an attachment of a message keeps the message attach_count right (a message with a file shows its paperclip, never a stale number)
create or replace function public.fmail_att_count_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare m uuid := coalesce(new.message_id, old.message_id);
begin
  if m is not null then update public.fmail_messages set attach_count = (select count(*) from public.fmail_attachments where message_id = m and state <> 'deleted') where id = m; end if;
  return null;
end $$;
drop trigger if exists fmail_att_count on public.fmail_attachments;
create trigger fmail_att_count after insert or update of message_id, state or delete on public.fmail_attachments for each row execute function public.fmail_att_count_167();

-- ===============================================================================================================================================
-- 11) FUNCTIONS the Rust engine calls (security definer, search_path pinned, service_role only). No dynamic SQL from caller text anywhere below.
-- ===============================================================================================================================================
-- 11a) folder counts of one mailbox: one row per folder, unread and total, in one index-friendly statement
create or replace function public.fmail_folder_counts(p_mailbox uuid)
returns table (folder_id uuid, kind text, total bigint, unread bigint) language sql stable security definer set search_path = pg_catalog, public as $$
  select f.id, f.kind, count(m.id), count(m.id) filter (where not m.is_read and not m.is_draft)
    from public.fmail_folders f left join public.fmail_messages m on m.folder_id = f.id
   where f.mailbox_id = p_mailbox group by f.id, f.kind, f.sort_order order by f.sort_order, f.kind;
$$;
revoke all on function public.fmail_folder_counts(uuid) from public, anon, authenticated;
grant execute on function public.fmail_folder_counts(uuid) to service_role;

-- 11b) KEYSET thread list of a folder: pass the (last_at, id) of the last row you got; no OFFSET, so page 5000 is as fast as page 1. The answer holds NO content:
--      the engine fetches the sealed blobs of those ids and the browser kernel opens them.
create or replace function public.fmail_thread_page(p_mailbox uuid, p_folder uuid, p_after_ts timestamptz default null, p_after_id uuid default null, p_limit int default 50, p_unread_only boolean default false)
returns table (thread_id uuid, last_at timestamptz, msg_count int, unread_count int, has_attach boolean, starred boolean, newest_message uuid)
language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  if p_limit is null or p_limit < 1 or p_limit > 200 then raise exception 'E167: limit must be 1..200' using errcode = '22023'; end if;
  return query
    select t.id, t.last_at, t.msg_count, t.unread_count, t.has_attach, t.starred,
           (select m.id from public.fmail_messages m where m.thread_id = t.id and m.folder_id = p_folder order by m.received_at desc, m.id desc limit 1)
      from public.fmail_threads t
     where t.mailbox_id = p_mailbox
       and exists (select 1 from public.fmail_messages m where m.thread_id = t.id and m.folder_id = p_folder)
       and (t.snoozed_until is null or t.snoozed_until <= now())
       and (not p_unread_only or t.unread_count > 0)
       and (p_after_ts is null or (t.last_at, t.id) < (p_after_ts, coalesce(p_after_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
     order by t.last_at desc, t.id desc limit p_limit;
end $$;
revoke all on function public.fmail_thread_page(uuid, uuid, timestamptz, uuid, int, boolean) from public, anon, authenticated;
grant execute on function public.fmail_thread_page(uuid, uuid, timestamptz, uuid, int, boolean) to service_role;

-- 11c) INBOUND delivery (called by the Rust LMTP handler after parse + verdicts + ClamAV + sealing). One transaction: find or open the thread by blind
--      indexes, insert the sealed message, return ids. A message already stored (same blind Message-ID) is NOT duplicated: it returns the old id.
create or replace function public.fmail_deliver_inbound(
  p_mailbox uuid, p_folder_kind text, p_seal_mode text, p_sealed_body bytea, p_sealed_meta bytea, p_nonce_body bytea, p_nonce_meta bytea,
  p_key_id text, p_key_wrap bytea, p_aad_hash bytea, p_msgid_blind bytea, p_parent_blind bytea, p_subject_blind bytea, p_sender_blind bytea,
  p_sender_domain text, p_size bigint, p_spf text, p_dkim text, p_dmarc text, p_arc text, p_lookalike boolean, p_spam numeric, p_tls text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_folder uuid; v_thread uuid; v_msg uuid; v_dup uuid; v_status text; v_policy_max bigint;
begin
  select status into v_status from public.fmail_mailboxes where id = p_mailbox;
  if v_status is null then raise exception 'E167: unknown mailbox' using errcode = '23503'; end if;
  if v_status in ('locked', 'retired') then return jsonb_build_object('stored', false, 'reason', 'mailbox_' || v_status); end if;
  select max_message_bytes into v_policy_max from public.fmail_policy where id = 1;
  if p_size > v_policy_max then return jsonb_build_object('stored', false, 'reason', 'too_big'); end if;
  if p_folder_kind not in ('inbox', 'spam', 'quarantine') then raise exception 'E167: inbound can only land in inbox, spam or quarantine' using errcode = '22023'; end if;
  select id into v_folder from public.fmail_folders where mailbox_id = p_mailbox and kind = p_folder_kind;
  if p_msgid_blind is not null then
    select id into v_dup from public.fmail_messages where mailbox_id = p_mailbox and msgid_blind = p_msgid_blind;
    if v_dup is not null then return jsonb_build_object('stored', false, 'reason', 'duplicate', 'message_id', v_dup); end if;
  end if;
  -- thread: the parent message's thread (In-Reply-To blind) first, else same subject blind inside 30 days, else a new thread
  if p_parent_blind is not null then select thread_id into v_thread from public.fmail_messages where mailbox_id = p_mailbox and msgid_blind = p_parent_blind limit 1; end if;
  if v_thread is null and p_subject_blind is not null then
    select id into v_thread from public.fmail_threads where mailbox_id = p_mailbox and subject_blind = p_subject_blind and last_at > now() - interval '30 days' order by last_at desc limit 1;
  end if;
  if v_thread is null then insert into public.fmail_threads (mailbox_id, subject_blind, first_at, last_at) values (p_mailbox, p_subject_blind, now(), now()) returning id into v_thread; end if;
  insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash,
        msgid_blind, parent_blind, subject_blind, sender_blind, sender_domain, size_bytes, spf, dkim, dmarc, arc, lookalike, spam_score, tls_in)
  values (p_mailbox, v_thread, v_folder, 'in', p_seal_mode, p_sealed_body, p_sealed_meta, p_nonce_body, p_nonce_meta, p_key_id, p_key_wrap, p_aad_hash,
        p_msgid_blind, p_parent_blind, p_subject_blind, p_sender_blind, p_sender_domain, p_size, p_spf, p_dkim, p_dmarc, p_arc, p_lookalike, p_spam, p_tls)
  returning id into v_msg;
  return jsonb_build_object('stored', true, 'message_id', v_msg, 'thread_id', v_thread, 'folder', p_folder_kind);
end $$;
revoke all on function public.fmail_deliver_inbound(uuid, text, text, bytea, bytea, bytea, bytea, text, bytea, bytea, bytea, bytea, bytea, bytea, text, bigint, text, text, text, text, boolean, numeric, text) from public, anon, authenticated;
grant execute on function public.fmail_deliver_inbound(uuid, text, text, bytea, bytea, bytea, bytea, text, bytea, bytea, bytea, bytea, bytea, bytea, text, bigint, text, text, text, text, boolean, numeric, text) to service_role;

-- 11d) move messages between folders. Hard delete is NOT here (it needs the touch + the ledger: fmail_delete_hard). Moving to 'sent'/'drafts'/'outbox' by hand is refused.
create or replace function public.fmail_move(p_mailbox uuid, p_ids uuid[], p_to_kind text)
returns integer language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_to uuid; n int;
begin
  if p_to_kind not in ('inbox', 'archive', 'spam', 'trash') then raise exception 'E167: cannot move to %', p_to_kind using errcode = '22023'; end if;
  if cardinality(p_ids) is null or cardinality(p_ids) > 500 then raise exception 'E167: 1..500 ids per call' using errcode = '22023'; end if;
  select id into v_to from public.fmail_folders where mailbox_id = p_mailbox and kind = p_to_kind;
  update public.fmail_messages set folder_id = v_to where mailbox_id = p_mailbox and id = any (p_ids) and direction = 'in' and not is_draft;
  get diagnostics n = row_count; return n;
end $$;
revoke all on function public.fmail_move(uuid, uuid[], text) from public, anon, authenticated;
grant execute on function public.fmail_move(uuid, uuid[], text) to service_role;

-- 11e) flags (read / star) in bulk, scoped to one mailbox
create or replace function public.fmail_flag(p_mailbox uuid, p_ids uuid[], p_read boolean default null, p_star boolean default null)
returns integer language plpgsql security definer set search_path = pg_catalog, public as $$
declare n int;
begin
  if cardinality(p_ids) is null or cardinality(p_ids) > 500 then raise exception 'E167: 1..500 ids per call' using errcode = '22023'; end if;
  update public.fmail_messages set is_read = coalesce(p_read, is_read), is_starred = coalesce(p_star, is_starred) where mailbox_id = p_mailbox and id = any (p_ids);
  get diagnostics n = row_count; return n;
end $$;
revoke all on function public.fmail_flag(uuid, uuid[], boolean, boolean) from public, anon, authenticated;
grant execute on function public.fmail_flag(uuid, uuid[], boolean, boolean) to service_role;

-- 11f) snooze a thread until a time (future, at most 365 days) and wake the due ones (the Rust ticker calls fmail_wake_snoozed every minute)
create or replace function public.fmail_snooze(p_mailbox uuid, p_thread uuid, p_until timestamptz)
returns boolean language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if p_until <= now() or p_until > now() + interval '365 days' then raise exception 'E167: snooze time must be in the future, at most 365 days' using errcode = '22023'; end if;
  update public.fmail_threads set snoozed_until = p_until where id = p_thread and mailbox_id = p_mailbox;
  return found;
end $$;
create or replace function public.fmail_wake_snoozed() returns integer language plpgsql security definer set search_path = pg_catalog, public as $$
declare n int;
begin update public.fmail_threads set snoozed_until = null where snoozed_until is not null and snoozed_until <= now(); get diagnostics n = row_count; return n; end $$;
revoke all on function public.fmail_snooze(uuid, uuid, timestamptz), public.fmail_wake_snoozed() from public, anon, authenticated;
grant execute on function public.fmail_snooze(uuid, uuid, timestamptz), public.fmail_wake_snoozed() to service_role;

-- 11g) OUTBOX enqueue: the sealed message is already stored (direction out, folder outbox). Limits come from the policy row and are checked HERE, not only in the UI:
--      recipients per message, sends per hour and per day (counted from the outbox itself), schedule horizon. Immediate send = not_before = now + undo window.
create or replace function public.fmail_outbox_enqueue(p_actor uuid, p_mailbox uuid, p_message uuid, p_rcpt_blind bytea[], p_schedule_at timestamptz default null, p_touch_hash text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare pol public.fmail_policy; v_state text; v_nb timestamptz; v_undo timestamptz; v_id uuid; v_h int; v_d int; v_led jsonb; v_status text; v_out uuid; v_box uuid;
begin
  select * into pol from public.fmail_policy where id = 1;
  select status into v_status from public.fmail_mailboxes where id = p_mailbox;
  if v_status is distinct from 'active' then raise exception 'E167: mailbox is not active (%)', coalesce(v_status, 'unknown') using errcode = '42501'; end if;
  select mailbox_id into v_box from public.fmail_messages where id = p_message and direction = 'out';
  if v_box is distinct from p_mailbox then raise exception 'E167: the message is not an outgoing message of this mailbox' using errcode = '23514'; end if;
  if cardinality(p_rcpt_blind) is null or cardinality(p_rcpt_blind) < 1 or cardinality(p_rcpt_blind) > pol.recipients_per_message then
    raise exception 'E167: recipients must be 1..%', pol.recipients_per_message using errcode = '22023'; end if;
  if pol.require_touch_send and (p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$') then raise exception 'E167: a passkey touch is required to send' using errcode = '42501'; end if;
  select count(*) filter (where created_at > now() - interval '1 hour'), count(*) filter (where created_at > now() - interval '1 day') into v_h, v_d
    from public.fmail_outbox where mailbox_id = p_mailbox and state not in ('cancelled', 'undone');
  if v_h >= pol.send_per_hour then raise exception 'E167: hourly send limit reached (%)', pol.send_per_hour using errcode = '53400'; end if;
  if v_d >= pol.send_per_day then raise exception 'E167: daily send limit reached (%)', pol.send_per_day using errcode = '53400'; end if;
  v_undo := now() + make_interval(secs => pol.undo_seconds);
  if p_schedule_at is not null then
    if p_schedule_at < v_undo then raise exception 'E167: a scheduled time must be after the undo window' using errcode = '22023'; end if;
    if p_schedule_at > now() + make_interval(days => pol.schedule_max_days) then raise exception 'E167: schedule horizon is % days', pol.schedule_max_days using errcode = '22023'; end if;
    v_nb := p_schedule_at; v_state := 'scheduled';
  else v_nb := v_undo; v_state := 'queued'; end if;
  select id into v_out from public.fmail_folders where mailbox_id = p_mailbox and kind = 'outbox';
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, case when v_state = 'scheduled' then 'send_schedule' else 'send_queue' end, p_message::text, 'send queued by the founder (passkey touched)',
            jsonb_build_object('rcpt', cardinality(p_rcpt_blind), 'not_before', v_nb), true);
  insert into public.fmail_outbox (mailbox_id, message_id, state, rcpt_count, rcpt_blind, not_before, undo_until, touch_hash, ledger_seq)
    values (p_mailbox, p_message, v_state, cardinality(p_rcpt_blind), p_rcpt_blind, v_nb, v_undo, p_touch_hash, (v_led ->> 'seq')::bigint) returning id into v_id;
  update public.fmail_messages set folder_id = v_out where id = p_message;
  return jsonb_build_object('outbox_id', v_id, 'state', v_state, 'not_before', v_nb, 'undo_until', v_undo, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_outbox_enqueue(uuid, uuid, uuid, bytea[], timestamptz, text) from public, anon, authenticated;
grant execute on function public.fmail_outbox_enqueue(uuid, uuid, uuid, bytea[], timestamptz, text) to service_role;

-- 11h) the sender ticker takes the next DUE rows with SKIP LOCKED (several Tokio workers never take the same row). Returns ids moved to 'sending'.
--      Failed rows come back through fmail_outbox_requeue_failed (their backoff time has passed, fewer than 12 attempts).
create or replace function public.fmail_outbox_claim(p_max int default 10)
returns setof uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare r record;
begin
  if p_max < 1 or p_max > 50 then raise exception 'E167: claim 1..50' using errcode = '22023'; end if;
  for r in select id from public.fmail_outbox where state in ('queued', 'scheduled') and not_before <= now() order by not_before, id for update skip locked limit p_max loop
    update public.fmail_outbox set state = 'sending' where id = r.id;
    return next r.id;
  end loop;
end $$;
create or replace function public.fmail_outbox_requeue_failed() returns integer language plpgsql security definer set search_path = pg_catalog, public as $$
declare n int;
begin
  update public.fmail_outbox set state = 'queued', not_before = now() where state = 'failed' and attempts < 12 and coalesce(next_attempt, now()) <= now();
  get diagnostics n = row_count; return n;
end $$;
revoke all on function public.fmail_outbox_claim(int), public.fmail_outbox_requeue_failed() from public, anon, authenticated;
grant execute on function public.fmail_outbox_claim(int), public.fmail_outbox_requeue_failed() to service_role;

-- 11i) the sender reports the result. ok -> sent (needs dkim_signed + tls), else failed with a backoff (1m, 5m, 30m, 2h, 6h, then daily; 12 attempts then it stays failed)
create or replace function public.fmail_outbox_result(p_actor uuid, p_outbox uuid, p_ok boolean, p_reply text, p_tls text, p_dkim boolean, p_error text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare o public.fmail_outbox; v_back interval; v_sent uuid; v_led jsonb;
begin
  select * into o from public.fmail_outbox where id = p_outbox for update;
  if o.id is null then raise exception 'E167: unknown outbox row' using errcode = '23503'; end if;
  if p_ok then
    update public.fmail_outbox set state = 'sent', smtp_reply = left(p_reply, 300), tls_out = p_tls, dkim_signed = coalesce(p_dkim, false), finished_at = now() where id = p_outbox;
    select id into v_sent from public.fmail_folders where mailbox_id = o.mailbox_id and kind = 'sent';
    update public.fmail_messages set folder_id = v_sent, sent_at = now() where id = o.message_id;
    v_led := public.fmail_ledger_append(p_actor, o.mailbox_id, 'send_ok', o.message_id::text, 'message accepted by the remote server', jsonb_build_object('tls', p_tls, 'dkim', coalesce(p_dkim, false)), true);
  else
    v_back := case o.attempts when 1 then interval '1 minute' when 2 then interval '5 minutes' when 3 then interval '30 minutes' when 4 then interval '2 hours' when 5 then interval '6 hours' else interval '1 day' end;
    update public.fmail_outbox set state = 'failed', last_error = left(coalesce(p_error, 'send failed'), 300), smtp_reply = left(p_reply, 300), next_attempt = now() + v_back where id = p_outbox;
    v_led := public.fmail_ledger_append(p_actor, o.mailbox_id, 'send_fail', o.message_id::text, 'send failed, will retry later', jsonb_build_object('attempt', o.attempts), false);
  end if;
  return jsonb_build_object('state', case when p_ok then 'sent' else 'failed' end, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_outbox_result(uuid, uuid, boolean, text, text, boolean, text) from public, anon, authenticated;
grant execute on function public.fmail_outbox_result(uuid, uuid, boolean, text, text, boolean, text) to service_role;

-- 11j) UNDO send inside the window (the trigger refuses it after undo_until); the message goes back to drafts
create or replace function public.fmail_outbox_undo(p_actor uuid, p_outbox uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare o public.fmail_outbox; v_dr uuid; v_led jsonb;
begin
  select * into o from public.fmail_outbox where id = p_outbox for update;
  if o.id is null then raise exception 'E167: unknown outbox row' using errcode = '23503'; end if;
  update public.fmail_outbox set state = 'undone' where id = p_outbox;
  select id into v_dr from public.fmail_folders where mailbox_id = o.mailbox_id and kind = 'drafts';
  update public.fmail_messages set folder_id = v_dr, is_draft = true where id = o.message_id;
  v_led := public.fmail_ledger_append(p_actor, o.mailbox_id, 'send_undo', o.message_id::text, 'send undone inside the undo window', '{}'::jsonb, false);
  return jsonb_build_object('state', 'undone', 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_outbox_undo(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_outbox_undo(uuid, uuid) to service_role;

-- 11k) HARD DELETE of messages (trash only). Needs the passkey touch (policy) and is ledgered + anchored. The attachments go with the message (cascade).
create or replace function public.fmail_delete_hard(p_actor uuid, p_mailbox uuid, p_ids uuid[], p_touch_hash text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare pol public.fmail_policy; n int; v_trash uuid; v_led jsonb;
begin
  select * into pol from public.fmail_policy where id = 1;
  if pol.require_touch_delete and (p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$') then raise exception 'E167: a passkey touch is required to delete for good' using errcode = '42501'; end if;
  if cardinality(p_ids) is null or cardinality(p_ids) > 200 then raise exception 'E167: 1..200 ids per call' using errcode = '22023'; end if;
  select id into v_trash from public.fmail_folders where mailbox_id = p_mailbox and kind = 'trash';
  delete from public.fmail_messages where mailbox_id = p_mailbox and id = any (p_ids) and folder_id = v_trash;
  get diagnostics n = row_count;
  delete from public.fmail_threads t where t.mailbox_id = p_mailbox and not exists (select 1 from public.fmail_messages m where m.thread_id = t.id);
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'delete_hard', 'messages', 'messages deleted for good from the trash (passkey touched)', jsonb_build_object('count', n), true);
  return jsonb_build_object('deleted', n, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_delete_hard(uuid, uuid, uuid[], text) from public, anon, authenticated;
grant execute on function public.fmail_delete_hard(uuid, uuid, uuid[], text) to service_role;

-- 11l) ATTACHMENT lifecycle called by fmail_att.rs: begin (returns the plan the browser must follow), put chunk (idempotent: the same chunk again with the same hash = ok,
--      a DIFFERENT hash for the same index = refused), missing chunks (resume), complete (all chunks present, manifest hash, sizes add up)
create or replace function public.fmail_att_begin(p_mailbox uuid, p_direction text, p_sealed_name bytea, p_nonce_name bytea, p_key_id text, p_key_wrap bytea, p_total bigint, p_chunk int, p_ext_class text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare pol public.fmail_policy; v_id uuid; v_n int;
begin
  select * into pol from public.fmail_policy where id = 1;
  if p_total > pol.max_attachment_bytes then raise exception 'E167: file is larger than the policy allows (% bytes)', pol.max_attachment_bytes using errcode = '53400'; end if;
  if p_chunk <> pol.chunk_bytes then raise exception 'E167: chunk size must be % (policy)', pol.chunk_bytes using errcode = '22023'; end if;
  if p_ext_class = 'blocked' then raise exception 'E167: this file type is blocked' using errcode = '42501'; end if;
  v_n := ((p_total + p_chunk - 1) / p_chunk)::int;
  insert into public.fmail_attachments (mailbox_id, direction, sealed_name, nonce_name, key_id, key_wrap, total_bytes, chunk_bytes, chunk_count, ext_class)
    values (p_mailbox, p_direction, p_sealed_name, p_nonce_name, p_key_id, p_key_wrap, p_total, p_chunk, v_n, p_ext_class) returning id into v_id;
  return jsonb_build_object('attachment_id', v_id, 'chunk_bytes', p_chunk, 'chunk_count', v_n, 'parallel_streams', pol.parallel_streams);
end $$;
create or replace function public.fmail_att_put_chunk(p_att uuid, p_idx int, p_cipher_bytes int, p_sha text, p_path text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare old_sha text;
begin
  select cipher_sha256 into old_sha from public.fmail_att_chunks where attachment_id = p_att and idx = p_idx;
  if old_sha is not null then
    if old_sha = p_sha then return jsonb_build_object('stored', true, 'again', true); end if;
    raise exception 'E167: chunk % already stored with a different hash (tamper or reorder)', p_idx using errcode = '23514';
  end if;
  insert into public.fmail_att_chunks (attachment_id, idx, cipher_bytes, cipher_sha256, storage_path) values (p_att, p_idx, p_cipher_bytes, p_sha, p_path);
  return jsonb_build_object('stored', true, 'again', false);
end $$;
create or replace function public.fmail_att_missing(p_att uuid)
returns int[] language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(array_agg(g order by g), '{}'::int[]) from public.fmail_attachments a cross join lateral generate_series(0, a.chunk_count - 1) g
   where a.id = p_att and not exists (select 1 from public.fmail_att_chunks c where c.attachment_id = a.id and c.idx = g);
$$;
create or replace function public.fmail_att_complete(p_att uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare a public.fmail_attachments; v_miss int[]; v_sum bigint; v_manifest text;
begin
  select * into a from public.fmail_attachments where id = p_att for update;
  if a.id is null then raise exception 'E167: unknown attachment' using errcode = '23503'; end if;
  v_miss := public.fmail_att_missing(p_att);
  if cardinality(v_miss) > 0 then return jsonb_build_object('complete', false, 'missing', to_jsonb(v_miss)); end if;
  select sum(cipher_bytes) into v_sum from public.fmail_att_chunks where attachment_id = p_att;
  if v_sum < a.total_bytes + a.chunk_count * 16 then raise exception 'E167: stored bytes are smaller than the file + tags' using errcode = '23514'; end if;
  select encode(digest(string_agg(cipher_sha256, '' order by idx), 'sha256'), 'hex') into v_manifest from public.fmail_att_chunks where attachment_id = p_att;
  update public.fmail_attachments set state = 'sealed', cipher_bytes = v_sum, manifest_hash = v_manifest, completed_at = now() where id = p_att;
  return jsonb_build_object('complete', true, 'manifest_hash', v_manifest, 'cipher_bytes', v_sum);
end $$;
revoke all on function public.fmail_att_begin(uuid, text, bytea, bytea, text, bytea, bigint, int, text), public.fmail_att_put_chunk(uuid, int, int, text, text), public.fmail_att_missing(uuid), public.fmail_att_complete(uuid) from public, anon, authenticated;
grant execute on function public.fmail_att_begin(uuid, text, bytea, bytea, text, bytea, bigint, int, text), public.fmail_att_put_chunk(uuid, int, int, text, text), public.fmail_att_missing(uuid), public.fmail_att_complete(uuid) to service_role;

-- 11m) scan verdict from ClamAV (clamd INSTREAM): clean moves on, infected goes to quarantine and is ledgered. Never "pass by default".
create or replace function public.fmail_att_scan_result(p_actor uuid, p_att uuid, p_verdict text, p_sig text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare a public.fmail_attachments; v_led jsonb;
begin
  if p_verdict not in ('clean', 'infected', 'error') then raise exception 'E167: verdict must be clean, infected or error' using errcode = '22023'; end if;
  select * into a from public.fmail_attachments where id = p_att for update;
  if a.id is null then raise exception 'E167: unknown attachment' using errcode = '23503'; end if;
  if a.state = 'sealed' then update public.fmail_attachments set state = 'scanning' where id = p_att; end if;
  if p_verdict = 'clean' then update public.fmail_attachments set state = 'clean', scan_verdict = 'clean' where id = p_att;
  elsif p_verdict = 'infected' then
    update public.fmail_attachments set state = 'infected', scan_verdict = 'infected', scan_sig = left(p_sig, 120) where id = p_att;
    update public.fmail_attachments set state = 'quarantined', quarantined_at = now() where id = p_att;
  else update public.fmail_attachments set state = 'failed', scan_verdict = 'error' where id = p_att; end if;
  v_led := public.fmail_ledger_append(p_actor, a.mailbox_id, case when p_verdict = 'infected' then 'quarantine_in' else 'attachment_scan' end, p_att::text,
            'attachment scan result recorded (clamd)', jsonb_build_object('verdict', p_verdict), p_verdict = 'infected');
  return jsonb_build_object('verdict', p_verdict, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_att_scan_result(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.fmail_att_scan_result(uuid, uuid, text, text) to service_role;

-- ===============================================================================================================================================
-- 11n) helper functions are not doors: nobody but service_role (and the definer functions above, which run as owner) may call them
revoke all on function public.fmail_sha256_167(bytea), public.fmail_lp_167(text), public.fmail_ledger_hash_167(text, bigint, bigint, uuid, text, text, text, jsonb),
  public.fmail_outbox_transition_ok_167(text, text), public.fmail_att_transition_ok_167(text, text), public.fmail_thread_recount_167(uuid) from public, anon, authenticated;
grant execute on function public.fmail_sha256_167(bytea), public.fmail_lp_167(text), public.fmail_ledger_hash_167(text, bigint, bigint, uuid, text, text, text, jsonb),
  public.fmail_outbox_transition_ok_167(text, text), public.fmail_att_transition_ok_167(text, text), public.fmail_thread_recount_167(uuid) to service_role;

-- ===============================================================================================================================================
-- 12) POSTURE (read only): one row of facts the CHECK file and the founder UI can show. No content, no address, no name.
-- ===============================================================================================================================================
create or replace function public.fmail_posture167()
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare t text; v_rls jsonb := '{}'::jsonb; v_tables text[] := array['fmail_policy','fmail_mailboxes','fmail_folders','fmail_threads','fmail_messages','fmail_labels','fmail_message_labels','fmail_drafts','fmail_draft_versions','fmail_outbox','fmail_attachments','fmail_att_chunks','fmail_ledger'];
        v_head bigint; v_ok boolean; v_anon boolean := false;
begin
  foreach t in array v_tables loop
    v_rls := v_rls || jsonb_build_object(t, coalesce((select c.relrowsecurity and c.relforcerowsecurity from pg_class c where c.oid = to_regclass('public.' || t)), false));
    if has_table_privilege('anon', 'public.' || t, 'select') or has_table_privilege('authenticated', 'public.' || t, 'select') then v_anon := true; end if;
  end loop;
  select coalesce(max(seq), 0) into v_head from public.fmail_ledger;
  begin perform public.fmail_ledger_verify(1); v_ok := true; exception when others then v_ok := false; end;
  return jsonb_build_object('rls_forced', v_rls, 'all_rls', not exists (select 1 from jsonb_each(v_rls) e where e.value <> 'true'::jsonb), 'anon_can_read', v_anon,
    'ledger_head', v_head, 'ledger_ok', v_ok, 'mailboxes', (select count(*) from public.fmail_mailboxes), 'messages', (select count(*) from public.fmail_messages),
    'pending_outbox', (select count(*) from public.fmail_outbox where state in ('queued', 'scheduled', 'sending')), 'quarantined', (select count(*) from public.fmail_attachments where state = 'quarantined'),
    'plain_text_columns', (select count(*) from information_schema.columns where table_schema = 'public' and table_name in ('fmail_messages', 'fmail_drafts', 'fmail_draft_versions') and column_name in ('body', 'subject', 'text', 'html')));
end $$;
revoke all on function public.fmail_posture167() from public, anon, authenticated;
grant execute on function public.fmail_posture167() to service_role;

-- ===============================================================================================================================================
-- 13) SELFTEST: runs the real rules against throw-away data and then ROLLS ITSELF BACK (a sentinel exception undoes every row, ledger rows included).
--     Returns {ok, passed, failed, checks:[{name, ok}]}. Needs one founder account to exist (E100). Writes nothing that stays.
-- ===============================================================================================================================================
create or replace function public.fmail_selftest167()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_actor uuid; v_out jsonb; v_box uuid; v_box2 uuid; v_inb uuid; v_f2 uuid; v_msg uuid; v_thr uuid; v_dr uuid; v_n int; v_att uuid; v_o uuid;
  b12 bytea := decode(repeat('01', 12), 'hex'); b40 bytea := decode(repeat('02', 40), 'hex'); b32 bytea := decode(repeat('03', 32), 'hex'); bl bytea := decode(repeat('ab', 40), 'hex');
  h1 text := repeat('a', 64); h2 text := repeat('b', 64); v_j jsonb; v_pass int; v_fail int; v_msg_out uuid; v_tok text := repeat('c', 64);
  v_txt text;
begin
  select user_id into v_actor from public.founder_accounts limit 1;
  if v_actor is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, brand, recipient_key_id, vault_key_id) values (v_actor, 'selftest167a@anexomail.com', 'anexomail', 'pqk-selftest-1', 'vk-selftest-1') returning id into v_box;
    insert into public.fmail_mailboxes (owner, address, brand, recipient_key_id, vault_key_id) values (v_actor, 'selftest167b@nexatect.com', 'nexatect', 'pqk-selftest-2', 'vk-selftest-2') returning id into v_box2;
    select count(*) into v_n from public.fmail_folders where mailbox_id = v_box;
    res := res || jsonb_build_object('name', 'nine system folders created by trigger', 'ok', v_n = 9);
    select id into v_inb from public.fmail_folders where mailbox_id = v_box and kind = 'inbox';
    select id into v_f2 from public.fmail_folders where mailbox_id = v_box2 and kind = 'inbox';

    begin update public.fmail_folders set name = 'x' where id = v_inb; res := res || jsonb_build_object('name', 'system folder rename refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'system folder rename refused', 'ok', true); end;

    begin insert into public.fmail_mailboxes (owner, address, brand) values (v_actor, 'Bad Address@x', 'anexomail'); res := res || jsonb_build_object('name', 'bad address refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'bad address refused', 'ok', true); end;

    v_out := public.fmail_deliver_inbound(v_box, 'inbox', 'recipient_pq', bl, bl, b12, b12, 'pqk-selftest-1', b40, b32, b32, null, b32, b32, 'example.org', 1200, 'pass', 'pass', 'pass', 'none', false, 1.5, 'tls13_pq');
    v_msg := (v_out ->> 'message_id')::uuid; v_thr := (v_out ->> 'thread_id')::uuid;
    res := res || jsonb_build_object('name', 'inbound delivery stores a sealed message', 'ok', (v_out ->> 'stored')::boolean and v_msg is not null);
    v_out := public.fmail_deliver_inbound(v_box, 'inbox', 'recipient_pq', bl, bl, b12, b12, 'pqk-selftest-1', b40, b32, b32, null, b32, b32, 'example.org', 1200, 'pass', 'pass', 'pass', 'none', false, 1.5, 'tls13_pq');
    res := res || jsonb_build_object('name', 'same Message-ID is not stored twice', 'ok', not (v_out ->> 'stored')::boolean and v_out ->> 'reason' = 'duplicate');
    select unread_count, msg_count into v_n, v_pass from public.fmail_threads where id = v_thr;
    res := res || jsonb_build_object('name', 'thread counters kept by trigger (1 message, 1 unread)', 'ok', v_n = 1 and v_pass = 1);
    perform public.fmail_flag(v_box, array[v_msg], true, null);
    select unread_count into v_n from public.fmail_threads where id = v_thr;
    res := res || jsonb_build_object('name', 'reading a message lowers the unread counter', 'ok', v_n = 0);

    begin update public.fmail_messages set sealed_body = bl || '\x00' where id = v_msg; res := res || jsonb_build_object('name', 'sealed body is immutable', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'sealed body is immutable', 'ok', true); end;

    begin insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash, size_bytes)
          values (v_box, v_thr, v_f2, 'in', 'vault', bl, bl, b12, b12, 'vk-selftest-1', b40, b32, 10);
          res := res || jsonb_build_object('name', 'a message cannot use a folder of another mailbox', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'a message cannot use a folder of another mailbox', 'ok', true); end;

    select count(*) into v_n from public.fmail_thread_page(v_box, v_inb, null, null, 50, false);
    res := res || jsonb_build_object('name', 'keyset thread page lists the thread', 'ok', v_n = 1);
    begin perform * from public.fmail_thread_page(v_box, v_inb, null, null, 1000, false); res := res || jsonb_build_object('name', 'page limit above 200 refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'page limit above 200 refused', 'ok', true); end;

    -- outbox
    insert into public.fmail_threads (mailbox_id, first_at, last_at) values (v_box, now(), now()) returning id into v_thr;
    select id into v_dr from public.fmail_folders where mailbox_id = v_box and kind = 'drafts';
    insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash, size_bytes, is_draft, is_read)
      values (v_box, v_thr, v_dr, 'out', 'recipient_pq', bl, bl, b12, b12, 'pqk-selftest-1', b40, b32, 900, true, true) returning id into v_msg_out;
    begin perform public.fmail_outbox_enqueue(v_actor, v_box, v_msg_out, array[b32], null, null); res := res || jsonb_build_object('name', 'send without a passkey touch refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'send without a passkey touch refused', 'ok', true); end;
    v_out := public.fmail_outbox_enqueue(v_actor, v_box, v_msg_out, array[b32], null, v_tok);
    v_o := (v_out ->> 'outbox_id')::uuid;
    res := res || jsonb_build_object('name', 'send with a touch is queued with an undo window', 'ok', v_out ->> 'state' = 'queued');
    begin update public.fmail_outbox set state = 'sent' where id = v_o; res := res || jsonb_build_object('name', 'illegal outbox move queued->sent refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'illegal outbox move queued->sent refused', 'ok', true); end;
    select count(*) into v_n from public.fmail_outbox_claim(10);
    res := res || jsonb_build_object('name', 'a row inside its undo window is not claimed yet', 'ok', v_n = 0);
    v_out := public.fmail_outbox_undo(v_actor, v_o);
    res := res || jsonb_build_object('name', 'undo inside the window works', 'ok', v_out ->> 'state' = 'undone');
    begin update public.fmail_outbox set state = 'queued' where id = v_o; res := res || jsonb_build_object('name', 'an undone row cannot come back', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'an undone row cannot come back', 'ok', true); end;

    -- ledger
    begin perform public.fmail_ledger_verify(1); res := res || jsonb_build_object('name', 'ledger chain verifies', 'ok', true);
    exception when others then res := res || jsonb_build_object('name', 'ledger chain verifies', 'ok', false); end;
    begin update public.fmail_ledger set reason = 'tampered tampered' where seq = (select max(seq) from public.fmail_ledger); res := res || jsonb_build_object('name', 'ledger update refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'ledger update refused', 'ok', true); end;
    begin delete from public.fmail_ledger; res := res || jsonb_build_object('name', 'ledger delete refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'ledger delete refused', 'ok', true); end;

    -- policy
    begin update public.fmail_policy set undo_seconds = 60 where id = 1; res := res || jsonb_build_object('name', 'policy cannot change without the ledger door', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'policy cannot change without the ledger door', 'ok', true); end;
    v_out := public.fmail_policy_set(v_actor, 'undo_seconds', '45', 'selftest policy change');
    res := res || jsonb_build_object('name', 'policy change through fmail_policy_set is ledgered', 'ok', (v_out ->> 'seq') is not null and (select undo_seconds from public.fmail_policy where id = 1) = 45);
    begin perform public.fmail_policy_set(v_actor, 'undo_seconds', '9999', 'selftest out of range'); res := res || jsonb_build_object('name', 'policy value out of range refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'policy value out of range refused', 'ok', true); end;

    -- attachments (3 chunks of 1 MiB: total 2.5 MiB -> 3 chunks)
    v_out := public.fmail_att_begin(v_box, 'out', bl, b12, 'pqk-selftest-1', b40, 2621440, 1048576, 'document');
    v_att := (v_out ->> 'attachment_id')::uuid;
    res := res || jsonb_build_object('name', 'attachment plan: 3 chunks for 2.5 MiB', 'ok', (v_out ->> 'chunk_count')::int = 3);
    begin perform public.fmail_att_put_chunk(v_att, 7, 1048592, h1, 'att/selftest/c7'); res := res || jsonb_build_object('name', 'chunk outside the file refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'chunk outside the file refused', 'ok', true); end;
    perform public.fmail_att_put_chunk(v_att, 0, 1048592, h1, 'att/selftest/c0');
    v_out := public.fmail_att_put_chunk(v_att, 0, 1048592, h1, 'att/selftest/c0');
    res := res || jsonb_build_object('name', 'same chunk twice with the same hash is idempotent', 'ok', (v_out ->> 'again')::boolean);
    begin perform public.fmail_att_put_chunk(v_att, 0, 1048592, h2, 'att/selftest/c0'); res := res || jsonb_build_object('name', 'same chunk with a different hash refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'same chunk with a different hash refused', 'ok', true); end;
    begin perform public.fmail_att_put_chunk(v_att, 1, 1048592, h1, 'att/../etc/passwd'); res := res || jsonb_build_object('name', 'path traversal in a chunk path refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'path traversal in a chunk path refused', 'ok', true); end;
    v_out := public.fmail_att_complete(v_att);
    res := res || jsonb_build_object('name', 'complete with missing chunks reports them', 'ok', not (v_out ->> 'complete')::boolean and jsonb_array_length(v_out -> 'missing') = 2);
    perform public.fmail_att_put_chunk(v_att, 1, 1048592, h2, 'att/selftest/c1');
    perform public.fmail_att_put_chunk(v_att, 2, 524288 + 16, h1, 'att/selftest/c2');
    v_out := public.fmail_att_complete(v_att);
    res := res || jsonb_build_object('name', 'complete with all chunks seals the file', 'ok', (v_out ->> 'complete')::boolean and (v_out ->> 'manifest_hash') ~ '^[0-9a-f]{64}$');
    begin perform public.fmail_att_put_chunk(v_att, 2, 524288 + 16, h2, 'att/selftest/c2b'); res := res || jsonb_build_object('name', 'chunk map frozen after completion', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'chunk map frozen after completion', 'ok', true); end;
    v_out := public.fmail_att_scan_result(v_actor, v_att, 'infected', 'Eicar-Test-Signature');
    res := res || jsonb_build_object('name', 'infected file is quarantined and ledgered', 'ok', (select state from public.fmail_attachments where id = v_att) = 'quarantined');
    begin insert into public.fmail_attachments (mailbox_id, direction, sealed_name, nonce_name, key_id, key_wrap, total_bytes, chunk_bytes, chunk_count)
          values (v_box, 'out', bl, b12, 'pqk-selftest-1', b40, 2621440, 1048576, 9); res := res || jsonb_build_object('name', 'wrong chunk count refused (arithmetic)', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'wrong chunk count refused (arithmetic)', 'ok', true); end;

    -- hard delete + snooze
    begin perform public.fmail_delete_hard(v_actor, v_box, array[v_msg], null); res := res || jsonb_build_object('name', 'hard delete without a touch refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'hard delete without a touch refused', 'ok', true); end;
    begin perform public.fmail_snooze(v_box, v_thr, now() - interval '1 hour'); res := res || jsonb_build_object('name', 'snooze in the past refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'snooze in the past refused', 'ok', true); end;
    begin perform public.fmail_ledger_verify(1); res := res || jsonb_build_object('name', 'ledger still verifies at the end', 'ok', true);
    exception when others then res := res || jsonb_build_object('name', 'ledger still verifies at the end', 'ok', false); end;
    -- roll everything back
    select count(*) filter (where (e ->> 'ok')::boolean), count(*) filter (where not (e ->> 'ok')::boolean) into v_pass, v_fail from jsonb_array_elements(res) e;
    raise exception using errcode = 'P0777', message = jsonb_build_object('ok', v_fail = 0, 'passed', v_pass, 'failed', v_fail, 'checks', res)::text;
  exception
    when sqlstate 'P0777' then
      get stacked diagnostics v_txt = message_text;      -- the sentinel carries the result; the subtransaction rolled every test row back
      return v_txt::jsonb;
    when others then
      return jsonb_build_object('ok', false, 'error', sqlerrm, 'checks', res);
  end;
end $$;
revoke all on function public.fmail_selftest167() from public, anon, authenticated;
grant execute on function public.fmail_selftest167() to service_role;

-- ===============================================================================================================================================
-- 14) RUN THE SELFTEST NOW (sql-run stops if a rule is broken): 0 failed, or this file fails loudly
-- ===============================================================================================================================================
do $$
declare r jsonb;
begin
  if exists (select 1 from public.founder_accounts) then
    r := public.fmail_selftest167();
    if not coalesce((r ->> 'ok')::boolean, false) then raise exception 'E167 selftest FAILED: %', r; end if;
    raise notice 'E167 selftest: % passed, % failed', r ->> 'passed', r ->> 'failed';
  else
    raise notice 'E167: no founder account yet, selftest skipped (run CHECK_E167 later)';
  end if;
end $$;
