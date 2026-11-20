
-- E194 (QC2, 20 Nov 2026): THE FOUNDER SIGNATURES + SNIPPETS. Sealed text the compose box inserts: one signature per From address (plus one fallback), and named snippets ("/thanks") with variables.
-- Stands on E167 (mailboxes, hash-chained ledger, sealing columns pattern), E179 (door audit), E186 (door + guard pattern). NOTHING of the awam templates or signatures is read or touched (separation law).
-- ---------------------------------------------------------------------------------------------------------------------------------------------------
-- WEB RESEARCH FIRST (standing rule 0, read 20 Nov 2026), written into docs/claude/QC2-PLAN-20NOV.md before this file:
--   * Superhuman Snippets (help.superhuman.com/article/466-snippets): snippets are named, inserted by a trigger, carry built-in variables and free {placeholders}, and Mail WARNS when a mail is sent with a
--     placeholder still unfilled. Private snippets exist next to shared team ones; the founder is one person, so ONLY private snippets exist here (no sharing column, no team table).
--   * Exclaimer / signature handbooks: a hosted or embedded logo has real deliverability costs (embedded adds ~33 %, shows as an attachment in some clients, hosted is blocked by default), so a signature
--     here is TEXT ONLY (a sealed JSON of lines and links); a logo waits for Q3 and comes from his own server.
--   * ProseMirror XSS (GHSA-c8x8-7fp4-3x9w, prosemirror-view < 1.42.3): pasted HTML is untrusted, so the database stores NO HTML at all. A signature and a snippet are plain lines of text; the Rust engine
--     (ammonia allow-list) and the browser schema build the HTML at send time.
--   => DESIGN: name, address, signature text and snippet text are SEALED (AES-256-GCM, produced by the Rust engine, the database never sees them). Two exact blind indexes (HMAC-SHA-256, vault key, E167
--      pattern): the From address of a signature and the lower-case name of a snippet, so the database can answer "is this one already here?" and nothing else. Numbers (counts, clocks, version) are plain.
--
-- TECHNOLOGY (PostgreSQL 16, advance level):
--   * forced row level security on both tables, no policy for anon / authenticated, service_role can only SELECT: every WRITE goes through a door (security definer, fixed search_path, VOLATILE,
--     service_role only). A trigger refuses any insert, update or delete that does not come from a door (a session flag set with set_config(..., is_local = true), so it can not leak across transactions).
--   * the guard trigger freezes identity (mailbox, blind index, created_at), lets the version grow by exactly one per change and the use counter only grow, and lets the sealed value change only as ONE unit
--     (a new ciphertext needs a new nonce: AES-GCM never reuses a nonce).
--   * a partial unique index lets exactly ONE signature per mailbox be the fallback (used when the From address has none).
--   * ONE hash-chained ledger: set / clear / put / delete are lines in the E167 fmail_ledger chain (same advisory lock, same SHA-256 chain). A line carries the BLIND, never the text. Using a snippet is NOT a
--     ledger line (it would flood the chain): it is a monotone counter guarded by the trigger.
--   * hard caps per mailbox (20 signatures, 200 snippets) and a size cap on every sealed value, so neither table can grow without bound; refusing at the cap, never evicting someone's text silently.
--   * idempotent doors: putting the same sealed unit again, deleting what is gone, clearing what is not there change nothing and write no second ledger line.
--   * selftest that rolls itself back, posture function, CHECK_E194.sql. Door names are built from two pieces in the posture function so the E179 audit (stable functions must not name a writing door)
--     stays clean.
-- Run once through sql-run.sh, after E193. Safe to run again (idempotent).

do $$
begin
  if to_regprocedure('public.fmail_ledger_append(uuid,uuid,text,text,text,jsonb,boolean)') is null then raise exception 'E194: E167 ledger is missing'; end if;
  if to_regprocedure('public.fmail_door_audit179()') is null then raise exception 'E194: E179 door audit is missing (run E179 first)'; end if;
  if to_regclass('public.fmail_contacts') is null then raise exception 'E194: E186 is missing (run E186 first)'; end if;
end $$;

-- 1) the ledger learns four action names (closed set, the same drop-and-re-add pattern as E185 / E186)
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_start%' loop
    if c.d like '%snippet_delete%' then v_has := true; else execute format('alter table public.fmail_ledger drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_ledger add constraint fmail_ledger_action_ck check (action in (
      'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
      'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
      'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
      'inbound_reject','panic_lock','inbound_ok','unseal_gated','vault_set','mailbox_seed','dkim_install','dkim_revoke','ledger_checkpoint',
      'dkim_policy','dkim_dns_check','dkim_proof','send_release',
      'contact_add','contact_forget','contact_pin','contact_evict',
      'signature_set','signature_clear','snippet_put','snippet_delete'));
  end if;
end $$;

