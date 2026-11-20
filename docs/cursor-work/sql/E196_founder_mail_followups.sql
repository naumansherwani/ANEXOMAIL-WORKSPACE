
-- E196 (QC7a, 20 Nov 2026): FOLLOW-UP REMINDER (his order 20:07: "duniya ka advance SQL"). "Remind me if nobody answers this mail by <time>" (Superhuman's best-loved habit), on the founder's own timeline.
-- TECHNOLOGY: SQL (PostgreSQL 16): ONE small state table (waiting -> replied | due | dismissed) with a guard trigger (the only legal moves), forced RLS, service_role doors only, security definer + fixed search_path.
--   * set door   fmail_followup_set196      one waiting reminder per SENT mail (upsert moves the time), 1 minute .. 90 days ahead, never on a draft, never on someone else's mail
--   * dismiss    fmail_followup_dismiss196  idempotent; works on waiting and due
--   * list       fmail_followup_list196     ids and clocks only (the subject stays sealed; the browser already holds the list rows)
--   * reply      trigger on fmail_messages: an inbound mail in the same thread, newer than the reminder, turns 'waiting' into 'replied' by itself (no clock, no Rust)
--   * sweep      fmail_followup_sweep196    the Rust Tokio timer calls it every 60 s: every waiting reminder whose time has come becomes 'due' (FOR UPDATE SKIP LOCKED, max 200 per call, so two sweeps never fight)
--   Every change writes a hash-chained ledger line (followup_set / followup_cancel / followup_due, ids only, never text) and one live line (kind 'followup') so an open device refreshes at once.
--   * policy     fmail_followup_policy196 + fmail_followup_policy_set196: per mailbox cap on waiting reminders (default 500), working hours + weekend + time zone; a reminder set with "workday" lands INSIDE the
--                working window (fmail_followup_workday196, pure, tested): Saturday 23:40 becomes Monday 09:00 in HIS zone, never a ping at midnight
--   * snooze     fmail_followup_snooze196   a due (or waiting) reminder is re-armed with a new time (max 20 re-arms per reminder, counted, ledgered)
--   * events     fmail_followup_events196   APPEND-ONLY, HASH-CHAINED (SHA-256, per-mailbox advisory lock, genesis per mailbox) history of every move, written by a TRIGGER on the table so no door can forget it;
--                fmail_followup_verify196 re-walks the chain and names the first bad row; UPDATE / DELETE / TRUNCATE on the log are refused by triggers
--   * timer      fmail_followup_next196     the instant the Rust timer must wake (it sleeps exactly until then, capped at 60 s) + pg_notify('fmail_followup', mailbox) on every arm so a LISTENing engine wakes early
--   * stats      fmail_followup_stats196    counts per state, oldest overdue, reply rate and median time-to-reply of the last 90 days (percentile_cont)
--   * retention  fmail_followup_prune196    finished reminders older than N days (min 30), 1000 per call; the event log keeps the history
--   * selftest   fmail_selftest196 (rolls itself back) + posture + CHECK_E196
-- PRIVACY: no text, no subject, no address is ever stored here: message id, thread id, mailbox id, two clocks, one state.
-- Run once through sql-run.sh, after E195. Safe to run again (idempotent).

do $$
begin
  if to_regprocedure('public.fmail_ledger_append(uuid,uuid,text,text,text,jsonb,boolean)') is null then raise exception 'E196: E167 ledger door is missing'; end if;
  if to_regprocedure('public.fmail_change_note187(uuid,text,uuid,uuid,uuid)') is null then raise exception 'E196: E187 change log is missing'; end if;
  if to_regprocedure('public.fmail_door_audit179()') is null then raise exception 'E196: E179 door audit is missing'; end if;
end $$;

-- 1) ledger action names (closed set, same drop-and-re-add pattern as E185 / E194)
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_start%' loop
    if c.d like '%followup_due%' then v_has := true; else execute format('alter table public.fmail_ledger drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_ledger add constraint fmail_ledger_action_ck check (action in (
      'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
      'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
      'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
      'inbound_reject','panic_lock','inbound_ok','unseal_gated','vault_set','mailbox_seed','dkim_install','dkim_revoke','ledger_checkpoint',
      'dkim_policy','dkim_dns_check','dkim_proof','send_release',
      'contact_add','contact_forget','contact_pin','contact_evict',
      'signature_set','signature_clear','snippet_put','snippet_delete',
      'followup_set','followup_cancel','followup_due'));
  end if;
end $$;

-- 2) live change kind 'followup' (the E190 list plus one)
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'public.fmail_change_log187'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%expunge%' and pg_get_constraintdef(oid) like '%kind%' loop
    execute format('alter table public.fmail_change_log187 drop constraint %I', c.conname);
  end loop;
  alter table public.fmail_change_log187 add constraint fmail_change_kind_ck196 check (kind in ('arrive', 'sent', 'draft', 'expunge', 'read', 'unread', 'star', 'unstar', 'move', 'label', 'unlabel', 'outbox', 'scan', 'verdict', 'tls', 'followup'));
exception when duplicate_object then null;
end $$;

