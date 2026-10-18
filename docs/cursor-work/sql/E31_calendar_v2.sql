-- =============================================================================
-- E31 — Calendar v2 (18 Oct 2026, shuru se dobara likhi): asli invitations, RSVP, invitation ledger, ek-query busy lookup.
--
-- Pehla version fail hua (founder, 18 Oct 05:2x PKT):
--   ERROR 23503  calendar_events_org_id_fkey — self-test ne bana-banaya org uuid daala, asli table mein FK hai.
-- Sabaq: self-test ab ASLI organisation use karta hai (FK ka target database se khud dhoondhta hai, naam andaze se nahi),
--        aur schema-badlav (Part 1) alag transaction hai, test (Part 2) alag — test ka kuch bhi bigre to schema par asar nahi.
--
-- Kya banta hai (Rust engine `calendar.create/update/invites.resend/rsvp.*/busy` isi ko use karta hai):
--   * calendar_events    : sequence (iTIP SEQUENCE), cancelled_at, tz
--   * calendar_attendees : rsvp_token (DB ka random uuid — email mein jata hai), role, rsvp_at, rsvp_comment,
--                          invite_status (not_sent|sent|failed), invite_sent_at, invite_error
--   * calendar_invite_log: har invitation/cancel mail ka APPEND-ONLY saboot (kisko, kaun si SEQUENCE, SMTP ka jawab);
--                          update/delete trigger se band; daily quota bhi isi se
--   * calendar_rsvp_lookup / calendar_rsvp_apply : token se ek hi jagah jawab (uuid type — SQL injection ka sawal nahi),
--                          apply mein row-lock (do saath-saath jawab ek doosre ko nahi kuchalte), NULL/ghalat jawab refuse
--   * calendar_busy      : kuch logon ki busy intervals EK query mein (Find-a-time) — org se bandha, cancelled/hold/declined nahi ginta
--
-- Hifazat: sirf additive + idempotent (koi drop/rename nahi), lock_timeout 15s (production table par line mein khada nahi rehta —
--          fail ho to dobara chalayein), advisory lock (do chalane wale ek saath nahi), naye constraints pehle NOT VALID phir VALIDATE,
--          naye tables par RLS ON + sirf service_role. rsvp_token browser ko kabhi nahi milna chahiye — E32 ne calendar tables lock kiye hain,
--          neeche aakhri jawab mein is ka saboot (rsvp_tokens_exposed_to_browser = false hona chahiye).
-- Chalane ka tareeqa: poori file ek saath (Supabase SQL Editor ya psql). Aakhri jawab: ek row `e31_result`.
-- Fail ho to: usi file ko shuru se theek karo (naya naam banned).
-- =============================================================================

-- ============================ PART 1 — schema (ek transaction) ===============================
begin;
set local lock_timeout = '15s';
set local statement_timeout = '120s';
select pg_advisory_xact_lock(hashtext('anexomail.E31'));

-- 0. preflight: jin columns par yeh file khadi hai woh maujood hain? (na hon to saaf wajah, adhoora kaam nahi)
do $$
declare
  need constant text[] := array[
    'calendar_events.id', 'calendar_events.org_id', 'calendar_events.title', 'calendar_events.agenda', 'calendar_events.location',
    'calendar_events.starts_at', 'calendar_events.ends_at', 'calendar_events.organiser', 'calendar_events.kind', 'calendar_events.status',
    'calendar_attendees.id', 'calendar_attendees.event_id', 'calendar_attendees.org_id', 'calendar_attendees.address', 'calendar_attendees.response'];
  n text;
  missing text[] := '{}';
begin
  foreach n in array need loop
    if not exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = split_part(n, '.', 1) and column_name = split_part(n, '.', 2)
    ) then
      missing := missing || n;
    end if;
  end loop;
  if coalesce(array_length(missing, 1), 0) > 0 then
    raise exception 'E31 PREFLIGHT: yeh columns maujood nahi: % — pehle sql/phase61_calendar_work.sql (idempotent) chalayen, phir E31', array_to_string(missing, ', ')
      using errcode = 'AX031';
  end if;
end $$;

-- 1. events
alter table public.calendar_events add column if not exists sequence     integer not null default 0;
alter table public.calendar_events add column if not exists cancelled_at timestamptz;
alter table public.calendar_events add column if not exists tz           text;

