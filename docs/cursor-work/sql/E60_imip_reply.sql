-- =============================================================================
-- E60 — iMIP REPLY (G26): guest apne calendar app (Gmail / Outlook / Apple) mein Yes/Maybe/No dabaye to jawab hamare calendar
-- mein khud lag jaye (22 Oct 2026). E31 + E56 ke baad chalti hai. Dobara chalana safe (idempotent). Koi DROP nahi.
-- Fail ho to USI file ko theek karo (naya naam banned).
--
-- Kya banta hai:
--   * calendar_attendees.rsvp_via / rsvp_sequence : jawab kahan se aaya ('link' = mail ka button, 'calendar_app' = iMIP REPLY) aur kis
--       invitation-sequence par. `rsvp_via` UI mein "answered from calendar app" dikhane ke liye.
--   * calendar_imip_log : har inbound REPLY ka hisaab (applied / stale / cancelled / no_event / no_attendee / bad_input / duplicate).
--       message_id UNIQUE => wahi mail dobara deliver ho (Postfix retry) to dobara apply nahi hoti. Sirf service_role.
--   * calendar_imip_apply(...) : Rust (anexomail-deliver, service_role) sirf yeh function bulata hai. Faislay yahin (DB) hote hain:
--       1. UID sirf `<event-uuid>@anexomail.com` — kisi aur UID se kuch nahi chhua jata,
--       2. jawab SIRF us attendee row par jis ka address bhejne wale se (case-insensitive) mel khaye — doosre ka jawab koi nahi badal sakta,
--       3. purana jawab (sequence < event.sequence, ya pehle se lagi sequence se kam) ignore — "stale",
--       4. cancelled meeting par no-op, 5. row lock (do saath-saath jawab ek ke baad ek lagte hain),
--       6. doharane (recurring) meeting: RECURRENCE-ID ho aur us ka "sirf yeh meeting" wala exception row ho to wahi; warna master row.
--   Sender ki SPF/DKIM/DMARC jaanch SQL ka kaam nahi — Rust mail ki asli headers dekh kar hi function bulata hai (p_auth sirf hisaab ke liye).
--
-- Advance level (Rule 38): lock_timeout/statement_timeout, advisory lock, NOT VALID phir VALIDATE, pinned search_path, RLS ON + revoke +
--   service_role only, covering unique index, comments, aur isi file ke aakhir mein self-test (sab rollback) jo har rasta asli INSERT/UPDATE se saabit karta hai.
-- Limit jo sach hai: ek RECURRENCE-ID wala reply jiska exception row abhi nahi bana, poori series ki master row par lagta hai (v1);
--   booking-page ki meeting par "No" calendar mein dikhta hai, booking ko cancel nahi karta (visitor Cancel link use karta hai).
-- =============================================================================

-- ============================ PART 1 — schema (ek transaction) ===============================
begin;
set local lock_timeout = '15s';
set local statement_timeout = '120s';
select pg_advisory_xact_lock(hashtext('anexomail.E60'));

-- 0. preflight
do $$
declare
  need constant text[] := array[
    'calendar_events.id', 'calendar_events.org_id', 'calendar_events.sequence', 'calendar_events.status', 'calendar_events.cancelled_at',
    'calendar_events.series_id', 'calendar_events.recurrence_id',
    'calendar_attendees.id', 'calendar_attendees.event_id', 'calendar_attendees.org_id', 'calendar_attendees.address',
    'calendar_attendees.response', 'calendar_attendees.rsvp_at', 'calendar_attendees.rsvp_comment', 'calendar_attendees.rsvp_token'];
  n text;
  missing text[] := '{}';
begin
  foreach n in array need loop
    if not exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = split_part(n, '.', 1) and column_name = split_part(n, '.', 2)) then
      missing := missing || n;
    end if;
  end loop;
  if array_length(missing, 1) > 0 then
    raise exception 'E60: pehle E31 + E56 chalayen — yeh columns nahi mile: %', array_to_string(missing, ', ') using errcode = 'AX060';
  end if;
end $$;

-- 1. attendee: jawab kahan se aaya
alter table public.calendar_attendees add column if not exists rsvp_via      text;
alter table public.calendar_attendees add column if not exists rsvp_sequence integer;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'calendar_attendees_rsvp_via_ck') then
    alter table public.calendar_attendees add constraint calendar_attendees_rsvp_via_ck
      check (rsvp_via is null or rsvp_via in ('link', 'calendar_app')) not valid;
  end if;