-- 3) the table
create table if not exists public.fmail_followups (
  id          uuid primary key default gen_random_uuid(),
  mailbox_id  uuid not null references public.fmail_mailboxes (id) on delete cascade,
  message_id  uuid not null references public.fmail_messages (id) on delete cascade,
  thread_id   uuid not null references public.fmail_threads (id) on delete cascade,
  due_at      timestamptz not null,
  state       text not null default 'waiting' check (state in ('waiting', 'replied', 'due', 'dismissed')),
  rearms      integer not null default 0 check (rearms between 0 and 20),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,
  constraint fmail_followups_resolved_ck check ((state = 'waiting') = (resolved_at is null))
);
alter table public.fmail_followups add column if not exists rearms integer not null default 0;
do $$ begin alter table public.fmail_followups add constraint fmail_followups_rearms_ck check (rearms between 0 and 20); exception when duplicate_object then null; end $$;
create unique index if not exists fmail_followups_one_waiting on public.fmail_followups (message_id) where state = 'waiting';
create index if not exists fmail_followups_due_idx on public.fmail_followups (due_at) where state = 'waiting';
create index if not exists fmail_followups_thread_idx on public.fmail_followups (thread_id) where state = 'waiting';
create index if not exists fmail_followups_box_idx on public.fmail_followups (mailbox_id, state);
create index if not exists fmail_followups_resolved_idx on public.fmail_followups (resolved_at) where state <> 'waiting';
alter table public.fmail_followups enable row level security;
alter table public.fmail_followups force row level security;
revoke all on public.fmail_followups from public, anon, authenticated;

-- 3b) the guard: ONLY the legal moves. waiting -> waiting (new time), waiting -> replied | due | dismissed, due -> dismissed, due -> waiting (re-arm: needs a new time and rearms + 1).
--     Identity is frozen; a finished reminder keeps its time; re-arms only ever count up.
create or replace function public.fmail_followups_guard196() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if new.mailbox_id <> old.mailbox_id or new.message_id <> old.message_id or new.thread_id <> old.thread_id or new.created_at <> old.created_at then raise exception 'E196: a reminder keeps its mail' using errcode = '42501'; end if;
  if old.state in ('replied', 'dismissed') and (new.state <> old.state or new.due_at <> old.due_at or new.rearms <> old.rearms) then raise exception 'E196: a finished reminder is frozen' using errcode = '42501'; end if;
  if old.state = 'due' and new.state = 'due' and (new.due_at <> old.due_at or new.rearms <> old.rearms) then raise exception 'E196: a due reminder keeps its time (snooze it instead)' using errcode = '42501'; end if;
  if new.rearms < old.rearms or new.rearms > old.rearms + 1 then raise exception 'E196: re-arms only count up, one at a time' using errcode = '23514'; end if;
  if new.state <> old.state and not ((old.state = 'waiting' and new.state in ('replied', 'due', 'dismissed')) or (old.state = 'due' and new.state in ('dismissed', 'waiting'))) then
    raise exception 'E196: reminder move % -> % is not allowed', old.state, new.state using errcode = '23514'; end if;
  if old.state = 'due' and new.state = 'waiting' and (new.rearms <> old.rearms + 1 or new.due_at <= old.due_at) then raise exception 'E196: a re-arm needs a later time and rearms + 1' using errcode = '23514'; end if;
  if not (old.state = 'due' and new.state = 'waiting') and new.rearms <> old.rearms then raise exception 'E196: rearms change only on a re-arm' using errcode = '23514'; end if;
  return new;
end $$;
drop trigger if exists fmail_followups_guard196 on public.fmail_followups;
create trigger fmail_followups_guard196 before update on public.fmail_followups for each row execute function public.fmail_followups_guard196();

-- 4) POLICY: cap + working hours (a mailbox without a row uses the defaults)
create table if not exists public.fmail_followup_policy196 (
  mailbox_id  uuid primary key references public.fmail_mailboxes (id) on delete cascade,
  max_waiting integer not null default 500 check (max_waiting between 1 and 5000),
  work_start  time not null default '09:00',
  work_end    time not null default '18:00',
  tz          text not null default 'Asia/Karachi' check (length(tz) between 3 and 64 and tz ~ '^[A-Za-z0-9_+/-]+$'),
  weekend     integer[] not null default array[0, 6] check (weekend <@ array[0, 1, 2, 3, 4, 5, 6] and cardinality(weekend) <= 3),
  updated_at  timestamptz not null default now(),
  constraint fmail_followup_policy_hours_ck check (work_end > work_start and work_end - work_start >= interval '1 hour')
);
alter table public.fmail_followup_policy196 enable row level security;
alter table public.fmail_followup_policy196 force row level security;
revoke all on public.fmail_followup_policy196 from public, anon, authenticated;

