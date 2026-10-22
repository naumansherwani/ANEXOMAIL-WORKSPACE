
-- E54 — mail bhejne ki queue: ek row ek hi worker uthaye (B3, 21 Oct 2026)
-- Pehle Bun `mail-worker.ts` sirf `select ... status='queued'` karta tha: do worker (Bun + Rust) ek saath chalein to ek mail DO baar jati.
-- Ab dono `mail_queue_claim` se uthate hain (FOR UPDATE SKIP LOCKED + claimed_at): ek row ek waqt mein ek worker ke paas; worker mar jaye to
-- 10 minute baad row dobara uthai ja sakti hai. Undo-send: `mail_queue_cancel` sirf tab chalta hai jab row abhi kisi worker ne nahi uthayi.
-- Sirf service_role. Dobara chalana safe (mail_scheduled ke maujooda columns/rows ko haath nahi lagta; sirf claimed_at jodta hai).
do $$
begin
  if to_regclass('public.mail_scheduled') is not null then
    alter table public.mail_scheduled add column if not exists claimed_at timestamptz;
    create index if not exists mail_scheduled_queue_idx on public.mail_scheduled (status, send_at) where status in ('holding', 'queued');
  end if;
end $$;

create or replace function public.mail_queue_release()
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if to_regclass('public.mail_scheduled') is null then return 0; end if;
  update public.mail_scheduled set status = 'queued' where status = 'holding' and send_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.mail_queue_claim(_limit integer default 20, _stale_minutes integer default 10)
returns setof public.mail_scheduled language plpgsql security definer set search_path = public as $$
begin
  return query
  update public.mail_scheduled s set claimed_at = now()
   where s.id in (
     select q.id from public.mail_scheduled q
      where q.status = 'queued' and q.send_at <= now()
        and (q.claimed_at is null or q.claimed_at < now() - make_interval(mins => greatest(1, coalesce(_stale_minutes, 10))))
      order by q.send_at
      limit greatest(1, least(coalesce(_limit, 20), 100))
        for update skip locked)
  returning s.*;
end $$;

create or replace function public.mail_queue_cancel(_id uuid, _user uuid, _org uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update public.mail_scheduled set status = 'cancelled'
   where id = _id and org_id = _org and user_id = _user and status in ('holding', 'queued') and claimed_at is null;
  get diagnostics n = row_count;
  return n > 0;
end $$;

revoke all on function public.mail_queue_release() from public, anon, authenticated;
revoke all on function public.mail_queue_claim(integer, integer) from public, anon, authenticated;
revoke all on function public.mail_queue_cancel(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.mail_queue_release() to service_role;
grant execute on function public.mail_queue_claim(integer, integer) to service_role;
grant execute on function public.mail_queue_cancel(uuid, uuid, uuid) to service_role;
