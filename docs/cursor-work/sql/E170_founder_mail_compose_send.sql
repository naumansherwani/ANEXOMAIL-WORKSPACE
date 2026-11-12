
-- E170 (Q1d, 13 Nov 2026): founder mailbox COMPOSE + SEND + UNDO doors, DKIM key registry.
-- Stands on E167 (outbox state machine, drafts tables, ledger), E168 (mailbox key guard), E169 (mail passkey actions, touch consume).
-- TECHNOLOGY: SQL (PostgreSQL 16, RLS forced, service_role only, security-definer doors with a fixed search_path, append-only ledger rows, optimistic draft versions,
-- ONE transaction for "create message + queue it", self-rolling-back selftest). The Rust engine (fmail_out.rs) seals the content (AES-256-GCM) before it gets here;
-- the database never sees a plain subject, body or address. Recipients arrive only as blind indexes (HMAC-SHA-256) for limits and duplicates.
-- OUTGOING MAIL IS ALWAYS 'vault' SEALED: the server has to read it to send it (the text leaves the building anyway), so a device-only (ML-KEM) seal would be a lie here.
-- Run once through sql-run.sh, after E169. Safe to run again (idempotent).
-- DKIM PRIVATE KEYS: stored only WRAPPED (AES-256-GCM under the vault master, wrapped in Rust). Never plain. The public half is shown to the founder as the DNS TXT value.

do $$
begin
  if to_regprocedure('public.fmail_touch_consume169(uuid,uuid,uuid,text,text,jsonb,text)') is null then raise exception 'E170: E169 is missing (run E169 first)'; end if;
  if to_regprocedure('public.fmail_outbox_enqueue(uuid,uuid,uuid,bytea[],timestamptz,text)') is null then raise exception 'E170: E167 outbox doors are missing'; end if;
end $$;

-- 1) the ledger action list grows by two names (closed set, same pattern as E169)
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_queue%' loop
    if c.d like '%dkim_install%' then v_has := true; else execute format('alter table public.fmail_ledger drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_ledger add constraint fmail_ledger_action_ck check (action in (
      'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
      'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
      'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
      'inbound_reject','panic_lock','inbound_ok','unseal_gated','vault_set','mailbox_seed','dkim_install','dkim_revoke'));
  end if;
end $$;

-- 2) DKIM KEY REGISTRY: one active key per mailbox + selector; old keys are revoked, never deleted (the DNS record can be removed later by hand)
create table if not exists public.fmail_dkim_keys (
  id          uuid primary key default gen_random_uuid(),
  mailbox_id  uuid not null references public.fmail_mailboxes (id) on delete cascade,
  selector    text not null check (selector ~ '^[a-z0-9][a-z0-9-]{0,62}$'),
  alg         text not null check (alg in ('ed25519-sha256', 'rsa-sha256')),
  public_key  bytea not null check (octet_length(public_key) between 32 and 1024),     -- ed25519: 32 raw bytes; rsa: DER SubjectPublicKeyInfo
  wrapped     bytea not null check (octet_length(wrapped) between 32 and 8192),         -- AES-256-GCM(vault master) of the PKCS#8 private key; never plain
  nonce       bytea not null check (octet_length(nonce) = 12),
  status      text not null default 'active' check (status in ('active', 'revoked')),
  touch_hash  text not null check (touch_hash ~ '^[0-9a-f]{64}$'),
  created_at  timestamptz not null default now(),
  revoked_at  timestamptz,
  check ((status = 'revoked') = (revoked_at is not null))
);
create unique index if not exists fmail_dkim_active_uq on public.fmail_dkim_keys (mailbox_id, alg) where status = 'active';
alter table public.fmail_dkim_keys enable row level security;
alter table public.fmail_dkim_keys force row level security;
revoke all on public.fmail_dkim_keys from public, anon, authenticated;
grant select, insert, update on public.fmail_dkim_keys to service_role;