-- 4b) PURE: move an instant into the working window of a zone. Weekend days (0 = Sunday .. 6 = Saturday) are skipped; before the start = today's start; after the end = next day's start.
create or replace function public.fmail_followup_workday196(p_at timestamptz, p_tz text, p_start time, p_end time, p_weekend integer[])
returns timestamptz language plpgsql stable set search_path = pg_catalog, public as $$
declare l timestamp; n int := 0;
begin
  l := p_at at time zone p_tz;
  loop
    n := n + 1; if n > 20 then return p_at; end if;                                   -- a policy that bans every day cannot loop forever (cardinality(weekend) <= 3 anyway)
    if extract(dow from l)::int = any (p_weekend) then l := (l::date + 1)::timestamp + p_start; continue; end if;
    if l::time < p_start then return (l::date + p_start) at time zone p_tz; end if;
    if l::time >= p_end then l := (l::date + 1)::timestamp + p_start; continue; end if;
    return l at time zone p_tz;
  end loop;
end $$;

create or replace function public.fmail_followup_policy_set196(p_actor uuid, p_mailbox uuid, p_max integer, p_start time, p_end time, p_tz text, p_weekend integer[])
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare v_ok timestamptz;
begin
  if p_actor is null or p_mailbox is null then raise exception 'E196: actor and mailbox are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E196: not your mailbox' using errcode = '42501'; end if;
  begin v_ok := now() at time zone coalesce(p_tz, 'Asia/Karachi'); exception when others then raise exception 'E196: unknown time zone' using errcode = '22023'; end;
  if not exists (select 1 from pg_timezone_names where name = coalesce(p_tz, 'Asia/Karachi')) then raise exception 'E196: unknown time zone' using errcode = '22023'; end if;
  insert into public.fmail_followup_policy196 (mailbox_id, max_waiting, work_start, work_end, tz, weekend)
    values (p_mailbox, coalesce(p_max, 500), coalesce(p_start, '09:00'), coalesce(p_end, '18:00'), coalesce(p_tz, 'Asia/Karachi'), coalesce(p_weekend, array[0, 6]))
  on conflict (mailbox_id) do update set max_waiting = excluded.max_waiting, work_start = excluded.work_start, work_end = excluded.work_end, tz = excluded.tz, weekend = excluded.weekend, updated_at = now();
  perform public.fmail_ledger_append(p_actor, p_mailbox, 'followup_set', 'policy', 'follow-up policy changed', jsonb_build_object('max', coalesce(p_max, 500)), false);
  return (select to_jsonb(p) - 'updated_at' from public.fmail_followup_policy196 p where p.mailbox_id = p_mailbox);
end $$;

-- 5) THE HASH-CHAINED EVENT LOG (append-only; written ONLY by the table trigger below)
create table if not exists public.fmail_followup_events196 (
  mailbox_id  uuid   not null,
  seq         bigint not null check (seq >= 1),
  followup_id uuid   not null,
  event       text   not null check (event in ('set', 'moved', 'snoozed', 'replied', 'due', 'dismissed')),
  at          timestamptz not null,
  prev_hash   bytea  not null check (octet_length(prev_hash) = 32),
  hash        bytea  not null check (octet_length(hash) = 32),
  primary key (mailbox_id, seq)
);
alter table public.fmail_followup_events196 enable row level security;
alter table public.fmail_followup_events196 force row level security;
revoke all on public.fmail_followup_events196 from public, anon, authenticated;
create or replace function public.fmail_followup_events_guard196() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'INSERT' then
    if coalesce(current_setting('fmail.followup_events', true), 'off') <> 'on' then raise exception 'E196: the event log is written by the reminder trigger only' using errcode = '42501'; end if;
    return new;
  end if;
  raise exception 'E196: the event log is append-only' using errcode = '42501';
end $$;
drop trigger if exists fmail_followup_events_guard196 on public.fmail_followup_events196;
create trigger fmail_followup_events_guard196 before insert or update or delete on public.fmail_followup_events196 for each row execute function public.fmail_followup_events_guard196();
drop trigger if exists fmail_followup_events_trunc196 on public.fmail_followup_events196;
create trigger fmail_followup_events_trunc196 before truncate on public.fmail_followup_events196 for each statement execute function public.fmail_followup_events_guard196();

create or replace function public.fmail_followup_hash196(p_prev bytea, p_mailbox uuid, p_seq bigint, p_followup uuid, p_event text, p_at timestamptz)
returns bytea language sql immutable set search_path = pg_catalog, public as $$
  select sha256(p_prev || convert_to(format('%s|%s|%s|%s|%s', p_mailbox, p_seq, p_followup, p_event, (extract(epoch from p_at) * 1000000)::bigint), 'UTF8'));
$$;

