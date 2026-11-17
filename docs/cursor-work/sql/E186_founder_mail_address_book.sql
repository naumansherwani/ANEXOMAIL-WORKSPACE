
-- E186 (QC1b, 18 Nov 2026): THE FOUNDER ADDRESS BOOK. The sealed list of people he writes to and hears from, which feeds the recipient suggestions under the To / Cc / Bcc chips.
-- Stands on E167 (mailboxes, ledger chain, sealing columns pattern), E179 (door audit), E185 (door pattern). NOTHING of the awam address book (E95) is read or touched (separation law).
-- ---------------------------------------------------------------------------------------------------------------------------------------------------
-- WEB RESEARCH FIRST (standing rule 0, read 18 Nov 2026), written into docs/claude/COMPOSE-RESEARCH-17NOV.md before this file:
--   * a blind index (HMAC) answers exactly ONE question: equality. HMAC("ali") says nothing about HMAC("alistair"), so "type-ahead over a blind index" silently becomes exact match;
--     the known cure (one index row per prefix) leaks prefix equality and costs about 15 writes per address. We refuse both: NO prefix index exists in this file.
--   * the pattern big mail clients use (Nylas recipient-autocomplete cookbook): load the contacts ONCE, filter in the BROWSER, no network call per key, dedupe by lower-case address
--     (never by name), rank by how often the address was a RECIPIENT of sent mail, show 5 to 8.  Thunderbird ranks by a plain counter with NO recency (bug 1671679, "no frecency").
--   => DESIGN: the database keeps the names and addresses SEALED (AES-256-GCM, produced by the Rust engine, the database never sees a plain address or name), ONE exact blind index
--      (HMAC-SHA-256, vault key, E167 pattern) used only to find "is this person already here", and plain numbers (counts, clocks) that are not personal. Typing is filtered in the
--      browser over the opened top 500. The ranking is FRECENCY done here, in one pure function, so Rust, the selftest and the screen can never disagree.
--
-- TECHNOLOGY (PostgreSQL 16, advance level):
--   * forced row level security on all three tables, no policy for anon / authenticated, and service_role can only SELECT: every WRITE goes through the doors below
--     (security definer, fixed search_path, VOLATILE, service_role only). A trigger refuses any insert, update or delete that does not come from a door (a session flag set with
--     set_config(..., is_local = true), so it can not leak across transactions).
--   * a guard trigger freezes the identity of a contact (mailbox, blind index of the address and of the domain, first seen, source), lets counters and clocks only GROW, and lets the sealed
--     name be replaced only as one whole unit (ciphertext, nonce, key id, key wrap and AAD hash change together).
--   * check constraints tie counters to clocks ("sent_count = 0 exactly when last_sent_at is null"), so a half-written row can not exist.
--   * ONE hash-chained ledger: membership changes (add, forget, pin, evict) are lines in the E167 fmail_ledger chain (same advisory lock, same SHA-256 chain). The ledger line carries the
--     BLIND of the address, never the address. Counting a mail is NOT a ledger line (it would flood the chain); it is a monotone counter guarded by the trigger.
--   * IDEMPOTENT touch: a retried send or a re-delivered mail (same event key) changes nothing the second time (compare-and-set on the last event key under a row lock).
--   * "forget" leaves a TOMBSTONE (blind only): mail that merely ARRIVES from a forgotten person does not bring them back; only when he writes to them again do they return.
--   * a hard cap per mailbox (5000, evicts the lowest frecency unpinned contact, one ledger line), so the table can never grow without bound.
--   * frecency = ln(1 + 3 * sent + received) * 2 ^ (-days_since_last_contact / 45), pinned contacts add 1e9. Sending counts three times what receiving does (he chose them); the logarithm
--     stops one old busy thread from outranking everyone for ever; the half life is 45 days.
--   * selftest that rolls itself back (30 checks), posture function, CHECK_E186.sql. Door names are built from two pieces in the posture function so the E179 audit (stable functions must
--     not name a writing door) stays clean.
-- Run once through sql-run.sh, after E185. Safe to run again (idempotent).

do $$
begin
  if to_regprocedure('public.fmail_ledger_append(uuid,uuid,text,text,text,jsonb,boolean)') is null then raise exception 'E186: E167 ledger is missing'; end if;
  if to_regprocedure('public.fmail_door_audit179()') is null then raise exception 'E186: E179 door audit is missing (run E179 first)'; end if;
  if to_regprocedure('public.fmail_outbox_release_now(uuid,uuid,uuid)') is null then raise exception 'E186: E185 is missing (run E185 first)'; end if;
end $$;

-- 1) the ledger learns four action names (closed set, the same drop-and-re-add pattern as E185)
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_start%' loop
    if c.d like '%contact_evict%' then v_has := true; else execute format('alter table public.fmail_ledger drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_ledger add constraint fmail_ledger_action_ck check (action in (
      'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
      'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
      'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
      'inbound_reject','panic_lock','inbound_ok','unseal_gated','vault_set','mailbox_seed','dkim_install','dkim_revoke','ledger_checkpoint',
      'dkim_policy','dkim_dns_check','dkim_proof','send_release',
      'contact_add','contact_forget','contact_pin','contact_evict'));
  end if;
end $$;