create or replace function public.fmail_dkim_guard_170() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E170: a DKIM key is revoked, never deleted' using errcode = '42501'; end if;
  if tg_op = 'UPDATE' and (new.wrapped is distinct from old.wrapped or new.public_key is distinct from old.public_key or new.selector is distinct from old.selector
        or new.alg is distinct from old.alg or new.mailbox_id is distinct from old.mailbox_id or new.nonce is distinct from old.nonce) then
    raise exception 'E170: a DKIM key row can only change its status' using errcode = '42501'; end if;
  if tg_op = 'UPDATE' and old.status = 'revoked' then raise exception 'E170: a revoked key stays revoked' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists fmail_dkim_guard on public.fmail_dkim_keys;
create trigger fmail_dkim_guard before update or delete on public.fmail_dkim_keys for each row execute function public.fmail_dkim_guard_170();

create or replace function public.fmail_dkim_install170(p_actor uuid, p_mailbox uuid, p_selector text, p_alg text, p_public bytea, p_wrapped bytea, p_nonce bytea, p_touch_hash text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid; v_old uuid; v_led jsonb;
begin
  if p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$' then raise exception 'E170: installing a DKIM key needs a passkey touch' using errcode = '42501'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E170: not your mailbox' using errcode = '42501'; end if;
  select id into v_old from public.fmail_dkim_keys where mailbox_id = p_mailbox and alg = p_alg and status = 'active' for update;
  if v_old is not null then update public.fmail_dkim_keys set status = 'revoked', revoked_at = now() where id = v_old; end if;
  insert into public.fmail_dkim_keys (mailbox_id, selector, alg, public_key, wrapped, nonce, touch_hash) values (p_mailbox, p_selector, p_alg, p_public, p_wrapped, p_nonce, p_touch_hash) returning id into v_id;
  update public.fmail_mailboxes set dkim_selector = p_selector where id = p_mailbox;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'dkim_install', v_id::text, 'DKIM signing key installed (passkey touched)', jsonb_build_object('selector', p_selector, 'alg', p_alg, 'replaced', v_old is not null), true);
  return jsonb_build_object('key_id', v_id, 'selector', p_selector, 'alg', p_alg, 'ledger_seq', v_led -> 'seq');
end $$;

create or replace function public.fmail_dkim_revoke170(p_actor uuid, p_mailbox uuid, p_key uuid, p_touch_hash text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_led jsonb;
begin
  if p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$' then raise exception 'E170: revoking a DKIM key needs a passkey touch' using errcode = '42501'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E170: not your mailbox' using errcode = '42501'; end if;
  update public.fmail_dkim_keys set status = 'revoked', revoked_at = now() where id = p_key and mailbox_id = p_mailbox and status = 'active';
  if not found then raise exception 'E170: no such active key' using errcode = '23503'; end if;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'dkim_revoke', p_key::text, 'DKIM signing key revoked (passkey touched)', '{}'::jsonb, true);
  return jsonb_build_object('revoked', true, 'ledger_seq', v_led -> 'seq');
end $$;

-- the sender asks for the active keys of a mailbox (wrapped; Rust unwraps them under the master). Public keys are listed for the DNS record.
create or replace function public.fmail_dkim_active170(p_mailbox uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public, extensions as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'selector', selector, 'alg', alg, 'public', public.fmail_b64_169(public_key),
                                               'wrapped', public.fmail_b64_169(wrapped), 'nonce', public.fmail_b64_169(nonce), 'created_at', created_at) order by created_at), '[]'::jsonb)
    from public.fmail_dkim_keys where mailbox_id = p_mailbox and status = 'active'
$$;