end $$;
alter table public.calendar_attendees validate constraint calendar_attendees_rsvp_via_ck;

-- purana tareeqa (mail ka button) ab `link` likhe: calendar_rsvp_apply wahi rehta hai; sirf nishani lagti hai (idempotent create or replace).
create or replace function public.calendar_rsvp_mark_link()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  -- jawab badla aur iMIP apply ne nahi badla (woh transaction-local flag 'anexomail.imip' = '1' lagata hai) => mail ka button = 'link'
  if new.response is distinct from old.response and coalesce(current_setting('anexomail.imip', true), '') <> '1' then
    new.rsvp_via := 'link';
  end if;
  return new;
end $$;
drop trigger if exists calendar_rsvp_mark_link_trg on public.calendar_attendees;
create trigger calendar_rsvp_mark_link_trg before update of response on public.calendar_attendees
  for each row execute function public.calendar_rsvp_mark_link();

-- 2. inbound REPLY ka hisaab
create table if not exists public.calendar_imip_log (
  id          uuid primary key default gen_random_uuid(),
  message_id  text not null,
  org_id      uuid,
  event_id    uuid,
  address     text,
  partstat    text,
  sequence    integer,
  outcome     text not null,
  auth        text,
  created_at  timestamptz not null default now()
);
create unique index if not exists calendar_imip_log_msg_uq on public.calendar_imip_log (message_id);
create index        if not exists calendar_imip_log_event_idx on public.calendar_imip_log (event_id, created_at desc) where event_id is not null;
alter table public.calendar_imip_log enable row level security;
revoke all on public.calendar_imip_log from public, anon, authenticated;
grant select, insert on public.calendar_imip_log to service_role;
comment on table public.calendar_imip_log is 'E60: har inbound iMIP REPLY ka natija (applied/stale/cancelled/...). message_id unique = redelivery safe.';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'calendar_imip_log_outcome_ck') then
    alter table public.calendar_imip_log add constraint calendar_imip_log_outcome_ck
      check (outcome in ('applied', 'stale', 'cancelled', 'no_event', 'no_attendee', 'bad_input', 'duplicate')) not valid;
  end if;
end $$;
alter table public.calendar_imip_log validate constraint calendar_imip_log_outcome_ck;

-- 3. apply
create or replace function public.calendar_imip_apply(
  p_uid           text,
  p_attendee      text,
  p_partstat      text,
  p_sequence      integer,
  p_recurrence_id timestamptz default null,
  p_message_id    text default null,
  p_auth          text default null,
  p_comment       text default null)
returns jsonb
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  v_event   uuid;
  v_target  uuid;
  v_resp    text;
  v_addr    text := lower(btrim(coalesce(p_attendee, '')));
  v_mid     text := nullif(left(btrim(coalesce(p_message_id, '')), 300), '');
  v_ev      public.calendar_events;
  v_att     public.calendar_attendees;
  v_out     text;
  v_seq     integer := greatest(coalesce(p_sequence, 0), 0);
  v_m       text[];