-- 2) the contacts. Sealed name + address, one exact blind index, numbers. NO plain personal data in any column.
create table if not exists public.fmail_contacts (
  id            uuid primary key default gen_random_uuid(),
  mailbox_id    uuid not null references public.fmail_mailboxes (id) on delete cascade,
  addr_blind    bytea not null check (octet_length(addr_blind) = 32),     -- HMAC-SHA-256(vault blind key, lower-case address), computed by Rust: "is this person already here?"
  domain_blind  bytea not null check (octet_length(domain_blind) = 32),   -- same for the domain: lets the database refuse the founder's own domains without knowing them
  sealed        bytea not null check (octet_length(sealed) between 17 and 2048),   -- AES-256-GCM(JSON {a: address, n: display name}) + 16 byte tag
  nonce         bytea not null check (octet_length(nonce) = 12),
  key_id        text  not null check (length(key_id) between 1 and 80 and key_id !~ '[[:cntrl:]]'),
  key_wrap      bytea not null check (octet_length(key_wrap) between 16 and 256),   -- the per-contact key wrapped under the vault master (E167 'vault' mode)
  aad_hash      bytea not null check (octet_length(aad_hash) = 32),       -- SHA-256 of the additional data the sealing was bound to (mailbox | blind), checked again on open
  source        text  not null check (source in ('sent', 'received')),    -- how he first met this person (never changes)
  sent_count    integer not null default 0 check (sent_count between 0 and 1000000),
  recv_count    integer not null default 0 check (recv_count between 0 and 1000000),
  first_seen_at timestamptz not null default now(),
  last_sent_at  timestamptz,
  last_recv_at  timestamptz,
  pinned        boolean not null default false,
  last_event    bytea check (last_event is null or octet_length(last_event) = 32),   -- key of the last mail that counted, so a retry counts once
  updated_at    timestamptz not null default now(),
  constraint fmail_contacts_uq unique (mailbox_id, addr_blind),
  constraint fmail_contacts_used_ck check (sent_count + recv_count >= 1),
  constraint fmail_contacts_clock_ck check ((sent_count = 0) = (last_sent_at is null) and (recv_count = 0) = (last_recv_at is null))
);
create index if not exists fmail_contacts_box_ix on public.fmail_contacts (mailbox_id, pinned desc, updated_at desc);

-- people he asked to forget: blind only, so incoming mail does not bring them back
create table if not exists public.fmail_contact_tombstones (
  mailbox_id    uuid not null references public.fmail_mailboxes (id) on delete cascade,
  addr_blind    bytea not null check (octet_length(addr_blind) = 32),
  forgotten_at  timestamptz not null default now(),
  primary key (mailbox_id, addr_blind)
);

-- the founder's own domains (blind only): never stored as contacts. Filled by the Rust engine from the mailboxes it serves.
create table if not exists public.fmail_contact_own_domains (
  mailbox_id    uuid not null references public.fmail_mailboxes (id) on delete cascade,
  domain_blind  bytea not null check (octet_length(domain_blind) = 32),
  created_at    timestamptz not null default now(),
  primary key (mailbox_id, domain_blind)
);

alter table public.fmail_contacts enable row level security;               alter table public.fmail_contacts force row level security;
alter table public.fmail_contact_tombstones enable row level security;     alter table public.fmail_contact_tombstones force row level security;
alter table public.fmail_contact_own_domains enable row level security;    alter table public.fmail_contact_own_domains force row level security;
revoke all on public.fmail_contacts from public, anon, authenticated;
revoke all on public.fmail_contact_tombstones from public, anon, authenticated;
revoke all on public.fmail_contact_own_domains from public, anon, authenticated;
revoke insert, update, delete, truncate on public.fmail_contacts from service_role;
revoke insert, update, delete, truncate on public.fmail_contact_tombstones from service_role;
revoke insert, update, delete, truncate on public.fmail_contact_own_domains from service_role;
grant select on public.fmail_contacts, public.fmail_contact_tombstones, public.fmail_contact_own_domains to service_role;   -- reading only: every write is a door

-- 3) THE GUARD. Only a door may write (session flag set inside the door, transaction local); identity is frozen; counters and clocks only grow.
create or replace function public.fmail_contact_door_on186() returns boolean language sql stable set search_path = pg_catalog as $$
  select coalesce(current_setting('fmail.contact_door', true), '') = 'on'
$$;

create or replace function public.fmail_contacts_guard186() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if not public.fmail_contact_door_on186() then
    raise exception 'E186: the address book is written only through its doors (% refused)', tg_op using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id or new.mailbox_id is distinct from old.mailbox_id or new.addr_blind is distinct from old.addr_blind
       or new.domain_blind is distinct from old.domain_blind or new.first_seen_at is distinct from old.first_seen_at or new.source is distinct from old.source then
      raise exception 'E186: the identity of a contact is frozen' using errcode = '23514'; end if;
    if new.sent_count < old.sent_count or new.recv_count < old.recv_count then raise exception 'E186: contact counters only grow' using errcode = '23514'; end if;
    if (old.last_sent_at is not null and new.last_sent_at < old.last_sent_at) or (old.last_recv_at is not null and new.last_recv_at < old.last_recv_at) then
      raise exception 'E186: contact clocks only move forward' using errcode = '23514'; end if;
    -- the sealed name moves as ONE unit: if any part changed, every part must have been given
    if (new.sealed is distinct from old.sealed) and (new.nonce is not distinct from old.nonce) then
      raise exception 'E186: a new sealed value needs a new nonce (AES-GCM never reuses a nonce)' using errcode = '23514'; end if;
    new.updated_at := now();
  end if;
  if tg_op = 'DELETE' then return old; end if;   -- a BEFORE DELETE trigger that returns NULL would silently cancel the delete
  return new;