-- 3) DRAFTS (autosave): sealed versions, optimistic concurrency (the caller names the version it saw; a stale save is refused, never merged silently)
create or replace function public.fmail_draft_save170(p_mailbox uuid, p_draft uuid, p_expected int, p_reply_to uuid, p_sealed bytea, p_nonce bytea, p_key_id text, p_key_wrap bytea)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_id uuid := p_draft; v_head int;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and status = 'active') then raise exception 'E170: mailbox is not active' using errcode = '42501'; end if;
  if v_id is null then
    if coalesce(p_expected, 0) <> 0 then raise exception 'E170: a new draft starts at version 0' using errcode = '22023'; end if;
    if p_reply_to is not null and not exists (select 1 from public.fmail_messages where id = p_reply_to and mailbox_id = p_mailbox) then raise exception 'E170: reply target is not in this mailbox' using errcode = '23514'; end if;
    insert into public.fmail_drafts (mailbox_id, reply_to) values (p_mailbox, p_reply_to) returning id into v_id;
  else
    select head_version into v_head from public.fmail_drafts where id = v_id and mailbox_id = p_mailbox and discarded_at is null for update;
    if v_head is null then raise exception 'E170: unknown or discarded draft' using errcode = '23503'; end if;
    if v_head <> coalesce(p_expected, -1) then raise exception 'E170: stale draft (head is %, you saw %)', v_head, p_expected using errcode = '40001'; end if;
  end if;
  insert into public.fmail_draft_versions (draft_id, version, sealed, nonce, key_id, key_wrap)
    values (v_id, (select head_version + 1 from public.fmail_drafts where id = v_id), p_sealed, p_nonce, p_key_id, p_key_wrap);
  return jsonb_build_object('draft_id', v_id, 'version', (select head_version from public.fmail_drafts where id = v_id));
end $$;

create or replace function public.fmail_draft_list170(p_mailbox uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'version', d.head_version, 'reply_to', d.reply_to, 'updated_at', d.updated_at) order by d.updated_at desc), '[]'::jsonb)
    from (select * from public.fmail_drafts where mailbox_id = p_mailbox and discarded_at is null and head_version >= 1 order by updated_at desc limit 100) d
$$;

