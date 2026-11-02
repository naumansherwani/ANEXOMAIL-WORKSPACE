-- E130 — fix for E129: org_integrity_report() returned varchar columns (auth.users.email is varchar(255)) where the function declares text.
-- Every detail column is now cast to text. Only this one function is replaced (create or replace, idempotent). Run CHECK_E129 after it.
set search_path = public, extensions;

create or replace function public.org_integrity_report() returns table (problem text, org_id uuid, detail text)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return query select 'owner_without_member_row'::text, o.id, 'owner_id has no org_members row'::text from public.organisations o
    where o.owner_id is not null and o.deleted_at is null and not exists (select 1 from public.org_members m where m.org_id = o.id and m.user_id = o.owner_id);
  return query select 'org_without_any_owner'::text, o.id, 'no member with role owner'::text from public.organisations o
    where o.deleted_at is null and exists (select 1 from public.org_members m where m.org_id = o.id)
      and not exists (select 1 from public.org_members m where m.org_id = o.id and m.role::text = 'owner');
  return query select 'domain_collides_case_insensitive'::text, (array_agg(o.id))[1], lower(o.domain)::text from public.organisations o
    where o.domain is not null and o.deleted_at is null group by lower(o.domain) having count(*) > 1;
  return query select 'domain_not_clean'::text, o.id, o.domain::text from public.organisations o
    where o.domain is not null and (o.domain <> public.org_norm_domain(o.domain) or not public.org_domain_valid(o.domain) or public.org_domain_blocked(o.domain));
  return query select 'slug_not_clean'::text, o.id, o.slug::text from public.organisations o
    where o.slug is null or o.slug !~ '^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$';
  return query select 'name_not_clean'::text, o.id, left(coalesce(o.name, ''), 40)::text from public.organisations o
    where o.name is null or char_length(btrim(o.name)) not between 2 and 80;
  return query select 'event_chain_broken'::text, e.org_id, 'hash chain does not verify'::text from (select distinct ev.org_id from public.org_events ev) e where not public.org_events_verify(e.org_id);
  return query select 'user_without_organisation'::text, null::uuid, u.email::text from auth.users u
    where not exists (select 1 from public.org_members m where m.user_id = u.id);
end $$;

revoke all on function public.org_integrity_report() from public, anon, authenticated;
grant execute on function public.org_integrity_report() to service_role;