-- 2) the signatures. Sealed text, one exact blind index of the From address, numbers. NO plain personal data in any column.
create table if not exists public.fmail_signatures (
  id            uuid primary key default gen_random_uuid(),
  mailbox_id    uuid not null references public.fmail_mailboxes (id) on delete cascade,
  from_blind    bytea not null check (octet_length(from_blind) = 32),     -- HMAC-SHA-256(vault blind key, lower-case From address), computed by Rust
  sealed        bytea not null check (octet_length(sealed) between 17 and 8192),   -- AES-256-GCM(JSON {a: from address, t: signature text}) + 16 byte tag
  nonce         bytea not null check (octet_length(nonce) = 12),
  key_id        text  not null check (length(key_id) between 1 and 80 and key_id !~ '[[:cntrl:]]'),
  key_wrap      bytea not null check (octet_length(key_wrap) between 16 and 256),
  aad_hash      bytea not null check (octet_length(aad_hash) = 32),
  is_fallback   boolean not null default false,                           -- used when the From address of a mail has no signature of its own (at most one per mailbox)
  version       integer not null default 1 check (version between 1 and 1000000),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint fmail_signatures_uq unique (mailbox_id, from_blind)
);
create unique index if not exists fmail_signatures_one_fallback_ix on public.fmail_signatures (mailbox_id) where is_fallback;

-- 3) the snippets. Sealed name + text, one exact blind index of the lower-case name, numbers. Private only: there is no sharing column.
create table if not exists public.fmail_snippets (
  id            uuid primary key default gen_random_uuid(),
  mailbox_id    uuid not null references public.fmail_mailboxes (id) on delete cascade,
  name_blind    bytea not null check (octet_length(name_blind) = 32),     -- HMAC-SHA-256(vault blind key, lower-case snippet name)
  sealed        bytea not null check (octet_length(sealed) between 17 and 16384),  -- AES-256-GCM(JSON {n: name, t: text}) + 16 byte tag
  nonce         bytea not null check (octet_length(nonce) = 12),
  key_id        text  not null check (length(key_id) between 1 and 80 and key_id !~ '[[:cntrl:]]'),
  key_wrap      bytea not null check (octet_length(key_wrap) between 16 and 256),
  aad_hash      bytea not null check (octet_length(aad_hash) = 32),
  use_count     integer not null default 0 check (use_count between 0 and 10000000),
  last_used_at  timestamptz,
  version       integer not null default 1 check (version between 1 and 1000000),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint fmail_snippets_uq unique (mailbox_id, name_blind),
  constraint fmail_snippets_used_ck check ((use_count = 0) = (last_used_at is null))
);
create index if not exists fmail_snippets_box_ix on public.fmail_snippets (mailbox_id, use_count desc, updated_at desc);

alter table public.fmail_signatures enable row level security;   alter table public.fmail_signatures force row level security;
alter table public.fmail_snippets enable row level security;     alter table public.fmail_snippets force row level security;
revoke all on public.fmail_signatures from public, anon, authenticated;
revoke all on public.fmail_snippets from public, anon, authenticated;
revoke insert, update, delete, truncate on public.fmail_signatures from service_role;
revoke insert, update, delete, truncate on public.fmail_snippets from service_role;
grant select on public.fmail_signatures, public.fmail_snippets to service_role;   -- reading only: every write is a door

-- 4) THE GUARD. Only a door may write (session flag set inside the door, transaction local); identity is frozen; the version moves by one; the sealed value moves as one unit.
create or replace function public.fmail_rich_door_on194() returns boolean language sql stable set search_path = pg_catalog as $$
  select coalesce(current_setting('fmail.rich_door', true), '') = 'on'
$$;

create or replace function public.fmail_signatures_guard194() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if not public.fmail_rich_door_on194() then
    raise exception 'E194: signatures are written only through their doors (% refused)', tg_op using errcode = '42501'; end if;
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id or new.mailbox_id is distinct from old.mailbox_id or new.from_blind is distinct from old.from_blind or new.created_at is distinct from old.created_at then
      raise exception 'E194: the identity of a signature is frozen' using errcode = '23514'; end if;
    if new.sealed is distinct from old.sealed then
      if new.nonce is not distinct from old.nonce then raise exception 'E194: a new sealed value needs a new nonce (AES-GCM never reuses a nonce)' using errcode = '23514'; end if;
      if new.version <> old.version + 1 then raise exception 'E194: a changed signature moves the version up by exactly one' using errcode = '23514'; end if;
    elsif new.version is distinct from old.version then raise exception 'E194: the version moves only with the sealed value' using errcode = '23514'; end if;
    new.updated_at := now();
  end if;
  if tg_op = 'DELETE' then return old; end if;   -- a BEFORE DELETE trigger that returns NULL would silently cancel the delete
  return new;
end $$;
drop trigger if exists fmail_signatures_guard on public.fmail_signatures;
create trigger fmail_signatures_guard before insert or update or delete on public.fmail_signatures for each row execute function public.fmail_signatures_guard194();
drop trigger if exists fmail_signatures_guard_t on public.fmail_signatures;
create trigger fmail_signatures_guard_t before truncate on public.fmail_signatures for each statement execute function public.fmail_append_only_167();

