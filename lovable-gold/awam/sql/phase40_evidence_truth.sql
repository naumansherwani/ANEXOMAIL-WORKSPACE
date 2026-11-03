-- ===========================================================================
-- ANEXOMAIL — Phase 40: EVIDENCE TRUTH (Phase 39 ka FIX 4 ka replacement)
-- Rule: historical evidence NEVER mutate. Koi clamp, koi normalise, koi
-- "PRE"/"MX" default nahi. Sirf: future writes par constraints enforce +
-- invalid rows ka clear audit report + VALIDATE sirf tab jab data genuinely
-- valid ho.
-- Tarteeb: phase37 -> phase38 -> phase39 -> phase40. Idempotent.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1) Constraints future writes par enforce (NOT VALID = purani rows chhoti
--    nahi, unhe touch bhi nahi kiya jata)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'movein_mailboxes_counts_chk'
                    and conrelid = 'public.movein_mailboxes'::regclass) then
    alter table public.movein_mailboxes
      add constraint movein_mailboxes_counts_chk check (
        coalesce(messages_source,0)   >= 0 and
        coalesce(messages_copied,0)   >= 0 and
        coalesce(messages_verified,0) >= 0 and
        coalesce(messages_copied,0)   <= coalesce(messages_source,0) and
        coalesce(messages_verified,0) <= coalesce(messages_copied,0)
      ) not valid;
  end if;

  if not exists (select 1 from pg_constraint
                  where conname = 'movein_dns_phase_chk'
                    and conrelid = 'public.movein_dns_checks'::regclass) then
    alter table public.movein_dns_checks
      add constraint movein_dns_phase_chk check (phase in ('PRE','POST')) not valid;
  end if;

  if not exists (select 1 from pg_constraint
                  where conname = 'movein_dns_record_chk'
                    and conrelid = 'public.movein_dns_checks'::regclass) then
    alter table public.movein_dns_checks
      add constraint movein_dns_record_chk check (record in ('MX','SPF','DKIM','DMARC')) not valid;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) AUDIT VIEW — invalid historical rows, jaisi hain waisi hi dikhti hain
-- ---------------------------------------------------------------------------
create or replace view public.movein_evidence_violations as
  select 'movein_mailboxes'::text as source_table,
         m.id                     as row_id,
         m.deal_id,
         case
           when coalesce(m.messages_source,0)   < 0
             or coalesce(m.messages_copied,0)   < 0
             or coalesce(m.messages_verified,0) < 0                        then 'negative_counts'
           when coalesce(m.messages_copied,0)   > coalesce(m.messages_source,0) then 'copied_gt_source'
           else 'verified_gt_copied'
         end                      as violation,
         jsonb_build_object(
           'messages_source',   m.messages_source,
           'messages_copied',   m.messages_copied,
           'messages_verified', m.messages_verified
         )                        as observed,
         m.created_at as observed_at
    from public.movein_mailboxes m
   where coalesce(m.messages_source,0)   < 0
      or coalesce(m.messages_copied,0)   < 0
      or coalesce(m.messages_verified,0) < 0
      or coalesce(m.messages_copied,0)   > coalesce(m.messages_source,0)
      or coalesce(m.messages_verified,0) > coalesce(m.messages_copied,0)
  union all
  select 'movein_dns_checks'::text,
         d.id,
         d.deal_id,
         case when d.phase is null or d.phase not in ('PRE','POST')
              then 'invalid_phase' else 'invalid_record' end,
         jsonb_build_object('phase', d.phase, 'record', d.record),
         d.checked_at
    from public.movein_dns_checks d
   where d.phase  is null or d.phase  not in ('PRE','POST')
      or d.record is null or d.record not in ('MX','SPF','DKIM','DMARC');

revoke all on public.movein_evidence_violations from public, anon, authenticated;
grant select on public.movein_evidence_violations to service_role;

-- ---------------------------------------------------------------------------
-- 3) CONDITIONAL VALIDATE — sirf clean data par, warna constraint NOT VALID
--    rehti hai aur invalid rows waisi hi (truthful) rehti hain
-- ---------------------------------------------------------------------------
create or replace function public.movein_evidence_validate()
returns table (constraint_name text, invalid_rows bigint, status text)
language plpgsql security definer set search_path = public as $$
declare
  v_mail  bigint;
  v_phase bigint;
  v_rec   bigint;
begin
  select count(*) into v_mail  from public.movein_evidence_violations
   where source_table = 'movein_mailboxes';
  select count(*) into v_phase from public.movein_evidence_violations
   where source_table = 'movein_dns_checks' and violation = 'invalid_phase';
  select count(*) into v_rec   from public.movein_evidence_violations
   where source_table = 'movein_dns_checks' and violation = 'invalid_record';

  if v_mail = 0 then
    begin alter table public.movein_mailboxes validate constraint movein_mailboxes_counts_chk;
    exception when undefined_object then null; end;
  end if;
  if v_phase = 0 then
    begin alter table public.movein_dns_checks validate constraint movein_dns_phase_chk;
    exception when undefined_object then null; end;
  end if;
  if v_rec = 0 then
    begin alter table public.movein_dns_checks validate constraint movein_dns_record_chk;
    exception when undefined_object then null; end;
  end if;

  return query
  select c.conname::text,
         case c.conname
           when 'movein_mailboxes_counts_chk' then v_mail
           when 'movein_dns_phase_chk'        then v_phase
           else v_rec
         end,
         case when c.convalidated then 'VALIDATED (data clean)'
              else 'NOT VALID — future writes enforced, historical rows preserved for manual correction'
         end
    from pg_constraint c
   where c.conname in ('movein_mailboxes_counts_chk','movein_dns_phase_chk','movein_dns_record_chk')
   order by 1;
end $$;

revoke all on function public.movein_evidence_validate() from public, anon, authenticated;
grant execute on function public.movein_evidence_validate() to service_role;

-- ---------------------------------------------------------------------------
-- 4) FINAL REPORT — execution ke end par saaf batata hai kitni rows invalid
-- ---------------------------------------------------------------------------
select * from public.movein_evidence_validate();

select source_table, violation, count(*) as remaining_invalid_rows
  from public.movein_evidence_violations
 group by 1, 2
 order by 1, 2;

-- Phase 40 done — evidence sach reh gaya, sirf constraints + audit.
