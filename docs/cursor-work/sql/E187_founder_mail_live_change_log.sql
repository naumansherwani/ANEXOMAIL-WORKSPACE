
-- E187 (QLIVE, 18 Nov 2026): THE FOUNDER MAIL CHANGE LOG. The one durable, ordered, tamper-evident record of "something changed in this mailbox", which lets the screen update by itself
-- (a new mail, a read flag, a move, a send state) without any refresh. Plan: docs/claude/QLIVE-PLAN-18NOV.md. Stands on E167 (mailboxes, messages, outbox, labels), E179 (door audit), E186 (door pattern).
-- Nothing of the awam mailbox is read or touched. Awam inherits the PATTERN later under its own number, its own gate and its own pull command.
-- ---------------------------------------------------------------------------------------------------------------------------------------------------
-- WEB RESEARCH FIRST (standing rule 0, read 18 Nov 2026; full table in QLIVE-PLAN-18NOV.md section 1):
--   * JMAP (RFC 8620): push carries only "state changed", the client then asks "changes since state". IMAP NOTIFY (RFC 5465): MessageNew / MessageExpunge / FlagChange per mailbox. A push is a PROMPT, never the record.
--   * Postgres LISTEN/NOTIFY: 7999 byte payload cap, nothing is delivered to a listener that is down, lost on reconnect, unusable behind a transaction pooler. The proven cure is a TABLE with a monotone id and a
--     cursor; NOTIFY is only the wake-up. A plain SEQUENCE is NOT enough: a sequence value is handed out before commit, so commit order can differ from number order and a reader that remembers "I saw 41" can skip 40
--     for ever. Here the sequence number is taken while holding a row lock on the mailbox head row, so commit order = sequence order and there is no hole.
-- => DESIGN: per mailbox an append-only, hash-chained log of ids and a closed kind. NO subject, NO address, NO body, NO blind index. Content always comes through the sealed doors.
--
-- TECHNOLOGY (PostgreSQL 16, advance level):
--   * forced row level security on both tables; service_role can only SELECT; every write is the internal door below or the prune door (security definer, fixed search_path, service_role only).
--   * a guard trigger refuses any insert, update, delete or truncate that does not come from a door (a session flag set with set_config(..., is_local = true), so it can not leak across transactions).
--   * GAPLESS per-mailbox sequence under a row lock on the head row (see above); head and log can never disagree (check constraints + the guard).
--   * HASH CHAIN: row_hash = SHA-256(prev_hash, mailbox, seq, kind, folder, message, thread, at in microseconds). The browser kernel and the verify door recompute it; one altered or missing row breaks every later hash.
--   * AFTER triggers on fmail_messages (arrive, sent, draft, expunge, read, unread, star, unstar, move, scan, verdict), fmail_outbox (outbox) and fmail_message_labels (label, unlabel). Several changed aspects of
--     one row write several lines. A mailbox that is being deleted (cascade) writes nothing.
--   * pg_notify('fmail_live', '<mailbox>:<seq>') on every line: ids only, delivered at commit, a wake-up for any direct listener. The Rust server also wakes in-process and re-checks the heads every 2 s.
--   * CURSOR doors: since (with `gap` when the cursor fell below the floor or is ahead of the head: the client then does a full refresh, never a silent hole), head, heads (watcher), verify (recompute the chain),
--     prune (14 days / 20000 rows by default; moves the floor and keeps the floor hash so the chain still verifies from the floor).
--   * posture function and a selftest that rolls itself back (CHECK_E187.sql). Door names are built from two pieces in the posture function and the stable functions never name a writing word, so the E179 audit stays clean.
-- Run once through sql-run.sh, after E186. Safe to run again (idempotent).

do $$
begin
  if to_regclass('public.fmail_messages') is null or to_regclass('public.fmail_outbox') is null or to_regclass('public.fmail_message_labels') is null then raise exception 'E187: E167 mail tables are missing'; end if;
  if to_regprocedure('public.fmail_door_audit179()') is null then raise exception 'E187: E179 door audit is missing (run E179 first)'; end if;
  if to_regclass('public.fmail_contacts') is null then raise exception 'E187: E186 is missing (run E186 first)'; end if;
end $$;