create or replace function public.fmail_snippets_guard194() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if not public.fmail_rich_door_on194() then
    raise exception 'E194: snippets are written only through their doors (% refused)', tg_op using errcode = '42501'; end if;
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id or new.mailbox_id is distinct from old.mailbox_id or new.name_blind is distinct from old.name_blind or new.created_at is distinct from old.created_at then
      raise exception 'E194: the identity of a snippet is frozen' using errcode = '23514'; end if;
    if new.use_count < old.use_count then raise exception 'E194: the use counter only grows' using errcode = '23514'; end if;
    if old.last_used_at is not null and new.last_used_at < old.last_used_at then raise exception 'E194: the use clock only moves forward' using errcode = '23514'; end if;
    if new.sealed is distinct from old.sealed then
      if new.nonce is not distinct from old.nonce then raise exception 'E194: a new sealed value needs a new nonce (AES-GCM never reuses a nonce)' using errcode = '23514'; end if;
      if new.version <> old.version + 1 then raise exception 'E194: a changed snippet moves the version up by exactly one' using errcode = '23514'; end if;
    elsif new.version is distinct from old.version then raise exception 'E194: the version moves only with the sealed value' using errcode = '23514'; end if;
    new.updated_at := now();
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
drop trigger if exists fmail_snippets_guard on public.fmail_snippets;
create trigger fmail_snippets_guard before insert or update or delete on public.fmail_snippets for each row execute function public.fmail_snippets_guard194();
drop trigger if exists fmail_snippets_guard_t on public.fmail_snippets;
create trigger fmail_snippets_guard_t before truncate on public.fmail_snippets for each statement execute function public.fmail_append_only_167();

-- 5) the caps. A session setting may only LOWER them (the selftest uses 2 and 3); they can never be raised above 20 / 200.
create or replace function public.fmail_signature_cap194() returns integer language sql stable set search_path = pg_catalog as $$
  select greatest(2, least(20, coalesce(nullif(current_setting('fmail.signature_cap', true), '')::integer, 20)))
$$;
create or replace function public.fmail_snippet_cap194() returns integer language sql stable set search_path = pg_catalog as $$
  select greatest(2, least(200, coalesce(nullif(current_setting('fmail.snippet_cap', true), '')::integer, 200)))
$$;

-- 6) DOOR: put a signature (create or replace the one of a From address). Idempotent: the same sealed unit again writes nothing and no second ledger line.
create or replace function public.fmail_signature_put194(p_actor uuid, p_mailbox uuid, p_from_blind bytea, p_sealed bytea, p_nonce bytea, p_key_id text, p_key_wrap bytea, p_aad_hash bytea, p_fallback boolean default false)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare s public.fmail_signatures; v_new boolean := false; v_n integer; v_led jsonb; v_fb boolean := coalesce(p_fallback, false);
begin
  if p_actor is null or p_mailbox is null or p_from_blind is null or p_sealed is null or p_nonce is null or p_key_id is null or p_key_wrap is null or p_aad_hash is null then
    raise exception 'E194: actor, mailbox, the From blind and the whole sealed unit are needed' using errcode = '22023'; end if;
  if octet_length(p_from_blind) <> 32 then raise exception 'E194: a blind index is 32 bytes' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E194: not your mailbox' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || 'signature', 194));
  select * into s from public.fmail_signatures where mailbox_id = p_mailbox and from_blind = p_from_blind for update;
  perform set_config('fmail.rich_door', 'on', true);
  if s.id is null then
    select count(*) into v_n from public.fmail_signatures where mailbox_id = p_mailbox;
    if v_n >= public.fmail_signature_cap194() then perform set_config('fmail.rich_door', 'off', true); raise exception 'E194: the signature list is full (% signatures)', v_n using errcode = '54000'; end if;
    if v_fb then update public.fmail_signatures set is_fallback = false where mailbox_id = p_mailbox and is_fallback; end if;
    insert into public.fmail_signatures (mailbox_id, from_blind, sealed, nonce, key_id, key_wrap, aad_hash, is_fallback)
      values (p_mailbox, p_from_blind, p_sealed, p_nonce, p_key_id, p_key_wrap, p_aad_hash, v_fb) returning * into s;
    v_new := true;
  else
    if s.sealed = p_sealed and s.is_fallback = v_fb then
      perform set_config('fmail.rich_door', 'off', true);
      return jsonb_build_object('ok', true, 'id', s.id, 'created', false, 'already', true, 'version', s.version);
    end if;
    if v_fb then update public.fmail_signatures set is_fallback = false where mailbox_id = p_mailbox and is_fallback and id <> s.id; end if;
    if s.sealed = p_sealed then
      update public.fmail_signatures set is_fallback = v_fb where id = s.id returning * into s;
    else
      update public.fmail_signatures set sealed = p_sealed, nonce = p_nonce, key_id = p_key_id, key_wrap = p_key_wrap, aad_hash = p_aad_hash, is_fallback = v_fb, version = version + 1
        where id = s.id returning * into s;
    end if;
  end if;
  perform set_config('fmail.rich_door', 'off', true);
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'signature_set', encode(p_from_blind, 'hex'), case when v_new then 'signature created' else 'signature changed' end,
                                      jsonb_build_object('signature', s.id, 'version', s.version, 'fallback', s.is_fallback), false);
  return jsonb_build_object('ok', true, 'id', s.id, 'created', v_new, 'already', false, 'version', s.version, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_signature_put194(uuid, uuid, bytea, bytea, bytea, text, bytea, bytea, boolean) from public, anon, authenticated;
grant execute on function public.fmail_signature_put194(uuid, uuid, bytea, bytea, bytea, text, bytea, bytea, boolean) to service_role;

-- 7) DOOR: clear a signature. Idempotent.
create or replace function public.fmail_signature_clear194(p_actor uuid, p_mailbox uuid, p_signature uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare s public.fmail_signatures; v_led jsonb;
begin
  if p_actor is null or p_mailbox is null or p_signature is null then raise exception 'E194: actor, mailbox and signature are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E194: not your mailbox' using errcode = '42501'; end if;
  select * into s from public.fmail_signatures where id = p_signature and mailbox_id = p_mailbox for update;
  if s.id is null then return jsonb_build_object('ok', true, 'already', true); end if;
  perform set_config('fmail.rich_door', 'on', true);
  delete from public.fmail_signatures where id = s.id;
  perform set_config('fmail.rich_door', 'off', true);
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'signature_clear', encode(s.from_blind, 'hex'), 'signature removed by the founder',
                                      jsonb_build_object('signature', s.id, 'version', s.version), false);
  return jsonb_build_object('ok', true, 'already', false, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_signature_clear194(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_signature_clear194(uuid, uuid, uuid) to service_role;

-- 8) DOOR: the signature list. The screen opens these (Rust unseals, the browser shows them). Stable, at most 20.
create or replace function public.fmail_signatures_list194(p_actor uuid, p_mailbox uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_items jsonb;
begin
  if p_actor is null or p_mailbox is null then raise exception 'E194: actor and mailbox are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E194: not your mailbox' using errcode = '42501'; end if;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.is_fallback desc, t.created_at, t.id), '[]'::jsonb) into v_items from (
    select id, encode(sealed, 'hex') as sealed, encode(nonce, 'hex') as nonce, key_id, encode(key_wrap, 'hex') as key_wrap, encode(aad_hash, 'hex') as aad_hash,
           encode(from_blind, 'hex') as blind, is_fallback, version, created_at, updated_at
      from public.fmail_signatures where mailbox_id = p_mailbox order by is_fallback desc, created_at, id limit 20) t;
  return jsonb_build_object('returned', jsonb_array_length(v_items), 'items', v_items);
