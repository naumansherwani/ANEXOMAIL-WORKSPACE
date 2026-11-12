
-- E169 - FOUNDER MAILBOX READ DOORS + TOUCH GATES + LEDGER PROOF (phase Q1b-3). Advanced level, sits on E167 + E168 + E117/E118, changes none of their behaviour.
-- ---------------------------------------------------------------------------------------------------------------------------------------------------
-- WHAT THE RUST ENDPOINTS NEED AND THE DATABASE NOW ENFORCES (never only the application):
--   * mail.* passkey actions registered as T2 in founder_action_tiers (E118); fmail_touch_consume169 is the ONE place a mail grant is spent (same grant, same device,
--     same action, same digest, unused, unexpired) and returns the action hash that every touch-gated door below stores as touch_hash.
--   * fmail_threads.vault: a thread the founder moved into the Vault. Vault threads and the quarantine folder are GATED: fmail_get169 hands out NO sealed bytes
--     for them without a touch hash, and every gated open is a ledger row (unseal_gated). Moving a thread OUT of the vault needs a touch too.
--   * fmail_list169 (keyset page by view: inbox sent drafts outbox archive snoozed spam quarantine trash vault), fmail_get169 (one message), fmail_counts169 (rail numbers).
--   * fmail_inbound_note169: after the Rust engine stored a message it writes the ledger row inbound_ok; the database RECOMPUTES sha256 of the stored sealed body and refuses
--     a hash that does not match. fmail_proof169 then proves, any time later, that the ciphertext is unchanged and that the chain from that row to the head verifies.
--   * fmail_mailbox_add169 (touch required) and the first founder mailbox seeded (naumansherwani.founder@anexomail.com, seal mode vault until the kernel can open ML-KEM mail).
--   * fmail_posture169 / fmail_selftest169 (rolls itself back) / CHECK_E169.
-- NOTHING of awam is touched (CORE FREEZE + separation law). service_role only, RLS stays forced on every table. Run again any time.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = pg_catalog, public, extensions;

do $$
begin
  if to_regprocedure('public.fmail_rcpt_resolve(text)') is null then raise exception 'E169: E168 is missing (run E168 first)'; end if;
  if to_regclass('public.founder_action_tiers') is null or to_regprocedure('public.founder_action_hash(text,text,jsonb,text)') is null then raise exception 'E169: E118 (action tiers) is missing'; end if;
end $$;

-- ===============================================================================================================================================
-- 1) THE FIVE MAIL ACTIONS (T2: a fresh passkey touch bound to the exact action)
-- ===============================================================================================================================================
insert into public.founder_action_tiers (action, tier, label, built) values
  ('mail.unseal',    2, 'Open a confidential or quarantined mail', true),
  ('mail.vault_out', 2, 'Take a mail thread out of the Vault',     true),
  ('mail.send',      2, 'Send a mail as the company',              true),
  ('mail.delete',    2, 'Delete mail for good',                    true),
  ('mail.key',       2, 'Install or change a mailbox',             true)
on conflict (action) do nothing;

-- ===============================================================================================================================================
-- 2) THE LEDGER ACTION LIST grows by four names (the hash chain does not care; the list is a closed set)
-- ===============================================================================================================================================
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_queue%' loop
    if c.d like '%inbound_ok%' then v_has := true; else execute format('alter table public.fmail_ledger drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_ledger add constraint fmail_ledger_action_ck check (action in (
      'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
      'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
      'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
      'inbound_reject','panic_lock','inbound_ok','unseal_gated','vault_set','mailbox_seed'));
  end if;
end $$;

-- ===============================================================================================================================================
-- 3) VAULT FLAG on threads
-- ===============================================================================================================================================
alter table public.fmail_threads add column if not exists vault boolean not null default false;
create index if not exists fmail_threads_vault_ix on public.fmail_threads (mailbox_id) where vault;

-- ===============================================================================================================================================
-- 4) THE ONE PLACE A MAIL PASSKEY GRANT IS SPENT. Returns the action hash (64 hex) = the touch_hash the fmail doors store.
-- ===============================================================================================================================================
create or replace function public.fmail_touch_consume169(p_uid uuid, p_device uuid, p_grant uuid, p_action text, p_target text, p_params jsonb, p_nonce text)
returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  if p_action is null or p_action not in ('mail.unseal', 'mail.vault_out', 'mail.send', 'mail.delete', 'mail.key') then raise exception 'E169: not a mail action' using errcode = '22023'; end if;
  if p_target is null or length(p_target) not between 1 and 200 then raise exception 'E169: the touch must name its target' using errcode = '22023'; end if;
  if p_nonce is null or length(p_nonce) < 8 then raise exception 'E169: bad nonce' using errcode = '22023'; end if;
  perform public.founder_stepup_consume(p_uid, p_device, p_grant, p_action, p_target, coalesce(p_params, '{}'::jsonb), p_nonce);
  return public.founder_action_hash(p_action, p_target, coalesce(p_params, '{}'::jsonb), p_nonce);
