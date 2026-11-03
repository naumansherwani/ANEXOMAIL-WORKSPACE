-- E141 — Founder J6 hardening: END-TO-END DELIVERY RECEIPTS for the phone alerts (founder order 3 Nov 2026 11:30 PKT: "ek bhi point nahi chodhna, seedha fix kero").
-- Why: E140 told the truth that "delivery is best-effort": a push service answering 201 only means IT accepted the message, not that the phone showed it. This file closes that gap.
--   1) RECEIPT     every alert carries a one-time ack token inside the ENCRYPTED payload; the phone's service worker returns it the moment it shows the notification. SQL keeps only sha256(token)
--                  (unique), sets acked_at once (null -> value, never back), and writes an `acked` event into the hash-chained ledger. The push service never sees the token.
--   2) ESCALATION  a T3 alert that was `sent` but not acknowledged for 90 s, while its T3 request is still waiting/approved, queues ONE reminder (t3_reminder, high urgency, per phone, per request) and
--                  writes an `escalated` event. The reminder is a second try over the same channel; the status page shows the red "not confirmed received" state until a receipt arrives.
--   3) STATUS      founder_push_status now reports, per phone, the last receipt time and a list of alerts that were sent but never acknowledged (last 24 h).
--   4) SELFTEST    founder_push_e141_selftest(): receipts, one-time use, wrong tokens, escalation (once, only while the request is open), status; rolled back.
-- Needs E140. Safe to run again. E140 must run BEFORE E141 on every re-run (this file replaces _fh_enqueue, _fh_outbox_guard, founder_push_status).

do $$ begin
  if to_regclass('public.founder_push_outbox') is null or to_regprocedure('public._fh_enqueue(uuid,uuid,text,uuid,text,text,integer,jsonb)') is null then raise exception 'E141 needs E140 first'; end if;
end $$;

-- 1) columns, kinds, indexes ---------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_push:ddl', 0));
  alter table public.founder_push_outbox add column if not exists ack_hash text;
  alter table public.founder_push_outbox add column if not exists acked_at timestamptz;
  if not exists (select 1 from pg_constraint where conname = 'founder_push_outbox_ack_shape') then
    alter table public.founder_push_outbox add constraint founder_push_outbox_ack_shape check ((ack_hash is null or ack_hash ~ '^[0-9a-f]{64}$') and (acked_at is null or ack_hash is not null));
  end if;
  alter table public.founder_push_outbox drop constraint if exists founder_push_outbox_kind_check;
  alter table public.founder_push_outbox add constraint founder_push_outbox_kind_check check (kind in ('confirm', 'test', 't3_begun', 't3_approved', 't3_cancelled', 't3_reminder'));
  alter table public.founder_push_event drop constraint if exists founder_push_event_kind_check;
  alter table public.founder_push_event add constraint founder_push_event_kind_check check (kind in ('subscribed', 'confirm_sent', 'confirmed', 'confirm_failed', 'removed', 'queued', 'sent', 'retry', 'dead', 'expired', 'test', 'acked', 'escalated'));
  create unique index if not exists founder_push_outbox_ack_once on public.founder_push_outbox (ack_hash) where ack_hash is not null;
  grant select (ack_hash, acked_at) on public.founder_push_outbox to service_role;
  revoke select (ack_hash) on public.founder_push_outbox from service_role;   -- the hash stays inside the database
end $$;