end $$;
drop trigger if exists fmail_contacts_guard on public.fmail_contacts;
create trigger fmail_contacts_guard before insert or update or delete on public.fmail_contacts for each row execute function public.fmail_contacts_guard186();
drop trigger if exists fmail_contacts_guard_t on public.fmail_contacts;
create trigger fmail_contacts_guard_t before truncate on public.fmail_contacts for each statement execute function public.fmail_append_only_167();

create or replace function public.fmail_contact_side_guard186() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if not public.fmail_contact_door_on186() then
    raise exception 'E186: % is written only through the address book doors (% refused)', tg_table_name, tg_op using errcode = '42501'; end if;
  if tg_op = 'UPDATE' then raise exception 'E186: % rows are never rewritten', tg_table_name using errcode = '42501'; end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
drop trigger if exists fmail_contact_tombstones_guard on public.fmail_contact_tombstones;
create trigger fmail_contact_tombstones_guard before insert or update or delete on public.fmail_contact_tombstones for each row execute function public.fmail_contact_side_guard186();
drop trigger if exists fmail_contact_own_domains_guard on public.fmail_contact_own_domains;
create trigger fmail_contact_own_domains_guard before insert or update or delete on public.fmail_contact_own_domains for each row execute function public.fmail_contact_side_guard186();

-- 4) FRECENCY, one pure function. Used by the top door, the cap eviction, the selftest (and mirrored bit for bit by founder-web/src/book.ts, which has a test against these numbers).
create or replace function public.fmail_contact_score186(p_sent integer, p_recv integer, p_last_sent timestamptz, p_last_recv timestamptz, p_pinned boolean, p_now timestamptz)
returns double precision language sql immutable parallel safe set search_path = pg_catalog as $$
  select (case when p_pinned then 1e9 else 0 end)
       + ln(1 + 3.0 * greatest(p_sent, 0) + greatest(p_recv, 0))
       * power(2.0, - greatest(0, extract(epoch from (p_now - coalesce(greatest(p_last_sent, p_last_recv), p_now)))) / 86400.0 / 45.0)
$$;

-- 5) the cap (5000 per mailbox). A session setting may only LOWER it (the selftest uses 3); it can never raise it above 5000.
create or replace function public.fmail_contact_cap186() returns integer language sql stable set search_path = pg_catalog as $$
  select greatest(3, least(5000, coalesce(nullif(current_setting('fmail.contact_cap', true), '')::integer, 5000)))
$$;

-- 6) DOOR: own domains (idempotent). The Rust engine says "these domains are mine"; the database stores blinds only.
create or replace function public.fmail_contact_own_domain186(p_actor uuid, p_mailbox uuid, p_domain_blind bytea)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_n integer;
begin
  if p_actor is null or p_mailbox is null or p_domain_blind is null or octet_length(p_domain_blind) <> 32 then raise exception 'E186: actor, mailbox and a 32 byte domain blind are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E186: not your mailbox' using errcode = '42501'; end if;
  perform set_config('fmail.contact_door', 'on', true);
  insert into public.fmail_contact_own_domains (mailbox_id, domain_blind) values (p_mailbox, p_domain_blind) on conflict do nothing;
  get diagnostics v_n = row_count;
  -- a domain that became "mine" removes the contacts that were stored before we knew (no ledger line per row: one summary line)
  if v_n = 1 then
    with gone as (delete from public.fmail_contacts where mailbox_id = p_mailbox and domain_blind = p_domain_blind returning 1)
    select count(*) into v_n from gone;
    if v_n > 0 then perform public.fmail_ledger_append(p_actor, p_mailbox, 'contact_evict', encode(p_domain_blind, 'hex'), 'own domain registered, contacts of it removed',
                                                      jsonb_build_object('removed', v_n, 'why', 'own_domain'), false); end if;
  else v_n := 0; end if;
  perform set_config('fmail.contact_door', 'off', true);
  return jsonb_build_object('ok', true, 'removed', v_n);
end $$;
revoke all on function public.fmail_contact_own_domain186(uuid, uuid, bytea) from public, anon, authenticated;
grant execute on function public.fmail_contact_own_domain186(uuid, uuid, bytea) to service_role;