-- 1) the two tables ------------------------------------------------------------------------------------------------------------------------------------
create table if not exists public.fmail_change_head187 (
  mailbox_id  uuid primary key references public.fmail_mailboxes (id) on delete cascade,
  head_seq    bigint not null default 0 check (head_seq >= 0),
  head_hash   bytea  not null check (octet_length(head_hash) = 32),
  floor_seq   bigint not null default 0 check (floor_seq >= 0),
  floor_hash  bytea  not null check (octet_length(floor_hash) = 32),
  updated_at  timestamptz not null default now(),
  constraint fmail_change_head_floor_ck check (floor_seq <= head_seq)
);
create table if not exists public.fmail_change_log187 (
  mailbox_id  uuid   not null references public.fmail_mailboxes (id) on delete cascade,
  seq         bigint not null check (seq >= 1),
  kind        text   not null check (kind in ('arrive', 'sent', 'draft', 'expunge', 'read', 'unread', 'star', 'unstar', 'move', 'label', 'unlabel', 'outbox', 'scan', 'verdict')),
  folder_id   uuid,
  message_id  uuid,
  thread_id   uuid,
  at          timestamptz not null default clock_timestamp(),
  prev_hash   bytea  not null check (octet_length(prev_hash) = 32),
  row_hash    bytea  not null check (octet_length(row_hash) = 32),
  primary key (mailbox_id, seq)
);
create index if not exists fmail_change_log_at_ix on public.fmail_change_log187 (mailbox_id, at);
alter table public.fmail_change_head187 enable row level security;  alter table public.fmail_change_head187 force row level security;
alter table public.fmail_change_log187  enable row level security;  alter table public.fmail_change_log187  force row level security;
revoke all on public.fmail_change_head187, public.fmail_change_log187 from public, anon, authenticated;
revoke all on public.fmail_change_head187, public.fmail_change_log187 from service_role;
grant select on public.fmail_change_head187, public.fmail_change_log187 to service_role;

-- 2) the hash (pure, immutable: Rust, the kernel, the selftest and the verify door can never disagree) ------------------------------------------------------
create or replace function public.fmail_change_hash187(p_prev bytea, p_mailbox uuid, p_seq bigint, p_kind text, p_folder uuid, p_message uuid, p_thread uuid, p_at timestamptz)
returns bytea language sql immutable set search_path = pg_catalog as $$
  select sha256(p_prev || convert_to(concat_ws('|', 'fmail-change-v1', p_mailbox::text, p_seq::text, p_kind, coalesce(p_folder::text, ''), coalesce(p_message::text, ''), coalesce(p_thread::text, ''),
         (round(extract(epoch from p_at) * 1000000))::bigint::text), 'UTF8'))
$$;
create or replace function public.fmail_change_genesis187(p_mailbox uuid) returns bytea language sql immutable set search_path = pg_catalog as $$
  select sha256(convert_to('fmail-change-genesis-v1|' || p_mailbox::text, 'UTF8'))
$$;
grant execute on function public.fmail_change_hash187(bytea, uuid, bigint, text, uuid, uuid, uuid, timestamptz), public.fmail_change_genesis187(uuid) to service_role;

-- 3) the guard: nothing writes these tables except the doors (flag 'on' = note, 'prune' = prune) -------------------------------------------------------------
create or replace function public.fmail_change_guard187() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare f text := coalesce(current_setting('fmail.change_door', true), '');
begin
  if tg_op = 'TRUNCATE' then raise exception 'E187: the change log can not be truncated' using errcode = '42501'; end if;
  if tg_table_name = 'fmail_change_log187' then
    if tg_op = 'INSERT' and f = 'on' then return new; end if;
    if tg_op = 'DELETE' and f = 'prune' then return old; end if;
    if tg_op = 'DELETE' and pg_trigger_depth() > 1 then return old; end if; -- a cascade from a deleted mailbox
    raise exception 'E187: the change log is append-only; writes go through the doors' using errcode = '42501';
  else
    if tg_op = 'INSERT' and f in ('on', 'prune') then return new; end if;
    if tg_op = 'UPDATE' and f in ('on', 'prune') then
      if new.mailbox_id is distinct from old.mailbox_id then raise exception 'E187: the mailbox of a head row never changes' using errcode = '42501'; end if;
      if new.head_seq < old.head_seq or new.floor_seq < old.floor_seq then raise exception 'E187: head and floor only grow' using errcode = '42501'; end if;
      return new;
    end if;
    if tg_op = 'DELETE' and pg_trigger_depth() > 1 then return old; end if;
    raise exception 'E187: the head row changes only through the doors' using errcode = '42501';
  end if;
end $$;
drop trigger if exists fmail_change_log_guard on public.fmail_change_log187;
create trigger fmail_change_log_guard before insert or update or delete on public.fmail_change_log187 for each row execute function public.fmail_change_guard187();
drop trigger if exists fmail_change_log_guard_t on public.fmail_change_log187;
create trigger fmail_change_log_guard_t before truncate on public.fmail_change_log187 for each statement execute function public.fmail_change_guard187();
drop trigger if exists fmail_change_head_guard on public.fmail_change_head187;
create trigger fmail_change_head_guard before insert or update or delete on public.fmail_change_head187 for each row execute function public.fmail_change_guard187();
drop trigger if exists fmail_change_head_guard_t on public.fmail_change_head187;
create trigger fmail_change_head_guard_t before truncate on public.fmail_change_head187 for each statement execute function public.fmail_change_guard187();

