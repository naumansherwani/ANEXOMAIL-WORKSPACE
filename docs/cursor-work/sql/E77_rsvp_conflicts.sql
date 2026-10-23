
-- E77 — Calendar spec baaqi: COLLISION WARNING jab RSVP aaye. 23 Oct 2026. Dobara chalana safe. Koi DROP nahi, koi table nahi badli.
-- Kya: invitation ke RSVP page par (token wala) guest ko pehle hi dikhe "is waqt aap ki aur meeting hai" — jawab dene se PEHLE.
--   calendar_rsvp_conflicts(token) -> {count, overlaps:[{starts_at, ends_at}] (max 3)}.
-- Privacy (RSVP token ek insaan ke haath mein hai, bahar ka bhi ho sakta hai): SIRF ginti aur waqt. Kisi doosri meeting ka TITLE, agenda,
--   location, organiser, doosre guests KABHI nahi. Sirf wohi events jinmein yehi address attendee hai, usi organisation ke, aur is event se alag.
-- Qaida calendar_busy ka mirror (E31): cancelled/hold nahi, declined nahi. Aadhi-khuli overlap (starts < doosre ka end AND ends > doosre ka start)
--   — aakhir-shuru chhune wali (back-to-back) meetings conflict NAHI.
-- Advance: lock_timeout/statement_timeout, STABLE, pinned search_path, sirf service_role (Rust), token uuid type (injection nahi),
--   ajnabi token / cancelled meeting par khali jawab (token ka wujood leak nahi hota), limit 3 + count LIMIT 50 par bounded (lamba loop nahi).
set lock_timeout = '5s';
set statement_timeout = '30s';

create or replace function public.calendar_rsvp_conflicts(p_token uuid)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  with me as (
    select a.event_id, lower(a.address) as addr, e.org_id, e.starts_at, e.ends_at
      from public.calendar_attendees a
      join public.calendar_events e on e.id = a.event_id
     where a.rsvp_token = p_token
       and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
  ), hits as (
    select e.starts_at, e.ends_at
      from me
      join public.calendar_attendees a on lower(a.address) = me.addr
      join public.calendar_events e on e.id = a.event_id
     where e.org_id = me.org_id
       and e.id <> me.event_id
       and e.starts_at < me.ends_at and e.ends_at > me.starts_at
       and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
       and coalesce(a.response, 'needs_action') <> 'declined'
       and coalesce(e.kind, 'meeting') <> 'hold'
     order by e.starts_at
     limit 50
  )
  select jsonb_build_object(
    'count',    (select count(*) from hits),
    'overlaps', coalesce((select jsonb_agg(jsonb_build_object('starts_at', h.starts_at, 'ends_at', h.ends_at))
                            from (select * from hits limit 3) h), '[]'::jsonb))
$$;

revoke all on function public.calendar_rsvp_conflicts(uuid) from public, anon, authenticated;
grant execute on function public.calendar_rsvp_conflicts(uuid) to service_role;
comment on function public.calendar_rsvp_conflicts(uuid) is 'RSVP page conflict chip (E77): count + up to 3 time ranges of the same address''s other meetings; never titles.';

notify pgrst, 'reload schema';