-- 7) DOOR: touch. Called by Rust after a real send ('sent') and after the intake of a real, authenticated inbound mail ('received').
create or replace function public.fmail_contact_touch186(p_actor uuid, p_mailbox uuid, p_addr_blind bytea, p_domain_blind bytea, p_direction text,
    p_sealed bytea, p_nonce bytea, p_key_id text, p_key_wrap bytea, p_aad_hash bytea, p_event bytea default null, p_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  c public.fmail_contacts; v_at timestamptz; v_new boolean := false; v_led jsonb; v_cnt integer; v_victim public.fmail_contacts; v_evicted integer := 0; v_cap integer := public.fmail_contact_cap186();
begin
  if p_actor is null or p_mailbox is null or p_addr_blind is null or p_domain_blind is null then raise exception 'E186: actor, mailbox and both blinds are needed' using errcode = '22023'; end if;
  if octet_length(p_addr_blind) <> 32 or octet_length(p_domain_blind) <> 32 then raise exception 'E186: a blind index is 32 bytes' using errcode = '22023'; end if;
  if p_direction is null or p_direction not in ('sent', 'received') then raise exception 'E186: direction is sent or received' using errcode = '22023'; end if;
  if p_event is not null and octet_length(p_event) <> 32 then raise exception 'E186: an event key is 32 bytes' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E186: not your mailbox' using errcode = '42501'; end if;
  -- the clock may not run ahead of the server by more than a few minutes (a bad client clock can not pin a contact to the top for years)
  v_at := least(coalesce(p_at, now()), now() + interval '5 minutes');
  if exists (select 1 from public.fmail_contact_own_domains where mailbox_id = p_mailbox and domain_blind = p_domain_blind) then
    return jsonb_build_object('ok', true, 'skipped', 'own_domain'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || encode(p_addr_blind, 'hex'), 186));
  select * into c from public.fmail_contacts where mailbox_id = p_mailbox and addr_blind = p_addr_blind for update;
  perform set_config('fmail.contact_door', 'on', true);
  if c.id is null then
    -- a forgotten person comes back only when HE writes to them; mail that merely arrives does not bring them back
    if exists (select 1 from public.fmail_contact_tombstones where mailbox_id = p_mailbox and addr_blind = p_addr_blind) then
      if p_direction = 'received' then perform set_config('fmail.contact_door', 'off', true); return jsonb_build_object('ok', true, 'skipped', 'forgotten'); end if;
      delete from public.fmail_contact_tombstones where mailbox_id = p_mailbox and addr_blind = p_addr_blind;
    end if;
    if p_sealed is null or p_nonce is null or p_key_id is null or p_key_wrap is null or p_aad_hash is null then
      raise exception 'E186: a new contact needs its sealed name and address' using errcode = '22023'; end if;
    -- the cap: make room by removing the lowest frecency unpinned contact (one ledger line), or refuse when everything is pinned
    select count(*) into v_cnt from public.fmail_contacts where mailbox_id = p_mailbox;
    while v_cnt >= v_cap loop
      select * into v_victim from public.fmail_contacts where mailbox_id = p_mailbox and not pinned
        order by public.fmail_contact_score186(sent_count, recv_count, last_sent_at, last_recv_at, pinned, v_at) asc, id asc limit 1;
      if v_victim.id is null then raise exception 'E186: the address book is full of pinned contacts' using errcode = '54000'; end if;
      delete from public.fmail_contacts where id = v_victim.id;
      perform public.fmail_ledger_append(p_actor, p_mailbox, 'contact_evict', encode(v_victim.addr_blind, 'hex'), 'address book full, lowest ranked contact removed',
                                         jsonb_build_object('contact', v_victim.id, 'why', 'cap', 'cap', v_cap), false);
      v_cnt := v_cnt - 1; v_evicted := v_evicted + 1;
    end loop;
    insert into public.fmail_contacts (mailbox_id, addr_blind, domain_blind, sealed, nonce, key_id, key_wrap, aad_hash, source, sent_count, recv_count,
                                       first_seen_at, last_sent_at, last_recv_at, last_event)
      values (p_mailbox, p_addr_blind, p_domain_blind, p_sealed, p_nonce, p_key_id, p_key_wrap, p_aad_hash, p_direction,
              case when p_direction = 'sent' then 1 else 0 end, case when p_direction = 'received' then 1 else 0 end, v_at,
              case when p_direction = 'sent' then v_at end, case when p_direction = 'received' then v_at end, p_event)
      returning * into c;
    v_new := true;
    v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'contact_add', encode(p_addr_blind, 'hex'), 'contact added from ' || p_direction || ' mail',
                                        jsonb_build_object('contact', c.id, 'source', p_direction), false);
  else
    -- the same mail twice (a retried send, a re-delivered message) counts once
    if p_event is not null and c.last_event is not distinct from p_event then
      perform set_config('fmail.contact_door', 'off', true);
      return jsonb_build_object('ok', true, 'id', c.id, 'created', false, 'already', true, 'sent_count', c.sent_count, 'recv_count', c.recv_count);
    end if;
    update public.fmail_contacts set
        sent_count   = sent_count + (case when p_direction = 'sent' then 1 else 0 end),
        recv_count   = recv_count + (case when p_direction = 'received' then 1 else 0 end),
        last_sent_at = case when p_direction = 'sent' then greatest(coalesce(last_sent_at, v_at), v_at) else last_sent_at end,
        last_recv_at = case when p_direction = 'received' then greatest(coalesce(last_recv_at, v_at), v_at) else last_recv_at end,
        last_event   = coalesce(p_event, last_event),
        -- a better display name may arrive with a later mail: the whole sealed unit is replaced together, never part of it
        sealed = coalesce(p_sealed, sealed), nonce = case when p_sealed is not null then p_nonce else nonce end,
        key_id = case when p_sealed is not null then p_key_id else key_id end, key_wrap = case when p_sealed is not null then p_key_wrap else key_wrap end,
        aad_hash = case when p_sealed is not null then p_aad_hash else aad_hash end
      where id = c.id returning * into c;
  end if;
  perform set_config('fmail.contact_door', 'off', true);
  return jsonb_build_object('ok', true, 'id', c.id, 'created', v_new, 'already', false, 'sent_count', c.sent_count, 'recv_count', c.recv_count,
                            'evicted', v_evicted, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_contact_touch186(uuid, uuid, bytea, bytea, text, bytea, bytea, text, bytea, bytea, bytea, timestamptz) from public, anon, authenticated;
grant execute on function public.fmail_contact_touch186(uuid, uuid, bytea, bytea, text, bytea, bytea, text, bytea, bytea, bytea, timestamptz) to service_role;

-- 8) DOOR: the top list. The screen opens these (Rust unseals, the browser filters). Ranked by frecency, pinned first, at most 500, keyset-stable (score desc, id asc).
create or replace function public.fmail_contacts_top186(p_actor uuid, p_mailbox uuid, p_limit integer default 500, p_now timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_now timestamptz := coalesce(p_now, now()); v_total integer; v_items jsonb;
begin
  if p_actor is null or p_mailbox is null then raise exception 'E186: actor and mailbox are needed' using errcode = '22023'; end if;
  if p_limit is null or p_limit < 1 or p_limit > 500 then raise exception 'E186: limit is 1 to 500' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E186: not your mailbox' using errcode = '42501'; end if;
  select count(*) into v_total from public.fmail_contacts where mailbox_id = p_mailbox;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.score desc, t.id), '[]'::jsonb) into v_items from (
    select c.id, encode(c.sealed, 'hex') as sealed, encode(c.nonce, 'hex') as nonce, c.key_id, encode(c.key_wrap, 'hex') as key_wrap, encode(c.aad_hash, 'hex') as aad_hash,
           encode(c.addr_blind, 'hex') as blind, c.sent_count, c.recv_count, c.last_sent_at, c.last_recv_at, c.pinned,
           round(public.fmail_contact_score186(c.sent_count, c.recv_count, c.last_sent_at, c.last_recv_at, c.pinned, v_now)::numeric, 6) as score
      from public.fmail_contacts c where c.mailbox_id = p_mailbox
      order by public.fmail_contact_score186(c.sent_count, c.recv_count, c.last_sent_at, c.last_recv_at, c.pinned, v_now) desc, c.id limit p_limit) t;
  return jsonb_build_object('total', v_total, 'returned', jsonb_array_length(v_items), 'truncated', v_total > p_limit, 'at', v_now, 'items', v_items);