begin
  -- bad input: log nahi (message_id par bharosa nahi), seedha jawab
  v_resp := case upper(btrim(coalesce(p_partstat, '')))
              when 'ACCEPTED' then 'accepted' when 'TENTATIVE' then 'tentative' when 'DECLINED' then 'declined' else null end;
  v_m := regexp_match(coalesce(p_uid, ''), '^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})@anexomail\.com$');
  if v_resp is null or v_m is null or v_addr !~ '^[^@\s<>"]+@[^@\s<>"]+\.[^@\s<>"]{2,}$' or char_length(v_addr) > 254 or v_mid is null then
    return jsonb_build_object('ok', false, 'outcome', 'bad_input');
  end if;
  v_event := v_m[1]::uuid;

  -- wahi mail dobara (Postfix retry): kuch nahi badalta
  if exists (select 1 from public.calendar_imip_log where message_id = v_mid) then
    return jsonb_build_object('ok', true, 'outcome', 'duplicate');
  end if;

  select * into v_ev from public.calendar_events where id = v_event;
  if not found then
    v_out := 'no_event';
  else
    -- "sirf yeh meeting" wali exception row ho to jawab usi par
    v_target := v_ev.id;
    if p_recurrence_id is not null then
      select e.id into v_target from public.calendar_events e where e.series_id = v_ev.id and e.recurrence_id = p_recurrence_id;
      if v_target is null then v_target := v_ev.id; else select * into v_ev from public.calendar_events where id = v_target; end if;
    end if;

    select a.* into v_att from public.calendar_attendees a
     where a.event_id = v_target and lower(a.address) = v_addr
     for update of a;

    if not found then
      v_out := 'no_attendee';
    elsif v_ev.status = 'cancelled' or v_ev.cancelled_at is not null then
      v_out := 'cancelled';
    elsif v_seq < coalesce(v_ev.sequence, 0) or v_seq < coalesce(v_att.rsvp_sequence, 0) then
      v_out := 'stale';
    else
      perform set_config('anexomail.imip', '1', true);
      update public.calendar_attendees
         set response = v_resp, rsvp_at = now(), rsvp_via = 'calendar_app', rsvp_sequence = v_seq,
             rsvp_comment = coalesce(nullif(left(btrim(coalesce(p_comment, '')), 500), ''), rsvp_comment)
       where id = v_att.id;
      perform set_config('anexomail.imip', '0', true);
      v_out := 'applied';
    end if;
  end if;

  begin
    insert into public.calendar_imip_log (message_id, org_id, event_id, address, partstat, sequence, outcome, auth)
      values (v_mid, v_ev.org_id, case when v_out = 'no_event' then null else v_event end, v_addr, v_resp, v_seq, v_out, left(p_auth, 300));
  exception when unique_violation then
    return jsonb_build_object('ok', true, 'outcome', 'duplicate');
  end;

  return jsonb_build_object('ok', v_out = 'applied', 'outcome', v_out, 'event_id', case when v_out in ('applied', 'stale', 'cancelled') then v_target else null end,
                            'org_id', v_ev.org_id, 'response', case when v_out = 'applied' then v_resp else null end);
end $$;
comment on function public.calendar_imip_apply(text, text, text, integer, timestamptz, text, text, text)
  is 'E60: inbound iMIP REPLY lagata hai. Sirf service_role. Sender ki SPF/DKIM jaanch Rust karta hai.';

revoke all on function public.calendar_imip_apply(text, text, text, integer, timestamptz, text, text, text) from public, anon, authenticated;
revoke all on function public.calendar_rsvp_mark_link() from public, anon, authenticated;
grant execute on function public.calendar_imip_apply(text, text, text, integer, timestamptz, text, text, text) to service_role;

notify pgrst, 'reload schema';
commit;

-- ============================ PART 2 — self-test (alag transaction, sab rollback) ===============================
do $$
declare
  v_org uuid; v_ev uuid; v_ev2 uuid; v_exc uuid; v_r jsonb; v_chk integer := 0; v_skip text; v_result text;
  v_pair record; v_sql text; v_first boolean := true; v_n integer; v_resp text; v_via text;
  v_uid text; v_mid text;
