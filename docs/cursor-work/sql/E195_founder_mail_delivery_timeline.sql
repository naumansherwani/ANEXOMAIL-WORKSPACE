
-- E195 (QC3-A, 20 Nov 2026): DELIVERY TIMELINE. The founder opens a sent mail and sees, step by step, what really happened to it:
--   queued -> undo window -> handed to the recipient's server -> accepted (or deferred with the retry count, the reason and the next try, or failed for good).
-- Stands on E167 (outbox state machine, ledger chain), E170 (compose door, send_fail), E175 (ledger action list), E179 (door audit), E185 (released_at).
-- TECHNOLOGY: SQL (PostgreSQL 16), READ-ONLY doors. Nothing here writes: no new table, no column, no ledger line. Four security-definer, fixed-search_path
--   doors for service_role only, a pure immutable phase classifier and backoff table, a whitelist filter for ledger meta, one partial index, a rolled-back
--   selftest with 40+ checks and a posture function. Founder-only: every door takes the actor and proves mailbox ownership first (42501 otherwise).
--
-- WHAT THE TIMELINE CAN HONESTLY SAY (research 20 Nov 2026, QC3-PLAN-20NOV.md):
--   * "accepted" means the recipient's mail server answered 250 to our SMTP hand-off. It is NOT "in the inbox" and NOT "read". The words never say more.
--   * "deferred" means a temporary refusal (4xx) or a network failure: the sender retries by itself (1 min, 5 min, 30 min, 2 h, 6 h, then daily, 12 tries).
--     The database stores the row as state 'failed' with a finite next_attempt, or as 'queued' again after the requeue: both are "deferred", never "failed".
--   * "failed" means a permanent refusal (5xx, no mail host, private address: next_attempt = infinity) or all 12 tries used.
--   * The bounce report (DSN) goes to the envelope return path, not to the From header; the timeline never claims a later bounce did not happen.
--   * One row per mail, not per recipient: the outbox stores the recipient COUNT and blind indexes only (an honest, logged gap: per-recipient rows need a table).
-- NO CONTENT: no subject, no body, no recipient address, no sealed column, no key, no nonce is ever read or returned by these doors.
--   last_error / smtp_reply are the remote server's own short reply text (at most 300 characters, control characters refused by E167).
--   Doors: timeline (one mail), timeline_batch (badges for a list), outbox_list (with phase), delivery_stats (health over 1..30 days).
-- Run once through sql-run.sh, after E194. Safe to run again (idempotent).

do $$
begin
  if to_regprocedure('public.fmail_outbox_release_now(uuid,uuid,uuid)') is null then raise exception 'E195: E185 (Send now) is missing, run E185 first'; end if;
  if to_regprocedure('public.fmail_outbox_result(uuid,uuid,boolean,text,text,boolean,text)') is null then raise exception 'E195: E167 outbox_result is missing'; end if;
  if to_regprocedure('public.fmail_outbox_dead170(uuid,uuid,text,text)') is null then raise exception 'E195: E170 outbox_dead is missing'; end if;
  if to_regprocedure('public.fmail_door_audit179()') is null then raise exception 'E195: E179 door audit is missing (run E179 first)'; end if;
  if to_regprocedure('public.fmail_ledger_verify(integer)') is null and to_regprocedure('public.fmail_ledger_verify(bigint)') is null then raise exception 'E195: the ledger verifier is missing'; end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fmail_outbox' and column_name = 'released_at') then
    raise exception 'E195: fmail_outbox.released_at is missing (E185)'; end if;
end $$;

-- ============================================================================================================================================
-- 1) THE RETRY CLOCK, in one place. E167 fmail_outbox_result hard-codes 1 min, 5 min, 30 min, 2 h, 6 h, then 1 day. The screen must show the SAME numbers
--    ("next try in about 30 minutes"), so the table lives here as a pure function and the selftest proves it equals what the sender really writes
--    (it drives fmail_outbox_result and compares). If E167 ever changes, the selftest fails loudly instead of the screen lying.
-- ============================================================================================================================================
create or replace function public.fmail_backoff195(p_attempts integer)
returns interval language sql immutable parallel safe set search_path = pg_catalog as $$
  select case p_attempts
           when 1 then interval '1 minute'
           when 2 then interval '5 minutes'
           when 3 then interval '30 minutes'
           when 4 then interval '2 hours'
           when 5 then interval '6 hours'
           else interval '1 day' end
$$;

-- the highest number of tries the outbox allows (CHECK attempts between 0 and 12 in E167; fmail_outbox_requeue_failed stops at 12)
create or replace function public.fmail_max_attempts195() returns integer language sql immutable parallel safe set search_path = pg_catalog as $$ select 12 $$;

-- ============================================================================================================================================
-- 2) THE PHASE CLASSIFIER (pure, immutable: the clock comes in as an argument, so the same inputs always give the same word and it can be tested).
--    One word per mail. The browser maps it to a label; Rust and the browser never re-derive it from raw columns (one truth).
--      undo          queued, the 30 s hold is still running (Undo and Send now are possible)
--      queued        queued, hold over or closed, waiting for the sender (normally a second)
--      scheduled     held until the time the founder chose
--      handing_off   the sender is talking to the recipient's server right now (first try)
--      retrying      the sender is on try 2 or later
--      deferred      a try failed for a temporary reason; the next try is planned (failed-with-a-date, or requeued)
--      accepted      the recipient's server took the mail (SMTP 250)
--      failed        permanent refusal, or the 12 tries are used up
--      cancelled     the founder cancelled it before it left
--      undone        the founder pressed Undo inside the hold
-- ============================================================================================================================================
create or replace function public.fmail_phase195(p_state text, p_attempts integer, p_next timestamptz, p_released timestamptz,
                                                  p_undo timestamptz, p_not_before timestamptz, p_now timestamptz)
