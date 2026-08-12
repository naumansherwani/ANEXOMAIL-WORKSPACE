-- ===========================================================================
-- ANEXOMAIL — Phase 39: Move-In surgical fixes (Phase 37 + 38 ka complement)
-- Sirf 4 cheezein: intent binding · rollback transitions · reference counter
-- · NOT VALID constraints validate. Baqi Phase 37/38 ko touch nahi kiya.
-- Chalane ki tarteeb: phase37 -> phase38 -> phase39
-- Idempotent: dobara chala sakte ho.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- FIX 1 (P0) — PAYMENT INTENT BINDING: intent exact deal ke saath bind
-- ---------------------------------------------------------------------------
alter table public.billing_intents add column if not exists movein_deal_id uuid;
alter table public.billing_intents add column if not exists movein_leg     text;

alter table public.billing_intents drop constraint if exists billing_intents_movein_leg_chk;
alter table public.billing_intents add constraint billing_intents_movein_leg_chk
  check (movein_leg is null or movein_leg in ('deposit','final'));

-- purani attachments se backfill (Phase 37/38 ke live deals)
update public.billing_intents bi
   set movein_deal_id = p.deal_id, movein_leg = p.leg
  from public.movein_payments p
 where p.intent_id = bi.id
   and (bi.movein_deal_id is distinct from p.deal_id or bi.movein_leg is distinct from p.leg);

-- ek intent = ek deal ka ek leg, hamesha
create unique index if not exists billing_intents_movein_bind_uidx
  on public.billing_intents (movein_deal_id, movein_leg)
  where movein_deal_id is not null and movein_leg is not null;

create or replace function public.movein_attach_intent(p_deal uuid, p_leg text, p_intent uuid)
returns void language plpgsql security definer set search_path = public as $$
declare d record; i record; v_expected numeric;
begin
  if p_leg not in ('deposit','final') then
    raise exception 'invalid_leg:%', p_leg using errcode = '22023';
  end if;

  select * into d from public.movein_deals where id = p_deal for update;
  if d is null then raise exception 'deal_not_found' using errcode = '22023'; end if;

  select * into i from public.billing_intents where id = p_intent for update;
  if i is null then raise exception 'intent_not_found' using errcode = '22023'; end if;

  if i.kind <> 'movein' then
    raise exception 'intent_kind_mismatch:%', i.kind using errcode = '22023';
  end if;
  if coalesce(i.currency,'') <> 'GBP' then
    raise exception 'intent_currency_mismatch:%', i.currency using errcode = '22023';
  end if;
  if d.user_id is null or i.user_id is distinct from d.user_id then
    raise exception 'intent_user_mismatch' using errcode = '42501';
  end if;

  -- HARD BIND: doosre deal/leg ka intent kabhi re-use nahi
  if i.movein_deal_id is not null and i.movein_deal_id <> p_deal then
    raise exception 'intent_bound_to_other_deal:%', i.movein_deal_id using errcode = '23505';
  end if;
  if i.movein_leg is not null and i.movein_leg <> p_leg then
    raise exception 'intent_bound_to_other_leg:%', i.movein_leg using errcode = '23505';
  end if;
  -- purana / already settled intent naye deal par attach nahi ho sakta
  if i.movein_deal_id is null and i.state in ('paid','entitled') then
    raise exception 'intent_already_settled_unbound' using errcode = '23505';
  end if;
  if i.created_at < d.created_at then
    raise exception 'intent_predates_deal' using errcode = '22023';
  end if;

  perform public.movein_sync_payments(p_deal);
  select amount_gbp into v_expected from public.movein_payments where deal_id = p_deal and leg = p_leg;
  if v_expected is null or coalesce(i.amount_expected, -1) <> v_expected then
    raise exception 'intent_amount_mismatch:expected=% got=%', v_expected, i.amount_expected
      using errcode = '22023';
  end if;

  if exists (select 1 from public.movein_payments p
              where p.intent_id = p_intent and not (p.deal_id = p_deal and p.leg = p_leg)) then
    raise exception 'intent_already_attached' using errcode = '23505';
  end if;

  -- bind pehle (unique index race ko rokta hai), phir payment row
  update public.billing_intents
     set movein_deal_id = p_deal, movein_leg = p_leg, updated_at = now()
   where id = p_intent;

  update public.movein_payments
     set intent_id = p_intent,
         state = case when state = 'due' then 'invoiced' else state end,
         invoiced_at = coalesce(invoiced_at, now()), updated_at = now()
   where deal_id = p_deal and leg = p_leg;

  if p_leg = 'deposit' then
    update public.movein_deals set deposit_intent_id = p_intent, updated_at = now() where id = p_deal;
  else
    update public.movein_deals set final_intent_id = p_intent, updated_at = now() where id = p_deal;
  end if;

  insert into public.movein_audit (deal_id, actor, action, reason, evidence, payload)
    values (p_deal, 'system', 'payment_invoiced', p_leg || ' invoice issued', p_intent::text,
            jsonb_build_object('leg', p_leg, 'intent_id', p_intent, 'amount_gbp', v_expected));
  perform public.movein_sync_payments(p_deal);