begin
  begin
    v_sql := null;
    for v_pair in
      select distinct c.confrelid::regclass as tab, a.attname as col
        from pg_constraint c
        join pg_attribute a on a.attrelid = c.confrelid and a.attnum = c.confkey[1]
       where c.contype = 'f'
         and c.conrelid in ('public.calendar_events'::regclass, 'public.calendar_attendees'::regclass)
         and c.conkey = array[(select x.attnum from pg_attribute x where x.attrelid = c.conrelid and x.attname = 'org_id')]
       order by 1
    loop
      if v_first then v_sql := format('select t.%I from %s t where true', v_pair.col, v_pair.tab); v_first := false;
      else v_sql := v_sql || format(' and exists (select 1 from %s u where u.%I = t.%I)', v_pair.tab, v_pair.col, v_pair.col); end if;
    end loop;
    if v_sql is null then v_org := gen_random_uuid();
    else execute v_sql || ' limit 1' into v_org; if v_org is null then v_skip := 'FK wali table mein koi organisation row nahi'; end if; end if;

    if v_skip is null then
      begin
        insert into public.calendar_events (org_id, title, starts_at, ends_at, organiser, kind, status, sequence)
          values (v_org, 'E60 selftest', now() + interval '2 days', now() + interval '2 days 30 minutes', 'host@e60.test', 'meeting', 'confirmed', 2)
          returning id into v_ev;
        insert into public.calendar_attendees (event_id, org_id, address, response) values
          (v_ev, v_org, 'host@e60.test', 'accepted'), (v_ev, v_org, 'Guest@E60.test', 'needs_action'), (v_ev, v_org, 'other@e60.test', 'needs_action');
      exception when others then v_skip := format('fixture nahi bana: %s [%s]', sqlerrm, sqlstate);
      end;
    end if;

    if v_skip is null then
      v_uid := v_ev::text || '@anexomail.com';
      -- 1. theek REPLY lagta hai (case-insensitive address), sirf usi attendee par
      v_r := public.calendar_imip_apply(v_uid, 'guest@e60.test', 'ACCEPTED', 2, null, 'm1', 'dkim=pass', null);
      if v_r ->> 'outcome' <> 'applied' then raise exception 'E60 FAILED: applied nahi %', v_r using errcode = 'AX060'; end if;
      select response, rsvp_via into v_resp, v_via from public.calendar_attendees where event_id = v_ev and lower(address) = 'guest@e60.test';
      if v_resp <> 'accepted' or v_via <> 'calendar_app' then raise exception 'E60 FAILED: response/via % %', v_resp, v_via using errcode = 'AX060'; end if;
      if (select response from public.calendar_attendees where event_id = v_ev and address = 'other@e60.test') <> 'needs_action' then
        raise exception 'E60 FAILED: doosre attendee ka jawab badal gaya' using errcode = 'AX060'; end if;
      v_chk := v_chk + 1;
      -- 2. wahi message dobara = duplicate, kuch nahi badalta
      if public.calendar_imip_apply(v_uid, 'guest@e60.test', 'DECLINED', 2, null, 'm1', null, null) ->> 'outcome' <> 'duplicate' then
        raise exception 'E60 FAILED: duplicate' using errcode = 'AX060'; end if;
      if (select response from public.calendar_attendees where event_id = v_ev and lower(address) = 'guest@e60.test') <> 'accepted' then
        raise exception 'E60 FAILED: duplicate ne jawab badla' using errcode = 'AX060'; end if;
      v_chk := v_chk + 1;
      -- 3. purani sequence (event.sequence = 2, reply 1) = stale
      if public.calendar_imip_apply(v_uid, 'other@e60.test', 'DECLINED', 1, null, 'm2', null, null) ->> 'outcome' <> 'stale' then
        raise exception 'E60 FAILED: stale' using errcode = 'AX060'; end if;
      -- ... aur pehle lagi hui sequence (3) se kam (2) bhi stale
      perform public.calendar_imip_apply(v_uid, 'other@e60.test', 'TENTATIVE', 3, null, 'm3', null, null);
      if public.calendar_imip_apply(v_uid, 'other@e60.test', 'DECLINED', 2, null, 'm4', null, null) ->> 'outcome' <> 'stale' then
        raise exception 'E60 FAILED: rsvp_sequence stale' using errcode = 'AX060'; end if;
      if (select response from public.calendar_attendees where event_id = v_ev and address = 'other@e60.test') <> 'tentative' then
        raise exception 'E60 FAILED: stale ne jawab badla' using errcode = 'AX060'; end if;
      v_chk := v_chk + 1;
      -- 4. anjaan attendee / anjaan event / ghalat UID / ghalat partstat / message-id ke bagair
      if public.calendar_imip_apply(v_uid, 'nobody@e60.test', 'ACCEPTED', 2, null, 'm5', null, null) ->> 'outcome' <> 'no_attendee' then raise exception 'E60 FAILED: no_attendee' using errcode = 'AX060'; end if;
      if public.calendar_imip_apply(gen_random_uuid()::text || '@anexomail.com', 'guest@e60.test', 'ACCEPTED', 0, null, 'm6', null, null) ->> 'outcome' <> 'no_event' then raise exception 'E60 FAILED: no_event' using errcode = 'AX060'; end if;
      if public.calendar_imip_apply(v_ev::text || '@evil.com', 'guest@e60.test', 'ACCEPTED', 2, null, 'm7', null, null) ->> 'outcome' <> 'bad_input' then raise exception 'E60 FAILED: bad uid' using errcode = 'AX060'; end if;
      if public.calendar_imip_apply(v_uid, 'guest@e60.test', 'MAYBE', 2, null, 'm8', null, null) ->> 'outcome' <> 'bad_input' then raise exception 'E60 FAILED: bad partstat' using errcode = 'AX060'; end if;
      if public.calendar_imip_apply(v_uid, 'guest@e60.test', 'ACCEPTED', 2, null, null, null, null) ->> 'outcome' <> 'bad_input' then raise exception 'E60 FAILED: message-id ke bagair' using errcode = 'AX060'; end if;
      v_chk := v_chk + 1;
      -- 5. cancelled meeting par no-op
      update public.calendar_events set status = 'cancelled', cancelled_at = now() where id = v_ev;
      if public.calendar_imip_apply(v_uid, 'other@e60.test', 'ACCEPTED', 3, null, 'm9', null, null) ->> 'outcome' <> 'cancelled' then raise exception 'E60 FAILED: cancelled' using errcode = 'AX060'; end if;
      if (select response from public.calendar_attendees where event_id = v_ev and address = 'other@e60.test') <> 'tentative' then raise exception 'E60 FAILED: cancelled par jawab badla' using errcode = 'AX060'; end if;
      v_chk := v_chk + 1;
      -- 6. link wala jawab (calendar_rsvp_apply wala UPDATE) rsvp_via='link' likhta hai
      update public.calendar_events set status = 'confirmed', cancelled_at = null where id = v_ev;
      update public.calendar_attendees set response = 'declined' where event_id = v_ev and address = 'other@e60.test';
      if (select rsvp_via from public.calendar_attendees where event_id = v_ev and address = 'other@e60.test') <> 'link' then raise exception 'E60 FAILED: link nishani' using errcode = 'AX060'; end if;
      v_chk := v_chk + 1;
      -- 7. doharane meeting: RECURRENCE-ID ka exception row ho to jawab usi par, master par nahi
      insert into public.calendar_events (org_id, title, starts_at, ends_at, organiser, kind, status, sequence, rrule)
        values (v_org, 'E60 series', now() + interval '3 days', now() + interval '3 days 30 minutes', 'host@e60.test', 'meeting', 'confirmed', 0, 'FREQ=DAILY;COUNT=3')
        returning id into v_ev2;
      insert into public.calendar_events (org_id, title, starts_at, ends_at, organiser, kind, status, sequence, series_id, recurrence_id)
        values (v_org, 'E60 series', now() + interval '4 days 1 hour', now() + interval '4 days 90 minutes', 'host@e60.test', 'meeting', 'confirmed', 0, v_ev2, date_trunc('second', now() + interval '4 days'))
        returning id into v_exc;
      insert into public.calendar_attendees (event_id, org_id, address, response) values (v_ev2, v_org, 'guest@e60.test', 'needs_action'), (v_exc, v_org, 'guest@e60.test', 'needs_action');
      v_r := public.calendar_imip_apply(v_ev2::text || '@anexomail.com', 'guest@e60.test', 'DECLINED', 0, date_trunc('second', now() + interval '4 days'), 'm10', null, null);
      if v_r ->> 'outcome' <> 'applied' or (v_r ->> 'event_id')::uuid <> v_exc then raise exception 'E60 FAILED: exception row %', v_r using errcode = 'AX060'; end if;
      if (select response from public.calendar_attendees where event_id = v_ev2) <> 'needs_action' then raise exception 'E60 FAILED: master badal gaya' using errcode = 'AX060'; end if;
      v_r := public.calendar_imip_apply(v_ev2::text || '@anexomail.com', 'guest@e60.test', 'ACCEPTED', 0, null, 'm11', null, null);
      if (select response from public.calendar_attendees where event_id = v_ev2) <> 'accepted' then raise exception 'E60 FAILED: master jawab' using errcode = 'AX060'; end if;
      v_chk := v_chk + 1;
      -- 8. log: har outcome likha gaya, message_id unique
      select count(*) into v_n from public.calendar_imip_log where message_id like 'm%';
      if v_n < 9 then raise exception 'E60 FAILED: log rows %', v_n using errcode = 'AX060'; end if;
      v_chk := v_chk + 1;
      v_result := format('PASSED (%s checks, sab rollback)', v_chk);
    else
      v_result := 'SKIPPED — ' || v_skip;
    end if;
    raise exception 'E60_ROLLBACK %', v_result using errcode = 'AX0RB';
  exception when sqlstate 'AX0RB' then
    v_result := replace(sqlerrm, 'E60_ROLLBACK ', '');
  end;
  perform set_config('e60.result', v_result, false);
end $$;

select 'E60 OK — iMIP reply lag gaya' as e60_result, current_setting('e60.result', true) as selftest,
       (select count(*) from pg_proc where proname in ('calendar_imip_apply', 'calendar_rsvp_mark_link')) as functions;