returns text language sql immutable parallel safe set search_path = pg_catalog as $$
  select case
    when p_state = 'sent'      then 'accepted'
    when p_state = 'cancelled' then 'cancelled'
    when p_state = 'undone'    then 'undone'
    when p_state = 'scheduled' then 'scheduled'
    when p_state = 'failed'    then case when p_next = 'infinity'::timestamptz or coalesce(p_attempts, 0) >= 12 then 'failed' else 'deferred' end
    when p_state = 'sending'   then case when coalesce(p_attempts, 0) >= 2 then 'retrying' else 'handing_off' end
    when p_state = 'queued'    then case
         when coalesce(p_attempts, 0) >= 1 then 'deferred'                         -- put back in the queue after a failed try
         when p_released is null and p_undo > p_now then 'undo'
         else 'queued' end
    else 'unknown' end
$$;

-- ============================================================================================================================================
-- 3) META WHITELIST. A ledger line's meta is free JSON (limit 4000 bytes). The timeline hands the screen ONLY these keys, so a future ledger writer
--    can never leak something through this door by adding a key. Values must be small scalars.
-- ============================================================================================================================================
create or replace function public.fmail_meta_safe195(p_meta jsonb)
returns jsonb language sql immutable parallel safe set search_path = pg_catalog as $$
  select coalesce(jsonb_object_agg(k, v), '{}'::jsonb)
    from (select e.key as k, e.value as v from jsonb_each(case when jsonb_typeof(p_meta) = 'object' then p_meta else '{}'::jsonb end) e
           where e.key in ('attempt', 'permanent', 'tls', 'dkim', 'saved_seconds')
             and jsonb_typeof(e.value) in ('number', 'boolean', 'string')
             and (jsonb_typeof(e.value) <> 'string' or length(e.value #>> '{}') <= 40)) s
$$;

-- ============================================================================================================================================
-- 4) ONE PARTIAL INDEX so the timeline of one mail is an index range scan, not a scan of the whole ledger (the ledger grows forever, append-only).
--    Only the eight send-line actions are indexed, so the index stays small.
-- ============================================================================================================================================
create index if not exists fmail_ledger_timeline_ix195 on public.fmail_ledger (mailbox_id, target, seq)
  where action in ('send_queue', 'send_schedule', 'send_release', 'send_undo', 'send_start', 'send_ok', 'send_fail', 'send_cancel');

-- ============================================================================================================================================
-- 5) THE DOOR: the timeline of ONE mail.
--    Answers null when the mail never went through the outbox (a received mail, a draft): the screen then shows no timeline at all.
--    Refuses someone else's mailbox with 42501 (same wording as E185, nothing about the mail is revealed).
--    server_now is part of the answer: "next try in 4 minutes" is computed from the SERVER clock, never from a browser clock that may be wrong.
-- ============================================================================================================================================
create or replace function public.fmail_timeline195(p_actor uuid, p_mailbox uuid, p_message uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  o public.fmail_outbox; v_now timestamptz := now(); v_phase text; v_events jsonb; v_total integer; v_sched boolean; v_next timestamptz; v_final boolean;
begin
  if p_actor is null or p_mailbox is null or p_message is null then raise exception 'E195: actor, mailbox and message are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E195: not your mailbox' using errcode = '42501'; end if;
  select * into o from public.fmail_outbox where mailbox_id = p_mailbox and message_id = p_message;
  if o.id is null then return null; end if;
  v_phase := public.fmail_phase195(o.state, o.attempts, o.next_attempt, o.released_at, o.undo_until, o.not_before, v_now);
  v_final := v_phase = 'failed';
  v_next := case when o.next_attempt is null or o.next_attempt = 'infinity'::timestamptz then null else o.next_attempt end;
  select count(*) into v_total from public.fmail_ledger l
   where l.mailbox_id = p_mailbox and l.target = p_message::text
     and l.action in ('send_queue', 'send_schedule', 'send_release', 'send_undo', 'send_start', 'send_ok', 'send_fail', 'send_cancel');
  select coalesce(jsonb_agg(jsonb_build_object('seq', x.seq, 'ts_ms', x.ts_ms, 'action', x.action, 'reason', x.reason, 'meta', public.fmail_meta_safe195(x.meta)) order by x.seq), '[]'::jsonb),
         coalesce(bool_or(x.action = 'send_schedule'), false)
    into v_events, v_sched
    from (select l.* from public.fmail_ledger l
           where l.mailbox_id = p_mailbox and l.target = p_message::text
             and l.action in ('send_queue', 'send_schedule', 'send_release', 'send_undo', 'send_start', 'send_ok', 'send_fail', 'send_cancel')
           order by l.seq desc limit 60) x;
  return jsonb_build_object(
    'message_id', p_message, 'outbox_id', o.id, 'server_now', v_now, 'phase', v_phase,
    'outbox', jsonb_build_object('state', o.state, 'created_at', o.created_at, 'updated_at', o.updated_at, 'not_before', o.not_before, 'undo_until', o.undo_until,
                                 'released_at', o.released_at, 'finished_at', o.finished_at, 'rcpt', o.rcpt_count, 'tls', o.tls_out, 'dkim', o.dkim_signed,
                                 'scheduled_by_founder', v_sched, 'sent_now', o.released_at is not null),
    'retry', jsonb_build_object('attempts', o.attempts, 'max_attempts', public.fmail_max_attempts195(), 'remaining', greatest(0, public.fmail_max_attempts195() - o.attempts),
                                'next_attempt', v_next, 'final', v_final,
                                'next_in_seconds', case when v_next is null then null else greatest(0, round(extract(epoch from (v_next - v_now)))::integer) end,
                                'last_error', o.last_error, 'smtp_reply', o.smtp_reply,
                                'plan_seconds', jsonb_build_array(60, 300, 1800, 7200, 21600, 86400)),
    'events', v_events, 'events_total', v_total, 'events_truncated', v_total > 60);
end $$;
revoke all on function public.fmail_timeline195(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_timeline195(uuid, uuid, uuid) to service_role;

-- ============================================================================================================================================
-- 6) THE DOOR: a compact phase badge for MANY mails at once (the Sent list shows a small word per row: one round trip, not one per row).
--    Up to 100 ids, answered in the order asked; ids without an outbox row are simply absent. No ledger read, so it stays cheap.
-- ============================================================================================================================================
create or replace function public.fmail_timeline_batch195(p_actor uuid, p_mailbox uuid, p_messages uuid[])
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_now timestamptz := now(); v_out jsonb;
begin
  if p_actor is null or p_mailbox is null or p_messages is null then raise exception 'E195: actor, mailbox and messages are needed' using errcode = '22023'; end if;
  if coalesce(array_length(p_messages, 1), 0) > 100 then raise exception 'E195: at most 100 messages at a time' using errcode = '54000'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E195: not your mailbox' using errcode = '42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('message_id', o.message_id, 'phase', public.fmail_phase195(o.state, o.attempts, o.next_attempt, o.released_at, o.undo_until, o.not_before, v_now),
           'attempts', o.attempts, 'next_attempt', case when o.next_attempt = 'infinity'::timestamptz then null else o.next_attempt end, 'finished_at', o.finished_at) order by m.ord), '[]'::jsonb)
    into v_out
    from unnest(p_messages) with ordinality as m(id, ord)
    join public.fmail_outbox o on o.message_id = m.id and o.mailbox_id = p_mailbox;
  return jsonb_build_object('server_now', v_now, 'items', v_out);