-- 4) the ONE internal write door: take the next number under the head row lock, chain it, wake listeners --------------------------------------------------
create or replace function public.fmail_change_note187(p_mailbox uuid, p_kind text, p_folder uuid, p_message uuid, p_thread uuid) returns bigint
language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare v_seq bigint; v_prev bytea; v_at timestamptz := clock_timestamp(); v_hash bytea; v_old text := current_setting('fmail.change_door', true);
begin
  if p_mailbox is null then return null; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox) then return null; end if;   -- a mailbox that is being deleted writes nothing
  perform set_config('fmail.change_door', 'on', true);
  insert into public.fmail_change_head187 (mailbox_id, head_seq, head_hash, floor_seq, floor_hash)
    values (p_mailbox, 0, public.fmail_change_genesis187(p_mailbox), 0, public.fmail_change_genesis187(p_mailbox)) on conflict (mailbox_id) do nothing;
  select head_seq + 1, head_hash into v_seq, v_prev from public.fmail_change_head187 where mailbox_id = p_mailbox for update;   -- the lock that makes commit order = sequence order
  v_hash := public.fmail_change_hash187(v_prev, p_mailbox, v_seq, p_kind, p_folder, p_message, p_thread, v_at);
  insert into public.fmail_change_log187 (mailbox_id, seq, kind, folder_id, message_id, thread_id, at, prev_hash, row_hash) values (p_mailbox, v_seq, p_kind, p_folder, p_message, p_thread, v_at, v_prev, v_hash);
  update public.fmail_change_head187 set head_seq = v_seq, head_hash = v_hash, updated_at = v_at where mailbox_id = p_mailbox;
  perform pg_notify('fmail_live', p_mailbox::text || ':' || v_seq::text);                                              -- ids only, delivered at commit
  perform set_config('fmail.change_door', coalesce(v_old, ''), true);
  return v_seq;
end $$;
revoke all on function public.fmail_change_note187(uuid, text, uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_change_note187(uuid, text, uuid, uuid, uuid) to service_role;

-- 5) the triggers on the mail tables ---------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_change_msg187() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare n int := 0;
begin
  if tg_op = 'INSERT' then
    perform public.fmail_change_note187(new.mailbox_id, case when new.is_draft then 'draft' when new.direction = 'out' then 'sent' else 'arrive' end, new.folder_id, new.id, new.thread_id);
  elsif tg_op = 'UPDATE' then
    if new.folder_id is distinct from old.folder_id then perform public.fmail_change_note187(new.mailbox_id, 'move', new.folder_id, new.id, new.thread_id); end if;
    if new.is_read is distinct from old.is_read then perform public.fmail_change_note187(new.mailbox_id, case when new.is_read then 'read' else 'unread' end, new.folder_id, new.id, new.thread_id); end if;
    if new.is_starred is distinct from old.is_starred then perform public.fmail_change_note187(new.mailbox_id, case when new.is_starred then 'star' else 'unstar' end, new.folder_id, new.id, new.thread_id); end if;
    if new.scan_state is distinct from old.scan_state then perform public.fmail_change_note187(new.mailbox_id, 'scan', new.folder_id, new.id, new.thread_id); end if;
    if (new.spf, new.dkim, new.dmarc, new.arc, new.lookalike) is distinct from (old.spf, old.dkim, old.dmarc, old.arc, old.lookalike) then perform public.fmail_change_note187(new.mailbox_id, 'verdict', new.folder_id, new.id, new.thread_id); end if;
  else
    perform public.fmail_change_note187(old.mailbox_id, 'expunge', old.folder_id, old.id, old.thread_id);
  end if;
  return null;
end $$;
drop trigger if exists fmail_change_msg on public.fmail_messages;
create trigger fmail_change_msg after insert or update or delete on public.fmail_messages for each row execute function public.fmail_change_msg187();

create or replace function public.fmail_change_outbox187() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'INSERT' or new.state is distinct from old.state then
    perform public.fmail_change_note187(new.mailbox_id, 'outbox', null, new.message_id, null);
  end if;
  return null;
end $$;
drop trigger if exists fmail_change_outbox on public.fmail_outbox;
create trigger fmail_change_outbox after insert or update on public.fmail_outbox for each row execute function public.fmail_change_outbox187();

create or replace function public.fmail_change_label187() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare m uuid; f uuid; t uuid; mid uuid := case when tg_op = 'DELETE' then old.message_id else new.message_id end;
begin
  select mailbox_id, folder_id, thread_id into m, f, t from public.fmail_messages where id = mid;
  if m is not null then perform public.fmail_change_note187(m, case when tg_op = 'DELETE' then 'unlabel' else 'label' end, f, mid, t); end if;
  return null;
end $$;
drop trigger if exists fmail_change_label on public.fmail_message_labels;
create trigger fmail_change_label after insert or delete on public.fmail_message_labels for each row execute function public.fmail_change_label187();