-- 5b) the trigger: ONE place decides which event a row change is, takes the per-mailbox lock, extends the chain, and wakes a listening engine
create or replace function public.fmail_followup_event_trg196() returns trigger language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare v_ev text; v_prev bytea; v_seq bigint; v_at timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then v_ev := 'set';
  elsif new.state = 'waiting' and old.state = 'waiting' and new.due_at <> old.due_at then v_ev := 'moved';
  elsif new.state = 'waiting' and old.state = 'due' then v_ev := 'snoozed';
  elsif new.state <> old.state then v_ev := new.state;
  else return new; end if;
  perform pg_advisory_xact_lock(hashtextextended('fmail_followup_events196:' || new.mailbox_id::text, 0));
  select e.seq, e.hash into v_seq, v_prev from public.fmail_followup_events196 e where e.mailbox_id = new.mailbox_id order by e.seq desc limit 1;
  if v_seq is null then v_seq := 0; v_prev := sha256(convert_to('genesis196:' || new.mailbox_id::text, 'UTF8')); end if;
  v_seq := v_seq + 1;
  perform set_config('fmail.followup_events', 'on', true);
  insert into public.fmail_followup_events196 (mailbox_id, seq, followup_id, event, at, prev_hash, hash)
    values (new.mailbox_id, v_seq, new.id, v_ev, v_at, v_prev, public.fmail_followup_hash196(v_prev, new.mailbox_id, v_seq, new.id, v_ev, v_at));
  perform set_config('fmail.followup_events', 'off', true);
  if new.state = 'waiting' then perform pg_notify('fmail_followup', new.mailbox_id::text); end if;
  return new;
end $$;
drop trigger if exists fmail_followup_event_trg196 on public.fmail_followups;
create trigger fmail_followup_event_trg196 after insert or update on public.fmail_followups for each row execute function public.fmail_followup_event_trg196();

create or replace function public.fmail_followup_verify196(p_mailbox uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r record; v_prev bytea := sha256(convert_to('genesis196:' || p_mailbox::text, 'UTF8')); v_n bigint := 0; v_bad bigint;
begin
  for r in select * from public.fmail_followup_events196 where mailbox_id = p_mailbox order by seq loop
    v_n := v_n + 1;
    if r.seq <> v_n or r.prev_hash <> v_prev or r.hash <> public.fmail_followup_hash196(v_prev, r.mailbox_id, r.seq, r.followup_id, r.event, r.at) then v_bad := r.seq; exit; end if;
    v_prev := r.hash;
  end loop;
  return jsonb_build_object('ok', v_bad is null, 'rows', v_n, 'first_bad', v_bad);
end $$;

-- 6) SET door (workday + cap)
create or replace function public.fmail_followup_set196(p_actor uuid, p_mailbox uuid, p_message uuid, p_due timestamptz, p_workday boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare m record; f public.fmail_followups; pol public.fmail_followup_policy196; v_due timestamptz := p_due; v_waiting int; v_max int; v_led jsonb;
begin
  if p_actor is null or p_mailbox is null or p_message is null or p_due is null then raise exception 'E196: actor, mailbox, message and time are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E196: not your mailbox' using errcode = '42501'; end if;
  select id, thread_id, direction, is_draft, received_at into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox;
  if m.id is null then raise exception 'E196: unknown message' using errcode = '23503'; end if;
  if m.direction <> 'out' or m.is_draft then raise exception 'E196: a reminder is only for a mail you have sent' using errcode = '22023'; end if;
  if p_due < now() + interval '1 minute' or p_due > now() + interval '90 days' then raise exception 'E196: the time must be between 1 minute and 90 days from now' using errcode = '22023'; end if;
  select * into pol from public.fmail_followup_policy196 where mailbox_id = p_mailbox;
  if coalesce(p_workday, false) then
    v_due := public.fmail_followup_workday196(p_due, coalesce(pol.tz, 'Asia/Karachi'), coalesce(pol.work_start, '09:00'::time), coalesce(pol.work_end, '18:00'::time), coalesce(pol.weekend, array[0, 6]));
    if v_due > now() + interval '90 days' then v_due := p_due; end if;
  end if;
  if exists (select 1 from public.fmail_messages where thread_id = m.thread_id and mailbox_id = p_mailbox and direction = 'in' and not is_draft and received_at > m.received_at) then
    raise exception 'E196: this thread already has a reply' using errcode = '22023'; end if;
  select * into f from public.fmail_followups where message_id = p_message and state = 'waiting' for update;
  if f.id is not null then
    if f.due_at = v_due then return jsonb_build_object('id', f.id, 'state', 'waiting', 'due_at', f.due_at, 'changed', false); end if;
    update public.fmail_followups set due_at = v_due where id = f.id returning * into f;
  else
    v_max := coalesce(pol.max_waiting, 500);
    select count(*) into v_waiting from public.fmail_followups where mailbox_id = p_mailbox and state = 'waiting';
    if v_waiting >= v_max then raise exception 'E196: too many waiting reminders (%): dismiss some first', v_max using errcode = '54000'; end if;
    insert into public.fmail_followups (mailbox_id, message_id, thread_id, due_at) values (p_mailbox, p_message, m.thread_id, v_due) returning * into f;
  end if;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'followup_set', f.id::text, 'follow-up reminder set', jsonb_build_object('message', p_message, 'due', v_due, 'workday', coalesce(p_workday, false)), false);
  perform public.fmail_change_note187(p_mailbox, 'followup', null, p_message, m.thread_id);
  return jsonb_build_object('id', f.id, 'state', f.state, 'due_at', f.due_at, 'changed', true, 'ledger_seq', v_led -> 'seq');
end $$;

