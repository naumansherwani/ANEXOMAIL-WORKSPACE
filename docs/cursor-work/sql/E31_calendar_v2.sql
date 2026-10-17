-- =============================================================================
-- E31 — Calendar v2 (18 Oct 2026): real invitations, RSVP, invitation ledger, one-query busy lookup.
--
-- Pehle: attendees sirf `calendar_attendees` mein likhe jate the, kisi ko mail nahi jati thi, RSVP ka koi rasta nahi tha.
-- Ab (Rust engine `calendar.create/update/invites.resend/rsvp.*/busy` use karta hai):
--   * calendar_events    : sequence (iTIP SEQUENCE), cancelled_at, tz
--   * calendar_attendees : rsvp_token (DB ka random uuid, email mein jata hai), role, rsvp_at, rsvp_comment,
--                          invite_status (not_sent|sent|failed), invite_sent_at, invite_error
--   * calendar_invite_log: har invitation/cancel mail ka saboot (kisko, kaun si SEQUENCE, SMTP ka jawab) — quota bhi isi se
--   * calendar_rsvp_lookup / calendar_rsvp_apply : token se ek hi jagah jawab (SQL injection ka sawal hi nahi: uuid type)
--   * calendar_busy      : kuch logon ki busy intervals EK query mein (Find-a-time ke liye)
--
-- Sirf additive: koi table/column drop nahi, kisi mojooda cheez ka naam nahi badalta. Idempotent. Sirf service_role (engine) chalata hai.
-- Fail ho to: usi file ko shuru se theek karo (naya naam banned).
-- =============================================================================

begin;

-- 1. events ------------------------------------------------------------------
alter table public.calendar_events add column if not exists sequence     integer not null default 0;
alter table public.calendar_events add column if not exists cancelled_at timestamptz;
alter table public.calendar_events add column if not exists tz           text;

-- 2. attendees ---------------------------------------------------------------
alter table public.calendar_attendees add column if not exists rsvp_token     uuid not null default gen_random_uuid();
alter table public.calendar_attendees add column if not exists role           text not null default 'required';
alter table public.calendar_attendees add column if not exists rsvp_at        timestamptz;
alter table public.calendar_attendees add column if not exists rsvp_comment   text;
alter table public.calendar_attendees add column if not exists invite_status  text not null default 'not_sent';
alter table public.calendar_attendees add column if not exists invite_sent_at timestamptz;
alter table public.calendar_attendees add column if not exists invite_error   text;

create unique index if not exists calendar_attendees_rsvp_token_uq on public.calendar_attendees (rsvp_token);

-- (event, address) unique — sirf tab jab koi duplicate maujood na ho (mojooda data ko haath nahi lagate)
do $$
begin
  if exists (
    select 1 from public.calendar_attendees group by event_id, lower(address) having count(*) > 1
  ) then
    raise notice 'E31: duplicate (event, address) rows maujood hain — unique index nahi lagaya (engine upsert se bhi theek chalta hai)';
  else
    create unique index if not exists calendar_attendees_event_addr_uq on public.calendar_attendees (event_id, lower(address));
  end if;
end $$;

-- 3. invitation ledger -------------------------------------------------------
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

-- 4. RSVP by token -----------------------------------------------------------
create or replace function public.calendar_rsvp_lookup(p_token uuid)
returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
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
  where a.rsvp_token = p_token
$$;