end $$;
revoke all on function public.fmail_signatures_list194(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_signatures_list194(uuid, uuid) to service_role;

-- 9) DOOR: put a snippet (create or replace the one of a name). Idempotent like the signature door.
create or replace function public.fmail_snippet_put194(p_actor uuid, p_mailbox uuid, p_name_blind bytea, p_sealed bytea, p_nonce bytea, p_key_id text, p_key_wrap bytea, p_aad_hash bytea)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare s public.fmail_snippets; v_new boolean := false; v_n integer; v_led jsonb;
begin
  if p_actor is null or p_mailbox is null or p_name_blind is null or p_sealed is null or p_nonce is null or p_key_id is null or p_key_wrap is null or p_aad_hash is null then
    raise exception 'E194: actor, mailbox, the name blind and the whole sealed unit are needed' using errcode = '22023'; end if;
  if octet_length(p_name_blind) <> 32 then raise exception 'E194: a blind index is 32 bytes' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E194: not your mailbox' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || 'snippet', 194));
  select * into s from public.fmail_snippets where mailbox_id = p_mailbox and name_blind = p_name_blind for update;
  perform set_config('fmail.rich_door', 'on', true);
  if s.id is null then
    select count(*) into v_n from public.fmail_snippets where mailbox_id = p_mailbox;
    if v_n >= public.fmail_snippet_cap194() then perform set_config('fmail.rich_door', 'off', true); raise exception 'E194: the snippet list is full (% snippets)', v_n using errcode = '54000'; end if;
    insert into public.fmail_snippets (mailbox_id, name_blind, sealed, nonce, key_id, key_wrap, aad_hash) values (p_mailbox, p_name_blind, p_sealed, p_nonce, p_key_id, p_key_wrap, p_aad_hash) returning * into s;
    v_new := true;
  else
    if s.sealed = p_sealed then
      perform set_config('fmail.rich_door', 'off', true);
      return jsonb_build_object('ok', true, 'id', s.id, 'created', false, 'already', true, 'version', s.version);
    end if;
    update public.fmail_snippets set sealed = p_sealed, nonce = p_nonce, key_id = p_key_id, key_wrap = p_key_wrap, aad_hash = p_aad_hash, version = version + 1 where id = s.id returning * into s;
  end if;
  perform set_config('fmail.rich_door', 'off', true);
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'snippet_put', encode(p_name_blind, 'hex'), case when v_new then 'snippet created' else 'snippet changed' end,
                                      jsonb_build_object('snippet', s.id, 'version', s.version), false);
  return jsonb_build_object('ok', true, 'id', s.id, 'created', v_new, 'already', false, 'version', s.version, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_snippet_put194(uuid, uuid, bytea, bytea, bytea, text, bytea, bytea) from public, anon, authenticated;
grant execute on function public.fmail_snippet_put194(uuid, uuid, bytea, bytea, bytea, text, bytea, bytea) to service_role;

-- 10) DOOR: delete a snippet. Idempotent.
create or replace function public.fmail_snippet_delete194(p_actor uuid, p_mailbox uuid, p_snippet uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare s public.fmail_snippets; v_led jsonb;
begin
  if p_actor is null or p_mailbox is null or p_snippet is null then raise exception 'E194: actor, mailbox and snippet are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E194: not your mailbox' using errcode = '42501'; end if;
  select * into s from public.fmail_snippets where id = p_snippet and mailbox_id = p_mailbox for update;
  if s.id is null then return jsonb_build_object('ok', true, 'already', true); end if;
  perform set_config('fmail.rich_door', 'on', true);
  delete from public.fmail_snippets where id = s.id;
  perform set_config('fmail.rich_door', 'off', true);
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'snippet_delete', encode(s.name_blind, 'hex'), 'snippet deleted by the founder',
                                      jsonb_build_object('snippet', s.id, 'used', s.use_count), false);
  return jsonb_build_object('ok', true, 'already', false, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_snippet_delete194(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_snippet_delete194(uuid, uuid, uuid) to service_role;

-- 11) DOOR: a snippet was used (count + clock only grow; no ledger line, it would flood the chain). The clock may not run ahead of the server by more than five minutes.
create or replace function public.fmail_snippet_used194(p_actor uuid, p_mailbox uuid, p_snippet uuid, p_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare s public.fmail_snippets; v_at timestamptz;
begin
  if p_actor is null or p_mailbox is null or p_snippet is null then raise exception 'E194: actor, mailbox and snippet are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E194: not your mailbox' using errcode = '42501'; end if;
  v_at := least(coalesce(p_at, now()), now() + interval '5 minutes');
  select * into s from public.fmail_snippets where id = p_snippet and mailbox_id = p_mailbox for update;
  if s.id is null then raise exception 'E194: unknown snippet' using errcode = '23503'; end if;
  perform set_config('fmail.rich_door', 'on', true);
  update public.fmail_snippets set use_count = use_count + 1, last_used_at = greatest(coalesce(last_used_at, v_at), v_at) where id = s.id returning * into s;
  perform set_config('fmail.rich_door', 'off', true);
  return jsonb_build_object('ok', true, 'use_count', s.use_count);
end $$;
revoke all on function public.fmail_snippet_used194(uuid, uuid, uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.fmail_snippet_used194(uuid, uuid, uuid, timestamptz) to service_role;

-- 12) DOOR: the snippet list (stable). Most used first, then newest, at most 200.
create or replace function public.fmail_snippets_list194(p_actor uuid, p_mailbox uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_items jsonb; v_total integer;
begin
  if p_actor is null or p_mailbox is null then raise exception 'E194: actor and mailbox are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E194: not your mailbox' using errcode = '42501'; end if;
  select count(*) into v_total from public.fmail_snippets where mailbox_id = p_mailbox;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.use_count desc, t.updated_at desc, t.id), '[]'::jsonb) into v_items from (
    select id, encode(sealed, 'hex') as sealed, encode(nonce, 'hex') as nonce, key_id, encode(key_wrap, 'hex') as key_wrap, encode(aad_hash, 'hex') as aad_hash,
           encode(name_blind, 'hex') as blind, use_count, last_used_at, version, updated_at
      from public.fmail_snippets where mailbox_id = p_mailbox order by use_count desc, updated_at desc, id limit 200) t;
  return jsonb_build_object('total', v_total, 'returned', jsonb_array_length(v_items), 'items', v_items);
end $$;
revoke all on function public.fmail_snippets_list194(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_snippets_list194(uuid, uuid) to service_role;

-- 13) SELFTEST (rolls itself back)
create or replace function public.fmail_selftest194() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_r jsonb; v_r2 jsonb; v_ok boolean; v_n int; v_id uuid; v_id2 uuid; v_ver int;
  v_nonce bytea := decode(repeat('01', 12), 'hex'); v_nonce2 bytea := decode(repeat('09', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex');
  v_aad bytea := decode(repeat('03', 32), 'hex'); v_seal bytea := decode(repeat('ab', 40), 'hex'); v_seal2 bytea := decode(repeat('cd', 41), 'hex');
  f1 bytea := decode(repeat('f1', 32), 'hex'); f2 bytea := decode(repeat('f2', 32), 'hex'); f3 bytea := decode(repeat('f3', 32), 'hex');
  n1 bytea := decode(repeat('a1', 32), 'hex'); n2 bytea := decode(repeat('a2', 32), 'hex'); n3 bytea := decode(repeat('a3', 32), 'hex');
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest194@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    -- write protection
    begin insert into public.fmail_signatures (mailbox_id, from_blind, sealed, nonce, key_id, key_wrap, aad_hash) values (v_box, f1, v_seal, v_nonce, 'k', v_wrap, v_aad); v_ok := false;
    exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct signature insert (not through a door) is refused', 'ok', v_ok);
    begin insert into public.fmail_snippets (mailbox_id, name_blind, sealed, nonce, key_id, key_wrap, aad_hash) values (v_box, n1, v_seal, v_nonce, 'k', v_wrap, v_aad); v_ok := false;
    exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct snippet insert (not through a door) is refused', 'ok', v_ok);
    -- signatures
    v_r := public.fmail_signature_put194(v_uid, v_box, f1, v_seal, v_nonce, 'k-selftest', v_wrap, v_aad, false);
    v_id := (v_r ->> 'id')::uuid;
    res := res || jsonb_build_object('name', 'a signature is created (version 1) with one hash-chained line that carries the blind, not the address', 'ok',
        (v_r ->> 'created')::boolean and (v_r ->> 'version') = '1' and (select count(*) from public.fmail_ledger where action = 'signature_set' and mailbox_id = v_box and target = encode(f1, 'hex')) = 1);
    v_r2 := public.fmail_signature_put194(v_uid, v_box, f1, v_seal, v_nonce, 'k-selftest', v_wrap, v_aad, false);
    res := res || jsonb_build_object('name', 'putting the same sealed unit again changes nothing and writes no second ledger line', 'ok',
        (v_r2 ->> 'already')::boolean and (select count(*) from public.fmail_ledger where action = 'signature_set' and mailbox_id = v_box) = 1);
    v_r2 := public.fmail_signature_put194(v_uid, v_box, f1, v_seal2, v_nonce2, 'k-selftest2', v_wrap, v_aad, false);
    res := res || jsonb_build_object('name', 'a changed signature replaces the whole sealed unit and moves the version to 2', 'ok',
        (v_r2 ->> 'version') = '2' and not (v_r2 ->> 'created')::boolean and (select octet_length(sealed) = 41 and nonce = v_nonce2 and key_id = 'k-selftest2' from public.fmail_signatures where id = v_id));
    -- fallback: only one per mailbox
    perform public.fmail_signature_put194(v_uid, v_box, f2, v_seal, v_nonce, 'k', v_wrap, v_aad, true);
    perform public.fmail_signature_put194(v_uid, v_box, f3, v_seal, v_nonce, 'k', v_wrap, v_aad, true);
    res := res || jsonb_build_object('name', 'only one signature per mailbox can be the fallback (the newest one takes it)', 'ok',
        (select count(*) from public.fmail_signatures where mailbox_id = v_box and is_fallback) = 1 and (select is_fallback from public.fmail_signatures where from_blind = f3));
    res := res || jsonb_build_object('name', 'the list opens the signatures, fallback first', 'ok',
        (public.fmail_signatures_list194(v_uid, v_box) ->> 'returned') = '3' and (public.fmail_signatures_list194(v_uid, v_box) -> 'items' -> 0 ->> 'blind') = encode(f3, 'hex'));
    -- cap (lowered to 3 for the test): refuse, never evict
    perform set_config('fmail.signature_cap', '3', true);
    begin perform public.fmail_signature_put194(v_uid, v_box, decode(repeat('f4', 32), 'hex'), v_seal, v_nonce, 'k', v_wrap, v_aad, false); v_ok := false; exception when sqlstate '54000' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'at the cap a new signature is refused and nothing is evicted', 'ok', v_ok and (select count(*) from public.fmail_signatures where mailbox_id = v_box) = 3);
    perform set_config('fmail.signature_cap', '', true);
    res := res || jsonb_build_object('name', 'the signature cap can only be lowered, never raised above 20', 'ok', public.fmail_signature_cap194() = 20
        and (select public.fmail_signature_cap194() from (select set_config('fmail.signature_cap', '999999', true)) s) = 20);
    perform set_config('fmail.signature_cap', '', true);
    -- guard: identity frozen, version, nonce reuse, direct write
    begin update public.fmail_signatures set from_blind = f3 where id = v_id; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct signature update outside a door is refused', 'ok', v_ok);
    perform set_config('fmail.rich_door', 'on', true);
    begin update public.fmail_signatures set from_blind = decode(repeat('ee', 32), 'hex') where id = v_id; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'even inside a door the From blind of a signature can not change', 'ok', v_ok);
    begin update public.fmail_signatures set sealed = decode(repeat('ee', 40), 'hex'), version = version + 1 where id = v_id; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a new ciphertext with the old nonce is refused (no nonce reuse)', 'ok', v_ok);
    begin update public.fmail_signatures set sealed = decode(repeat('ee', 40), 'hex'), nonce = decode(repeat('0a', 12), 'hex') where id = v_id; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a changed sealed value without version + 1 is refused', 'ok', v_ok);
    perform set_config('fmail.rich_door', 'off', true);
    begin delete from public.fmail_signatures where id = v_id; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct delete outside a door is refused', 'ok', v_ok);
    -- refusals
    begin perform public.fmail_signature_put194('44444444-4444-4444-4444-444444444444', v_box, f1, v_seal, v_nonce, 'k', v_wrap, v_aad, false); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'another founder cannot write to my signatures', 'ok', v_ok);
    begin perform public.fmail_signature_put194(v_uid, v_box, decode('aabb', 'hex'), v_seal, v_nonce, 'k', v_wrap, v_aad, false); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a blind index that is not 32 bytes is refused', 'ok', v_ok);
    begin perform public.fmail_signature_put194(v_uid, v_box, f1, null, null, null, null, null, false); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a half sealed unit is refused', 'ok', v_ok);
    begin perform public.fmail_signature_put194(v_uid, v_box, decode(repeat('f5', 32), 'hex'), decode(repeat('ab', 9000), 'hex'), v_nonce, 'k', v_wrap, v_aad, false); v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a sealed signature above 8 KB is refused', 'ok', v_ok);
    -- clear
    v_r := public.fmail_signature_clear194(v_uid, v_box, v_id); v_r2 := public.fmail_signature_clear194(v_uid, v_box, v_id);
    res := res || jsonb_build_object('name', 'clearing removes the signature with one ledger line; clearing again = already', 'ok', (v_r ->> 'already') = 'false' and (v_r2 ->> 'already') = 'true'
        and not exists (select 1 from public.fmail_signatures where id = v_id) and (select count(*) from public.fmail_ledger where action = 'signature_clear' and mailbox_id = v_box) = 1);
    -- snippets
    v_r := public.fmail_snippet_put194(v_uid, v_box, n1, v_seal, v_nonce, 'k-selftest', v_wrap, v_aad);
    v_id2 := (v_r ->> 'id')::uuid;
    res := res || jsonb_build_object('name', 'a snippet is created (version 1, use 0) with one hash-chained line that carries the blind', 'ok', (v_r ->> 'created')::boolean and (v_r ->> 'version') = '1'
        and (select use_count = 0 and last_used_at is null from public.fmail_snippets where id = v_id2) and (select count(*) from public.fmail_ledger where action = 'snippet_put' and mailbox_id = v_box and target = encode(n1, 'hex')) = 1);
    v_r2 := public.fmail_snippet_put194(v_uid, v_box, n1, v_seal, v_nonce, 'k-selftest', v_wrap, v_aad);
    res := res || jsonb_build_object('name', 'the same snippet again changes nothing (already) and writes no second ledger line', 'ok', (v_r2 ->> 'already')::boolean
        and (select count(*) from public.fmail_ledger where action = 'snippet_put' and mailbox_id = v_box) = 1);
    v_r2 := public.fmail_snippet_put194(v_uid, v_box, n1, v_seal2, v_nonce2, 'k-selftest2', v_wrap, v_aad);
    res := res || jsonb_build_object('name', 'a changed snippet replaces the whole sealed unit and moves to version 2', 'ok', (v_r2 ->> 'version') = '2'
        and (select nonce = v_nonce2 and key_id = 'k-selftest2' from public.fmail_snippets where id = v_id2));
    v_r := public.fmail_snippet_used194(v_uid, v_box, v_id2, now()); v_r2 := public.fmail_snippet_used194(v_uid, v_box, v_id2, now() + interval '400 days');
    res := res || jsonb_build_object('name', 'using a snippet counts (1, 2) with no ledger line, and a far future clock is pulled back to now + 5 minutes', 'ok', (v_r ->> 'use_count') = '1' and (v_r2 ->> 'use_count') = '2'
        and (select last_used_at <= now() + interval '6 minutes' from public.fmail_snippets where id = v_id2) and (select count(*) from public.fmail_ledger where mailbox_id = v_box and action like 'snippet%') = 2);
    perform set_config('fmail.rich_door', 'on', true);
    begin update public.fmail_snippets set use_count = 0, last_used_at = null where id = v_id2; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the use counter can not go down', 'ok', v_ok);
    begin update public.fmail_snippets set name_blind = n3 where id = v_id2; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'even inside a door the name blind of a snippet can not change', 'ok', v_ok);
    perform set_config('fmail.rich_door', 'off', true);
    begin update public.fmail_snippets set use_count = 9 where id = v_id2; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct snippet update outside a door is refused', 'ok', v_ok);
    perform public.fmail_snippet_put194(v_uid, v_box, n2, v_seal, v_nonce, 'k', v_wrap, v_aad);
    perform public.fmail_snippet_used194(v_uid, v_box, (select id from public.fmail_snippets where name_blind = n2), now());
    perform public.fmail_snippet_used194(v_uid, v_box, (select id from public.fmail_snippets where name_blind = n2), now());
    perform public.fmail_snippet_used194(v_uid, v_box, (select id from public.fmail_snippets where name_blind = n2), now());
    res := res || jsonb_build_object('name', 'the list puts the most used snippet first and says how many exist', 'ok', (public.fmail_snippets_list194(v_uid, v_box) -> 'items' -> 0 ->> 'blind') = encode(n2, 'hex')
        and (public.fmail_snippets_list194(v_uid, v_box) ->> 'total') = '2');
    perform set_config('fmail.snippet_cap', '2', true);
    begin perform public.fmail_snippet_put194(v_uid, v_box, n3, v_seal, v_nonce, 'k', v_wrap, v_aad); v_ok := false; exception when sqlstate '54000' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'at the snippet cap a new snippet is refused and nothing is evicted', 'ok', v_ok and (select count(*) from public.fmail_snippets where mailbox_id = v_box) = 2);
    perform set_config('fmail.snippet_cap', '', true);
    res := res || jsonb_build_object('name', 'the snippet cap can only be lowered, never raised above 200', 'ok', public.fmail_snippet_cap194() = 200
        and (select public.fmail_snippet_cap194() from (select set_config('fmail.snippet_cap', '999999', true)) s) = 200);
    perform set_config('fmail.snippet_cap', '', true);
    begin perform public.fmail_snippet_used194(v_uid, v_box, '33333333-3333-3333-3333-333333333333'); v_ok := false; exception when sqlstate '23503' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'using an unknown snippet is refused', 'ok', v_ok);
    v_r := public.fmail_snippet_delete194(v_uid, v_box, v_id2); v_r2 := public.fmail_snippet_delete194(v_uid, v_box, v_id2);
    res := res || jsonb_build_object('name', 'deleting removes the snippet with one ledger line; deleting again = already', 'ok', (v_r ->> 'already') = 'false' and (v_r2 ->> 'already') = 'true'
        and not exists (select 1 from public.fmail_snippets where id = v_id2) and (select count(*) from public.fmail_ledger where action = 'snippet_delete' and mailbox_id = v_box) = 1);
    -- nothing personal is stored in a plain column
    res := res || jsonb_build_object('name', 'no plain text column exists on the two tables except key id', 'ok',
        (select array_agg(attname::text order by attname) from pg_attribute where attrelid in ('public.fmail_signatures'::regclass, 'public.fmail_snippets'::regclass) and attnum > 0 and not attisdropped and atttypid = 'text'::regtype) = array['key_id', 'key_id']);
    res := res || jsonb_build_object('name', 'ledger chain still verifies', 'ok', public.fmail_ledger_verify(1) >= 1);
    raise exception 'E194_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E194_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E194_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is true),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest194() from public, anon, authenticated;