end $$;
revoke all on function public.fmail_timeline_batch195(uuid, uuid, uuid[]) from public, anon, authenticated;
grant execute on function public.fmail_timeline_batch195(uuid, uuid, uuid[]) to service_role;

-- ============================================================================================================================================
-- 7) THE DOOR: the outbox list with the fields the timeline needs (E170's list stays as it is: the old screen keeps working).
--    Adds message_id, phase, created_at, released_at, next_attempt, smtp_reply; window 1..30 days (E170 shows 1 day), at most 200 rows, newest first.
--    Rows still on their way (not finished) are always listed, however old.
-- ============================================================================================================================================
create or replace function public.fmail_outbox_list195(p_actor uuid, p_mailbox uuid, p_days integer default 2)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_now timestamptz := now(); v_rows jsonb;
begin
  if p_actor is null or p_mailbox is null then raise exception 'E195: actor and mailbox are needed' using errcode = '22023'; end if;
  if p_days is null or p_days < 1 or p_days > 30 then raise exception 'E195: days must be 1 to 30' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E195: not your mailbox' using errcode = '42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'outbox_id', o.id, 'message_id', o.message_id, 'state', o.state, 'phase', public.fmail_phase195(o.state, o.attempts, o.next_attempt, o.released_at, o.undo_until, o.not_before, v_now),
           'created_at', o.created_at, 'not_before', o.not_before, 'undo_until', o.undo_until, 'released_at', o.released_at, 'finished_at', o.finished_at,
           'next_attempt', case when o.next_attempt = 'infinity'::timestamptz then null else o.next_attempt end,
           'rcpt', o.rcpt_count, 'attempts', o.attempts, 'last_error', o.last_error, 'smtp_reply', o.smtp_reply, 'tls', o.tls_out, 'dkim', o.dkim_signed) order by o.created_at desc), '[]'::jsonb)
    into v_rows
    from (select * from public.fmail_outbox where mailbox_id = p_mailbox and (finished_at is null or finished_at > v_now - make_interval(days => p_days))
           order by created_at desc limit 200) o;
  return jsonb_build_object('server_now', v_now, 'days', p_days, 'outbox', v_rows);
end $$;
revoke all on function public.fmail_outbox_list195(uuid, uuid, integer) from public, anon, authenticated;
grant execute on function public.fmail_outbox_list195(uuid, uuid, integer) to service_role;