create or replace function public.fmail_draft_get170(p_mailbox uuid, p_draft uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('id', d.id, 'version', d.head_version, 'reply_to', d.reply_to, 'key_id', v.key_id,
           'sealed', public.fmail_b64_169(v.sealed), 'nonce', public.fmail_b64_169(v.nonce), 'key_wrap', public.fmail_b64_169(v.key_wrap), 'updated_at', d.updated_at)
    from public.fmail_drafts d join public.fmail_draft_versions v on v.draft_id = d.id and v.version = d.head_version
   where d.id = p_draft and d.mailbox_id = p_mailbox and d.discarded_at is null
$$;

create or replace function public.fmail_draft_discard170(p_mailbox uuid, p_draft uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  update public.fmail_drafts set discarded_at = now() where id = p_draft and mailbox_id = p_mailbox and discarded_at is null;
  return jsonb_build_object('discarded', found);
end $$;

-- 4) COMPOSE + QUEUE in ONE transaction: the out message is created in the outbox folder and the outbox row (undo window, limits, touch, ledger) is written together.
--    Any refusal (limits, touch, schedule window) rolls the message back too, so there is never an orphan "queued" message without an outbox row.
create or replace function public.fmail_compose_send170(
  p_actor uuid, p_mailbox uuid, p_sealed_body bytea, p_sealed_meta bytea, p_nonce_body bytea, p_nonce_meta bytea, p_key_id text, p_key_wrap bytea, p_aad_hash bytea,
  p_msgid_blind bytea, p_parent_blind bytea, p_subject_blind bytea, p_size bigint, p_attach int, p_rcpt_hex text[], p_schedule_at timestamptz, p_touch_hash text, p_draft uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_box public.fmail_mailboxes; v_folder uuid; v_thread uuid; v_msg uuid; v_max bigint; v_out jsonb; v_rc bytea[];
begin
  if p_rcpt_hex is null or exists (select 1 from unnest(p_rcpt_hex) x where x !~ '^[0-9a-f]{64}$') then raise exception 'E170: recipient blind indexes must be 64 hex' using errcode = '22023'; end if;
  v_rc := array(select decode(x, 'hex') from unnest(p_rcpt_hex) x);
  select * into v_box from public.fmail_mailboxes where id = p_mailbox and owner = p_actor;
  if v_box.id is null then raise exception 'E170: not your mailbox' using errcode = '42501'; end if;
  if v_box.status <> 'active' then raise exception 'E170: mailbox is not active (%)', v_box.status using errcode = '42501'; end if;
  select max_message_bytes into v_max from public.fmail_policy where id = 1;
  if p_size > v_max then raise exception 'E170: message is bigger than the policy limit (% bytes)', v_max using errcode = '54000'; end if;
  if p_msgid_blind is null then raise exception 'E170: a Message-ID blind index is required' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_dkim_keys where mailbox_id = p_mailbox and status = 'active') then
    raise exception 'E170: no active DKIM key - install one first (mail would be unsigned)' using errcode = '55000'; end if;
  select id into v_folder from public.fmail_folders where mailbox_id = p_mailbox and kind = 'outbox';
  if p_parent_blind is not null then select thread_id into v_thread from public.fmail_messages where mailbox_id = p_mailbox and msgid_blind = p_parent_blind limit 1; end if;
  if v_thread is null and p_subject_blind is not null then
    select id into v_thread from public.fmail_threads where mailbox_id = p_mailbox and subject_blind = p_subject_blind and last_at > now() - interval '30 days' order by last_at desc limit 1; end if;
  if v_thread is null then insert into public.fmail_threads (mailbox_id, subject_blind, first_at, last_at) values (p_mailbox, p_subject_blind, now(), now()) returning id into v_thread; end if;
  insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash,
        msgid_blind, parent_blind, subject_blind, sender_domain, size_bytes, attach_count, is_read, sent_at, spf, dkim, dmarc)
  values (p_mailbox, v_thread, v_folder, 'out', 'vault', p_sealed_body, p_sealed_meta, p_nonce_body, p_nonce_meta, p_key_id, p_key_wrap, p_aad_hash,
        p_msgid_blind, p_parent_blind, p_subject_blind, split_part(v_box.address, '@', 2), p_size, coalesce(p_attach, 0), true, now(), 'none', 'none', 'none')
  returning id into v_msg;
  v_out := public.fmail_outbox_enqueue(p_actor, p_mailbox, v_msg, v_rc, p_schedule_at, p_touch_hash);
  if p_draft is not null then update public.fmail_drafts set discarded_at = now() where id = p_draft and mailbox_id = p_mailbox and discarded_at is null; end if;
  return v_out || jsonb_build_object('message_id', v_msg, 'thread_id', v_thread);
end $$;