create or replace function public.calendar_rsvp_apply(p_token uuid, p_response text, p_comment text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_event uuid;
  v_cancelled boolean;
begin
  if p_response not in ('accepted', 'tentative', 'declined') then
    return jsonb_build_object('found', false, 'error', 'bad_response');
  end if;
  select a.event_id, (e.status = 'cancelled' or e.cancelled_at is not null)
    into v_event, v_cancelled
    from public.calendar_attendees a join public.calendar_events e on e.id = a.event_id
   where a.rsvp_token = p_token;
  if v_event is null then
    return jsonb_build_object('found', false, 'error', 'not_found');
  end if;
  if v_cancelled then
    return jsonb_build_object('found', true, 'error', 'cancelled') || coalesce(public.calendar_rsvp_lookup(p_token), '{}'::jsonb);
  end if;
  update public.calendar_attendees
     set response = p_response, rsvp_at = now(), rsvp_comment = nullif(left(coalesce(p_comment, ''), 500), '')
   where rsvp_token = p_token;
  return public.calendar_rsvp_lookup(p_token);
end;
$$;

-- 5. busy intervals for a few people in ONE query ----------------------------
create or replace function public.calendar_busy(p_org uuid, p_addresses text[], p_from timestamptz, p_to timestamptz)
returns table (address text, starts_at timestamptz, ends_at timestamptz)
language sql stable
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

revoke all on function public.calendar_rsvp_lookup(uuid) from public, anon, authenticated;
revoke all on function public.calendar_rsvp_apply(uuid, text, text) from public, anon, authenticated;
revoke all on function public.calendar_busy(uuid, text[], timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.calendar_rsvp_lookup(uuid) to service_role;
grant execute on function public.calendar_rsvp_apply(uuid, text, text) to service_role;
grant execute on function public.calendar_busy(uuid, text[], timestamptz, timestamptz) to service_role;

-- 6. self-test (sub-transaction, rolled back) --------------------------------
do $$
declare
  v_org uuid := gen_random_uuid(); v_ev uuid; v_tok uuid; v_r jsonb; v_n int; v_hit boolean := false;
begin
  begin
    insert into public.calendar_events (org_id, title, agenda, starts_at, ends_at, organiser)
      values (v_org, 'E31 selftest', 'selftest agenda', now() + interval '1 day', now() + interval '1 day 30 minutes', 'org@e31.test')
      returning id into v_ev;
    insert into public.calendar_attendees (event_id, org_id, address, response)
      values (v_ev, v_org, 'Guest@E31.test', 'needs_action'), (v_ev, v_org, 'org@e31.test', 'accepted');
    select rsvp_token into v_tok from public.calendar_attendees where event_id = v_ev and lower(address) = 'guest@e31.test';
    if v_tok is null then raise exception 'E31 FAILED: rsvp_token missing'; end if;

    v_r := public.calendar_rsvp_lookup(v_tok);
    if not ((v_r->>'found')::boolean and v_r->>'response' = 'needs_action' and v_r->>'title' = 'E31 selftest') then
      raise exception 'E31 FAILED: lookup %', v_r;
    end if;
    v_r := public.calendar_rsvp_apply(v_tok, 'accepted', 'see you');
    if v_r->>'response' <> 'accepted' or (v_r->>'rsvp_at') is null then raise exception 'E31 FAILED: apply %', v_r; end if;
    v_r := public.calendar_rsvp_apply(v_tok, 'banana');
    if v_r->>'error' <> 'bad_response' then raise exception 'E31 FAILED: bad response not refused %', v_r; end if;
    v_r := public.calendar_rsvp_apply(gen_random_uuid(), 'accepted');
    if v_r->>'error' <> 'not_found' then raise exception 'E31 FAILED: unknown token not refused %', v_r; end if;

    select count(*) into v_n from public.calendar_busy(v_org, array['GUEST@e31.test'], now(), now() + interval '3 days');
    if v_n <> 1 then raise exception 'E31 FAILED: busy lookup returned % rows', v_n; end if;
    update public.calendar_attendees set response = 'declined' where rsvp_token = v_tok;
    select count(*) into v_n from public.calendar_busy(v_org, array['guest@e31.test'], now(), now() + interval '3 days');
    if v_n <> 0 then raise exception 'E31 FAILED: declined attendee still busy (%)', v_n; end if;

    update public.calendar_attendees set response = 'accepted' where rsvp_token = v_tok;
    update public.calendar_events set status = 'cancelled', cancelled_at = now() where id = v_ev;
    v_r := public.calendar_rsvp_apply(v_tok, 'declined');
    if v_r->>'error' <> 'cancelled' then raise exception 'E31 FAILED: cancelled event accepted an RSVP %', v_r; end if;

    insert into public.calendar_invite_log (org_id, event_id, address, method, ok) values (v_org, v_ev, 'guest@e31.test', 'REQUEST', true);
    begin
      insert into public.calendar_invite_log (org_id, event_id, address, method, ok) values (v_org, v_ev, 'x@y.zz', 'BANANA', true);
    exception when check_violation then v_hit := true;
    end;
    if not v_hit then raise exception 'E31 FAILED: invite log accepted an unknown method'; end if;

    raise exception 'E31_selftest_ok';
  exception when others then
    if sqlerrm <> 'E31_selftest_ok' then raise exception '%', sqlerrm; end if;
  end;
end $$;

commit;

-- read-only proof (run after):
--   select count(*) filter (where rsvp_token is not null) as with_token, count(*) as total from public.calendar_attendees;
--   select to_regclass('public.calendar_invite_log') is not null as ledger_ready;
