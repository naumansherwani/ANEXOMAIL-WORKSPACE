
-- =============================================================================
-- E96 — PEOPLE ka asli bug (live saboot: people-check.sh 06:43): anexo_rebuild_contacts har baar FAIL:
--   column "last_contact_at" of relation "contacts" does not exist.
-- Live `contacts` mein last_contact_at / company_id nahi; `contact_stats` mein org_id/updated_at nahi
-- (first_contact_at, computed_at hain). Purani phase62 file ke hisaab se likha function live schema se milta nahi tha,
-- exception khaa kar {"ok":false} lautata tha => People hamesha khali. Ab function live columns par (E95 ka to_addrs fix saath).
-- Apna domain (@anexomail.com) design se contact nahi. Idempotent. Rule 38/42/43/44.
-- =============================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

create or replace function public.anexo_rebuild_contacts(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
declare
  v_own_domain text := 'anexomail.com';
  v_count int := 0;
begin
  if p_org is null then
    return jsonb_build_object('ok', false, 'error', 'no_org');
  end if;

  -- distinct counterpart addresses touched by this org's mail, with rollups
  with inbound as (
    select lower(m.from_address) as address,
           m.from_name,
           m.sent_at,
           m.thread_id
      from public.mail_messages m
     where m.org_id = p_org
       and m.direction = 'in'
       and m.from_address is not null
       and lower(m.from_address) not like '%@' || v_own_domain
  ),
  outbound_to as (
    select lower(a) as address, null::text as from_name, m.sent_at, m.thread_id
      from public.mail_messages m, unnest(coalesce(nullif(m.to_addrs, '{}'::text[]), m.to_addresses)) a
     where m.org_id = p_org and m.direction = 'out'
       and lower(a) not like '%@' || v_own_domain
  ),
  outbound_cc as (
    select lower(a) as address, null::text as from_name, m.sent_at, m.thread_id
      from public.mail_messages m, unnest(coalesce(nullif(m.cc_addrs, '{}'::text[]), m.cc_addresses)) a
     where m.org_id = p_org and m.direction = 'out'
       and lower(a) not like '%@' || v_own_domain
  ),
  touched as (
    select address, from_name, sent_at, thread_id, 'in'::text as direction from inbound
    union all
    select address, from_name, sent_at, thread_id, 'out'::text as direction from outbound_to
    union all
    select address, from_name, sent_at, thread_id, 'out'::text as direction from outbound_cc
  ),
  agg as (
    select
      address,
      max(from_name) as display_name,
      count(*) filter (where direction = 'in')  as messages_in,
      count(*) filter (where direction = 'out') as messages_out,
      min(sent_at) as first_contact_at,
      max(sent_at) as last_contact_at,
      count(distinct thread_id) as open_threads
    from touched
    where address is not null and address <> ''
    group by address
  ),
  upserted_contacts as (
    insert into public.contacts (org_id, display_name, primary_address, addresses, company_domain)
    select p_org, a.display_name, a.address, array[a.address], split_part(a.address, '@', 2)
      from agg a
    on conflict (org_id, primary_address) do update
      set display_name    = coalesce(excluded.display_name, public.contacts.display_name),
          updated_at      = now()
    returning id, primary_address
  )
  insert into public.contact_stats (contact_id, messages_in, messages_out, open_threads, first_contact_at, last_contact_at, relationship)
  select
    c.id, a.messages_in, a.messages_out, a.open_threads, a.first_contact_at, a.last_contact_at,
    case
      when a.last_contact_at is null then 'new'
      when a.last_contact_at > now() - interval '14 days' then 'active'
      when a.last_contact_at < now() - interval '60 days' then 'dormant'
      else 'active'
    end
    from upserted_contacts c
    join agg a on a.address = c.primary_address
  on conflict (contact_id) do update
    set messages_in     = excluded.messages_in,
        messages_out    = excluded.messages_out,
        open_threads    = excluded.open_threads,
        first_contact_at = excluded.first_contact_at,
        last_contact_at = excluded.last_contact_at,
        relationship    = excluded.relationship,
        computed_at     = now();

  select count(*) into v_count from public.contacts where org_id = p_org;
  return jsonb_build_object('ok', true, 'contacts', v_count);
exception when others then
  raise notice '[anexo_rebuild_contacts] %', sqlerrm;
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end $$;

revoke all on function public.anexo_rebuild_contacts(uuid) from public, anon, authenticated;
grant execute on function public.anexo_rebuild_contacts(uuid) to service_role;