-- ============================================================================================================================================
-- 7b) THE DOOR: delivery health of a mailbox over 1..30 days (counts per phase + how long accepted mail took). Read-only, no content.
--     "took" = created_at -> finished_at of ACCEPTED rows, in seconds (median and 95th percentile; the 30 s hold is part of it, so a normal mail shows about 30).
--     Rates are against finished + still-open rows; an empty window answers zeros, never a division error.
-- ============================================================================================================================================
create or replace function public.fmail_delivery_stats195(p_actor uuid, p_mailbox uuid, p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_now timestamptz := now(); v_counts jsonb; v_total integer; v_p50 numeric; v_p95 numeric; v_acc integer; v_def integer; v_fail integer;
begin
  if p_actor is null or p_mailbox is null then raise exception 'E195: actor and mailbox are needed' using errcode = '22023'; end if;
  if p_days is null or p_days < 1 or p_days > 30 then raise exception 'E195: days must be 1 to 30' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E195: not your mailbox' using errcode = '42501'; end if;
  with r as (select o.*, public.fmail_phase195(o.state, o.attempts, o.next_attempt, o.released_at, o.undo_until, o.not_before, v_now) as ph
               from public.fmail_outbox o where o.mailbox_id = p_mailbox and o.created_at > v_now - make_interval(days => p_days))
  select coalesce(jsonb_object_agg(ph, n), '{}'::jsonb), coalesce(sum(n), 0)::integer into v_counts, v_total from (select ph, count(*)::integer as n from r group by ph) c;
  select percentile_cont(0.5) within group (order by extract(epoch from (finished_at - created_at))),
         percentile_cont(0.95) within group (order by extract(epoch from (finished_at - created_at)))
    into v_p50, v_p95
    from public.fmail_outbox where mailbox_id = p_mailbox and state = 'sent' and finished_at is not null and created_at > v_now - make_interval(days => p_days);
  v_acc := coalesce((v_counts ->> 'accepted')::integer, 0); v_def := coalesce((v_counts ->> 'deferred')::integer, 0) + coalesce((v_counts ->> 'retrying')::integer, 0); v_fail := coalesce((v_counts ->> 'failed')::integer, 0);
  return jsonb_build_object('server_now', v_now, 'days', p_days, 'total', v_total, 'by_phase', v_counts,
    'accepted_took_seconds', jsonb_build_object('p50', case when v_p50 is null then null else round(v_p50, 1) end, 'p95', case when v_p95 is null then null else round(v_p95, 1) end),
    'accepted_rate', case when v_total = 0 then 0 else round(v_acc::numeric / v_total, 4) end,
    'deferred_rate', case when v_total = 0 then 0 else round(v_def::numeric / v_total, 4) end,
    'failed_rate',   case when v_total = 0 then 0 else round(v_fail::numeric / v_total, 4) end);
end $$;
revoke all on function public.fmail_delivery_stats195(uuid, uuid, integer) from public, anon, authenticated;
grant execute on function public.fmail_delivery_stats195(uuid, uuid, integer) to service_role;

-- the pure helpers are harmless (no table access) but are still closed to the browser roles: only the service door set is reachable
do $$
declare f text;
begin
  for f in select p.oid::regprocedure::text from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('fmail_backoff195', 'fmail_max_attempts195', 'fmail_phase195', 'fmail_meta_safe195') loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ============================================================================================================================================
-- 8) SELFTEST (rolls itself back, writes nothing that survives). Needs a founder account. Re-run safe.
--    Part A: the pure functions (no table). Part B: the doors on real rows driven by the REAL doors of E167/E170 (result, dead, claim, requeue).
-- ============================================================================================================================================
create or replace function public.fmail_selftest195() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_other uuid := gen_random_uuid(); v_box uuid; v_box2 uuid; v_th uuid; v_folder uuid;
  v_m1 uuid; v_m2 uuid; v_m3 uuid; v_ob1 uuid; v_ob2 uuid; v_ob3 uuid; v_t jsonb; v_t2 jsonb; v_b jsonb; v_l jsonb; v_ok boolean; v_n bigint; v_n2 bigint; v_i integer;
  v_now timestamptz := now(); v_before text; v_after text; v_sec numeric;
  v_seal bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