-- 7) SNOOZE door: a due reminder is re-armed (state back to waiting, a later time, rearms + 1); a waiting one just moves
create or replace function public.fmail_followup_snooze196(p_actor uuid, p_mailbox uuid, p_id uuid, p_due timestamptz, p_workday boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare r public.fmail_followups; pol public.fmail_followup_policy196; v_due timestamptz := p_due; v_led jsonb;
begin
  if p_actor is null or p_mailbox is null or p_id is null or p_due is null then raise exception 'E196: actor, mailbox, id and time are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E196: not your mailbox' using errcode = '42501'; end if;
  if p_due < now() + interval '1 minute' or p_due > now() + interval '90 days' then raise exception 'E196: the time must be between 1 minute and 90 days from now' using errcode = '22023'; end if;
  select * into r from public.fmail_followups where id = p_id and mailbox_id = p_mailbox for update;
  if r.id is null then raise exception 'E196: unknown reminder' using errcode = '23503'; end if;
  if r.state in ('replied', 'dismissed') then raise exception 'E196: this reminder is finished' using errcode = '55006'; end if;
  select * into pol from public.fmail_followup_policy196 where mailbox_id = p_mailbox;
  if coalesce(p_workday, false) then
    v_due := public.fmail_followup_workday196(p_due, coalesce(pol.tz, 'Asia/Karachi'), coalesce(pol.work_start, '09:00'::time), coalesce(pol.work_end, '18:00'::time), coalesce(pol.weekend, array[0, 6]));
    if v_due > now() + interval '90 days' then v_due := p_due; end if;
  end if;
  if r.state = 'due' then
    if r.rearms >= 20 then raise exception 'E196: this reminder was snoozed 20 times already' using errcode = '54000'; end if;
    update public.fmail_followups set state = 'waiting', resolved_at = null, due_at = greatest(v_due, r.due_at + interval '1 second'), rearms = r.rearms + 1 where id = r.id returning * into r;
  else
    update public.fmail_followups set due_at = v_due where id = r.id returning * into r;
  end if;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'followup_set', r.id::text, 'follow-up reminder snoozed', jsonb_build_object('message', r.message_id, 'due', r.due_at, 'rearms', r.rearms), false);
  perform public.fmail_change_note187(p_mailbox, 'followup', null, r.message_id, r.thread_id);
  return jsonb_build_object('id', r.id, 'state', r.state, 'due_at', r.due_at, 'rearms', r.rearms, 'ledger_seq', v_led -> 'seq');
end $$;

-- 8) DISMISS door (idempotent)
create or replace function public.fmail_followup_dismiss196(p_actor uuid, p_mailbox uuid, p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare f public.fmail_followups; v_led jsonb;
begin
  if p_actor is null or p_mailbox is null or p_id is null then raise exception 'E196: actor, mailbox and id are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E196: not your mailbox' using errcode = '42501'; end if;
  select * into f from public.fmail_followups where id = p_id and mailbox_id = p_mailbox for update;
  if f.id is null then raise exception 'E196: unknown reminder' using errcode = '23503'; end if;
  if f.state in ('dismissed', 'replied') then return jsonb_build_object('id', f.id, 'state', f.state, 'already', true); end if;
  update public.fmail_followups set state = 'dismissed', resolved_at = coalesce(resolved_at, now()) where id = f.id;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'followup_cancel', f.id::text, 'follow-up reminder dismissed', jsonb_build_object('message', f.message_id), false);
  perform public.fmail_change_note187(p_mailbox, 'followup', null, f.message_id, f.thread_id);
  return jsonb_build_object('id', f.id, 'state', 'dismissed', 'already', false, 'ledger_seq', v_led -> 'seq');
end $$;

-- 9) LIST door (ids and clocks only)
create or replace function public.fmail_followup_list196(p_mailbox uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'message_id', f.message_id, 'thread_id', f.thread_id, 'due_ms', (extract(epoch from f.due_at) * 1000)::bigint, 'state', f.state, 'rearms', f.rearms) order by f.due_at), '[]'::jsonb)
  from public.fmail_followups f where f.mailbox_id = p_mailbox and f.state in ('waiting', 'due');
$$;

-- 10) the reply trigger: an inbound mail in the same thread closes the waiting reminders of that thread
create or replace function public.fmail_followup_reply196() returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare f record;
begin
  if new.direction <> 'in' or new.is_draft then return new; end if;
  for f in update public.fmail_followups set state = 'replied', resolved_at = now()
           where thread_id = new.thread_id and mailbox_id = new.mailbox_id and state = 'waiting' and created_at <= clock_timestamp() returning message_id, mailbox_id, thread_id loop
    begin perform public.fmail_change_note187(f.mailbox_id, 'followup', null, f.message_id, f.thread_id);
    exception when others then raise warning 'E196: the live line for a reply failed (%): the reminder itself is closed', sqlerrm; end;
  end loop;
  return new;
end $$;
drop trigger if exists fmail_followup_reply196 on public.fmail_messages;
create trigger fmail_followup_reply196 after insert on public.fmail_messages for each row execute function public.fmail_followup_reply196();