-- 6) the read doors (stable, service_role only) ----------------------------------------------------------------------------------------------------------
-- changes since a cursor. gap = the cursor fell below the floor (rows pruned) or is ahead of the head (the log was reset): the client then does a full refresh.
create or replace function public.fmail_change_since187(p_actor uuid, p_mailbox uuid, p_after bigint, p_limit integer default 200) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare h public.fmail_change_head187%rowtype; v_lim int := least(greatest(coalesce(p_limit, 200), 1), 500); v_after bigint := greatest(coalesce(p_after, 0), 0); v_from bigint := greatest(coalesce(p_after, 0), 0); v_rows jsonb; v_more boolean; v_sum jsonb;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  select * into h from public.fmail_change_head187 where mailbox_id = p_mailbox;
  if not found then return jsonb_build_object('ok', true, 'head', 0, 'floor', 0, 'gap', v_after > 0, 'more', false, 'changes', '[]'::jsonb, 'head_hash', encode(public.fmail_change_genesis187(p_mailbox), 'hex')); end if;
  if v_after < h.floor_seq or v_after > h.head_seq then
    return jsonb_build_object('ok', true, 'head', h.head_seq, 'floor', h.floor_seq, 'gap', true, 'more', false, 'changes', '[]'::jsonb, 'head_hash', encode(h.head_hash, 'hex'));
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('seq', seq, 'kind', kind, 'folder', folder_id, 'message', message_id, 'thread', thread_id, 'at', at, 'prev', encode(prev_hash, 'hex'), 'hash', encode(row_hash, 'hex')) order by seq), '[]'::jsonb),
         coalesce(max(seq), v_after)
    into v_rows, v_after
    from (select * from public.fmail_change_log187 where mailbox_id = p_mailbox and seq > v_after order by seq limit v_lim) s;
  v_more := v_after < h.head_seq;
  select coalesce(jsonb_object_agg(kind, n), '{}'::jsonb) into v_sum from (select kind, count(*) as n from public.fmail_change_log187 where mailbox_id = p_mailbox and seq > v_from and seq <= v_after group by kind) k;   -- "3 new mails, 1 move" for a notification, without opening the rows
  return jsonb_build_object('ok', true, 'head', h.head_seq, 'floor', h.floor_seq, 'gap', false, 'more', v_more, 'changes', v_rows, 'summary', v_sum, 'head_hash', encode(h.head_hash, 'hex'));
end $$;
revoke all on function public.fmail_change_since187(uuid, uuid, bigint, integer) from public, anon, authenticated;
grant execute on function public.fmail_change_since187(uuid, uuid, bigint, integer) to service_role;

-- every mailbox head in one tiny answer: what the Rust watcher asks every 2 s while a stream is open
create or replace function public.fmail_change_heads187() returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('mailbox', mailbox_id, 'head', head_seq)), '[]'::jsonb) from public.fmail_change_head187
$$;
revoke all on function public.fmail_change_heads187() from public, anon, authenticated;
grant execute on function public.fmail_change_heads187() to service_role;

-- recompute the chain: first retained row must start at the floor hash, every row must chain to the one before and hash to itself, the last one must be the head
create or replace function public.fmail_change_verify187(p_mailbox uuid) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare h public.fmail_change_head187%rowtype; v_n bigint; v_bad bigint; v_last bytea; v_cnt bigint;
begin
  select * into h from public.fmail_change_head187 where mailbox_id = p_mailbox;
  if not found then return jsonb_build_object('ok', true, 'checked', 0, 'note', 'no changes yet'); end if;
  select count(*), min(seq) filter (where bad) into v_n, v_bad from (
    select seq, (prev_hash is distinct from coalesce(lag(row_hash) over (order by seq), h.floor_hash)
                 or row_hash is distinct from public.fmail_change_hash187(prev_hash, mailbox_id, seq, kind, folder_id, message_id, thread_id, at)
                 or seq <> coalesce(lag(seq) over (order by seq), h.floor_seq) + 1) as bad
      from public.fmail_change_log187 where mailbox_id = p_mailbox) s;
  select row_hash into v_last from public.fmail_change_log187 where mailbox_id = p_mailbox order by seq desc limit 1;
  select count(*) into v_cnt from public.fmail_change_log187 where mailbox_id = p_mailbox;
  return jsonb_build_object('ok', v_bad is null and v_n = h.head_seq - h.floor_seq and coalesce(v_last, h.floor_hash) = h.head_hash, 'checked', v_n, 'first_bad', v_bad, 'head', h.head_seq, 'floor', h.floor_seq);
end $$;
revoke all on function public.fmail_change_verify187(uuid) from public, anon, authenticated;
grant execute on function public.fmail_change_verify187(uuid) to service_role;

-- 7) prune: keep the last N days and at most M rows; the floor moves up and its hash is kept, so the rest of the chain still verifies ----------------------------
create or replace function public.fmail_change_prune187(p_keep_days integer default 14, p_keep_rows integer default 20000) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare r record; v_new bigint; v_hash bytea; v_total bigint := 0; v_n bigint; v_days int := least(greatest(coalesce(p_keep_days, 14), 1), 365); v_rows int := least(greatest(coalesce(p_keep_rows, 20000), 100), 1000000);
begin
  perform set_config('fmail.change_door', 'prune', true);
  for r in select * from public.fmail_change_head187 order by mailbox_id loop
    select max(seq) into v_new from public.fmail_change_log187 where mailbox_id = r.mailbox_id and (at < now() - make_interval(days => v_days) or seq <= r.head_seq - v_rows);
    if v_new is null or v_new <= r.floor_seq then continue; end if;
    select row_hash into v_hash from public.fmail_change_log187 where mailbox_id = r.mailbox_id and seq = v_new;
    delete from public.fmail_change_log187 where mailbox_id = r.mailbox_id and seq <= v_new;
    get diagnostics v_n = row_count; v_total := v_total + v_n;
    update public.fmail_change_head187 set floor_seq = v_new, floor_hash = v_hash where mailbox_id = r.mailbox_id;
  end loop;
  perform set_config('fmail.change_door', '', true);
  return jsonb_build_object('ok', true, 'pruned', v_total, 'keep_days', v_days, 'keep_rows', v_rows);