-- 2. attendees. rsvp_token: volatile default poori table dobara likhwata hai — isliye pehle nullable, default, bharo, phir NOT NULL.
alter table public.calendar_attendees add column if not exists rsvp_token     uuid;
alter table public.calendar_attendees alter column rsvp_token set default gen_random_uuid();
update public.calendar_attendees set rsvp_token = gen_random_uuid() where rsvp_token is null;
alter table public.calendar_attendees alter column rsvp_token set not null;

alter table public.calendar_attendees add column if not exists role           text not null default 'required';
alter table public.calendar_attendees add column if not exists rsvp_at        timestamptz;
alter table public.calendar_attendees add column if not exists rsvp_comment   text;
alter table public.calendar_attendees add column if not exists invite_status  text not null default 'not_sent';
alter table public.calendar_attendees add column if not exists invite_sent_at timestamptz;
alter table public.calendar_attendees add column if not exists invite_error   text;

-- constraints: pehle NOT VALID (lock halka), phir VALIDATE. Naam se idempotent.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_sequence_ck' and conrelid = 'public.calendar_events'::regclass) then
    alter table public.calendar_events add constraint calendar_events_sequence_ck check (sequence >= 0) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'calendar_attendees_invite_status_ck' and conrelid = 'public.calendar_attendees'::regclass) then
    alter table public.calendar_attendees add constraint calendar_attendees_invite_status_ck check (invite_status in ('not_sent', 'sent', 'failed')) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'calendar_attendees_role_ck' and conrelid = 'public.calendar_attendees'::regclass) then
    alter table public.calendar_attendees add constraint calendar_attendees_role_ck check (role in ('required', 'optional')) not valid;
  end if;
  alter table public.calendar_events    validate constraint calendar_events_sequence_ck;
  alter table public.calendar_attendees validate constraint calendar_attendees_invite_status_ck;
  alter table public.calendar_attendees validate constraint calendar_attendees_role_ck;
end $$;

create unique index if not exists calendar_attendees_rsvp_token_uq on public.calendar_attendees (rsvp_token);
-- busy lookup ke raaste: address se, aur org ke zinda (cancel nahi) events waqt se
create index if not exists calendar_attendees_addr_event_idx on public.calendar_attendees (lower(address), event_id);
create index if not exists calendar_events_live_time_idx on public.calendar_events (org_id, starts_at, ends_at) where cancelled_at is null;

-- (event, address) unique — sirf tab jab koi duplicate maujood na ho (mojooda data ko haath nahi lagate)
do $$
begin
  if exists (select 1 from public.calendar_attendees group by event_id, lower(address) having count(*) > 1) then
    raise notice 'E31: duplicate (event, address) rows maujood hain — unique index nahi lagaya (engine upsert se bhi theek chalta hai)';
  else
    create unique index if not exists calendar_attendees_event_addr_uq on public.calendar_attendees (event_id, lower(address));
  end if;
end $$;

-- 3. invitation ledger (append-only)
create table if not exists public.calendar_invite_log (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid,
  event_id      uuid not null,
  address       text not null,
  method        text not null check (method in ('REQUEST', 'CANCEL')),
  sequence      integer not null default 0,
  sent_by       uuid,
  message_id    text,
  ok            boolean not null,
  smtp_response text,
  error         text,
  created_at    timestamptz not null default now()
);
create index if not exists calendar_invite_log_org_time_idx on public.calendar_invite_log (org_id, created_at desc);
create index if not exists calendar_invite_log_sender_time_idx on public.calendar_invite_log (sent_by, created_at desc);
create index if not exists calendar_invite_log_event_idx on public.calendar_invite_log (event_id, created_at desc);

alter table public.calendar_invite_log enable row level security;
revoke all on public.calendar_invite_log from anon, authenticated;
grant all on public.calendar_invite_log to service_role;
drop policy if exists service_role_all on public.calendar_invite_log;
create policy service_role_all on public.calendar_invite_log for all to service_role using (true) with check (true);

-- saboot badla nahi jata: update/delete band. Jaan-boojh kar safai chahiye to usi transaction mein
--   select set_config('anexo.ledger_maintenance', 'on', true);
create or replace function public.calendar_invite_log_guard()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if current_setting('anexo.ledger_maintenance', true) = 'on' then
    return coalesce(new, old);
  end if;
  raise exception 'calendar_invite_log append-only hai (% band)', tg_op using errcode = 'AX032';