grant execute on function public.fmail_selftest194() to service_role;

-- 14) POSTURE (stable, E179-safe: the door names are built from two pieces on purpose, this function only reads catalogs)
create or replace function public.fmail_posture194() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  doors regprocedure[] := array[
    to_regprocedure('public.fmail_signature_' || 'put194(uuid,uuid,bytea,bytea,bytea,text,bytea,bytea,boolean)'),
    to_regprocedure('public.fmail_signature_' || 'clear194(uuid,uuid,uuid)'),
    to_regprocedure('public.fmail_snippet_' || 'put194(uuid,uuid,bytea,bytea,bytea,text,bytea,bytea)'),
    to_regprocedure('public.fmail_snippet_' || 'delete194(uuid,uuid,uuid)'),
    to_regprocedure('public.fmail_snippet_' || 'used194(uuid,uuid,uuid,timestamptz)')];
  lists regprocedure[] := array[to_regprocedure('public.fmail_signatures_list194(uuid,uuid)'), to_regprocedure('public.fmail_snippets_list194(uuid,uuid)')];
begin
  return jsonb_build_object(
    'doors_exist', (select bool_and(d is not null) from unnest(doors) d),
    'doors_volatile', (select bool_and(provolatile = 'v') from pg_proc where oid = any (doors::oid[])),
    'doors_service_only', (select bool_and(has_function_privilege('service_role', d, 'execute') and not has_function_privilege('anon', d, 'execute') and not has_function_privilege('authenticated', d, 'execute')) from unnest(doors) d),
    'lists_stable_service_only', (select bool_and(l is not null) from unnest(lists) l) and (select bool_and(provolatile = 's') from pg_proc where oid = any (lists::oid[]))
        and (select bool_and(has_function_privilege('service_role', l, 'execute') and not has_function_privilege('anon', l, 'execute') and not has_function_privilege('authenticated', l, 'execute')) from unnest(lists) l),
    'rls_forced', (select bool_and(relforcerowsecurity) from pg_class where oid in ('public.fmail_signatures'::regclass, 'public.fmail_snippets'::regclass)),
    'service_role_read_only', not exists (select 1 from information_schema.role_table_grants where grantee = 'service_role' and table_schema = 'public'
                                           and table_name in ('fmail_signatures', 'fmail_snippets') and privilege_type = any (array['INS' || 'ERT', 'UPD' || 'ATE', 'DEL' || 'ETE', 'TRUNC' || 'ATE'])),
    'anon_no_access', not exists (select 1 from information_schema.role_table_grants where grantee in ('anon', 'authenticated', 'PUBLIC') and table_schema = 'public' and table_name in ('fmail_signatures', 'fmail_snippets')),
    'guard_triggers', (select count(*) from pg_trigger where tgrelid in ('public.fmail_signatures'::regclass, 'public.fmail_snippets'::regclass) and not tgisinternal),
    'one_fallback_index', exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'fmail_signatures_one_fallback_ix'),
    'ledger_knows_rich_actions', exists (select 1 from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%signature_set%'
                                          and pg_get_constraintdef(oid) like '%signature_clear%' and pg_get_constraintdef(oid) like '%snippet_put%' and pg_get_constraintdef(oid) like '%snippet_delete%'
                                          and pg_get_constraintdef(oid) like '%contact_evict%'),
    'door_audit_clean', not exists (select 1 from public.fmail_door_audit179()));
end $$;
revoke all on function public.fmail_posture194() from public, anon, authenticated;
grant execute on function public.fmail_posture194() to service_role;

select public.fmail_posture194() as e194_posture;
select public.fmail_selftest194() ->> 'passed' as e194_selftest_passed, public.fmail_selftest194() ->> 'failed' as e194_selftest_failed;