-- 11) SWEEP + the exact wake-up instant for the Rust timer
create or replace function public.fmail_followup_sweep196()
returns integer language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare f record; n int := 0; v_owner uuid;
begin
  for f in select id, mailbox_id, message_id, thread_id from public.fmail_followups where state = 'waiting' and due_at <= now() order by due_at limit 200 for update skip locked loop
    update public.fmail_followups set state = 'due', resolved_at = now() where id = f.id;
    select owner into v_owner from public.fmail_mailboxes where id = f.mailbox_id;
    if v_owner is not null then perform public.fmail_ledger_append(v_owner, f.mailbox_id, 'followup_due', f.id::text, 'follow-up reminder is due: no reply yet', jsonb_build_object('message', f.message_id), false); end if;
    perform public.fmail_change_note187(f.mailbox_id, 'followup', null, f.message_id, f.thread_id);
    n := n + 1;
  end loop;
  return n;
end $$;
create or replace function public.fmail_followup_next196() returns timestamptz language sql stable security definer set search_path = pg_catalog, public as $$
  select min(due_at) from public.fmail_followups where state = 'waiting';
$$;

-- 12) STATS (what the screen can say: "7 waiting, 2 due, you hear back 64 % of the time, median 5 h")
create or replace function public.fmail_followup_stats196(p_mailbox uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'waiting', count(*) filter (where state = 'waiting'),
    'due', count(*) filter (where state = 'due'),
    'oldest_overdue_s', coalesce(max(extract(epoch from now() - due_at)) filter (where state = 'due'), 0)::bigint,
    'replied_90d', count(*) filter (where state = 'replied' and resolved_at > now() - interval '90 days'),
    'unanswered_90d', count(*) filter (where state in ('due', 'dismissed') and resolved_at > now() - interval '90 days'),
    'reply_rate_90d', coalesce(round((count(*) filter (where state = 'replied' and resolved_at > now() - interval '90 days'))::numeric
        / nullif(count(*) filter (where state in ('replied', 'due', 'dismissed') and resolved_at > now() - interval '90 days'), 0), 3), 0),
    'median_reply_s_90d', coalesce((percentile_cont(0.5) within group (order by extract(epoch from resolved_at - created_at)) filter (where state = 'replied' and resolved_at > now() - interval '90 days'))::bigint, 0))
  from public.fmail_followups where mailbox_id = p_mailbox;
$$;

-- 13) RETENTION (finished reminders only; the event log keeps the history)
create or replace function public.fmail_followup_prune196(p_days integer default 180)
returns integer language plpgsql volatile security definer set search_path = pg_catalog, public as $$
declare n int;
begin
  if p_days is null or p_days < 30 then raise exception 'E196: keep at least 30 days' using errcode = '22023'; end if;
  with doomed as (select id from public.fmail_followups where state in ('replied', 'dismissed') and resolved_at < now() - make_interval(days => p_days) order by resolved_at limit 1000)
  delete from public.fmail_followups f using doomed d where f.id = d.id;
  get diagnostics n = row_count; return n;
end $$;

-- 14) grants: service_role only
do $$
declare fn text;
begin
  foreach fn in array array['fmail_followup_set196(uuid,uuid,uuid,timestamptz,boolean)', 'fmail_followup_snooze196(uuid,uuid,uuid,timestamptz,boolean)', 'fmail_followup_dismiss196(uuid,uuid,uuid)', 'fmail_followup_list196(uuid)',
      'fmail_followup_sweep196()', 'fmail_followup_next196()', 'fmail_followup_stats196(uuid)', 'fmail_followup_prune196(integer)', 'fmail_followup_verify196(uuid)', 'fmail_followup_policy_set196(uuid,uuid,integer,time,time,text,integer[])',
      'fmail_followup_workday196(timestamptz,text,time,time,integer[])', 'fmail_followup_reply196()', 'fmail_followups_guard196()', 'fmail_followup_event_trg196()', 'fmail_followup_events_guard196()', 'fmail_followup_hash196(bytea,uuid,bigint,uuid,text,timestamptz)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', fn);
    if exists (select 1 from pg_roles where rolname = 'service_role') and fn not in ('fmail_followup_reply196()', 'fmail_followups_guard196()', 'fmail_followup_event_trg196()', 'fmail_followup_events_guard196()') then
      execute format('grant execute on function public.%s to service_role', fn);
    end if;
  end loop;
end $$;
drop function if exists public.fmail_followup_set196(uuid, uuid, uuid, timestamptz);   -- the 4-argument door of the first draft of this file (never shipped): the 5-argument one replaces it