-- 5) what the sender worker needs for ONE claimed row (sealed fields as base64; the mailbox owner is the ledger actor)
create or replace function public.fmail_outbox_job170(p_outbox uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('outbox_id', o.id, 'mailbox_id', o.mailbox_id, 'message_id', o.message_id, 'actor', b.owner, 'address', b.address, 'attempts', o.attempts,
           'direction', m.direction, 'key_id', m.key_id, 'seal_mode', m.seal_mode,
           'msgid_blind', encode(m.msgid_blind, 'hex'), 'aad_hash', encode(m.aad_hash, 'hex'),
           'key_wrap', public.fmail_b64_169(m.key_wrap), 'meta', public.fmail_b64_169(m.sealed_meta), 'nonce_meta', public.fmail_b64_169(m.nonce_meta),
           'body', public.fmail_b64_169(m.sealed_body), 'nonce_body', public.fmail_b64_169(m.nonce_body),
           'dkim', public.fmail_dkim_active170(o.mailbox_id))
    from public.fmail_outbox o join public.fmail_messages m on m.id = o.message_id join public.fmail_mailboxes b on b.id = o.mailbox_id
   where o.id = p_outbox and o.state = 'sending'
$$;

-- a PERMANENT failure (5xx from the remote server, null MX, private address): the row is failed and never requeued (next_attempt = infinity), ledgered
create or replace function public.fmail_outbox_dead170(p_actor uuid, p_outbox uuid, p_reply text, p_error text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare o public.fmail_outbox; v_led jsonb;
begin
  select * into o from public.fmail_outbox where id = p_outbox for update;
  if o.id is null then raise exception 'E170: unknown outbox row' using errcode = '23503'; end if;
  update public.fmail_outbox set state = 'failed', last_error = left(coalesce(p_error, 'permanent failure'), 300), smtp_reply = left(p_reply, 300), next_attempt = 'infinity'::timestamptz where id = p_outbox;
  v_led := public.fmail_ledger_append(p_actor, o.mailbox_id, 'send_fail', o.message_id::text, 'send failed for good (permanent refusal), will not retry', jsonb_build_object('attempt', o.attempts, 'permanent', true), false);
  return jsonb_build_object('state', 'failed', 'permanent', true, 'ledger_seq', v_led -> 'seq');
end $$;

-- what the Outbox view and the Undo bar show: states and clocks only, never content
create or replace function public.fmail_outbox_list170(p_mailbox uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('outbox_id', o.id, 'message_id', o.message_id, 'state', o.state, 'not_before', o.not_before, 'undo_until', o.undo_until,
           'rcpt', o.rcpt_count, 'attempts', o.attempts, 'last_error', o.last_error, 'tls', o.tls_out, 'dkim', o.dkim_signed, 'finished_at', o.finished_at) order by o.created_at desc), '[]'::jsonb)
    from (select * from public.fmail_outbox where mailbox_id = p_mailbox and (finished_at is null or finished_at > now() - interval '1 day') order by created_at desc limit 100) o
$$;

-- cancel a scheduled / failed row (not inside the undo window: that is "undo"); ledgered
create or replace function public.fmail_outbox_cancel170(p_actor uuid, p_mailbox uuid, p_outbox uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare o public.fmail_outbox; v_led jsonb; v_dr uuid;
begin
  select * into o from public.fmail_outbox where id = p_outbox and mailbox_id = p_mailbox for update;
  if o.id is null then raise exception 'E170: unknown outbox row' using errcode = '23503'; end if;
  update public.fmail_outbox set state = 'cancelled' where id = p_outbox;
  select id into v_dr from public.fmail_folders where mailbox_id = p_mailbox and kind = 'drafts';
  update public.fmail_messages set folder_id = v_dr, is_draft = true where id = o.message_id;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'send_cancel', o.message_id::text, 'queued mail cancelled by the founder', '{}'::jsonb, false);
  return jsonb_build_object('state', 'cancelled', 'ledger_seq', v_led -> 'seq');
end $$;

do $$
declare f text;
begin
  for f in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname ~ '170$' loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- 6) POSTURE + SELFTEST (rolls itself back)
create or replace function public.fmail_posture170() returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'rls_forced', (select relforcerowsecurity from pg_class where oid = 'public.fmail_dkim_keys'::regclass),
    'anon_can_touch', has_table_privilege('anon', 'public.fmail_dkim_keys', 'select') or has_table_privilege('authenticated', 'public.fmail_dkim_keys', 'select'),
    'doors_service_only', (select bool_and(has_function_privilege('service_role', p.oid, 'execute') and not has_function_privilege('anon', p.oid, 'execute') and not has_function_privilege('authenticated', p.oid, 'execute'))
                             from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname ~ '170$' and p.proname <> 'fmail_posture170' and p.proname <> 'fmail_selftest170'),
    'door_count', (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname ~ '170$'),
    'guard_trigger', (select count(*) from pg_trigger where tgname = 'fmail_dkim_guard' and not tgisinternal),
    'plain_private_key_columns', (select count(*) from information_schema.columns where table_name = 'fmail_dkim_keys' and column_name ~ 'private|secret|pem'))
$$;
revoke all on function public.fmail_posture170() from public, anon, authenticated;
grant execute on function public.fmail_posture170() to service_role;