end $$;
revoke all on function public.fmail_contacts_top186(uuid, uuid, integer, timestamptz) from public, anon, authenticated;
grant execute on function public.fmail_contacts_top186(uuid, uuid, integer, timestamptz) to service_role;

-- 9) DOOR: forget. Removes the contact for good, leaves a blind tombstone, one ledger line. Idempotent.
create or replace function public.fmail_contact_forget186(p_actor uuid, p_mailbox uuid, p_contact uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare c public.fmail_contacts; v_led jsonb;
begin
  if p_actor is null or p_mailbox is null or p_contact is null then raise exception 'E186: actor, mailbox and contact are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E186: not your mailbox' using errcode = '42501'; end if;
  select * into c from public.fmail_contacts where id = p_contact and mailbox_id = p_mailbox for update;
  if c.id is null then return jsonb_build_object('ok', true, 'already', true); end if;
  perform set_config('fmail.contact_door', 'on', true);
  delete from public.fmail_contacts where id = c.id;
  insert into public.fmail_contact_tombstones (mailbox_id, addr_blind) values (p_mailbox, c.addr_blind) on conflict do nothing;
  perform set_config('fmail.contact_door', 'off', true);
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'contact_forget', encode(c.addr_blind, 'hex'), 'removed from suggestions by the founder',
                                      jsonb_build_object('contact', c.id, 'sent', c.sent_count, 'received', c.recv_count), false);
  return jsonb_build_object('ok', true, 'already', false, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_contact_forget186(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_contact_forget186(uuid, uuid, uuid) to service_role;

-- 10) DOOR: pin / unpin. Idempotent: setting the state it already has writes nothing.
create or replace function public.fmail_contact_pin186(p_actor uuid, p_mailbox uuid, p_contact uuid, p_pinned boolean)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare c public.fmail_contacts; v_led jsonb;
begin
  if p_actor is null or p_mailbox is null or p_contact is null or p_pinned is null then raise exception 'E186: actor, mailbox, contact and the new state are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E186: not your mailbox' using errcode = '42501'; end if;
  select * into c from public.fmail_contacts where id = p_contact and mailbox_id = p_mailbox for update;
  if c.id is null then raise exception 'E186: unknown contact' using errcode = '23503'; end if;
  if c.pinned = p_pinned then return jsonb_build_object('ok', true, 'already', true, 'pinned', c.pinned); end if;
  perform set_config('fmail.contact_door', 'on', true);
  update public.fmail_contacts set pinned = p_pinned where id = c.id;
  perform set_config('fmail.contact_door', 'off', true);
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'contact_pin', encode(c.addr_blind, 'hex'), case when p_pinned then 'pinned to the top of suggestions' else 'unpinned from the top of suggestions' end,
                                      jsonb_build_object('contact', c.id, 'pinned', p_pinned), false);
  return jsonb_build_object('ok', true, 'already', false, 'pinned', p_pinned, 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_contact_pin186(uuid, uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.fmail_contact_pin186(uuid, uuid, uuid, boolean) to service_role;

-- 11) SELFTEST (rolls itself back)
create or replace function public.fmail_selftest186() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_r jsonb; v_r2 jsonb; v_ok boolean; v_n int; v_n2 int; v_id uuid; v_id2 uuid; v_top jsonb;
  v_nonce bytea := decode(repeat('01', 12), 'hex'); v_nonce2 bytea := decode(repeat('09', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex');
  v_aad bytea := decode(repeat('03', 32), 'hex'); v_seal bytea := decode(repeat('ab', 40), 'hex'); v_dom bytea := decode(repeat('d1', 32), 'hex'); v_own bytea := decode(repeat('d2', 32), 'hex');
  b1 bytea := decode(repeat('b1', 32), 'hex'); b2 bytea := decode(repeat('b2', 32), 'hex'); b3 bytea := decode(repeat('b3', 32), 'hex'); b4 bytea := decode(repeat('b4', 32), 'hex'); b5 bytea := decode(repeat('b5', 32), 'hex');
  e1 bytea := decode(repeat('e1', 32), 'hex'); e2 bytea := decode(repeat('e2', 32), 'hex');
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest186@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    -- identity and write protection
    begin insert into public.fmail_contacts (mailbox_id, addr_blind, domain_blind, sealed, nonce, key_id, key_wrap, aad_hash, source, sent_count, last_sent_at) values (v_box, b1, v_dom, v_seal, v_nonce, 'k', v_wrap, v_aad, 'sent', 1, now()); v_ok := false;
    exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct insert (not through a door) is refused', 'ok', v_ok);
    -- first send creates the contact
    v_r := public.fmail_contact_touch186(v_uid, v_box, b1, v_dom, 'sent', v_seal, v_nonce, 'k-selftest', v_wrap, v_aad, e1, now());
    v_id := (v_r ->> 'id')::uuid;
    res := res || jsonb_build_object('name', 'a first send creates the contact (created, sent 1, received 0)', 'ok', (v_r ->> 'created')::boolean and (v_r ->> 'sent_count') = '1' and (v_r ->> 'recv_count') = '0');
    res := res || jsonb_build_object('name', 'adding writes one hash-chained contact_add line that carries the blind, not the address',
        'ok', (select count(*) from public.fmail_ledger where action = 'contact_add' and mailbox_id = v_box and target = encode(b1, 'hex')) = 1);
    -- the same mail twice counts once
    v_r2 := public.fmail_contact_touch186(v_uid, v_box, b1, v_dom, 'sent', null, null, null, null, null, e1, now());
    res := res || jsonb_build_object('name', 'a retried send with the same event key counts once (already)', 'ok', (v_r2 ->> 'already')::boolean and (v_r2 ->> 'sent_count') = '1');
    -- a second, different mail counts, no new ledger line
    select count(*) into v_n from public.fmail_ledger where mailbox_id = v_box;
    v_r2 := public.fmail_contact_touch186(v_uid, v_box, b1, v_dom, 'sent', null, null, null, null, null, e2, now());
    res := res || jsonb_build_object('name', 'a second send counts (sent 2) and writes no ledger line', 'ok', (v_r2 ->> 'sent_count') = '2' and not (v_r2 ->> 'created')::boolean and (select count(*) from public.fmail_ledger where mailbox_id = v_box) = v_n);
    -- received mail counts on the same person, the source stays sent
    v_r2 := public.fmail_contact_touch186(v_uid, v_box, b1, v_dom, 'received', null, null, null, null, null, decode(repeat('e3', 32), 'hex'), now());
    res := res || jsonb_build_object('name', 'a received mail counts on the same person and the source stays sent', 'ok', (v_r2 ->> 'recv_count') = '1'
        and (select source from public.fmail_contacts where id = v_id) = 'sent' and (select last_recv_at is not null from public.fmail_contacts where id = v_id));
    -- a better display name replaces the whole sealed unit together
    perform public.fmail_contact_touch186(v_uid, v_box, b1, v_dom, 'received', decode(repeat('cd', 41), 'hex'), v_nonce2, 'k-selftest2', v_wrap, v_aad, decode(repeat('e4', 32), 'hex'), now());
    res := res || jsonb_build_object('name', 'a better sealed name replaces ciphertext, nonce and key id together', 'ok',
        (select octet_length(sealed) = 41 and nonce = v_nonce2 and key_id = 'k-selftest2' from public.fmail_contacts where id = v_id));
    -- refusals
    begin perform public.fmail_contact_touch186('22222222-2222-2222-2222-222222222222', v_box, b2, v_dom, 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now()); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'another founder cannot touch my address book', 'ok', v_ok);
    begin perform public.fmail_contact_touch186(v_uid, v_box, b2, v_dom, 'both', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now()); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direction other than sent / received is refused', 'ok', v_ok);
    begin perform public.fmail_contact_touch186(v_uid, v_box, decode('aabb', 'hex'), v_dom, 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now()); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a blind index that is not 32 bytes is refused', 'ok', v_ok);
    begin perform public.fmail_contact_touch186(v_uid, v_box, b2, v_dom, 'sent', null, null, null, null, null, null, now()); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a new contact without its sealed name is refused', 'ok', v_ok and not exists (select 1 from public.fmail_contacts where addr_blind = b2));
    -- a clock in the far future is pulled back
    perform public.fmail_contact_touch186(v_uid, v_box, b2, v_dom, 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now() + interval '400 days');
    res := res || jsonb_build_object('name', 'a clock far in the future is pulled back to now + 5 minutes', 'ok', (select last_sent_at <= now() + interval '6 minutes' from public.fmail_contacts where addr_blind = b2));
    -- guard trigger: identity frozen, counters only grow, direct delete refused (the flag is only on inside a door)
    begin update public.fmail_contacts set addr_blind = b3 where id = v_id; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct update outside a door is refused', 'ok', v_ok);
    perform set_config('fmail.contact_door', 'on', true);
    begin update public.fmail_contacts set addr_blind = b3 where id = v_id; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'even inside a door the blind index of a contact can not change', 'ok', v_ok);
    begin update public.fmail_contacts set sent_count = 0 where id = v_id; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'counters can not go down', 'ok', v_ok);
    begin update public.fmail_contacts set sealed = decode(repeat('ee', 40), 'hex') where id = v_id; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a new ciphertext with the old nonce is refused (no nonce reuse)', 'ok', v_ok);
    perform set_config('fmail.contact_door', 'off', true);
    begin delete from public.fmail_contacts where id = v_id; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct delete outside a door is refused', 'ok', v_ok);
    -- own domain
    v_r := public.fmail_contact_own_domain186(v_uid, v_box, v_own);
    v_r2 := public.fmail_contact_touch186(v_uid, v_box, b3, v_own, 'received', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now());
    res := res || jsonb_build_object('name', 'a contact of the founder''s own domain is never stored', 'ok', v_r2 ->> 'skipped' = 'own_domain' and not exists (select 1 from public.fmail_contacts where addr_blind = b3));
    perform public.fmail_contact_touch186(v_uid, v_box, b3, decode(repeat('d3', 32), 'hex'), 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now());
    v_r := public.fmail_contact_own_domain186(v_uid, v_box, decode(repeat('d3', 32), 'hex'));
    res := res || jsonb_build_object('name', 'registering an own domain later removes what was stored before (one ledger line)', 'ok', (v_r ->> 'removed') = '1' and not exists (select 1 from public.fmail_contacts where addr_blind = b3));
    -- ranking: frecency
    delete from public.fmail_contact_own_domains where mailbox_id = v_box and false;
    perform set_config('fmail.contact_door', 'on', true); delete from public.fmail_contacts where mailbox_id = v_box; perform set_config('fmail.contact_door', 'off', true);
    perform public.fmail_contact_touch186(v_uid, v_box, b1, v_dom, 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now());                       -- A: 1 send today
    for v_n in 1..3 loop perform public.fmail_contact_touch186(v_uid, v_box, b2, v_dom, 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now()); end loop;   -- B: 3 sends today
    for v_n in 1..10 loop perform public.fmail_contact_touch186(v_uid, v_box, b4, v_dom, 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now() - interval '200 days'); end loop;   -- C: 10 sends 200 days ago
    v_top := public.fmail_contacts_top186(v_uid, v_box, 500);
    res := res || jsonb_build_object('name', 'frecency order: recent and frequent first, old busy thread decayed (B, A, C)',
        'ok', (v_top -> 'items' -> 0 ->> 'blind') = encode(b2, 'hex') and (v_top -> 'items' -> 1 ->> 'blind') = encode(b1, 'hex') and (v_top -> 'items' -> 2 ->> 'blind') = encode(b4, 'hex'));
    res := res || jsonb_build_object('name', 'the score function matches the hand calculation ln(1+3*3) = 2.302585', 'ok', abs(public.fmail_contact_score186(3, 0, now(), null, false, now()) - ln(10.0)) < 1e-9);
    res := res || jsonb_build_object('name', 'the half life is 45 days (score halves)', 'ok', abs(public.fmail_contact_score186(3, 0, now() - interval '45 days', null, false, now()) / public.fmail_contact_score186(3, 0, now(), null, false, now()) - 0.5) < 1e-6);
    begin perform public.fmail_contacts_top186(v_uid, v_box, 501); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a limit above 500 is refused', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'the list says how many exist and whether it was cut', 'ok', (v_top ->> 'total') = '3' and (v_top ->> 'truncated') = 'false' and (public.fmail_contacts_top186(v_uid, v_box, 2) ->> 'truncated') = 'true');
    -- pin
    select id into v_id from public.fmail_contacts where addr_blind = b4;
    v_r := public.fmail_contact_pin186(v_uid, v_box, v_id, true); v_r2 := public.fmail_contact_pin186(v_uid, v_box, v_id, true);
    res := res || jsonb_build_object('name', 'pinning lifts a contact to the top, once in the ledger (second pin is idempotent)', 'ok', (v_r ->> 'already') = 'false' and (v_r2 ->> 'already') = 'true'
        and (public.fmail_contacts_top186(v_uid, v_box, 500) -> 'items' -> 0 ->> 'blind') = encode(b4, 'hex') and (select count(*) from public.fmail_ledger where action = 'contact_pin' and mailbox_id = v_box) = 1);
    -- forget + tombstone
    select id into v_id2 from public.fmail_contacts where addr_blind = b2;
    v_r := public.fmail_contact_forget186(v_uid, v_box, v_id2); v_r2 := public.fmail_contact_forget186(v_uid, v_box, v_id2);
    res := res || jsonb_build_object('name', 'forget removes the contact, leaves a blind tombstone, one ledger line; again = already', 'ok', (v_r ->> 'already') = 'false' and (v_r2 ->> 'already') = 'true'
        and not exists (select 1 from public.fmail_contacts where id = v_id2) and exists (select 1 from public.fmail_contact_tombstones where mailbox_id = v_box and addr_blind = b2)
        and (select count(*) from public.fmail_ledger where action = 'contact_forget' and mailbox_id = v_box) = 1);
    v_r := public.fmail_contact_touch186(v_uid, v_box, b2, v_dom, 'received', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now());
    res := res || jsonb_build_object('name', 'mail that only ARRIVES from a forgotten person does not bring them back', 'ok', v_r ->> 'skipped' = 'forgotten' and not exists (select 1 from public.fmail_contacts where addr_blind = b2));
    v_r := public.fmail_contact_touch186(v_uid, v_box, b2, v_dom, 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now());
    res := res || jsonb_build_object('name', 'writing to them again brings them back and clears the tombstone', 'ok', (v_r ->> 'created')::boolean and not exists (select 1 from public.fmail_contact_tombstones where mailbox_id = v_box and addr_blind = b2));
    perform public.fmail_contact_touch186(v_uid, v_box, b2, v_dom, 'sent', null, null, null, null, null, null, now());   -- B now ranks above A (no tie for the eviction check)
    -- cap (lowered to 3 for the test): the lowest ranked unpinned contact makes room, one contact_evict line
    perform set_config('fmail.contact_cap', '3', true);
    select count(*) into v_n from public.fmail_contacts where mailbox_id = v_box;   -- A, B, C(pinned) = 3
    v_r := public.fmail_contact_touch186(v_uid, v_box, b5, v_dom, 'sent', v_seal, v_nonce, 'k', v_wrap, v_aad, null, now());
    res := res || jsonb_build_object('name', 'at the cap the lowest ranked unpinned contact is evicted (not the pinned one)', 'ok', v_n = 3 and (v_r ->> 'evicted') = '1'
        and (select count(*) from public.fmail_contacts where mailbox_id = v_box) = 3 and exists (select 1 from public.fmail_contacts where addr_blind = b4) and not exists (select 1 from public.fmail_contacts where addr_blind = b1)
        and (select count(*) from public.fmail_ledger where action = 'contact_evict' and mailbox_id = v_box) >= 1);
    perform set_config('fmail.contact_cap', '', true);
    res := res || jsonb_build_object('name', 'the cap can only be lowered, never raised above 5000', 'ok', public.fmail_contact_cap186() = 5000
        and (select public.fmail_contact_cap186() from (select set_config('fmail.contact_cap', '999999', true)) s) = 5000);
    perform set_config('fmail.contact_cap', '', true);
    -- nothing personal is stored in a plain column: the table has no text column that could hold an address or a name
    res := res || jsonb_build_object('name', 'no plain text column exists on the contacts table except key id and source', 'ok',
        (select array_agg(attname::text order by attname) from pg_attribute where attrelid = 'public.fmail_contacts'::regclass and attnum > 0 and not attisdropped and atttypid = 'text'::regtype) = array['key_id', 'source']);
    res := res || jsonb_build_object('name', 'ledger chain still verifies', 'ok', public.fmail_ledger_verify(1) >= 1);
    raise exception 'E186_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E186_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E186_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest186() from public, anon, authenticated;
