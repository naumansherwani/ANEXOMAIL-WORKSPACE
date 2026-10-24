-- E85 — Pro "Shared inbox": mail_thread_assign ke do overloads (text aur uuid) PostgREST ko confuse karte the (PGRST203) — assign Bun aur Rust dono par fail. 24 Oct 2026. Dobara chalana safe.
-- Ab sirf EK function: (uuid thread, uuid assignee|null, uuid org). null = assign hatao. Assignee us org ka active member hona chahiye (pehle koi bhi user uuid chal jata tha).
set lock_timeout = '5s';
set statement_timeout = '60s';

drop function if exists public.mail_thread_assign(uuid, text, uuid);

create or replace function public.mail_thread_assign(_thread_id uuid, _assignee uuid, _org_id uuid)
returns public.mail_threads
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result public.mail_threads;
begin
  if _assignee is not null and not exists (
    select 1 from public.org_members m
    where m.org_id = _org_id and m.user_id = _assignee and m.status = 'active'
  ) then
    raise exception 'assignee_not_member';
  end if;

  update public.mail_threads
  set assignee = _assignee
  where id = _thread_id
    and org_id = _org_id
  returning * into result;

  if result.id is null then
    raise exception 'thread_not_found_or_not_owned';
  end if;

  return result;
end;
$$;

revoke execute on function public.mail_thread_assign(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.mail_thread_assign(uuid, uuid, uuid) to service_role;