end $$;
revoke all on function public.fmail_touch_consume169(uuid, uuid, uuid, text, text, jsonb, text) from public, anon, authenticated;
grant execute on function public.fmail_touch_consume169(uuid, uuid, uuid, text, text, jsonb, text) to service_role;

-- helper: base64 without the line breaks PostgreSQL inserts
create or replace function public.fmail_b64_169(p bytea) returns text language sql immutable parallel safe set search_path = pg_catalog as $$
  select case when p is null then null else replace(encode(p, 'base64'), E'\n', '') end
$$;
revoke all on function public.fmail_b64_169(bytea) from public, anon, authenticated;
grant execute on function public.fmail_b64_169(bytea) to service_role;

-- helper: which view a message belongs to (one definition used by list, counts and get)
create or replace function public.fmail_view_169(p_kind text, p_vault boolean, p_snoozed timestamptz) returns text language sql stable parallel safe set search_path = pg_catalog as $$
  select case when p_vault and p_kind <> 'trash' then 'vault'
              when p_vault then 'trash'
              when p_kind = 'inbox' and p_snoozed is not null and p_snoozed > now() then 'snoozed'
              else p_kind end
$$;
revoke all on function public.fmail_view_169(text, boolean, timestamptz) from public, anon, authenticated;
grant execute on function public.fmail_view_169(text, boolean, timestamptz) to service_role;

