-- =============================================================================
-- Step 5 — mail_thread_assign
-- Recorded 25 Sep 2026. Already applied on Supabase (CREATE FUNCTION, REVOKE, GRANT).
-- Do not run again.
-- Plan gate (Pro+) lives in Express, not in this function.
-- =============================================================================

set search_path = public, extensions;

create or replace function public.mail_thread_assign(
  _thread_id uuid,
  _assignee text,
  _org_id uuid
)
returns public.mail_threads
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.mail_threads;
begin
  update public.mail_threads
  set assignee = nullif(btrim(_assignee), '')
  where id = _thread_id
    and org_id = _org_id
  returning * into result;

  if result.id is null then
    raise exception 'thread_not_found_or_not_owned';
  end if;

  return result;
end;
$$;

revoke execute on function public.mail_thread_assign(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.mail_thread_assign(uuid, text, uuid) to service_role;