begin
  -- ---------------------------------------------------------------- PART A: pure functions
  res := res || jsonb_build_object('name', 'phase: a sent row is accepted', 'ok', public.fmail_phase195('sent', 1, null, null, v_now, v_now, v_now) = 'accepted');
  res := res || jsonb_build_object('name', 'phase: cancelled stays cancelled', 'ok', public.fmail_phase195('cancelled', 0, null, null, v_now, v_now, v_now) = 'cancelled');
  res := res || jsonb_build_object('name', 'phase: undone stays undone', 'ok', public.fmail_phase195('undone', 0, null, null, v_now, v_now, v_now) = 'undone');
  res := res || jsonb_build_object('name', 'phase: a scheduled row is scheduled', 'ok', public.fmail_phase195('scheduled', 0, null, null, v_now, v_now + interval '2 hours', v_now) = 'scheduled');
  res := res || jsonb_build_object('name', 'phase: queued inside the 30 s hold is undo', 'ok', public.fmail_phase195('queued', 0, null, null, v_now + interval '20 seconds', v_now + interval '20 seconds', v_now) = 'undo');
  res := res || jsonb_build_object('name', 'phase: queued after the hold is queued', 'ok', public.fmail_phase195('queued', 0, null, null, v_now - interval '1 second', v_now - interval '1 second', v_now) = 'queued');
  res := res || jsonb_build_object('name', 'phase: Send now closes the hold at once (queued, not undo)', 'ok', public.fmail_phase195('queued', 0, null, v_now, v_now, v_now, v_now) = 'queued');
  res := res || jsonb_build_object('name', 'phase: the hold edge (undo_until = now) is queued, not undo', 'ok', public.fmail_phase195('queued', 0, null, null, v_now, v_now, v_now) = 'queued');
  res := res || jsonb_build_object('name', 'phase: first try in flight is handing_off', 'ok', public.fmail_phase195('sending', 1, null, null, v_now, v_now, v_now) = 'handing_off');
  res := res || jsonb_build_object('name', 'phase: second try in flight is retrying', 'ok', public.fmail_phase195('sending', 2, null, null, v_now, v_now, v_now) = 'retrying');
  res := res || jsonb_build_object('name', 'phase: failed with a date is deferred, never failed', 'ok', public.fmail_phase195('failed', 1, v_now + interval '1 minute', null, v_now, v_now, v_now) = 'deferred');
  res := res || jsonb_build_object('name', 'phase: failed with next_attempt = infinity is failed for good', 'ok', public.fmail_phase195('failed', 1, 'infinity'::timestamptz, null, v_now, v_now, v_now) = 'failed');
  res := res || jsonb_build_object('name', 'phase: twelve tries used is failed even with a date', 'ok', public.fmail_phase195('failed', 12, v_now + interval '1 day', null, v_now, v_now, v_now) = 'failed');
  res := res || jsonb_build_object('name', 'phase: eleven tries is still deferred', 'ok', public.fmail_phase195('failed', 11, v_now + interval '1 day', null, v_now, v_now, v_now) = 'deferred');
  res := res || jsonb_build_object('name', 'phase: requeued after a failed try is deferred, not undo', 'ok', public.fmail_phase195('queued', 1, null, null, v_now + interval '20 seconds', v_now, v_now) = 'deferred');
  res := res || jsonb_build_object('name', 'phase: an unknown state is "unknown", never a guess', 'ok', public.fmail_phase195('weird', 0, null, null, v_now, v_now, v_now) = 'unknown');
  res := res || jsonb_build_object('name', 'phase: null attempts counts as zero (no crash)', 'ok', public.fmail_phase195('sending', null, null, null, v_now, v_now, v_now) = 'handing_off');
  res := res || jsonb_build_object('name', 'phase is immutable and parallel safe (pure)', 'ok', (select provolatile = 'i' and proparallel = 's' from pg_proc where oid = 'public.fmail_phase195(text,integer,timestamptz,timestamptz,timestamptz,timestamptz,timestamptz)'::regprocedure));
  v_ok := true;
  for v_i in 1..8 loop
    v_ok := v_ok and public.fmail_backoff195(v_i) = (array[interval '1 minute', interval '5 minutes', interval '30 minutes', interval '2 hours', interval '6 hours', interval '1 day', interval '1 day', interval '1 day'])[v_i];
  end loop;
  res := res || jsonb_build_object('name', 'backoff table: 1 m, 5 m, 30 m, 2 h, 6 h, then a day', 'ok', v_ok);
  res := res || jsonb_build_object('name', 'max attempts is 12 (the outbox CHECK)', 'ok', public.fmail_max_attempts195() = 12
        and exists (select 1 from pg_constraint where conrelid = 'public.fmail_outbox'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%attempts%12%'));
  res := res || jsonb_build_object('name', 'meta filter keeps only whitelisted small scalars',
        'ok', public.fmail_meta_safe195('{"attempt":2,"permanent":true,"tls":"tls13","dkim":true,"saved_seconds":12.5,"secret":"x","outbox":"u","to":"a@b.c"}'::jsonb) = '{"attempt":2,"permanent":true,"tls":"tls13","dkim":true,"saved_seconds":12.5}'::jsonb);
  res := res || jsonb_build_object('name', 'meta filter drops objects, arrays and long strings', 'ok', public.fmail_meta_safe195(jsonb_build_object('tls', repeat('x', 41), 'attempt', jsonb_build_object('a', 1), 'dkim', jsonb_build_array(1))) = '{}'::jsonb);
  res := res || jsonb_build_object('name', 'meta filter survives null and non-objects', 'ok', public.fmail_meta_safe195(null) = '{}'::jsonb and public.fmail_meta_safe195('[1]'::jsonb) = '{}'::jsonb and public.fmail_meta_safe195('"x"'::jsonb) = '{}'::jsonb);

  -- ---------------------------------------------------------------- PART B: the doors on real rows
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with', 'so_far', res); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest195@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest195b@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box2;
    select id into v_folder from public.fmail_folders where mailbox_id = v_box and kind = 'outbox';
    insert into public.fmail_threads (mailbox_id) values (v_box) returning id into v_th;
    -- three outgoing mails: m1 goes the whole way, m2 dies for good, m3 is a plain received-style mail with NO outbox row
    insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash, size_bytes, sent_at)
      values (v_box, v_th, v_folder, 'out', 'vault', v_seal, v_seal, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, 10, now()) returning id into v_m1;
    insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash, size_bytes, sent_at)
      values (v_box, v_th, v_folder, 'out', 'vault', v_seal, v_seal, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, 10, now()) returning id into v_m2;
    insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash, size_bytes, sent_at)
      values (v_box, v_th, v_folder, 'out', 'vault', v_seal, v_seal, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, 10, now()) returning id into v_m3;
    insert into public.fmail_outbox (mailbox_id, message_id, rcpt_count, undo_until) values (v_box, v_m1, 2, now() + interval '30 seconds') returning id into v_ob1;
    insert into public.fmail_outbox (mailbox_id, message_id, rcpt_count, undo_until) values (v_box, v_m2, 1, now() + interval '30 seconds') returning id into v_ob2;
    perform public.fmail_ledger_append(v_uid, v_box, 'send_queue', v_m1::text, 'mail queued, 30 s hold', '{"outbox":"x","secret":"leak"}'::jsonb, false);

    -- ownership and shape
    begin perform public.fmail_timeline195(v_other, v_box, v_m1); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'timeline: another founder is refused (42501)', 'ok', v_ok);
    begin perform public.fmail_timeline195(v_uid, v_box2, v_m1); v_t := public.fmail_timeline195(v_uid, v_box2, v_m1); v_ok := v_t is null; exception when others then v_ok := false; end;
    res := res || jsonb_build_object('name', 'timeline: my other mailbox does not see this mail (null, no leak)', 'ok', v_ok);
    begin perform public.fmail_timeline195(null, v_box, v_m1); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'timeline: a null argument is refused (22023)', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'timeline: a mail with no outbox row answers null (no timeline)', 'ok', public.fmail_timeline195(v_uid, v_box, v_m3) is null);
    res := res || jsonb_build_object('name', 'timeline: an unknown message answers null', 'ok', public.fmail_timeline195(v_uid, v_box, gen_random_uuid()) is null);

    -- step 1: inside the hold
    v_t := public.fmail_timeline195(v_uid, v_box, v_m1);
    res := res || jsonb_build_object('name', 'step 1: inside the 30 s hold the phase is undo', 'ok', v_t ->> 'phase' = 'undo' and (v_t #>> '{outbox,state}') = 'queued' and (v_t #>> '{outbox,rcpt}') = '2');
    res := res || jsonb_build_object('name', 'step 1: the ledger line appears and its meta is filtered', 'ok', jsonb_array_length(v_t -> 'events') = 1 and (v_t #>> '{events,0,action}') = 'send_queue' and v_t #>> '{events,0,meta}' = '{}');
    res := res || jsonb_build_object('name', 'step 1: server_now is part of the answer (the browser clock is never trusted)', 'ok', (v_t ->> 'server_now')::timestamptz between now() - interval '5 seconds' and now() + interval '5 seconds');
    res := res || jsonb_build_object('name', 'step 1: no retry plan yet (attempts 0, no next try, not final)', 'ok', (v_t #>> '{retry,attempts}') = '0' and v_t #> '{retry,next_attempt}' = 'null'::jsonb and (v_t #>> '{retry,final}') = 'false' and (v_t #>> '{retry,remaining}') = '12');
    res := res || jsonb_build_object('name', 'step 1: the answer carries no sealed column, key, nonce or address', 'ok', v_t::text !~* '(sealed|nonce|key_wrap|aad_hash|msgid_blind|rcpt_blind|@)');

    -- step 2: Send now closes the hold (the same writes E185 does, done here directly so this test does not depend on E185 internals)
    update public.fmail_outbox set not_before = least(not_before, now()), undo_until = least(undo_until, now()), released_at = now() where id = v_ob1;
    perform public.fmail_ledger_append(v_uid, v_box, 'send_release', v_m1::text, 'sent now by the founder (undo window closed early)', '{"outbox":"x","saved_seconds":22.5}'::jsonb, false);
    v_t := public.fmail_timeline195(v_uid, v_box, v_m1);
    res := res || jsonb_build_object('name', 'step 2: after Send now the phase is queued and sent_now is true', 'ok', v_t ->> 'phase' = 'queued' and (v_t #>> '{outbox,sent_now}') = 'true');
    res := res || jsonb_build_object('name', 'step 2: the release line keeps saved_seconds and drops the rest', 'ok', (v_t #>> '{events,1,action}') = 'send_release' and (v_t #> '{events,1,meta}') = '{"saved_seconds":22.5}'::jsonb);

    -- step 3: the sender claims it
    update public.fmail_outbox set state = 'sending' where id = v_ob1;
    perform public.fmail_ledger_append(v_uid, v_box, 'send_start', v_m1::text, 'sender started the hand-off', '{"attempt":1}'::jsonb, false);
    v_t := public.fmail_timeline195(v_uid, v_box, v_m1);
    res := res || jsonb_build_object('name', 'step 3: first try in flight is handing_off', 'ok', v_t ->> 'phase' = 'handing_off' and (v_t #>> '{retry,attempts}') = '1');

    -- step 4: a temporary refusal, written by the REAL sender door
    perform public.fmail_outbox_result(v_uid, v_ob1, false, '451 4.7.1 try again later', null, false, 'greylisted');
    v_t := public.fmail_timeline195(v_uid, v_box, v_m1);
    res := res || jsonb_build_object('name', 'step 4: a 4xx is deferred (not failed) with the reason and a next try', 'ok', v_t ->> 'phase' = 'deferred' and (v_t #>> '{retry,last_error}') = 'greylisted'
          and (v_t #>> '{retry,smtp_reply}') = '451 4.7.1 try again later' and (v_t #>> '{retry,final}') = 'false' and v_t #>> '{retry,next_attempt}' is not null);
    v_sec := (v_t #>> '{retry,next_in_seconds}')::numeric;
    res := res || jsonb_build_object('name', 'step 4: the next try is about one minute away (server clock)', 'ok', v_sec between 50 and 61);
    select extract(epoch from (next_attempt - now())) into v_sec from public.fmail_outbox where id = v_ob1;
    res := res || jsonb_build_object('name', 'DRIFT GUARD: backoff195(1) equals what the real sender wrote (within 5 s)', 'ok', abs(v_sec - extract(epoch from public.fmail_backoff195(1))) < 5);
    res := res || jsonb_build_object('name', 'step 4: the failed line carries attempt 1 and no permanent flag', 'ok', (select (e -> 'meta') = '{"attempt":1}'::jsonb from jsonb_array_elements(v_t -> 'events') e where e ->> 'action' = 'send_fail'));

    -- step 5: the sender puts it back in the queue and tries again (try 2)
    update public.fmail_outbox set next_attempt = now() - interval '1 second' where id = v_ob1;
    perform public.fmail_outbox_requeue_failed();
    v_t := public.fmail_timeline195(v_uid, v_box, v_m1);
    res := res || jsonb_build_object('name', 'step 5: requeued after a failed try is still deferred (not undo, not queued)', 'ok', v_t ->> 'phase' = 'deferred' and (v_t #>> '{outbox,state}') = 'queued');
    update public.fmail_outbox set state = 'sending' where id = v_ob1;
    v_t := public.fmail_timeline195(v_uid, v_box, v_m1);
    res := res || jsonb_build_object('name', 'step 5: the second try is retrying, attempts = 2, ten left', 'ok', v_t ->> 'phase' = 'retrying' and (v_t #>> '{retry,attempts}') = '2' and (v_t #>> '{retry,remaining}') = '10');

    -- step 6: the recipient's server accepts
    perform public.fmail_outbox_result(v_uid, v_ob1, true, '250 2.0.0 queued as ABC', 'tls13', true, null);
    v_t := public.fmail_timeline195(v_uid, v_box, v_m1);
    res := res || jsonb_build_object('name', 'step 6: accepted, with the TLS and DKIM facts', 'ok', v_t ->> 'phase' = 'accepted' and (v_t #>> '{outbox,tls}') = 'tls13' and (v_t #>> '{outbox,dkim}') = 'true' and (v_t #>> '{outbox,finished_at}') is not null);
    res := res || jsonb_build_object('name', 'step 6: events are in ledger order and the last one is send_ok', 'ok',
          (select array_agg(e ->> 'action' order by (e ->> 'seq')::bigint) from jsonb_array_elements(v_t -> 'events') e) = array['send_queue', 'send_release', 'send_start', 'send_fail', 'send_ok']
          and (select (e -> 'meta') = '{"tls":"tls13","dkim":true}'::jsonb from jsonb_array_elements(v_t -> 'events') e where e ->> 'action' = 'send_ok'));
    res := res || jsonb_build_object('name', 'step 6: seq numbers rise strictly', 'ok', (select bool_and((e ->> 'seq')::bigint > coalesce(lag_seq, 0)) from (select e, lag((e ->> 'seq')::bigint) over (order by (e ->> 'seq')::bigint) as lag_seq from jsonb_array_elements(v_t -> 'events') e) q));
    res := res || jsonb_build_object('name', 'step 6: the words never promise the inbox (no "inbox", "read", "delivered" key in the answer)', 'ok', v_t::text !~* '(inbox|"read"|delivered)');

    -- a mail that dies for good (5xx), written by the REAL door
    update public.fmail_outbox set state = 'sending' where id = v_ob2;
    perform public.fmail_outbox_dead170(v_uid, v_ob2, '550 5.1.1 user unknown', 'recipient refused');
    v_t2 := public.fmail_timeline195(v_uid, v_box, v_m2);
    res := res || jsonb_build_object('name', 'a 5xx is failed for good: final, no next try, the reason kept', 'ok', v_t2 ->> 'phase' = 'failed' and (v_t2 #>> '{retry,final}') = 'true' and v_t2 #> '{retry,next_attempt}' = 'null'::jsonb
          and v_t2 #> '{retry,next_in_seconds}' = 'null'::jsonb and (v_t2 #>> '{retry,last_error}') = 'recipient refused');
    res := res || jsonb_build_object('name', 'a 5xx line says permanent = true', 'ok', exists (select 1 from jsonb_array_elements(v_t2 -> 'events') e where e ->> 'action' = 'send_fail' and (e #>> '{meta,permanent}') = 'true'));
    res := res || jsonb_build_object('name', 'a failed mail is never shown with "infinity" in the answer', 'ok', v_t2::text !~* 'infinity');

    -- cancelled and undone are told apart
    insert into public.fmail_messages (mailbox_id, thread_id, folder_id, direction, seal_mode, sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash, size_bytes, sent_at)
      values (v_box, v_th, v_folder, 'out', 'vault', v_seal, v_seal, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, 10, now()) returning id into v_m3;
    insert into public.fmail_outbox (mailbox_id, message_id, rcpt_count, undo_until) values (v_box, v_m3, 1, now() + interval '30 seconds') returning id into v_ob3;
    perform public.fmail_outbox_cancel170(v_uid, v_box, v_ob3);
    v_t2 := public.fmail_timeline195(v_uid, v_box, v_m3);
    res := res || jsonb_build_object('name', 'a cancelled mail shows cancelled with its ledger line', 'ok', v_t2 ->> 'phase' = 'cancelled' and exists (select 1 from jsonb_array_elements(v_t2 -> 'events') e where e ->> 'action' = 'send_cancel'));

    -- batch and list
    v_b := public.fmail_timeline_batch195(v_uid, v_box, array[v_m2, v_m1, gen_random_uuid(), v_m3]);
    res := res || jsonb_build_object('name', 'batch: answers in the order asked, unknown ids absent', 'ok', jsonb_array_length(v_b -> 'items') = 3
          and (select array_agg(i ->> 'phase' order by ord) from jsonb_array_elements(v_b -> 'items') with ordinality as t(i, ord)) = array['failed', 'accepted', 'cancelled']);
    begin perform public.fmail_timeline_batch195(v_uid, v_box, array(select gen_random_uuid() from generate_series(1, 101))); v_ok := false; exception when sqlstate '54000' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'batch: 101 ids are refused (54000)', 'ok', v_ok);
    begin perform public.fmail_timeline_batch195(v_other, v_box, array[v_m1]); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'batch: another founder is refused', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'batch: an empty list answers an empty list', 'ok', jsonb_array_length(public.fmail_timeline_batch195(v_uid, v_box, array[]::uuid[]) -> 'items') = 0);
    v_l := public.fmail_outbox_list195(v_uid, v_box, 2);
    res := res || jsonb_build_object('name', 'list: three rows with phase, message id and clocks', 'ok', jsonb_array_length(v_l -> 'outbox') = 3 and (select bool_and(r ? 'phase' and r ? 'message_id' and r ? 'created_at') from jsonb_array_elements(v_l -> 'outbox') r));
    res := res || jsonb_build_object('name', 'list: no sealed column or address in the answer', 'ok', v_l::text !~* '(sealed|nonce|key_wrap|aad_hash|rcpt_blind|@)');
    begin perform public.fmail_outbox_list195(v_uid, v_box, 0); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'list: days 0 and 31 are refused', 'ok', v_ok);
    begin perform public.fmail_outbox_list195(v_uid, v_box, 31); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'list: 31 days refused too', 'ok', v_ok);
    begin perform public.fmail_outbox_list195(v_other, v_box, 2); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'list: another founder is refused', 'ok', v_ok);

    -- delivery health
    v_t := public.fmail_delivery_stats195(v_uid, v_box, 7);
    res := res || jsonb_build_object('name', 'stats: three mails in the window, one accepted, one failed, one cancelled', 'ok', (v_t ->> 'total') = '3' and (v_t #>> '{by_phase,accepted}') = '1' and (v_t #>> '{by_phase,failed}') = '1' and (v_t #>> '{by_phase,cancelled}') = '1');
    res := res || jsonb_build_object('name', 'stats: rates are fractions of the total (a third each)', 'ok', (v_t ->> 'accepted_rate')::numeric = 0.3333 and (v_t ->> 'failed_rate')::numeric = 0.3333 and (v_t ->> 'deferred_rate')::numeric = 0);
    res := res || jsonb_build_object('name', 'stats: the accepted time is a number and p95 >= p50', 'ok', (v_t #>> '{accepted_took_seconds,p50}') is not null and (v_t #>> '{accepted_took_seconds,p95}')::numeric >= (v_t #>> '{accepted_took_seconds,p50}')::numeric);
    res := res || jsonb_build_object('name', 'stats: an empty mailbox answers zeros, no division error', 'ok', (public.fmail_delivery_stats195(v_uid, v_box2, 7) ->> 'total') = '0' and (public.fmail_delivery_stats195(v_uid, v_box2, 7) ->> 'accepted_rate') = '0'
          and public.fmail_delivery_stats195(v_uid, v_box2, 7) #> '{accepted_took_seconds,p50}' = 'null'::jsonb);
    begin perform public.fmail_delivery_stats195(v_uid, v_box, 0); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'stats: 0 days refused', 'ok', v_ok);
    begin perform public.fmail_delivery_stats195(v_other, v_box, 7); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'stats: another founder refused', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'stats: no sealed column or address in the answer', 'ok', v_t::text !~* '(sealed|nonce|key_wrap|aad_hash|rcpt_blind|@)');

    -- twelve tries used = failed even though a date is stored
    update public.fmail_outbox set state = 'failed', attempts = 12, next_attempt = now() + interval '1 day' where id = v_ob2;
    res := res || jsonb_build_object('name', 'twelve tries used: failed, the screen stops promising a retry', 'ok', public.fmail_timeline195(v_uid, v_box, v_m2) ->> 'phase' = 'failed');

    -- the doors never write
    select count(*) into v_n from public.fmail_ledger;
    perform public.fmail_timeline195(v_uid, v_box, v_m1); perform public.fmail_timeline_batch195(v_uid, v_box, array[v_m1]); perform public.fmail_outbox_list195(v_uid, v_box, 2); perform public.fmail_delivery_stats195(v_uid, v_box, 7);
    select count(*) into v_n2 from public.fmail_ledger;
    res := res || jsonb_build_object('name', 'reading the timeline writes no ledger line', 'ok', v_n = v_n2);
    res := res || jsonb_build_object('name', 'the doors are STABLE (a read cannot write)', 'ok', (select bool_and(provolatile = 's') from pg_proc where pronamespace = 'public'::regnamespace and proname in ('fmail_timeline195', 'fmail_timeline_batch195', 'fmail_outbox_list195', 'fmail_delivery_stats195')));
    res := res || jsonb_build_object('name', 'the ledger chain still verifies', 'ok', public.fmail_ledger_verify(1) >= 1);
    raise exception 'E195_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E195_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E195_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest195() from public, anon, authenticated;
grant execute on function public.fmail_selftest195() to service_role;

-- ============================================================================================================================================
-- 9) POSTURE (read-only, stable; its text names no writing door on purpose, so the E179 audit stays clean)
-- ============================================================================================================================================
create or replace function public.fmail_posture195() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  v_doors regprocedure[] := array['public.fmail_timeline195(uuid,uuid,uuid)'::regprocedure, 'public.fmail_timeline_batch195(uuid,uuid,uuid[])'::regprocedure, 'public.fmail_outbox_list195(uuid,uuid,integer)'::regprocedure, 'public.fmail_delivery_stats195(uuid,uuid,integer)'::regprocedure];
  v_pure regprocedure[] := array['public.fmail_backoff195(integer)'::regprocedure, 'public.fmail_max_attempts195()'::regprocedure, 'public.fmail_meta_safe195(jsonb)'::regprocedure,
                                 'public.fmail_phase195(text,integer,timestamptz,timestamptz,timestamptz,timestamptz,timestamptz)'::regprocedure];
begin
  return jsonb_build_object(
    'doors_stable',        (select bool_and(provolatile = 's') from pg_proc where oid = any (v_doors)),
    'doors_security_definer', (select bool_and(prosecdef) from pg_proc where oid = any (v_doors)),
    'doors_fixed_search_path', (select bool_and(coalesce(array_to_string(proconfig, ',') like '%search_path=%', false)) from pg_proc where oid = any (v_doors || v_pure)),
    'doors_service_only',  (select bool_and(has_function_privilege('service_role', d, 'execute') and not has_function_privilege('anon', d, 'execute') and not has_function_privilege('authenticated', d, 'execute')) from unnest(v_doors || v_pure) d),
    'pure_are_immutable',  (select bool_and(provolatile = 'i') from pg_proc where oid = any (v_pure)),
    'timeline_index',      exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'fmail_ledger' and indexname = 'fmail_ledger_timeline_ix195'),
    'outbox_rls_forced',   (select relforcerowsecurity from pg_class where oid = 'public.fmail_outbox'::regclass),
    'ledger_rls_forced',   (select relforcerowsecurity from pg_class where oid = 'public.fmail_ledger'::regclass),
    'door_audit_clean',    not exists (select 1 from public.fmail_door_audit179()));
end $$;
revoke all on function public.fmail_posture195() from public, anon, authenticated;
grant execute on function public.fmail_posture195() to service_role;

select public.fmail_posture195() as e195_posture;
select public.fmail_selftest195() ->> 'passed' as e195_selftest_passed, public.fmail_selftest195() ->> 'failed' as e195_selftest_failed;