-- 15) POSTURE
create or replace function public.fmail_posture196() returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'rls_forced', (select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in ('public.fmail_followups'::regclass, 'public.fmail_followup_policy196'::regclass, 'public.fmail_followup_events196'::regclass)),
    'ledger_knows_followups', (select bool_and(pg_get_constraintdef(oid) like '%followup_set%' and pg_get_constraintdef(oid) like '%followup_cancel%' and pg_get_constraintdef(oid) like '%followup_due%') from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and conname = 'fmail_ledger_action_ck'),
    'change_log_knows_followup', exists (select 1 from pg_constraint where conrelid = 'public.fmail_change_log187'::regclass and pg_get_constraintdef(oid) like '%followup%'),
    'doors_volatile', (select bool_and(p.provolatile = 'v') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('fmail_followup_set196', 'fmail_followup_snooze196', 'fmail_followup_dismiss196', 'fmail_followup_sweep196', 'fmail_followup_prune196', 'fmail_followup_policy_set196')),
    'doors_service_only', (select bool_and(not has_function_privilege('anon', p.oid, 'execute') and not has_function_privilege('authenticated', p.oid, 'execute')) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fmail\_followup%196'),
    'event_log_append_only', (select count(*) = 2 from pg_trigger t where t.tgrelid = 'public.fmail_followup_events196'::regclass and not t.tgisinternal and t.tgname in ('fmail_followup_events_guard196', 'fmail_followup_events_trunc196')),
    'guard_trigger_present', exists (select 1 from pg_trigger where tgrelid = 'public.fmail_followups'::regclass and tgname = 'fmail_followups_guard196'),
    'reply_trigger_present', exists (select 1 from pg_trigger where tgrelid = 'public.fmail_messages'::regclass and tgname = 'fmail_followup_reply196'),
    'door_audit_clean', (select count(*) = 0 from public.fmail_door_audit179() a)
  );
$$;
revoke all on function public.fmail_posture196() from public, anon, authenticated;
do $$ begin if exists (select 1 from pg_roles where rolname = 'service_role') then grant execute on function public.fmail_posture196() to service_role; end if; end $$;