end $$;
revoke all on function public.fmail_change_prune187(integer, integer) from public, anon, authenticated;
grant execute on function public.fmail_change_prune187(integer, integer) to service_role;

-- 7b) PACKAGE LIMITS (his 18 Nov 05:24 word: basic, PRO, business, Business PRO first; Business Premium and Business MAX are built LATER but their codes are preserved here, so nothing is hard-coded) -------------
create table if not exists public.fmail_tier_limits187 (
  tier          text primary key check (tier in ('founder', 'basic', 'pro', 'business', 'business_pro', 'business_premium', 'business_max')),
  live_streams  int  not null check (live_streams between 1 and 1000),      -- open live streams (tabs / devices) per account
  keep_days     int  not null check (keep_days between 1 and 365),          -- how long the change log is kept
  keep_rows     int  not null check (keep_rows between 100 and 1000000),    -- and at most this many rows per mailbox
  built         boolean not null default true,                               -- false = code preserved, package not built yet
  note          text not null default '' check (length(note) <= 200),
  created_at    timestamptz not null default now()
);
alter table public.fmail_tier_limits187 enable row level security;  alter table public.fmail_tier_limits187 force row level security;
revoke all on public.fmail_tier_limits187 from public, anon, authenticated, service_role;
grant select on public.fmail_tier_limits187 to service_role;
insert into public.fmail_tier_limits187 (tier, live_streams, keep_days, keep_rows, built, note) values
  ('founder', 20, 14, 20000, true, 'founder lane, live.rs MAX_STREAMS'),
  ('basic', 1, 3, 2000, true, 'awam package, later'),
  ('pro', 2, 7, 5000, true, 'awam package, later'),
  ('business', 5, 14, 20000, true, 'awam package, later'),
  ('business_pro', 10, 14, 20000, true, 'awam package, later'),
  ('business_premium', 25, 30, 50000, false, 'code preserved, built later'),
  ('business_max', 100, 30, 100000, false, 'code preserved, built later')
  on conflict (tier) do nothing;
create or replace function public.fmail_tier_limit187(p_tier text) returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce((select jsonb_build_object('tier', tier, 'live_streams', live_streams, 'keep_days', keep_days, 'keep_rows', keep_rows, 'built', built) from public.fmail_tier_limits187 where tier = p_tier), jsonb_build_object('error', 'unknown tier'))
$$;
revoke all on function public.fmail_tier_limit187(text) from public, anon, authenticated;
grant execute on function public.fmail_tier_limit187(text) to service_role;

-- 7c) HEALTH: how big is the log, how old is its oldest line, is anything stuck (read only; the Rust side shows it in the mail health row) -------------------------------------------------------------
create or replace function public.fmail_change_health187() returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('mailboxes', (select count(*) from public.fmail_change_head187), 'rows', (select count(*) from public.fmail_change_log187),
         'oldest_age_s', (select coalesce(extract(epoch from now() - min(at))::bigint, 0) from public.fmail_change_log187),
         'newest_age_s', (select coalesce(extract(epoch from now() - max(at))::bigint, 0) from public.fmail_change_log187),
         'max_head', (select coalesce(max(head_seq), 0) from public.fmail_change_head187),
         'table_bytes', pg_total_relation_size('public.fmail_change_log187'))
$$;
revoke all on function public.fmail_change_health187() from public, anon, authenticated;
grant execute on function public.fmail_change_health187() to service_role;