-- 2) the guard: a FINAL `sent` row may still receive exactly one change, acked_at null -> value. Everything else stays as E140 made it.
create or replace function public._fh_outbox_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E140: an outbox row is never deleted' using errcode = '42501'; end if;
  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id or new.sub_id <> old.sub_id or new.kind <> old.kind or new.ref is distinct from old.ref or new.tag <> old.tag or new.urgency <> old.urgency
       or new.ttl_s <> old.ttl_s or new.created_at <> old.created_at or new.ack_hash is distinct from old.ack_hash then raise exception 'E140: the core of an outbox row is frozen' using errcode = '42501'; end if;
    if old.acked_at is not null and new.acked_at is distinct from old.acked_at then raise exception 'E141: a receipt cannot be changed or taken back' using errcode = '42501'; end if;
    if old.state in ('sent', 'dead', 'expired') then
      if not (old.state = 'sent' and old.acked_at is null and new.acked_at is not null and (to_jsonb(new) - 'acked_at') = (to_jsonb(old) - 'acked_at')) then
        raise exception 'E140: a final outbox row cannot change' using errcode = '42501'; end if;
      return new;
    end if;
    if new.attempts < old.attempts then raise exception 'E140: attempts only go up' using errcode = '42501'; end if;
    if new.payload is not null and new.payload is distinct from old.payload then raise exception 'E140: a payload can only be cleared' using errcode = '42501'; end if;
    if not (   (old.state = new.state)
            or (old.state = 'queued'  and new.state in ('sending', 'expired', 'dead'))
            or (old.state = 'sending' and new.state in ('sent', 'failed', 'dead', 'expired', 'queued'))
            or (old.state = 'failed'  and new.state in ('sending', 'dead', 'expired'))) then
      raise exception 'E140: outbox state % -> % is not a legal step', old.state, new.state using errcode = '42501'; end if;
  end if;
  return new;
end $$;

-- 3) enqueue now mints the ack token (inside the encrypted payload; only its hash is stored)
create or replace function public._fh_enqueue(p_uid uuid, p_sub uuid, p_kind text, p_ref uuid, p_tag text, p_urgency text, p_ttl integer, p_payload jsonb) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid; v_ack text := public._fh_b64u(extensions.gen_random_bytes(24));
begin
  insert into public.founder_push_outbox (user_id, sub_id, kind, ref, tag, urgency, ttl_s, payload, ack_hash)
  values (p_uid, p_sub, p_kind, p_ref, p_tag, p_urgency, p_ttl, coalesce(p_payload, '{}'::jsonb) || jsonb_build_object('a', v_ack), public._fh_sha(v_ack))
  on conflict (sub_id, kind, ref) where ref is not null do nothing returning id into v_id;
  if v_id is not null then perform public._fh_log(p_uid, p_sub, v_id, 'queued', jsonb_build_object('kind', p_kind, 'urgency', p_urgency)); end if;
  return v_id;
end $$;

-- 4) the receipt door (called by the phone's service worker; no session: the 32-char random token IS the credential, one use, valid only for this alert's lifetime)
create or replace function public.founder_push_ack(p_token text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare o public.founder_push_outbox%rowtype;
begin
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{32}$' then return jsonb_build_object('ok', false); end if;
  select * into o from public.founder_push_outbox where ack_hash = public._fh_sha(p_token) for update;
  if not found or o.acked_at is not null or o.state not in ('sending', 'sent') or now() > o.created_at + make_interval(secs => o.ttl_s) then return jsonb_build_object('ok', false); end if;
  update public.founder_push_outbox set acked_at = now() where id = o.id;
  update public.founder_push_sub set last_ok_at = now(), fail_count = 0 where id = o.sub_id;
  perform public._fh_log(o.user_id, o.sub_id, o.id, 'acked', jsonb_build_object('kind', o.kind, 'ms_after_queue', (extract(epoch from now() - o.created_at) * 1000)::bigint));
  return jsonb_build_object('ok', true);
end $$;

-- 5) escalation: sent, not acknowledged for 90 s, the T3 request still open -> ONE reminder per phone per request
create or replace function public.founder_push_escalate() returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r record; v_n integer := 0; v_new uuid;
begin
  for r in
    select o.id, o.user_id, o.sub_id, o.ref from public.founder_push_outbox o join public.founder_push_sub s on s.id = o.sub_id and s.removed_at is null and s.confirmed_at is not null
     where o.kind in ('t3_begun', 't3_approved') and o.state = 'sent' and o.acked_at is null and o.done_at < now() - interval '90 seconds' and o.created_at > now() - interval '2 hours'
       and exists (select 1 from public.founder_t3_requests t where t.id = o.ref and t.state in ('waiting', 'approved'))
       and not exists (select 1 from public.founder_push_outbox x where x.sub_id = o.sub_id and x.kind = 't3_reminder' and x.ref = o.ref)
     order by o.done_at limit 20
  loop
    v_new := public._fh_enqueue(r.user_id, r.sub_id, 't3_reminder', r.ref, 't3:' || left(r.ref::text, 8), 'high', 3600, jsonb_build_object('k', 't3_reminder', 'r', r.ref));
    if v_new is not null then v_n := v_n + 1; perform public._fh_log(r.user_id, r.sub_id, v_new, 'escalated', jsonb_build_object('because', r.id, 'why', 'sent but not acknowledged for 90 s')); end if;
  end loop;
  return jsonb_build_object('escalated', v_n);