create or replace function public.fmail_selftest170() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_t text := repeat('a', 64); v_r jsonb; v_msg uuid; v_ob uuid; v_d uuid; v_ok boolean; v_n int;
  v_sealed bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
  v_mid bytea := decode(repeat('04', 32), 'hex'); v_rc text[] := array[repeat('05', 32)];
  procedure_dummy int;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest170@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    -- 1 compose without a DKIM key is refused
    begin perform public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, v_mid, null, null, 100, 0, v_rc, null, v_t, null); v_ok := false;
    exception when sqlstate '55000' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'compose without an active DKIM key refused', 'ok', v_ok);
    -- 2 DKIM install needs a touch
    begin perform public.fmail_dkim_install170(v_uid, v_box, 'sel1', 'ed25519-sha256', decode(repeat('06', 32), 'hex'), v_wrap, v_nonce, null); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'DKIM install without a touch refused', 'ok', v_ok);
    v_r := public.fmail_dkim_install170(v_uid, v_box, 'sel1', 'ed25519-sha256', decode(repeat('06', 32), 'hex'), v_wrap, v_nonce, v_t);
    res := res || jsonb_build_object('name', 'DKIM install with a touch is ledgered', 'ok', (v_r ->> 'ledger_seq') is not null);
    res := res || jsonb_build_object('name', 'active key listed with wrapped bytes only', 'ok', jsonb_array_length(public.fmail_dkim_active170(v_box)) = 1);
    v_r := public.fmail_dkim_install170(v_uid, v_box, 'sel2', 'ed25519-sha256', decode(repeat('07', 32), 'hex'), v_wrap, v_nonce, v_t);
    res := res || jsonb_build_object('name', 'a new key of the same algorithm revokes the old one (one active)', 'ok', (select count(*) from public.fmail_dkim_keys where mailbox_id = v_box and status = 'active') = 1
                                                                                  and (select count(*) from public.fmail_dkim_keys where mailbox_id = v_box and status = 'revoked') = 1);
    begin update public.fmail_dkim_keys set wrapped = decode(repeat('0c', 64), 'hex') where mailbox_id = v_box and status = 'active'; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'DKIM key bytes cannot be changed', 'ok', v_ok);
    begin delete from public.fmail_dkim_keys where mailbox_id = v_box; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'DKIM key cannot be deleted', 'ok', v_ok);
    -- 3 drafts: create, save, stale refused, list, get, discard
    v_r := public.fmail_draft_save170(v_box, null, 0, null, v_sealed, v_nonce, 'k-selftest', v_wrap); v_d := (v_r ->> 'draft_id')::uuid;
    res := res || jsonb_build_object('name', 'draft starts at version 1', 'ok', (v_r ->> 'version')::int = 1);
    v_r := public.fmail_draft_save170(v_box, v_d, 1, null, v_sealed, v_nonce, 'k-selftest', v_wrap);
    res := res || jsonb_build_object('name', 'second save is version 2', 'ok', (v_r ->> 'version')::int = 2);
    begin perform public.fmail_draft_save170(v_box, v_d, 1, null, v_sealed, v_nonce, 'k-selftest', v_wrap); v_ok := false; exception when sqlstate '40001' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a stale draft save is refused (no silent merge)', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'draft list and get return the head', 'ok', jsonb_array_length(public.fmail_draft_list170(v_box)) = 1 and (public.fmail_draft_get170(v_box, v_d) ->> 'version')::int = 2);
    -- 4 compose + queue is atomic, creates message + outbox row in the outbox folder, discards the draft
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, v_mid, null, null, 100, 0, v_rc, null, v_t, v_d);
    v_msg := (v_r ->> 'message_id')::uuid; v_ob := (v_r ->> 'outbox_id')::uuid;
    res := res || jsonb_build_object('name', 'compose queues the message with an undo window', 'ok', v_r ->> 'state' = 'queued' and (v_r ->> 'undo_until')::timestamptz > now());
    res := res || jsonb_build_object('name', 'message sits in the outbox folder', 'ok', (select f.kind from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id where m.id = v_msg) = 'outbox');
    res := res || jsonb_build_object('name', 'the draft is discarded by the send', 'ok', public.fmail_draft_get170(v_box, v_d) is null);
    res := res || jsonb_build_object('name', 'outbox list shows the row (no content)', 'ok', jsonb_array_length(public.fmail_outbox_list170(v_box)) = 1 and public.fmail_outbox_list170(v_box)::text !~ 'sealed');
    -- 5 same Message-ID twice is refused (unique index), and the refusal leaves no orphan outbox row
    select count(*) into v_n from public.fmail_outbox where mailbox_id = v_box;
    begin perform public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, v_mid, null, null, 100, 0, v_rc, null, v_t, null); v_ok := false; exception when unique_violation then v_ok := true; end;
    res := res || jsonb_build_object('name', 'duplicate Message-ID refused and no orphan row', 'ok', v_ok and (select count(*) from public.fmail_outbox where mailbox_id = v_box) = v_n);
    -- 6 no touch refused, schedule inside the undo window refused
    begin perform public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, decode(repeat('08', 32), 'hex'), null, null, 100, 0, v_rc, null, null, null); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'send without a touch refused', 'ok', v_ok);
    begin perform public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, decode(repeat('09', 32), 'hex'), null, null, 100, 0, v_rc, now() + interval '5 seconds', v_t, null); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'schedule inside the undo window refused', 'ok', v_ok);
    -- 7 someone else's mailbox refused
    begin perform public.fmail_compose_send170('22222222-2222-2222-2222-222222222222', v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, decode(repeat('0a', 32), 'hex'), null, null, 100, 0, v_rc, null, v_t, null); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'composing in another founder''s mailbox refused', 'ok', v_ok);
    -- 8 job is only visible while the row is sending
    res := res || jsonb_build_object('name', 'job is empty before the sender claims it', 'ok', public.fmail_outbox_job170(v_ob) is null);
    -- 9 undo inside the window returns the message to drafts
    perform public.fmail_outbox_undo(v_uid, v_ob);
    res := res || jsonb_build_object('name', 'undo returns the mail to drafts', 'ok', (select f.kind from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id where m.id = v_msg) = 'drafts' and (select is_draft from public.fmail_messages where id = v_msg));
    -- 10 a scheduled row can be cancelled
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, decode(repeat('0b', 32), 'hex'), null, null, 100, 0, v_rc, now() + interval '2 hours', v_t, null);
    res := res || jsonb_build_object('name', 'a scheduled send is state scheduled', 'ok', v_r ->> 'state' = 'scheduled');
    v_r := public.fmail_outbox_cancel170(v_uid, v_box, (v_r ->> 'outbox_id')::uuid);
    res := res || jsonb_build_object('name', 'a scheduled send can be cancelled (ledgered)', 'ok', v_r ->> 'state' = 'cancelled' and (v_r ->> 'ledger_seq') is not null);
    -- 11 a permanent failure is never requeued
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, decode(repeat('0d', 32), 'hex'), null, null, 100, 0, v_rc, null, v_t, null);
    update public.fmail_outbox set not_before = now() - interval '1 second', undo_until = now() - interval '1 second', created_at = now() - interval '1 minute' where id = (v_r ->> 'outbox_id')::uuid;
    perform public.fmail_outbox_claim(10);
    perform public.fmail_outbox_dead170(v_uid, (v_r ->> 'outbox_id')::uuid, '550 5.1.1 no such user', 'rejected');
    res := res || jsonb_build_object('name', 'a permanent failure is not requeued', 'ok', public.fmail_outbox_requeue_failed() = 0 and (select state from public.fmail_outbox where id = (v_r ->> 'outbox_id')::uuid) = 'failed');
    res := res || jsonb_build_object('name', 'ledger chain still verifies', 'ok', public.fmail_ledger_verify(1) >= 1);
    raise exception 'E170_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E170_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E170_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest170() from public, anon, authenticated;
grant execute on function public.fmail_selftest170() to service_role;