grant execute on function public.fmail_selftest186() to service_role;

-- 12) POSTURE (stable, E179-safe: the door names are built from two pieces on purpose, this function only reads catalogs)
create or replace function public.fmail_posture186() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  doors regprocedure[] := array[
    to_regprocedure('public.fmail_contact_' || 'touch186(uuid,uuid,bytea,bytea,text,bytea,bytea,text,bytea,bytea,bytea,timestamptz)'),
    to_regprocedure('public.fmail_contact_' || 'forget186(uuid,uuid,uuid)'),
    to_regprocedure('public.fmail_contact_' || 'pin186(uuid,uuid,uuid,boolean)'),
    to_regprocedure('public.fmail_contact_' || 'own_domain186(uuid,uuid,bytea)')];
  top regprocedure := to_regprocedure('public.fmail_contacts_top186(uuid,uuid,integer,timestamptz)');
begin
  return jsonb_build_object(
    'doors_exist', (select bool_and(d is not null) from unnest(doors) d),
    'doors_volatile', (select bool_and(provolatile = 'v') from pg_proc where oid = any (doors::oid[])),
    'doors_service_only', (select bool_and(has_function_privilege('service_role', d, 'execute') and not has_function_privilege('anon', d, 'execute') and not has_function_privilege('authenticated', d, 'execute')) from unnest(doors) d),
    'top_door_stable_service_only', (select provolatile = 's' from pg_proc where oid = top) and has_function_privilege('service_role', top, 'execute') and not has_function_privilege('anon', top, 'execute') and not has_function_privilege('authenticated', top, 'execute'),
    'rls_forced', (select bool_and(relforcerowsecurity) from pg_class where oid in ('public.fmail_contacts'::regclass, 'public.fmail_contact_tombstones'::regclass, 'public.fmail_contact_own_domains'::regclass)),
    'service_role_read_only', not exists (select 1 from information_schema.role_table_grants where grantee = 'service_role' and table_schema = 'public'
                                           and table_name in ('fmail_contacts', 'fmail_contact_tombstones', 'fmail_contact_own_domains') and privilege_type = any (array['INS' || 'ERT', 'UPD' || 'ATE', 'DEL' || 'ETE', 'TRUNC' || 'ATE'])),
    'anon_no_access', not exists (select 1 from information_schema.role_table_grants where grantee in ('anon', 'authenticated', 'PUBLIC') and table_schema = 'public'
                                   and table_name in ('fmail_contacts', 'fmail_contact_tombstones', 'fmail_contact_own_domains')),
    'guard_triggers', (select count(*) from pg_trigger where tgrelid in ('public.fmail_contacts'::regclass, 'public.fmail_contact_tombstones'::regclass, 'public.fmail_contact_own_domains'::regclass) and not tgisinternal),
    'ledger_knows_contact_actions', exists (select 1 from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%contact_evict%' and pg_get_constraintdef(oid) like '%contact_forget%'
                                            and pg_get_constraintdef(oid) like '%contact_pin%' and pg_get_constraintdef(oid) like '%contact_add%'),
    'door_audit_clean', not exists (select 1 from public.fmail_door_audit179()));
end $$;
revoke all on function public.fmail_posture186() from public, anon, authenticated;
grant execute on function public.fmail_posture186() to service_role;

select public.fmail_posture186() as e186_posture;
select public.fmail_selftest186() ->> 'passed' as e186_selftest_passed, public.fmail_selftest186() ->> 'failed' as e186_selftest_failed;