end $$;
drop trigger if exists calendar_invite_log_append_only on public.calendar_invite_log;
create trigger calendar_invite_log_append_only
  before update or delete on public.calendar_invite_log
  for each row execute function public.calendar_invite_log_guard();

-- 4. RSVP by token
create or replace function public.calendar_rsvp_lookup(p_token uuid)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(
    (select jsonb_build_object(
        'found',     true,
        'event_id',  e.id,
        'title',     e.title,
        'agenda',    e.agenda,
        'location',  e.location,
        'starts_at', e.starts_at,
        'ends_at',   e.ends_at,
        'organiser', e.organiser,
        'cancelled', (e.status = 'cancelled' or e.cancelled_at is not null),
        'address',   a.address,
        'response',  a.response,
        'rsvp_at',   a.rsvp_at
      )
      from public.calendar_attendees a
      join public.calendar_events e on e.id = a.event_id
     where a.rsvp_token = p_token),
    jsonb_build_object('found', false))
$$;

create or replace function public.calendar_rsvp_apply(p_token uuid, p_response text, p_comment text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_att       uuid;
  v_cancelled boolean;
begin
  -- NULL ya ghalat jawab: refuse (pehle `null not in (...)` guard se nikal jata tha)
  if p_response is null or p_response not in ('accepted', 'tentative', 'declined') then
    return jsonb_build_object('found', false, 'error', 'bad_response');
  end if;

  -- attendee row lock: do jawab ek saath aaye to ek ke baad ek lagte hain
  select a.id, (e.status = 'cancelled' or e.cancelled_at is not null)
    into v_att, v_cancelled
    from public.calendar_attendees a
    join public.calendar_events e on e.id = a.event_id
   where a.rsvp_token = p_token
     for update of a;

  if v_att is null then
    return jsonb_build_object('found', false, 'error', 'not_found');
  end if;
  if v_cancelled then
    return jsonb_build_object('found', true, 'error', 'cancelled') || public.calendar_rsvp_lookup(p_token);
  end if;

  update public.calendar_attendees
     set response     = p_response,
         rsvp_at      = now(),
         rsvp_comment = nullif(left(btrim(coalesce(p_comment, '')), 500), '')
   where id = v_att;
  return public.calendar_rsvp_lookup(p_token);
end;
$$;

-- 5. kuch logon ki busy intervals EK query mein
create or replace function public.calendar_busy(p_org uuid, p_addresses text[], p_from timestamptz, p_to timestamptz)
returns table (address text, starts_at timestamptz, ends_at timestamptz)
language sql
stable
set search_path = public, pg_temp
as $$
  select lower(a.address), e.starts_at, e.ends_at
    from public.calendar_attendees a
    join public.calendar_events e on e.id = a.event_id
   where e.org_id = p_org
     and lower(a.address) = any (select lower(x) from unnest(p_addresses) x)
     and e.starts_at < p_to and e.ends_at > p_from
     and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
     and coalesce(a.response, 'needs_action') <> 'declined'
     and coalesce(e.kind, 'meeting') <> 'hold'
   order by 1, 2
$$;

revoke all on function public.calendar_invite_log_guard()                              from public, anon, authenticated;
revoke all on function public.calendar_rsvp_lookup(uuid)                               from public, anon, authenticated;
revoke all on function public.calendar_rsvp_apply(uuid, text, text)                    from public, anon, authenticated;
revoke all on function public.calendar_busy(uuid, text[], timestamptz, timestamptz)    from public, anon, authenticated;
grant execute on function public.calendar_rsvp_lookup(uuid)                            to service_role;
grant execute on function public.calendar_rsvp_apply(uuid, text, text)                 to service_role;
grant execute on function public.calendar_busy(uuid, text[], timestamptz, timestamptz) to service_role;

notify pgrst, 'reload schema';
commit;

-- ============================ PART 2 — self-test (alag transaction, sab rollback) ===============================
-- Asli organisation use hota hai: FK ka target pg_constraint se nikalta hai. Test ka saaman (fixture) na ban sake
-- (jaise table mein koi org hi nahi) to test SKIPPED likhta hai — schema (Part 1) tab bhi lag chuka hota hai. Mantiq ki galti = FAIL.
do $$
declare
  v_org   uuid;
  v_ev    uuid;
  v_ev2   uuid;
  v_tok   uuid;
  v_tok2  uuid;
  v_r     jsonb;
  v_n     integer;
  v_chk   integer := 0;
  v_hit   boolean;
  v_skip  text;
  v_sql   text;
  v_pair  record;
  v_first boolean := true;
begin
  perform set_config('anexo.e31_selftest', 'not run', false);
  begin
    -- 1. ek aisa org jise calendar_events.org_id aur calendar_attendees.org_id ke SAB FK maante hain
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
      if v_first then
        v_sql := format('select t.%I from %s t where true', v_pair.col, v_pair.tab);
        v_first := false;
      else
        v_sql := v_sql || format(' and exists (select 1 from %s u where u.%I = t.%I)', v_pair.tab, v_pair.col, v_pair.col);
      end if;
    end loop;
    if v_sql is null then
      v_org := gen_random_uuid();                       -- org_id par koi FK hi nahi
    else
      execute v_sql || ' limit 1' into v_org;
      if v_org is null then v_skip := 'FK wali table mein koi organisation row nahi'; end if;
    end if;

    -- 2. fixture (seedhe INSERT; yahan kuch bigre to wajah chhapti hai, test SKIPPED)
    if v_skip is null then
      begin
        insert into public.calendar_events (org_id, title, agenda, starts_at, ends_at, organiser)
          values (v_org, 'E31 selftest', 'selftest agenda', now() + interval '1 day', now() + interval '1 day 30 minutes', 'org@e31.test')
          returning id into v_ev;
        insert into public.calendar_attendees (event_id, org_id, address, response)
          values (v_ev, v_org, 'Guest@E31.test', 'needs_action'), (v_ev, v_org, 'org@e31.test', 'accepted');
      exception when others then
        v_skip := format('fixture nahi bana: %s [%s]', sqlerrm, sqlstate);
      end;
    end if;

    if v_skip is null then
      -- token khud bante hain, har attendee ka alag
      select count(distinct rsvp_token) into v_n from public.calendar_attendees where event_id = v_ev and rsvp_token is not null;
      if v_n <> 2 then raise exception 'E31 FAILED: rsvp_token har attendee ka alag nahi (%)', v_n using errcode = 'AX031'; end if;
      v_chk := v_chk + 1;
      select rsvp_token into v_tok from public.calendar_attendees where event_id = v_ev and lower(address) = 'guest@e31.test';

      -- lookup
      v_r := public.calendar_rsvp_lookup(v_tok);
      if not ((v_r->>'found')::boolean and v_r->>'response' = 'needs_action' and v_r->>'title' = 'E31 selftest' and (v_r->>'cancelled')::boolean is false) then
        raise exception 'E31 FAILED: lookup %', v_r using errcode = 'AX031';
      end if;
      v_chk := v_chk + 1;
      if (public.calendar_rsvp_lookup(gen_random_uuid())->>'found')::boolean is not false then
        raise exception 'E31 FAILED: anjaan token ka lookup found nahi hona chahiye' using errcode = 'AX031';
      end if;
      v_chk := v_chk + 1;

      -- apply: jawab + comment (500 par kata, khali = NULL)
      v_r := public.calendar_rsvp_apply(v_tok, 'accepted', repeat('x', 600));
      if v_r->>'response' <> 'accepted' or (v_r->>'rsvp_at') is null then raise exception 'E31 FAILED: apply %', v_r using errcode = 'AX031'; end if;
      select char_length(rsvp_comment) into v_n from public.calendar_attendees where rsvp_token = v_tok;
      if v_n <> 500 then raise exception 'E31 FAILED: comment 500 par nahi kata (%)', v_n using errcode = 'AX031'; end if;
      perform public.calendar_rsvp_apply(v_tok, 'tentative', '   ');
      select count(*) into v_n from public.calendar_attendees where rsvp_token = v_tok and response = 'tentative' and rsvp_comment is null;
      if v_n <> 1 then raise exception 'E31 FAILED: khali comment NULL nahi bana / jawab nahi badla' using errcode = 'AX031'; end if;
      v_chk := v_chk + 3;

      -- ghalat / NULL / anjaan: refuse, kuch badalta nahi
      v_r := public.calendar_rsvp_apply(v_tok, 'banana');
      if v_r->>'error' is distinct from 'bad_response' then raise exception 'E31 FAILED: ghalat jawab refuse nahi hua %', v_r using errcode = 'AX031'; end if;
      v_r := public.calendar_rsvp_apply(v_tok, null);
      if v_r->>'error' is distinct from 'bad_response' then raise exception 'E31 FAILED: NULL jawab refuse nahi hua %', v_r using errcode = 'AX031'; end if;
      v_r := public.calendar_rsvp_apply(gen_random_uuid(), 'accepted');
      if v_r->>'error' is distinct from 'not_found' then raise exception 'E31 FAILED: anjaan token refuse nahi hua %', v_r using errcode = 'AX031'; end if;
      select count(*) into v_n from public.calendar_attendees where rsvp_token = v_tok and response = 'tentative';
      if v_n <> 1 then raise exception 'E31 FAILED: refuse hui call ne jawab badal diya' using errcode = 'AX031'; end if;
      v_chk := v_chk + 3;

      -- busy: case-insensitive, sirf apni org, waqt ki khidki, declined / hold / cancelled nahi
      select count(*) into v_n from public.calendar_busy(v_org, array['GUEST@e31.test'], now(), now() + interval '3 days');
      if v_n <> 1 then raise exception 'E31 FAILED: busy lookup ne % row diye (1 chahiye)', v_n using errcode = 'AX031'; end if;
      select count(*) into v_n from public.calendar_busy(v_org, array['guest@e31.test'], now() + interval '5 days', now() + interval '6 days');
      if v_n <> 0 then raise exception 'E31 FAILED: khidki ke bahar ka event busy gina gaya' using errcode = 'AX031'; end if;
      select count(*) into v_n from public.calendar_busy(gen_random_uuid(), array['guest@e31.test'], now(), now() + interval '3 days');
      if v_n <> 0 then raise exception 'E31 FAILED: doosri org ka busy dikha (tenant leak)' using errcode = 'AX031'; end if;
      update public.calendar_attendees set response = 'declined' where rsvp_token = v_tok;
      select count(*) into v_n from public.calendar_busy(v_org, array['guest@e31.test'], now(), now() + interval '3 days');
      if v_n <> 0 then raise exception 'E31 FAILED: declined attendee ab bhi busy (%)', v_n using errcode = 'AX031'; end if;
      update public.calendar_attendees set response = 'accepted' where rsvp_token = v_tok;
      update public.calendar_events set kind = 'hold' where id = v_ev;
      select count(*) into v_n from public.calendar_busy(v_org, array['guest@e31.test'], now(), now() + interval '3 days');
      if v_n <> 0 then raise exception 'E31 FAILED: hold busy gina gaya' using errcode = 'AX031'; end if;
      update public.calendar_events set kind = 'meeting' where id = v_ev;
      v_chk := v_chk + 5;

      -- cancelled event: RSVP nahi leta, busy nahi
      update public.calendar_events set status = 'cancelled', cancelled_at = now() where id = v_ev;
      v_r := public.calendar_rsvp_apply(v_tok, 'declined');
      if v_r->>'error' is distinct from 'cancelled' then raise exception 'E31 FAILED: cancelled event ne RSVP le liya %', v_r using errcode = 'AX031'; end if;
      select count(*) into v_n from public.calendar_attendees where rsvp_token = v_tok and response = 'accepted';
      if v_n <> 1 then raise exception 'E31 FAILED: cancelled event par jawab badal gaya' using errcode = 'AX031'; end if;
      select count(*) into v_n from public.calendar_busy(v_org, array['guest@e31.test'], now(), now() + interval '3 days');
      if v_n <> 0 then raise exception 'E31 FAILED: cancelled event busy gina gaya' using errcode = 'AX031'; end if;
      v_chk := v_chk + 3;

      -- (event, address) duplicate: agar unique index laga hai to refuse
      if to_regclass('public.calendar_attendees_event_addr_uq') is not null then
        v_hit := false;
        begin
          insert into public.calendar_attendees (event_id, org_id, address) values (v_ev, v_org, 'GUEST@e31.test');
        exception when unique_violation then v_hit := true;
        end;
        if not v_hit then raise exception 'E31 FAILED: ek hi event mein wahi address do baar gaya' using errcode = 'AX031'; end if;
        v_chk := v_chk + 1;
      end if;

      -- naye column ke checks
      v_hit := false;
      begin
        update public.calendar_attendees set invite_status = 'banana' where rsvp_token = v_tok;
      exception when check_violation then v_hit := true;
      end;
      if not v_hit then raise exception 'E31 FAILED: ghalat invite_status chal gaya' using errcode = 'AX031'; end if;
      v_chk := v_chk + 1;

      -- invitation ledger: theek rows jati hain, ghalat method nahi, badla/mitaya nahi ja sakta
      insert into public.calendar_invite_log (org_id, event_id, address, method, ok) values (v_org, v_ev, 'guest@e31.test', 'REQUEST', true);
      v_hit := false;
      begin
        insert into public.calendar_invite_log (org_id, event_id, address, method, ok) values (v_org, v_ev, 'x@y.zz', 'BANANA', true);
      exception when check_violation then v_hit := true;
      end;
      if not v_hit then raise exception 'E31 FAILED: invite log ne anjaan method le liya' using errcode = 'AX031'; end if;
      v_hit := false;
      begin
        update public.calendar_invite_log set ok = false where event_id = v_ev;
      exception when sqlstate 'AX032' then v_hit := true;
      end;
      if not v_hit then raise exception 'E31 FAILED: invite log badla ja saka' using errcode = 'AX031'; end if;
      v_hit := false;
      begin
        delete from public.calendar_invite_log where event_id = v_ev;
      exception when sqlstate 'AX032' then v_hit := true;
      end;
      if not v_hit then raise exception 'E31 FAILED: invite log mita diya gaya' using errcode = 'AX031'; end if;
      perform set_config('anexo.ledger_maintenance', 'on', true);
      delete from public.calendar_invite_log where event_id = v_ev;
      perform set_config('anexo.ledger_maintenance', 'off', true);
      v_chk := v_chk + 3;

      -- huqooq: browser ke roles na functions chala sakte hain na ledger padh sakte hain; engine (service_role) chala sakta hai
      if has_function_privilege('anon', 'public.calendar_rsvp_apply(uuid,text,text)', 'execute')
         or has_function_privilege('authenticated', 'public.calendar_rsvp_apply(uuid,text,text)', 'execute')
         or has_function_privilege('authenticated', 'public.calendar_rsvp_lookup(uuid)', 'execute')
         or has_function_privilege('authenticated', 'public.calendar_busy(uuid,text[],timestamptz,timestamptz)', 'execute')
         or has_table_privilege('authenticated', 'public.calendar_invite_log', 'select')
         or has_table_privilege('anon', 'public.calendar_invite_log', 'select') then
        raise exception 'E31 FAILED: browser ke roles ko naye functions/ledger ke huqooq mile hue hain' using errcode = 'AX031';
      end if;
      if not has_function_privilege('service_role', 'public.calendar_rsvp_apply(uuid,text,text)', 'execute') then
        raise exception 'E31 FAILED: service_role (engine) ko execute nahi mila' using errcode = 'AX031';
      end if;
      v_chk := v_chk + 2;
    end if;

    raise exception 'rollback marker' using errcode = 'AX099';   -- test ka saara data wapas (AX099: '...000' class-code hota to AX031 bhi pakad leta)
  exception when sqlstate 'AX099' then
    null;
  end;

  perform set_config('anexo.e31_selftest',
    case when v_skip is null then format('PASSED (%s checks, sab rollback)', v_chk)
         else 'SKIPPED — ' || v_skip || ' (schema lag chuka hai; functions test nahi hue — yeh line mujhe bhej dein)' end,
    false);
end $$;

-- ============================ jawab: ek row ===============================
select
  'E31 OK — schema lag gaya' as e31_result,
  current_setting('anexo.e31_selftest', true) as selftest,
  (select count(*) from public.calendar_attendees)                                  as attendees,
  (select count(*) from public.calendar_attendees where rsvp_token is not null)     as attendees_with_token,
  to_regclass('public.calendar_invite_log') is not null                             as ledger_ready,
  to_regclass('public.calendar_attendees_event_addr_uq') is not null                as event_address_unique,
  (has_table_privilege('authenticated', 'public.calendar_attendees', 'select')
     or has_table_privilege('anon', 'public.calendar_attendees', 'select'))         as rsvp_tokens_exposed_to_browser;