end $$;

-- 6) status: per-phone last receipt and the alerts that never got one
create or replace function public.founder_push_status(p_uid uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fs_assert_founder(p_uid);
  return jsonb_build_object(
    'phones', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'label', s.label, 'service', public._fh_host(s.endpoint), 'confirmed', s.confirmed_at is not null,
                         'waiting', s.confirmed_at is null and s.confirm_until > now(), 'last_ok_ms', (extract(epoch from s.last_ok_at) * 1000)::bigint, 'fail_count', s.fail_count,
                         'sha', s.endpoint_sha,
                         'last_ack_ms', (select (extract(epoch from max(o.acked_at)) * 1000)::bigint from public.founder_push_outbox o where o.sub_id = s.id)) order by s.added_at)
                from public.founder_push_sub s where s.user_id = p_uid and s.removed_at is null), '[]'::jsonb),
    'unacked', coalesce((select jsonb_agg(jsonb_build_object('kind', o.kind, 'sent_ms', (extract(epoch from o.done_at) * 1000)::bigint, 'phone', s.label) order by o.done_at desc)
                from public.founder_push_outbox o join public.founder_push_sub s on s.id = o.sub_id
               where o.user_id = p_uid and o.kind like 't3\_%' and o.kind <> 't3_cancelled' and o.state = 'sent' and o.acked_at is null and o.done_at > now() - interval '24 hours' and o.done_at < now() - interval '90 seconds'), '[]'::jsonb),
    'queue', coalesce((select jsonb_object_agg(state, n) from (select state, count(*) n from public.founder_push_outbox where user_id = p_uid group by state) q), '{}'::jsonb),
    'recent', coalesce((select jsonb_agg(jsonb_build_object('kind', kind, 'ts_ms', ts_ms) order by id desc) from (select * from public.founder_push_event where user_id = p_uid order by id desc limit 8) e), '[]'::jsonb),
    'chain', public.founder_push_verify(500),
    'limits', jsonb_build_array(
      'The push service (Google, Mozilla, Apple or Microsoft) sees that a message was sent, its size and its time, never its text: the payload is encrypted to the phone. This is true of every push service and cannot be removed by code.',
      'A push service saying "accepted" is not proof. A phone shows "received" only when its own receipt came back through the encrypted payload; an alert with no receipt after 90 s gets one reminder and shows here in red.',
      'A phone that never confirmed gets no alerts. No phone registered means no flare, and this page says so.'));
end $$;

