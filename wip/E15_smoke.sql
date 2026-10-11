begin;
do $$
declare o uuid; r jsonb; d uuid; dom text := 'smoketest-co.com';
begin
  select m.org_id into o from org_members m join auth.users u on u.id = m.user_id
   where u.email = 'basic.test@anexomail.com' limit 1;
  if o is null then raise exception 'SMOKE_FAIL: basic.test org nahi mila'; end if;
  r := org_domain_add(o, 'https://www.SmokeTest-Co.com/x');
  if not coalesce((r->>'ok')::boolean, false) then raise exception 'SMOKE_FAIL add: %', r; end if;
  if r->'domain'->>'domain' <> dom then raise exception 'SMOKE_FAIL normalize: %', r; end if;
  d := (r->'domain'->>'id')::uuid;
  if org_domain_add(o, 'second-smoke.com')->>'error' is distinct from 'domain_limit_reached' then raise exception 'SMOKE_FAIL basic domain cap'; end if;
  if org_domain_add(o, 'not a domain')->>'error' is distinct from 'invalid_domain' then raise exception 'SMOKE_FAIL invalid'; end if;
  if org_domain_add(o, 'anexomail.com')->>'error' is distinct from 'reserved_domain' then raise exception 'SMOKE_FAIL reserved'; end if;
  if org_address_create(o, d, 'info')->>'error' is distinct from 'domain_not_verified' then raise exception 'SMOKE_FAIL not verified gate'; end if;
  if org_domain_set_checks(d, true, true, true, false, true)->'domain'->>'status' <> 'pending' then raise exception 'SMOKE_FAIL partial'; end if;
  if org_domain_set_checks(d, true, true, true, true, true)->'domain'->>'status' <> 'verified' then raise exception 'SMOKE_FAIL verified'; end if;
  if not (org_address_create(o, d, 'info')->>'ok')::boolean then raise exception 'SMOKE_FAIL create info'; end if;
  if not (org_address_create(o, d, 'sales', 'shared')->>'ok')::boolean then raise exception 'SMOKE_FAIL create sales'; end if;
  if not (org_address_create(o, d, 'support')->>'ok')::boolean then raise exception 'SMOKE_FAIL create support'; end if;
  if org_address_create(o, d, 'hr')->>'error' is distinct from 'mailbox_limit' then raise exception 'SMOKE_FAIL basic mailbox cap'; end if;
  if not (org_address_create(o, d, 'team', 'alias', null, 'info@' || dom)->>'ok')::boolean then raise exception 'SMOKE_FAIL alias free'; end if;
  if org_address_create(o, d, 'INFO')->>'error' is distinct from 'address_taken' then raise exception 'SMOKE_FAIL taken'; end if;
  if org_address_create(o, d, 'bad name')->>'error' is distinct from 'invalid_local_part' then raise exception 'SMOKE_FAIL local'; end if;
  if jsonb_array_length(org_mail_sync_state()->'addresses') < 4 then raise exception 'SMOKE_FAIL sync state'; end if;
  if not (org_address_remove(o, (org_address_list(o)->0->>'id')::uuid)->>'ok')::boolean then raise exception 'SMOKE_FAIL remove addr'; end if;
  if not (org_address_create(o, d, 'info')->>'ok')::boolean then raise exception 'SMOKE_FAIL recreate after remove'; end if;
  if not (org_domain_remove(o, d)->>'ok')::boolean then raise exception 'SMOKE_FAIL domain remove'; end if;
  if not (org_domain_add(o, 'smoketest-co.com')->>'ok')::boolean then raise exception 'SMOKE_FAIL readd domain'; end if;
  raise notice 'SMOKE_ALL_PASS (17 checks)';
end $$;
rollback;