end $$;

revoke all on function public.movein_attach_intent(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.movein_attach_intent(uuid, text, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- FIX 2 (P0) — ROLLBACK TRANSITIONS legal: cutover ke baad bhi ON_HOLD/recovery
-- ---------------------------------------------------------------------------
insert into public.movein_transitions (from_state, to_state, gate) values
  ('CUTOVER_EXECUTED','ON_HOLD',null),
  ('POST_CUTOVER_VERIFIED','ON_HOLD',null),
  ('FINAL_50_INVOICED','ON_HOLD',null),
  -- recovery raaste (ON_HOLD se wapis kaam par)
  ('ON_HOLD','DATA_COPY','deposit_paid'),
  ('ON_HOLD','DATA_VERIFIED','data_verified'),
  ('ON_HOLD','CUTOVER_READY','cutover_ready')
on conflict (from_state, to_state) do update set gate = excluded.gate;

-- ---------------------------------------------------------------------------
-- FIX 3 (P1) — REFERENCE COUNTER: count(*) nahi, asli highest NNN
-- ---------------------------------------------------------------------------
with parsed as (
  select coalesce(nullif(substring(reference from 'MOVE-IN-([0-9]{4})-'), '')::int,
                  extract(year from created_at)::int)                      as year,
         coalesce(nullif(substring(reference from 'MOVE-IN-[0-9]{4}-([0-9]+)$'), '')::int, 0) as seq
    from public.movein_deals
   where reference is not null
)
insert into public.movein_reference_counter (year, last_value)
select year, max(seq) from parsed group by year
on conflict (year) do update
  set last_value = greatest(public.movein_reference_counter.last_value, excluded.last_value);

-- ---------------------------------------------------------------------------
-- FIX 4 (P2) — NOT VALID constraints: data clean karo, phir VALIDATE
-- ---------------------------------------------------------------------------
-- mailbox counts: negatives 0, copied <= source, verified <= copied
update public.movein_mailboxes set
  messages_source    = greatest(coalesce(messages_source,0), 0),
  messages_copied    = greatest(coalesce(messages_copied,0), 0),
  messages_verified  = greatest(coalesce(messages_verified,0), 0),
  folders_found      = greatest(coalesce(folders_found,0), 0),
  contacts_count     = greatest(coalesce(contacts_count,0), 0),
  calendar_events    = greatest(coalesce(calendar_events,0), 0),
  aliases_count      = greatest(coalesce(aliases_count,0), 0),
  signatures_count   = greatest(coalesce(signatures_count,0), 0),
  exceptions         = greatest(coalesce(exceptions,0), 0);

update public.movein_mailboxes
   set messages_copied = messages_source
 where messages_copied > messages_source;

update public.movein_mailboxes
   set messages_verified = messages_copied
 where messages_verified > messages_copied;

-- DNS rows: phase/record normalise, ajnabi values ko safe default
update public.movein_dns_checks set phase = upper(trim(phase)) where phase is distinct from upper(trim(phase));
update public.movein_dns_checks set phase = 'PRE'  where phase is null or phase not in ('PRE','POST');
update public.movein_dns_checks set record = upper(trim(record)) where record is distinct from upper(trim(record));
update public.movein_dns_checks set record = 'MX' where record is null or record not in ('MX','SPF','DKIM','DMARC');

do $$
begin
  begin alter table public.movein_mailboxes  validate constraint movein_mailboxes_counts_chk; exception when undefined_object then null; end;
  begin alter table public.movein_dns_checks validate constraint movein_dns_phase_chk;        exception when undefined_object then null; end;
  begin alter table public.movein_dns_checks validate constraint movein_dns_record_chk;       exception when undefined_object then null; end;
end $$;

-- Phase 39 done — sirf ye 4 fixes.