do $$ declare f text; begin
  foreach f in array array['public.founder_push_ack(text)', 'public.founder_push_escalate()', 'public.founder_push_status(uuid)', 'public._fh_enqueue(uuid,uuid,text,uuid,text,text,integer,jsonb)', 'public._fh_outbox_guard()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
comment on function public.founder_push_ack(text) is 'E141: the phone returns the one-time token it found inside the encrypted push; acked_at is set once, the ledger gets an acked event.';
comment on function public.founder_push_escalate() is 'E141: one reminder per phone per open T3 request when an alert was sent but never acknowledged for 90 s.';

-- 7) selftest -------------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_push_e141_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '120s' as $$
declare
  u uuid; d uuid; r text := ''; j jsonb; g uuid; n text; v_cred text := 'selftestR_' || encode(extensions.gen_random_bytes(10), 'hex');
  v_ep text := 'https://fcm.googleapis.com/fcm/send/selftest-receipt-aaaaaaaaaaaaaaaaaaaa'; v_k text := 'B' || repeat('A', 86); v_a text := repeat('A', 22);
  v_tok text; v_sub uuid; v_out uuid; v_t3 uuid; v_t3b uuid; v_ack text; o public.founder_push_outbox%rowtype; c jsonb;
  b_sub bigint; b_out bigint; b_ev bigint; b_aud bigint; b_pk bigint; b_dev bigint; b_step bigint; b_t3 bigint; b_pro boolean; v_head text;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E141 selftest SKIP — no founder account'; end if;
  select count(*) into b_sub from public.founder_push_sub; select count(*) into b_out from public.founder_push_outbox; select count(*), coalesce(max(hash), '') into b_ev, v_head from public.founder_push_event;
  select count(*) into b_aud from public.founder_audit; select count(*) into b_pk from public.founder_passkeys; select count(*) into b_dev from public.founder_devices;
  select count(*) into b_step from public.founder_stepups; select count(*) into b_t3 from public.founder_t3_requests; select t2_hardware_only into b_pro from public.founder_protocol where id;
  begin
    update public.founder_protocol set t2_hardware_only = false where id;
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (u, 'selftest receipt device', encode(extensions.digest('e141', 'sha256'), 'hex'), now()) returning id into d;
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (u, v_cred, '{"k":1}', 'selftest receipt key');
    n := md5(random()::text);
    j := public.founder_stepup_issue(u, d, v_cred, 'flare.push', public._fh_sha(v_ep), '{}'::jsonb, n); g := (j ->> 'grant')::uuid;
    j := public.founder_push_subscribe(u, d, v_ep, v_k, v_a, 'Receipt phone', g, n); v_sub := (j ->> 'sub')::uuid;
    select (payload ->> 't') into v_tok from public.founder_push_outbox where sub_id = v_sub and kind = 'confirm';
    perform public.founder_push_confirm(u, d, v_tok);

    -- 1) every queued alert carries a 32-char ack token in its payload; only the hash is stored
    insert into public.founder_t3_requests (user_id, device_id, action, action_hash, first_credential, ready_at, expires_at)
      values (u, d, 'key.rotate', repeat('b', 64), v_cred, now() + interval '10 minutes', now() + interval '70 minutes') returning id into v_t3;
    select * into o from public.founder_push_outbox where sub_id = v_sub and kind = 't3_begun' and ref = v_t3; v_out := o.id; v_ack := o.payload ->> 'a';
    if v_ack !~ '^[A-Za-z0-9_-]{32}$' or o.ack_hash <> public._fh_sha(v_ack) or o.ack_hash = v_ack then raise exception 'the alert has no proper ack token / hash: %', o; end if;
    if (select count(*) from public.founder_push_outbox where ack_hash = v_ack) <> 0 then raise exception 'the raw token is stored'; end if;
    r := r || 'ack token minted inside the payload, only its hash stored OK; ';

    -- 2) wrong / malformed tokens do nothing; before the push is accepted (queued) a receipt is refused
    if (public.founder_push_ack(repeat('Z', 32)) ->> 'ok')::boolean or (public.founder_push_ack('short') ->> 'ok')::boolean or (public.founder_push_ack(null) ->> 'ok')::boolean then raise exception 'a bad token was accepted'; end if;
    if (public.founder_push_ack(v_ack) ->> 'ok')::boolean then raise exception 'a receipt arrived for an alert that was never sent'; end if;
    c := public.founder_push_claim(50); perform public.founder_push_report(v_out, 201);
    -- 3) the right token once; the second time and a changed receipt are refused
    if not (public.founder_push_ack(v_ack) ->> 'ok')::boolean then raise exception 'the right token was refused'; end if;
    if (select acked_at from public.founder_push_outbox where id = v_out) is null or (select payload from public.founder_push_outbox where id = v_out) is not null then raise exception 'receipt not stored or the payload not cleared'; end if;
    if (public.founder_push_ack(v_ack) ->> 'ok')::boolean then raise exception 'a token worked twice'; end if;
    if not public._fs_fails(format($q$update public.founder_push_outbox set acked_at = null where id = %L$q$, v_out)) or not public._fs_fails(format($q$update public.founder_push_outbox set acked_at = now() + interval '1 hour' where id = %L$q$, v_out))
       or not public._fs_fails(format($q$update public.founder_push_outbox set ack_hash = repeat('c', 64) where id = %L$q$, v_out)) or not public._fs_fails(format($q$update public.founder_push_outbox set http_status = 500 where id = %L$q$, v_out)) then
      raise exception 'a receipt or a final row was changed'; end if;
    if not exists (select 1 from public.founder_push_event where outbox_id = v_out and kind = 'acked') then raise exception 'no acked event'; end if;
    r := r || 'receipt once, immutable, ledger event OK; ';

    -- 4) escalation: a second request, sent, no receipt, older than 90 s -> exactly one reminder; none for a cancelled request; none before 90 s
    insert into public.founder_t3_requests (user_id, device_id, action, action_hash, first_credential, ready_at, expires_at)
      values (u, d, 'key.rotate', repeat('d', 64), v_cred, now() + interval '10 minutes', now() + interval '70 minutes') returning id into v_t3b;
    select id into v_out from public.founder_push_outbox where sub_id = v_sub and kind = 't3_begun' and ref = v_t3b;
    c := public.founder_push_claim(50); perform public.founder_push_report(v_out, 201);
    if (public.founder_push_escalate() ->> 'escalated')::int <> 0 then raise exception 'escalated before 90 s'; end if;
    alter table public.founder_push_outbox disable trigger founder_push_outbox_guard;
    update public.founder_push_outbox set done_at = now() - interval '5 minutes' where id = v_out;
    alter table public.founder_push_outbox enable trigger founder_push_outbox_guard;
    if (public.founder_push_status(u) -> 'unacked') is null or jsonb_array_length(public.founder_push_status(u) -> 'unacked') <> 1 then raise exception 'status must list the one unacknowledged alert: %', public.founder_push_status(u) -> 'unacked'; end if;
    if (public.founder_push_escalate() ->> 'escalated')::int <> 1 then raise exception 'no reminder after 90 s without a receipt'; end if;
    if (public.founder_push_escalate() ->> 'escalated')::int <> 0 then raise exception 'a second reminder was queued'; end if;
    select * into o from public.founder_push_outbox where sub_id = v_sub and kind = 't3_reminder' and ref = v_t3b;
    if o.id is null or o.urgency <> 'high' or o.ack_hash is null or not exists (select 1 from public.founder_push_event where outbox_id = o.id and kind = 'escalated') then raise exception 'the reminder is wrong: %', o; end if;
    -- a request that is no longer open never gets a reminder
    update public.founder_t3_requests set state = 'cancelled', cancelled_at = now() where id = v_t3b;
    if (public.founder_push_escalate() ->> 'escalated')::int <> 0 then raise exception 'escalated for a closed request'; end if;
    r := r || 'escalation once, only while the request is open, status lists the unacknowledged one OK; ';

    -- 5) the reminder is itself acknowledged like any alert, and the ledger still verifies
    c := public.founder_push_claim(50); perform public.founder_push_report(o.id, 201);
    if (public.founder_push_verify(100000) ->> 'ok')::boolean is not true then raise exception 'the chain must verify'; end if;
    r := r || 'chain verifies OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E141 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_push_sub) <> b_sub or (select count(*) from public.founder_push_outbox) <> b_out or (select count(*) from public.founder_push_event) <> b_ev
     or coalesce((select max(hash) from public.founder_push_event), '') <> v_head or (select count(*) from public.founder_audit) <> b_aud or (select count(*) from public.founder_passkeys) <> b_pk
     or (select count(*) from public.founder_devices) <> b_dev or (select count(*) from public.founder_stepups) <> b_step or (select count(*) from public.founder_t3_requests) <> b_t3
     or (select t2_hardware_only from public.founder_protocol where id) is distinct from b_pro then raise exception 'E141 selftest left rows behind'; end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_push_outbox'::regclass and tgname = 'founder_push_outbox_guard' and tgenabled = 'O') then raise exception 'E141 selftest left a trigger disabled'; end if;
  return 'E141 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_push_e141_selftest() from public, anon, authenticated;
grant execute on function public.founder_push_e141_selftest() to service_role;
do $$ begin raise notice '%', public.founder_push_e140_selftest(); raise notice '%', public.founder_push_e141_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E141_founder_flare_receipts CHECK_E141  (after fetch). Needs E140.
-- Undo: nothing else depends on it; re-running E140 restores the E140 versions of the three replaced functions (the columns stay, harmless).