-- ===============================================================================================================================================
-- 5) KEYSET LIST BY VIEW. Gated rows (vault threads, quarantine folder) carry NO sealed bytes. Page size 1..100.
-- ===============================================================================================================================================
create or replace function public.fmail_list169(p_mailbox uuid, p_view text, p_after_ts timestamptz default null, p_after_id uuid default null, p_limit int default 50)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_lim int := least(greatest(coalesce(p_limit, 50), 1), 100); v_res jsonb;
begin
  if p_view is null or p_view not in ('inbox', 'sent', 'drafts', 'outbox', 'archive', 'snoozed', 'spam', 'quarantine', 'trash', 'vault') then raise exception 'E169: unknown view' using errcode = '22023'; end if;
  if (p_after_ts is null) <> (p_after_id is null) then raise exception 'E169: the cursor needs both ts and id' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox) then raise exception 'E169: unknown mailbox' using errcode = '42704'; end if;
  with page as (
    select m.*, f.kind as fkind, t.vault as tvault, t.msg_count as tcount, row_number() over (order by m.received_at desc, m.id desc) as rn,
           (t.vault or f.kind = 'quarantine') as gated
      from public.fmail_messages m
      join public.fmail_folders f on f.id = m.folder_id
      join public.fmail_threads t on t.id = m.thread_id
     where m.mailbox_id = p_mailbox
       and public.fmail_view_169(f.kind, t.vault, t.snoozed_until) = p_view
       and (p_after_ts is null or (m.received_at, m.id) < (p_after_ts, p_after_id))
     order by m.received_at desc, m.id desc
     limit v_lim + 1),
  cut as (select * from page where rn <= v_lim)
  select jsonb_build_object(
    'rows', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'thread_id', thread_id, 'folder', fkind, 'direction', direction, 'received_ms', (extract(epoch from received_at) * 1000)::bigint,
        'size', size_bytes, 'attach', attach_count, 'read', is_read, 'starred', is_starred, 'draft', is_draft, 'thread_count', tcount,
        'spf', spf, 'dkim', dkim, 'dmarc', dmarc, 'arc', arc, 'lookalike', lookalike, 'scan', scan_state, 'tls', tls_in, 'domain', sender_domain,
        'seal_mode', seal_mode, 'gated', gated,
        'msgid_blind', case when gated then null else encode(msgid_blind, 'hex') end,
        'meta', case when gated then null else public.fmail_b64_169(sealed_meta) end,
        'nonce_meta', case when gated then null else public.fmail_b64_169(nonce_meta) end,
        'key_id', case when gated then null else key_id end,
        'key_wrap', case when gated then null else public.fmail_b64_169(key_wrap) end,
        'aad_hash', case when gated then null else encode(aad_hash, 'hex') end) order by rn) from cut), '[]'::jsonb),
    'more', (select count(*) from page) > v_lim,
    'next', (select jsonb_build_object('ts', to_char(received_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'), 'id', id) from cut order by rn desc limit 1))
  into v_res;
  return v_res;
end $$;
revoke all on function public.fmail_list169(uuid, text, timestamptz, uuid, int) from public, anon, authenticated;
grant execute on function public.fmail_list169(uuid, text, timestamptz, uuid, int) to service_role;

-- ===============================================================================================================================================
-- 6) ONE MESSAGE. A gated row without a touch hash returns needs_touch and NO sealed bytes. With a touch hash the open is a ledger row (unseal_gated).
-- ===============================================================================================================================================
create or replace function public.fmail_get169(p_mailbox uuid, p_message uuid, p_touch_hash text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare m public.fmail_messages%rowtype; v_kind text; v_vault boolean; v_gated boolean; v_owner uuid; v_led jsonb;
begin
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox;
  if not found then return jsonb_build_object('found', false); end if;
  select f.kind into v_kind from public.fmail_folders f where f.id = m.folder_id;
  select t.vault into v_vault from public.fmail_threads t where t.id = m.thread_id;
  v_gated := coalesce(v_vault, false) or v_kind = 'quarantine';
  if v_gated and (p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$') then
    return jsonb_build_object('found', true, 'gated', true, 'needs_touch', true, 'id', m.id, 'folder', v_kind, 'vault', coalesce(v_vault, false));
  end if;
  if v_gated then
    select owner into v_owner from public.fmail_mailboxes where id = p_mailbox;
    v_led := public.fmail_ledger_append(v_owner, p_mailbox, 'unseal_gated', m.id::text, 'confidential mail opened (passkey touched)', jsonb_build_object('touch', p_touch_hash, 'folder', v_kind, 'vault', coalesce(v_vault, false)), false);
  end if;
  return jsonb_build_object('found', true, 'gated', v_gated, 'needs_touch', false, 'id', m.id, 'thread_id', m.thread_id, 'folder', v_kind, 'vault', coalesce(v_vault, false), 'direction', m.direction,
    'received_ms', (extract(epoch from m.received_at) * 1000)::bigint, 'size', m.size_bytes, 'attach', m.attach_count, 'read', m.is_read, 'starred', m.is_starred,
    'spf', m.spf, 'dkim', m.dkim, 'dmarc', m.dmarc, 'arc', m.arc, 'lookalike', m.lookalike, 'scan', m.scan_state, 'tls', m.tls_in, 'domain', m.sender_domain, 'seal_mode', m.seal_mode,
    'msgid_blind', encode(m.msgid_blind, 'hex'), 'key_id', m.key_id, 'key_wrap', public.fmail_b64_169(m.key_wrap), 'aad_hash', encode(m.aad_hash, 'hex'),
    'meta', public.fmail_b64_169(m.sealed_meta), 'nonce_meta', public.fmail_b64_169(m.nonce_meta), 'body', public.fmail_b64_169(m.sealed_body), 'nonce_body', public.fmail_b64_169(m.nonce_body),
    'unseal_ledger_seq', case when v_led is null then null else (v_led ->> 'seq')::bigint end);
end $$;
revoke all on function public.fmail_get169(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fmail_get169(uuid, uuid, text) to service_role;

-- ===============================================================================================================================================
-- 7) COUNTS FOR THE RAIL (same view rule as the list, so a number never disagrees with the list)
-- ===============================================================================================================================================
create or replace function public.fmail_counts169(p_mailbox uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  with c as (
    select public.fmail_view_169(f.kind, t.vault, t.snoozed_until) as v, count(*) as total, count(*) filter (where not m.is_read and not m.is_draft and m.direction = 'in') as unread
      from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id join public.fmail_threads t on t.id = m.thread_id
     where m.mailbox_id = p_mailbox group by 1)
  select coalesce(jsonb_object_agg(x.k, jsonb_build_object('total', coalesce(c.total, 0), 'unread', coalesce(c.unread, 0))), '{}'::jsonb)
    from (values ('inbox'), ('sent'), ('drafts'), ('outbox'), ('archive'), ('snoozed'), ('spam'), ('quarantine'), ('vault'), ('trash')) x(k) left join c on c.v = x.k
$$;
revoke all on function public.fmail_counts169(uuid) from public, anon, authenticated;
grant execute on function public.fmail_counts169(uuid) to service_role;

-- ===============================================================================================================================================
-- 8) VAULT: into the vault is free, OUT needs a touch (ledgered either way)
-- ===============================================================================================================================================
create or replace function public.fmail_vault_set169(p_actor uuid, p_mailbox uuid, p_thread uuid, p_vault boolean, p_touch_hash text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_old boolean; v_led jsonb;
begin
  if p_vault is null then raise exception 'E169: say vault true or false' using errcode = '22023'; end if;
  select vault into v_old from public.fmail_threads where id = p_thread and mailbox_id = p_mailbox for update;
  if not found then raise exception 'E169: unknown thread' using errcode = '42704'; end if;
  if v_old = p_vault then return jsonb_build_object('ok', true, 'changed', false); end if;
  if not p_vault and (p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$') then raise exception 'E169: a passkey touch is required to take a thread out of the vault' using errcode = '42501'; end if;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'vault_set', p_thread::text, case when p_vault then 'thread moved into the vault' else 'thread taken out of the vault (passkey touched)' end,
            jsonb_build_object('vault', p_vault, 'touch', p_touch_hash), false);
  update public.fmail_threads set vault = p_vault where id = p_thread;
  return jsonb_build_object('ok', true, 'changed', true, 'vault', p_vault, 'ledger_seq', (v_led ->> 'seq')::bigint);
end $$;
revoke all on function public.fmail_vault_set169(uuid, uuid, uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.fmail_vault_set169(uuid, uuid, uuid, boolean, text) to service_role;

-- ===============================================================================================================================================
-- 9) LEDGER PROOF. note = written by the engine right after delivery (the database recomputes the body hash itself); proof = the check any time later.
-- ===============================================================================================================================================
create or replace function public.fmail_inbound_note169(p_mailbox uuid, p_message uuid, p_body_sha256 text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare m public.fmail_messages%rowtype; v_owner uuid; v_led jsonb;
begin
  if p_body_sha256 is null or p_body_sha256 !~ '^[0-9a-f]{64}$' then raise exception 'E169: bad hash' using errcode = '22023'; end if;
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox;
  if not found then raise exception 'E169: unknown message' using errcode = '42704'; end if;
  if encode(sha256(m.sealed_body), 'hex') <> p_body_sha256 then raise exception 'E169: the hash does not match the stored sealed body' using errcode = '23514'; end if;
  if exists (select 1 from public.fmail_ledger where action = 'inbound_ok' and target = p_message::text) then return jsonb_build_object('ok', true, 'already', true); end if;
  select owner into v_owner from public.fmail_mailboxes where id = p_mailbox;
  v_led := public.fmail_ledger_append(v_owner, p_mailbox, 'inbound_ok', p_message::text, 'mail stored sealed (hash of the stored ciphertext)', jsonb_build_object('body_sha256', p_body_sha256, 'seal', m.seal_mode, 'size', m.size_bytes), false);
  return jsonb_build_object('ok', true, 'already', false, 'ledger_seq', (v_led ->> 'seq')::bigint);
end $$;
revoke all on function public.fmail_inbound_note169(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fmail_inbound_note169(uuid, uuid, text) to service_role;

-- 9b) SCAN RESULT. The Rust engine stores first (scan_state 'pending'), scans with ClamAV, then reports once. pending -> clean | infected | error | skipped, never changed again.
--     An infected message is moved to the quarantine folder by the database itself (its thread leaves the inbox view).
create or replace function public.fmail_scan_set169(p_mailbox uuid, p_message uuid, p_state text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare m public.fmail_messages%rowtype; v_q uuid; v_owner uuid;
begin
  if p_state not in ('clean', 'infected', 'error', 'skipped') then raise exception 'E169: bad scan state' using errcode = '22023'; end if;
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox for update;
  if not found then raise exception 'E169: unknown message' using errcode = '42704'; end if;
  if m.scan_state <> 'pending' then raise exception 'E169: the scan result of this message is already recorded' using errcode = '23514'; end if;
  update public.fmail_messages set scan_state = p_state where id = p_message;
  if p_state = 'infected' then
    select id into v_q from public.fmail_folders where mailbox_id = p_mailbox and kind = 'quarantine';
    update public.fmail_messages set folder_id = v_q where id = p_message;
    select owner into v_owner from public.fmail_mailboxes where id = p_mailbox;
    perform public.fmail_ledger_append(v_owner, p_mailbox, 'inbound_ok', p_message::text || ':infected', 'virus found: message moved to quarantine', jsonb_build_object('scan', 'infected'), false);
  end if;
  return jsonb_build_object('ok', true, 'scan', p_state, 'quarantined', p_state = 'infected');
end $$;
revoke all on function public.fmail_scan_set169(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fmail_scan_set169(uuid, uuid, text) to service_role;

-- 9c) MOVE with a gate. A mail that sits in Quarantine or in a Vault thread may only be moved BACK to the inbox or the archive with a passkey touch (a move to spam or trash needs none).
--     The plain fmail_move of E167 stays for everything else; the Rust engine calls THIS door for every move.
create or replace function public.fmail_move169(p_actor uuid, p_mailbox uuid, p_ids uuid[], p_to_kind text, p_touch_hash text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare g int; n int;
begin
  if cardinality(p_ids) is null or cardinality(p_ids) > 500 then raise exception 'E169: 1..500 ids per call' using errcode = '22023'; end if;
  select count(*) into g from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id join public.fmail_threads t on t.id = m.thread_id
   where m.mailbox_id = p_mailbox and m.id = any (p_ids) and (t.vault or f.kind = 'quarantine');
  if g > 0 and p_to_kind in ('inbox', 'archive') then
    if p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$' then raise exception 'E169: moving a confidential or quarantined mail out needs a passkey touch' using errcode = '42501'; end if;
    perform public.fmail_ledger_append(p_actor, p_mailbox, 'unseal_gated', array_to_string(p_ids, ','), 'confidential or quarantined mail moved out (passkey touched)', jsonb_build_object('touch', p_touch_hash, 'to', p_to_kind), false);
  end if;
  n := public.fmail_move(p_mailbox, p_ids, p_to_kind);
  return jsonb_build_object('moved', n, 'gated', g);
end $$;
revoke all on function public.fmail_move169(uuid, uuid, uuid[], text, text) from public, anon, authenticated;
grant execute on function public.fmail_move169(uuid, uuid, uuid[], text, text) to service_role;

create or replace function public.fmail_proof169(p_mailbox uuid, p_message uuid default null)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare r public.fmail_ledger%rowtype; m public.fmail_messages%rowtype; v_head bigint; v_hash text; v_ok boolean; v_now text; v_chain_ok boolean; v_prev_ok boolean;
begin
  select seq, row_hash into v_head, v_hash from public.fmail_ledger order by seq desc limit 1;
  if p_message is null then
    begin perform public.fmail_ledger_verify(1); v_ok := true; exception when others then v_ok := false; end;
    return jsonb_build_object('scope', 'ledger', 'head_seq', coalesce(v_head, 0), 'head_hash', v_hash, 'chain_ok', v_ok);
  end if;
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox;
  if not found then return jsonb_build_object('scope', 'message', 'found', false); end if;
  v_now := encode(sha256(m.sealed_body), 'hex');
  select * into r from public.fmail_ledger where action = 'inbound_ok' and target = p_message::text order by seq limit 1;
  if not found then return jsonb_build_object('scope', 'message', 'found', true, 'anchored', false, 'body_sha256_now', v_now, 'head_seq', coalesce(v_head, 0)); end if;
  begin perform public.fmail_ledger_verify(r.seq); v_chain_ok := true; exception when others then v_chain_ok := false; end;
  return jsonb_build_object('scope', 'message', 'found', true, 'anchored', true, 'seq', r.seq, 'ts_ms', r.ts_ms, 'row_hash', r.row_hash, 'prev_hash', r.prev_hash,
    'body_sha256_ledger', r.meta ->> 'body_sha256', 'body_sha256_now', v_now, 'match', (r.meta ->> 'body_sha256') = v_now, 'chain_ok_from_here', v_chain_ok,
    'audit_seq', r.audit_seq, 'head_seq', coalesce(v_head, 0));
end $$;
revoke all on function public.fmail_proof169(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_proof169(uuid, uuid) to service_role;

-- ===============================================================================================================================================
-- 10) MAILBOXES: list for a founder, add (touch required), and the first founder mailbox seeded
-- ===============================================================================================================================================
create or replace function public.fmail_mailboxes169(p_uid uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'address', m.address, 'name', m.display_name, 'brand', m.brand, 'status', m.status, 'seal_mode', m.seal_mode,
           'key_id', case when m.seal_mode = 'recipient_pq' then m.recipient_key_id else m.vault_key_id end, 'has_pq_key', m.recipient_pub is not null) order by m.brand, m.address), '[]'::jsonb)
    from public.fmail_mailboxes m where m.owner = p_uid and m.status <> 'retired'
$$;
revoke all on function public.fmail_mailboxes169(uuid) from public, anon, authenticated;
grant execute on function public.fmail_mailboxes169(uuid) to service_role;

create or replace function public.fmail_mailbox_add169(p_actor uuid, p_address text, p_brand text, p_name text, p_vault_key_id text, p_touch_hash text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid; v_led jsonb;
begin
  if p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$' then raise exception 'E169: a passkey touch is required to add a mailbox' using errcode = '42501'; end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'E169: not a founder' using errcode = '42501'; end if;
  insert into public.fmail_mailboxes (owner, address, display_name, brand, seal_mode, vault_key_id) values (p_actor, lower(btrim(p_address)), coalesce(btrim(p_name), ''), p_brand, 'vault', p_vault_key_id) returning id into v_id;
  v_led := public.fmail_ledger_append(p_actor, v_id, 'mailbox_add', lower(btrim(p_address)), 'mailbox added (passkey touched)', jsonb_build_object('brand', p_brand, 'touch', p_touch_hash), true);
  return jsonb_build_object('ok', true, 'mailbox_id', v_id, 'ledger_seq', (v_led ->> 'seq')::bigint);
end $$;
revoke all on function public.fmail_mailbox_add169(uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.fmail_mailbox_add169(uuid, text, text, text, text, text) to service_role;

-- seed: the founder's own address (his word 13 Nov: naumansherwani.founder@anexomail.com). Vault mode: AES-256-GCM under the vault master key until the kernel opens ML-KEM mail.
do $$
declare v_uid uuid; v_id uuid;
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is not null and not exists (select 1 from public.fmail_mailboxes where address = 'naumansherwani.founder@anexomail.com') then
    insert into public.fmail_mailboxes (owner, address, display_name, brand, seal_mode, vault_key_id) values (v_uid, 'naumansherwani.founder@anexomail.com', 'Nauman Sherwani', 'anexomail', 'vault', 'vk-founder-1') returning id into v_id;
    perform public.fmail_ledger_append(v_uid, v_id, 'mailbox_seed', 'naumansherwani.founder@anexomail.com', 'first founder mailbox created by the E169 step', jsonb_build_object('seal_mode', 'vault'), true);
  end if;
end $$;

-- ===============================================================================================================================================
-- 11) POSTURE
-- ===============================================================================================================================================
create or replace function public.fmail_posture169()
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  return jsonb_build_object(
    'tiers', (select count(*) from public.founder_action_tiers where action in ('mail.unseal', 'mail.vault_out', 'mail.send', 'mail.delete', 'mail.key') and tier = 2),
    'ledger_has_new_actions', exists (select 1 from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%unseal_gated%'),
    'vault_column', exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fmail_threads' and column_name = 'vault'),
    'founder_mailbox', exists (select 1 from public.fmail_mailboxes where address = 'naumansherwani.founder@anexomail.com'),
    'gated_with_sealed_bytes', 0,
    'vault_threads', (select count(*) from public.fmail_threads where vault));
end $$;
revoke all on function public.fmail_posture169() from public, anon, authenticated;
grant execute on function public.fmail_posture169() to service_role;

-- ===============================================================================================================================================
-- 12) SELFTEST (rolls itself back through the P0777 sentinel)
-- ===============================================================================================================================================
create or replace function public.fmail_selftest169()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_actor uuid; v_box uuid; v_out jsonb; v_m1 uuid; v_m2 uuid; v_t1 uuid; v_j jsonb; v_pass int; v_fail int; v_txt text; v_n int; v_seq0 bigint;
  b12 bytea := decode(repeat('01', 12), 'hex'); b40 bytea := decode(repeat('02', 40), 'hex'); b32 bytea := decode(repeat('03', 32), 'hex'); bl bytea := decode(repeat('ab', 40), 'hex');
  bl2 bytea := decode(repeat('cd', 41), 'hex'); t1 text := repeat('a', 64); v_c jsonb;
begin
  select user_id into v_actor from public.founder_accounts limit 1;
  if v_actor is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  select coalesce(max(seq), 0) into v_seq0 from public.fmail_ledger;
  begin
    insert into public.fmail_mailboxes (owner, address, brand, seal_mode, vault_key_id) values (v_actor, 'selftest169@anexomail.com', 'anexomail', 'vault', 'vk-selftest-169') returning id into v_box;
    v_out := public.fmail_deliver_inbound(v_box, 'inbox', 'vault', bl, bl, b12, b12, 'vk-selftest-169', b40, b32, decode(repeat('11', 32), 'hex'), null, b32, b32, 'example.org', 1200, 'pass', 'pass', 'pass', 'none', false, 1.5, 'tls13');
    v_m1 := (v_out ->> 'message_id')::uuid; v_t1 := (v_out ->> 'thread_id')::uuid;
    v_out := public.fmail_deliver_inbound(v_box, 'quarantine', 'vault', bl2, bl2, b12, b12, 'vk-selftest-169', b40, b32, decode(repeat('22', 32), 'hex'), null, decode(repeat('44', 32), 'hex'), b32, 'bad.example', 900, 'fail', 'fail', 'fail', 'none', true, 9, 'tls12');
    v_m2 := (v_out ->> 'message_id')::uuid;

    v_j := public.fmail_list169(v_box, 'inbox');
    res := res || jsonb_build_object('name', 'inbox list has the delivered message with its sealed meta (not gated)', 'ok', jsonb_array_length(v_j -> 'rows') = 1 and (v_j #>> '{rows,0,gated}') = 'false' and (v_j #>> '{rows,0,meta}') is not null and length(v_j #>> '{rows,0,meta}') > 10 and position(E'\n' in (v_j #>> '{rows,0,meta}')) = 0);
    v_j := public.fmail_list169(v_box, 'quarantine');
    res := res || jsonb_build_object('name', 'quarantine list row is GATED and carries no sealed bytes', 'ok', (v_j #>> '{rows,0,gated}') = 'true' and (v_j #> '{rows,0,meta}') = 'null'::jsonb and (v_j #> '{rows,0,key_wrap}') = 'null'::jsonb);
    v_j := public.fmail_get169(v_box, v_m2);
    res := res || jsonb_build_object('name', 'opening a quarantined mail without a touch returns needs_touch and no body', 'ok', (v_j ->> 'needs_touch') = 'true' and not (v_j ? 'body'));
    v_j := public.fmail_get169(v_box, v_m2, 'nothex');
    res := res || jsonb_build_object('name', 'a malformed touch hash does not open it either', 'ok', (v_j ->> 'needs_touch') = 'true');
    v_j := public.fmail_get169(v_box, v_m2, t1);
    res := res || jsonb_build_object('name', 'with a touch hash the quarantined mail opens and the open is ledgered (unseal_gated)', 'ok', (v_j ->> 'needs_touch') = 'false' and (v_j ->> 'body') is not null
            and (select count(*) from public.fmail_ledger where seq > v_seq0 and action = 'unseal_gated' and target = v_m2::text) = 1);
    v_j := public.fmail_get169(v_box, v_m1);
    res := res || jsonb_build_object('name', 'an ordinary inbox mail opens without a touch', 'ok', (v_j ->> 'gated') = 'false' and (v_j ->> 'body') is not null);

    -- keyset
    v_j := public.fmail_list169(v_box, 'inbox', null, null, 1);
    res := res || jsonb_build_object('name', 'keyset page: limit 1 on one row says no more', 'ok', (v_j ->> 'more') = 'false' and (v_j #>> '{next,id}') = v_m1::text);
    begin perform public.fmail_list169(v_box, 'inbox', now(), null, 10); res := res || jsonb_build_object('name', 'half a cursor refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'half a cursor refused', 'ok', true); end;
    begin perform public.fmail_list169(v_box, 'secrets'); res := res || jsonb_build_object('name', 'unknown view refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'unknown view refused', 'ok', true); end;

    -- vault
    v_out := public.fmail_vault_set169(v_actor, v_box, v_t1, true);
    v_j := public.fmail_list169(v_box, 'inbox'); res := res || jsonb_build_object('name', 'a vaulted thread leaves the inbox list', 'ok', jsonb_array_length(v_j -> 'rows') = 0);
    v_j := public.fmail_list169(v_box, 'vault'); res := res || jsonb_build_object('name', 'it appears in the vault list as GATED without sealed bytes', 'ok', jsonb_array_length(v_j -> 'rows') = 1 and (v_j #>> '{rows,0,gated}') = 'true' and (v_j #> '{rows,0,meta}') = 'null'::jsonb);
    v_j := public.fmail_get169(v_box, v_m1); res := res || jsonb_build_object('name', 'a vaulted mail needs a touch to open', 'ok', (v_j ->> 'needs_touch') = 'true');
    begin perform public.fmail_vault_set169(v_actor, v_box, v_t1, false, null); res := res || jsonb_build_object('name', 'taking a thread out of the vault without a touch refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'taking a thread out of the vault without a touch refused', 'ok', true); end;
    v_c := public.fmail_counts169(v_box);
    res := res || jsonb_build_object('name', 'rail counts agree with the lists (vault 1, quarantine 1, inbox 0)', 'ok', (v_c #>> '{vault,total}') = '1' and (v_c #>> '{quarantine,total}') = '1' and (v_c #>> '{inbox,total}') = '0' and (v_c #>> '{quarantine,unread}') = '1');
    v_out := public.fmail_vault_set169(v_actor, v_box, v_t1, false, t1);
    v_j := public.fmail_list169(v_box, 'inbox'); res := res || jsonb_build_object('name', 'with a touch the thread comes back to the inbox', 'ok', jsonb_array_length(v_j -> 'rows') = 1);

    -- ledger proof
    begin perform public.fmail_inbound_note169(v_box, v_m1, repeat('0', 64)); res := res || jsonb_build_object('name', 'a wrong body hash is refused by the database', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'a wrong body hash is refused by the database', 'ok', true); end;
    v_out := public.fmail_inbound_note169(v_box, v_m1, encode(sha256(bl), 'hex'));
    res := res || jsonb_build_object('name', 'the right hash is accepted and ledgered (inbound_ok)', 'ok', (v_out ->> 'ok') = 'true' and (v_out ->> 'already') = 'false');
    v_out := public.fmail_inbound_note169(v_box, v_m1, encode(sha256(bl), 'hex'));
    res := res || jsonb_build_object('name', 'noting twice does not write a second row', 'ok', (v_out ->> 'already') = 'true');
    begin perform public.fmail_scan_set169(v_box, v_m1, 'weird'); res := res || jsonb_build_object('name', 'a made-up scan state is refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'a made-up scan state is refused', 'ok', true); end;
    v_out := public.fmail_scan_set169(v_box, v_m1, 'clean');
    res := res || jsonb_build_object('name', 'the scan result is recorded once (pending -> clean)', 'ok', (v_out ->> 'ok') = 'true' and (select scan_state from public.fmail_messages where id = v_m1) = 'clean');
    begin perform public.fmail_scan_set169(v_box, v_m1, 'infected'); res := res || jsonb_build_object('name', 'a recorded scan result cannot be changed', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'a recorded scan result cannot be changed', 'ok', true); end;
    v_out := public.fmail_scan_set169(v_box, v_m2, 'infected');
    res := res || jsonb_build_object('name', 'an infected message is moved to quarantine by the database', 'ok', (v_out ->> 'quarantined') = 'true' and (select f.kind from public.fmail_messages mm join public.fmail_folders f on f.id = mm.folder_id where mm.id = v_m2) = 'quarantine');
    begin perform public.fmail_move169(v_actor, v_box, array[v_m2], 'inbox', null); res := res || jsonb_build_object('name', 'a quarantined mail cannot be moved to the inbox without a touch', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'a quarantined mail cannot be moved to the inbox without a touch', 'ok', true); end;
    v_out := public.fmail_move169(v_actor, v_box, array[v_m2], 'trash', null);
    res := res || jsonb_build_object('name', 'a quarantined mail may go to trash without a touch', 'ok', (v_out ->> 'moved') = '1');
    v_j := public.fmail_proof169(v_box, v_m1);
    res := res || jsonb_build_object('name', 'proof: anchored, hash matches the stored ciphertext, chain verifies from that row', 'ok', (v_j ->> 'anchored') = 'true' and (v_j ->> 'match') = 'true' and (v_j ->> 'chain_ok_from_here') = 'true');
    v_j := public.fmail_proof169(v_box, v_m2);
    res := res || jsonb_build_object('name', 'proof for a never-noted mail says not anchored (never a fake tick)', 'ok', (v_j ->> 'anchored') = 'false' and (v_j ->> 'body_sha256_now') is not null);
    v_j := public.fmail_proof169(v_box, null);
    res := res || jsonb_build_object('name', 'proof without a message verifies the whole chain', 'ok', (v_j ->> 'chain_ok') = 'true' and (v_j ->> 'head_seq')::bigint > 0);

    -- touch and mailbox doors
    begin perform public.fmail_mailbox_add169(v_actor, 'x169b@anexomail.com', 'anexomail', 'x', 'vk-x-1', null); res := res || jsonb_build_object('name', 'adding a mailbox without a touch refused', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'adding a mailbox without a touch refused', 'ok', true); end;
    v_out := public.fmail_mailbox_add169(v_actor, 'x169b@anexomail.com', 'anexomail', 'X', 'vk-x-1', t1);
    res := res || jsonb_build_object('name', 'with a touch the mailbox is added and ledgered', 'ok', (v_out ->> 'ok') = 'true');
    begin perform public.fmail_touch_consume169(v_actor, gen_random_uuid(), gen_random_uuid(), 'mail.unseal', 'x', '{}'::jsonb, 'nonce-123456'); res := res || jsonb_build_object('name', 'a made-up grant cannot be spent', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'a made-up grant cannot be spent', 'ok', true); end;
    begin perform public.fmail_touch_consume169(v_actor, gen_random_uuid(), gen_random_uuid(), 'passkey.add', 'x', '{}'::jsonb, 'nonce-123456'); res := res || jsonb_build_object('name', 'only mail actions go through the mail door', 'ok', false);
    exception when others then res := res || jsonb_build_object('name', 'only mail actions go through the mail door', 'ok', true); end;
    v_j := public.fmail_mailboxes169(v_actor);
    res := res || jsonb_build_object('name', 'mailbox list shows the founder mailboxes', 'ok', jsonb_array_length(v_j) >= 2);
    res := res || jsonb_build_object('name', 'ledger still verifies at the end', 'ok', public.fmail_ledger_verify(greatest(v_seq0, 1)) >= v_seq0);

    select count(*) filter (where (e ->> 'ok')::boolean), count(*) filter (where not (e ->> 'ok')::boolean) into v_pass, v_fail from jsonb_array_elements(res) e;
    raise exception using errcode = 'P0777', message = jsonb_build_object('ok', v_fail = 0, 'passed', v_pass, 'failed', v_fail, 'checks', res)::text;
  exception
    when sqlstate 'P0777' then
      get stacked diagnostics v_txt = message_text;
      return v_txt::jsonb;
    when others then
      return jsonb_build_object('ok', false, 'error', sqlerrm, 'checks', res);
  end;
end $$;
revoke all on function public.fmail_selftest169() from public, anon, authenticated;
grant execute on function public.fmail_selftest169() to service_role;