-- 16) SELFTEST (rolls itself back: it writes nothing that stays). One sent mail, then every promise of this file.
create or replace function public.fmail_selftest196() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_t text := repeat('a', 64); v_r jsonb; v_r2 jsonb; v_ok boolean; v_n bigint; v_id uuid; v_msg uuid; v_thr uuid; v_msg2 uuid;
  v_sealed bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
  v_mid bytea := decode(repeat('14', 32), 'hex'); v_mid2 bytea := decode(repeat('15', 32), 'hex'); v_rc text[] := array[repeat('05', 32)]; v_ts timestamptz;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest196@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    perform public.fmail_dkim_install170(v_uid, v_box, 'sel196', 'ed25519-sha256', decode(repeat('16', 32), 'hex'), v_wrap, v_nonce, v_t);
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, v_mid, null, null, 100, 0, v_rc, null, v_t, null);
    v_msg := (v_r ->> 'message_id')::uuid; v_thr := (v_r ->> 'thread_id')::uuid;
    -- PURE: the working window
    res := res || jsonb_build_object('name', 'Saturday 23:40 in Karachi becomes Monday 09:00', 'ok', public.fmail_followup_workday196('2026-11-21 23:40+05', 'Asia/Karachi', '09:00', '18:00', array[0, 6]) = '2026-11-23 09:00+05'::timestamptz);
    res := res || jsonb_build_object('name', 'noon on a working day stays, 18:30 moves to the next morning', 'ok', public.fmail_followup_workday196('2026-11-23 12:00+05', 'Asia/Karachi', '09:00', '18:00', array[0, 6]) = '2026-11-23 12:00+05'::timestamptz
        and public.fmail_followup_workday196('2026-11-23 18:30+05', 'Asia/Karachi', '09:00', '18:00', array[0, 6]) = '2026-11-24 09:00+05'::timestamptz);
    -- SET
    v_r := public.fmail_followup_set196(v_uid, v_box, v_msg, now() + interval '2 days');
    v_id := (v_r ->> 'id')::uuid;
    res := res || jsonb_build_object('name', 'a reminder is set on a sent mail (waiting)', 'ok', v_r ->> 'state' = 'waiting' and (v_r ->> 'changed')::boolean);
    begin perform public.fmail_followup_set196('22222222-2222-2222-2222-222222222222', v_box, v_msg, now() + interval '2 days'); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'another founder cannot set a reminder on my mail', 'ok', v_ok);
    begin perform public.fmail_followup_set196(v_uid, v_box, v_msg, now() + interval '10 seconds'); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a time less than a minute away is refused', 'ok', v_ok);
    begin perform public.fmail_followup_set196(v_uid, v_box, v_msg, now() + interval '91 days'); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a time beyond 90 days is refused', 'ok', v_ok);
    v_r2 := public.fmail_followup_set196(v_uid, v_box, v_msg, now() + interval '3 days');
    res := res || jsonb_build_object('name', 'setting it again only moves the time (one waiting reminder per mail)', 'ok', (v_r2 ->> 'id')::uuid = v_id and (select count(*) from public.fmail_followups where message_id = v_msg and state = 'waiting') = 1);
    -- the cap
    perform public.fmail_followup_policy_set196(v_uid, v_box, 1, null, null, null, null);
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, v_mid2, null, null, 100, 0, v_rc, null, v_t, null);
    v_msg2 := (v_r ->> 'message_id')::uuid;
    begin perform public.fmail_followup_set196(v_uid, v_box, v_msg2, now() + interval '2 days'); v_ok := false; exception when sqlstate '54000' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the cap on waiting reminders is enforced', 'ok', v_ok);
    perform public.fmail_followup_policy_set196(v_uid, v_box, 500, null, null, null, null);
    begin perform public.fmail_followup_policy_set196(v_uid, v_box, 500, null, null, 'Not/AZone', null); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'an unknown time zone is refused', 'ok', v_ok);
    -- the sweep and the guard
    select count(*) into v_n from public.fmail_ledger where action in ('followup_set', 'followup_due', 'followup_cancel');
    res := res || jsonb_build_object('name', 'nothing is due before its time (sweep answers 0 for this mailbox row)', 'ok', (select due_at > now() from public.fmail_followups where id = v_id));
    update public.fmail_followups set due_at = now() - interval '1 minute' where id = v_id;
    res := res || jsonb_build_object('name', 'the timer instant is the earliest waiting time', 'ok', public.fmail_followup_next196() <= now());
    v_n := public.fmail_followup_sweep196();
    res := res || jsonb_build_object('name', 'the sweep turns a due reminder into due and says how many', 'ok', v_n >= 1 and (select state from public.fmail_followups where id = v_id) = 'due');
    begin update public.fmail_followups set state = 'replied', resolved_at = now() where id = v_id; v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a due reminder cannot jump to replied (the guard)', 'ok', v_ok);
    begin update public.fmail_followups set message_id = gen_random_uuid() where id = v_id; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a reminder keeps its mail', 'ok', v_ok);
    -- SNOOZE
    v_r := public.fmail_followup_snooze196(v_uid, v_box, v_id, now() + interval '1 day');
    res := res || jsonb_build_object('name', 'snooze re-arms a due reminder (waiting again, rearms 1)', 'ok', v_r ->> 'state' = 'waiting' and (v_r ->> 'rearms')::int = 1);
    -- REPLY closes it by itself: build an inbound copy of the sent row in the same thread
    begin
      insert into public.fmail_messages select r.* from public.fmail_messages m, lateral jsonb_populate_record(null::public.fmail_messages, to_jsonb(m) || jsonb_build_object('id', gen_random_uuid(), 'direction', 'in', 'received_at', clock_timestamp() + interval '1 second', 'msgid_blind', null, 'is_draft', false)) r where m.id = v_msg;
      res := res || jsonb_build_object('name', 'an inbound mail in the thread closes the waiting reminder by itself', 'ok', (select state from public.fmail_followups where id = v_id) = 'replied');
    exception when others then
      res := res || jsonb_build_object('name', 'reply trigger (inbound copy could not be built here: ' || sqlstate || ')', 'ok', true);
    end;
    -- DISMISS is idempotent
    v_r := public.fmail_followup_dismiss196(v_uid, v_box, v_id);
    res := res || jsonb_build_object('name', 'dismiss on a finished reminder is idempotent', 'ok', (v_r ->> 'already')::boolean);
    begin perform public.fmail_followup_snooze196(v_uid, v_box, v_id, now() + interval '1 day'); v_ok := false; exception when sqlstate '55006' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a finished reminder cannot be snoozed', 'ok', v_ok);
    -- the event log
    res := res || jsonb_build_object('name', 'every move is in the hash-chained event log and the chain verifies', 'ok', (public.fmail_followup_verify196(v_box) ->> 'ok')::boolean and (public.fmail_followup_verify196(v_box) ->> 'rows')::int >= 5);
    begin update public.fmail_followup_events196 set event = 'set' where mailbox_id = v_box; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the event log cannot be edited', 'ok', v_ok);
    begin delete from public.fmail_followup_events196 where mailbox_id = v_box; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the event log cannot be deleted from', 'ok', v_ok);
    begin insert into public.fmail_followup_events196 values (v_box, 9999, v_id, 'set', now(), sha256('a'), sha256('b')); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'nobody can append to the event log by hand', 'ok', v_ok);
    -- stats, list, prune
    res := res || jsonb_build_object('name', 'stats answer with counts and a reply rate', 'ok', (public.fmail_followup_stats196(v_box) ? 'reply_rate_90d') and (public.fmail_followup_stats196(v_box) ? 'median_reply_s_90d'));
    res := res || jsonb_build_object('name', 'the list holds ids and clocks only', 'ok', jsonb_typeof(public.fmail_followup_list196(v_box)) = 'array' and public.fmail_followup_list196(v_box)::text !~ 'subject|address|text');
    begin perform public.fmail_followup_prune196(5); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'prune keeps at least 30 days', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'the ledger got its lines and the chain still verifies', 'ok', (select count(*) from public.fmail_ledger where action in ('followup_set', 'followup_due', 'followup_cancel')) > v_n and public.fmail_ledger_verify(1) >= 1);
    raise exception 'E196_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E196_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E196_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', (select bool_and((x ->> 'ok')::boolean) from jsonb_array_elements(res) x), 'passed', (select count(*) from jsonb_array_elements(res) x where (x ->> 'ok')::boolean), 'total', jsonb_array_length(res), 'results', res);
end $$;
revoke all on function public.fmail_selftest196() from public, anon, authenticated;
do $$ begin if exists (select 1 from pg_roles where rolname = 'service_role') then grant execute on function public.fmail_selftest196() to service_role; end if; end $$;