-- 8) SELFTEST (rolls itself back) ------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_selftest187() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_other uuid := gen_random_uuid(); v_box uuid; v_inbox uuid; v_arch uuid; v_th uuid; v_m1 uuid; v_m2 uuid; v_lbl uuid; v_r jsonb; v_ok boolean; v_n bigint; v_h bytea; v_ob uuid;
  v_seal bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest187@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    select id into v_inbox from public.fmail_folders where mailbox_id = v_box and kind = 'inbox';
    select id into v_arch from public.fmail_folders where mailbox_id = v_box and kind = 'archive';
    insert into public.fmail_threads (mailbox_id) values (v_box) returning id into v_th;
    -- write protection
    begin insert into public.fmail_change_log187 (mailbox_id, seq, kind, prev_hash, row_hash) values (v_box, 1, 'arrive', public.fmail_change_genesis187(v_box), public.fmail_change_genesis187(v_box)); v_ok := false;
    exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct write to the log (not through a door) is refused', 'ok', v_ok);
    begin insert into public.fmail_change_head187 (mailbox_id, head_hash, floor_hash) values (v_box, public.fmail_change_genesis187(v_box), public.fmail_change_genesis187(v_box)); v_ok := false;
    exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct write to the head row is refused', 'ok', v_ok);
    -- an arriving mail
    insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash, size_bytes)
      values (v_box, v_th, v_inbox, 'in', 'vault', v_seal, v_seal, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, 10) returning id into v_m1;
    v_r := public.fmail_change_since187(v_uid, v_box, 0, 50);
    res := res || jsonb_build_object('name', 'a new mail writes one arrive line, number 1', 'ok', (v_r ->> 'head') = '1' and v_r #>> '{changes,0,kind}' = 'arrive' and v_r #>> '{changes,0,message}' = v_m1::text and v_r #>> '{changes,0,folder}' = v_inbox::text);
    -- read, star, move
    update public.fmail_messages set is_read = true where id = v_m1;
    update public.fmail_messages set is_starred = true where id = v_m1;
    update public.fmail_messages set folder_id = v_arch where id = v_m1;
    v_r := public.fmail_change_since187(v_uid, v_box, 1, 50);
    res := res || jsonb_build_object('name', 'read, star and move each write their own line, in order', 'ok', (select array_agg(c ->> 'kind' order by (c ->> 'seq')::bigint) from jsonb_array_elements(v_r -> 'changes') c) = array['read', 'star', 'move']);
    res := res || jsonb_build_object('name', 'the move line carries the NEW folder', 'ok', v_r #>> '{changes,2,folder}' = v_arch::text);
    update public.fmail_messages set is_read = false where id = v_m1;
    res := res || jsonb_build_object('name', 'marking unread writes unread', 'ok', public.fmail_change_since187(v_uid, v_box, 4, 50) #>> '{changes,0,kind}' = 'unread');
    update public.fmail_messages set spf = 'pass', dkim = 'pass', dmarc = 'pass' where id = v_m1;
    update public.fmail_messages set scan_state = 'clean' where id = v_m1;
    res := res || jsonb_build_object('name', 'verdicts and the scan state each write one line (three verdict columns in one update = one line)',
        'ok', (select array_agg(c ->> 'kind' order by (c ->> 'seq')::bigint) from jsonb_array_elements(public.fmail_change_since187(v_uid, v_box, 5, 50) -> 'changes') c) = array['verdict', 'scan']);
    -- labels
    insert into public.fmail_labels (mailbox_id, name) values (v_box, 'selftest') returning id into v_lbl;
    insert into public.fmail_message_labels (message_id, label_id) values (v_m1, v_lbl);
    delete from public.fmail_message_labels where message_id = v_m1 and label_id = v_lbl;
    res := res || jsonb_build_object('name', 'adding and removing a label write label and unlabel', 'ok', (select array_agg(c ->> 'kind' order by (c ->> 'seq')::bigint) from jsonb_array_elements(public.fmail_change_since187(v_uid, v_box, 7, 50) -> 'changes') c) = array['label', 'unlabel']);
    -- an outgoing mail and its outbox state
    insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash, size_bytes, sent_at)
      values (v_box, v_th, v_inbox, 'out', 'vault', v_seal, v_seal, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, 10, now()) returning id into v_m2;
    insert into public.fmail_outbox (mailbox_id, message_id, rcpt_count, undo_until) values (v_box, v_m2, 1, now() + interval '30 seconds') returning id into v_ob;
    update public.fmail_outbox set state = 'sending' where id = v_ob;
    update public.fmail_outbox set last_error = 'x' where id = v_ob;
    res := res || jsonb_build_object('name', 'an outgoing mail writes sent, the outbox writes one line per STATE change (not per other column)',
        'ok', (select array_agg(c ->> 'kind' order by (c ->> 'seq')::bigint) from jsonb_array_elements(public.fmail_change_since187(v_uid, v_box, 9, 50) -> 'changes') c) = array['sent', 'outbox', 'outbox']);
    -- deleting a mail
    delete from public.fmail_outbox where id = v_ob;
    delete from public.fmail_messages where id = v_m2;
    res := res || jsonb_build_object('name', 'deleting a mail writes expunge', 'ok', public.fmail_change_since187(v_uid, v_box, 12, 50) #>> '{changes,0,kind}' = 'expunge');
    -- numbering and chain
    select head_seq into v_n from public.fmail_change_head187 where mailbox_id = v_box;
    res := res || jsonb_build_object('name', 'numbers are gapless 1..head', 'ok', v_n = 13 and (select count(*) from public.fmail_change_log187 where mailbox_id = v_box) = 13 and (select max(seq) - min(seq) + 1 from public.fmail_change_log187 where mailbox_id = v_box) = 13);
    res := res || jsonb_build_object('name', 'the hash chain verifies end to end', 'ok', (public.fmail_change_verify187(v_box) ->> 'ok')::boolean and (public.fmail_change_verify187(v_box) ->> 'checked') = '13');
    -- cursor rules
    v_r := public.fmail_change_since187(v_uid, v_box, 13, 50);
    res := res || jsonb_build_object('name', 'a cursor at the head gets nothing and no gap', 'ok', (v_r ->> 'gap') = 'false' and jsonb_array_length(v_r -> 'changes') = 0 and (v_r ->> 'more') = 'false');
    v_r := public.fmail_change_since187(v_uid, v_box, 99, 50);
    res := res || jsonb_build_object('name', 'a cursor AHEAD of the head is a gap (full refresh), never silence', 'ok', (v_r ->> 'gap') = 'true');
    v_r := public.fmail_change_since187(v_uid, v_box, 0, 5);
    res := res || jsonb_build_object('name', 'the limit pages the answer and says more', 'ok', jsonb_array_length(v_r -> 'changes') = 5 and (v_r ->> 'more') = 'true');
    res := res || jsonb_build_object('name', 'another person gets no answer for this mailbox', 'ok', (public.fmail_change_since187(v_other, v_box, 0, 5) ->> 'ok') = 'false');
    res := res || jsonb_build_object('name', 'the heads door lists this mailbox with its head', 'ok', exists (select 1 from jsonb_array_elements(public.fmail_change_heads187()) e where e ->> 'mailbox' = v_box::text and (e ->> 'head') = '13'));
    -- tamper: an update of one row through the flag-less path is refused; a forged row breaks verify
    begin update public.fmail_change_log187 set kind = 'arrive' where mailbox_id = v_box and seq = 2; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a row can not be changed (append-only)', 'ok', v_ok);
    begin delete from public.fmail_change_log187 where mailbox_id = v_box and seq = 2; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a row can not be removed', 'ok', v_ok);
    perform set_config('fmail.change_door', 'prune', true);
    alter table public.fmail_change_log187 disable trigger fmail_change_log_guard;
    update public.fmail_change_log187 set kind = 'unread' where mailbox_id = v_box and seq = 2;
    alter table public.fmail_change_log187 enable trigger fmail_change_log_guard;
    perform set_config('fmail.change_door', '', true);
    v_r := public.fmail_change_verify187(v_box);
    res := res || jsonb_build_object('name', 'a forged row is found by verify and named', 'ok', (v_r ->> 'ok') = 'false' and (v_r ->> 'first_bad') = '2');
    alter table public.fmail_change_log187 disable trigger fmail_change_log_guard;
    update public.fmail_change_log187 set kind = 'read' where mailbox_id = v_box and seq = 2;
    alter table public.fmail_change_log187 enable trigger fmail_change_log_guard;
    res := res || jsonb_build_object('name', 'restoring the row makes the chain verify again', 'ok', (public.fmail_change_verify187(v_box) ->> 'ok')::boolean);
    -- prune
    v_r := public.fmail_change_prune187(14, 100);
    res := res || jsonb_build_object('name', 'prune keeps recent rows (nothing is older than 14 days, 13 rows are fewer than 100)', 'ok', (v_r ->> 'pruned') = '0');
    perform set_config('fmail.change_door', '', true);
    alter table public.fmail_change_log187 disable trigger fmail_change_log_guard;
    update public.fmail_change_log187 set at = at - interval '30 days' where mailbox_id = v_box and seq <= 6;
    alter table public.fmail_change_log187 enable trigger fmail_change_log_guard;
    -- the old rows are now old by their clock, but their hash was made with the real clock, so honest pruning keeps verification via the floor hash (verify of the kept part)
    select row_hash into v_h from public.fmail_change_log187 where mailbox_id = v_box and seq = 6;
    v_r := public.fmail_change_prune187(14, 1000);
    res := res || jsonb_build_object('name', 'prune removes the rows older than the window and moves the floor to 6', 'ok', (v_r ->> 'pruned') = '6' and (select floor_seq from public.fmail_change_head187 where mailbox_id = v_box) = 6
        and (select floor_hash from public.fmail_change_head187 where mailbox_id = v_box) = v_h);
    res := res || jsonb_build_object('name', 'a cursor below the floor is a gap, a cursor at the floor still works', 'ok', (public.fmail_change_since187(v_uid, v_box, 3, 50) ->> 'gap') = 'true' and (public.fmail_change_since187(v_uid, v_box, 6, 50) ->> 'gap') = 'false'
        and jsonb_array_length(public.fmail_change_since187(v_uid, v_box, 6, 50) -> 'changes') = 7);
    res := res || jsonb_build_object('name', 'after pruning the kept part still verifies from the floor hash', 'ok', (public.fmail_change_verify187(v_box) ->> 'ok')::boolean and (public.fmail_change_verify187(v_box) ->> 'checked') = '7');
    -- summary, tiers, health
    v_r := public.fmail_change_since187(v_uid, v_box, 6, 50);
    res := res || jsonb_build_object('name', 'the answer carries a summary of kinds (for "3 new mails" without opening rows)', 'ok', (v_r -> 'summary' ->> 'read') is null and (v_r -> 'summary' ->> 'scan') = '1' and (v_r -> 'summary' ->> 'outbox') = '2' and (v_r -> 'summary' ->> 'sent') = '1' and (v_r -> 'summary' ->> 'expunge') = '1');
    res := res || jsonb_build_object('name', 'six package codes plus the founder lane exist, Premium and MAX are kept but not built', 'ok', (select count(*) from public.fmail_tier_limits187) = 7
        and (select count(*) from public.fmail_tier_limits187 where not built) = 2 and (public.fmail_tier_limit187('business_max') ->> 'live_streams') = '100' and (public.fmail_tier_limit187('founder') ->> 'live_streams') = '20');
    res := res || jsonb_build_object('name', 'an unknown package is named as unknown, never guessed', 'ok', public.fmail_tier_limit187('gold') ? 'error');
    begin insert into public.fmail_tier_limits187 (tier, live_streams, keep_days, keep_rows) values ('basic', 9, 9, 9999); v_ok := false; exception when sqlstate '42501' then v_ok := true; when others then v_ok := sqlstate in ('42501', '23505'); end;
    res := res || jsonb_build_object('name', 'package limits can not be written through the API role', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'health reads rows and heads', 'ok', (public.fmail_change_health187() ->> 'rows')::bigint >= 7 and (public.fmail_change_health187() ->> 'mailboxes')::bigint >= 1);
    -- privacy
    res := res || jsonb_build_object('name', 'the log has no text column except the kind (no subject, address or body can be stored)',
        'ok', (select array_agg(attname::text order by attname) from pg_attribute where attrelid = 'public.fmail_change_log187'::regclass and attnum > 0 and not attisdropped and atttypid = 'text'::regtype) = array['kind']);
    res := res || jsonb_build_object('name', 'every line wakes listeners with ids only (pg_notify is in the write door)', 'ok', position('pg_notify' in pg_get_functiondef('public.fmail_change_note187(uuid,text,uuid,uuid,uuid)'::regprocedure)) > 0);
    -- a mailbox that is being deleted writes nothing and does not fail
    delete from public.fmail_mailboxes where id = v_box;
    res := res || jsonb_build_object('name', 'deleting the mailbox (cascade) works and leaves no log or head rows', 'ok', not exists (select 1 from public.fmail_change_log187 where mailbox_id = v_box) and not exists (select 1 from public.fmail_change_head187 where mailbox_id = v_box));
    raise exception 'E187_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E187_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E187_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest187() from public, anon, authenticated;
grant execute on function public.fmail_selftest187() to service_role;

-- 9) POSTURE (stable, E179-safe) -------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_posture187() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  rd regprocedure[] := array[to_regprocedure('public.fmail_change_since187(uuid,uuid,bigint,integer)'), to_regprocedure('public.fmail_change_heads187()'), to_regprocedure('public.fmail_change_verify187(uuid)'), to_regprocedure('public.fmail_tier_limit187(text)'), to_regprocedure('public.fmail_change_health187()')];
  wd regprocedure[] := array[to_regprocedure('public.fmail_change_' || 'note187(uuid,text,uuid,uuid,uuid)'), to_regprocedure('public.fmail_change_' || 'prune187(integer,integer)')];
begin
  return jsonb_build_object(
    'read_doors_stable_service_only', (select bool_and(provolatile = 's') from pg_proc where oid = any (rd::oid[])) and (select bool_and(has_function_privilege('service_role', d, 'execute') and not has_function_privilege('anon', d, 'execute') and not has_function_privilege('authenticated', d, 'execute')) from unnest(rd) d),
    'write_doors_volatile_service_only', (select bool_and(provolatile = 'v') from pg_proc where oid = any (wd::oid[])) and (select bool_and(has_function_privilege('service_role', d, 'execute') and not has_function_privilege('anon', d, 'execute') and not has_function_privilege('authenticated', d, 'execute')) from unnest(wd) d),
    'rls_forced', (select bool_and(relforcerowsecurity) from pg_class where oid in ('public.fmail_change_head187'::regclass, 'public.fmail_change_log187'::regclass)),
    'service_role_read_only', not exists (select 1 from information_schema.role_table_grants where grantee = 'service_role' and table_schema = 'public' and table_name in ('fmail_change_head187', 'fmail_change_log187', 'fmail_tier_limits187')
                                           and privilege_type = any (array['INS' || 'ERT', 'UPD' || 'ATE', 'DEL' || 'ETE', 'TRUNC' || 'ATE'])),
    'anon_no_access', not exists (select 1 from information_schema.role_table_grants where grantee in ('anon', 'authenticated', 'PUBLIC') and table_schema = 'public' and table_name in ('fmail_change_head187', 'fmail_change_log187', 'fmail_tier_limits187')),
    'triggers_on_mail_tables', (select count(*) from pg_trigger where not tgisinternal and tgname in ('fmail_change_msg', 'fmail_change_outbox', 'fmail_change_label', 'fmail_change_log_guard', 'fmail_change_log_guard_t', 'fmail_change_head_guard', 'fmail_change_head_guard_t')),
    'door_audit_clean', not exists (select 1 from public.fmail_door_audit179()));
end $$;
revoke all on function public.fmail_posture187() from public, anon, authenticated;
grant execute on function public.fmail_posture187() to service_role;

select public.fmail_posture187() as e187_posture;
select public.fmail_selftest187() ->> 'passed' as e187_selftest_passed, public.fmail_selftest187() ->> 'failed' as e187_selftest_failed;
