-- ===========================================================================
-- ANEXOMAIL Workspace — PHASE 38: MOVE-IN SECURITY & INTEGRITY HARDENING
-- Complements sql/phase37_movein_ops.sql (no rewrite, surgical fixes only).
-- Idempotent + self-healing. Run in Supabase #4 SQL editor.
-- ===========================================================================
begin;

-- ---------------------------------------------------------------------------
-- P0.1  SECURITY DEFINER / RPC LOCKDOWN
--       Har movein_* function ka EXECUTE public/anon/authenticated se revoke.
--       Baad mein sirf allowed list ko grant kiya jata hai (P0.3 ke neeche).
-- ---------------------------------------------------------------------------
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname like 'movein_%'
  loop
    execute format('revoke all on function %s from public', f.sig);
    execute format('revoke all on function %s from anon', f.sig);
    execute format('revoke all on function %s from authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- P0.2  CUSTOMER AUTHORIZATION — customer sirf apna deal dekhe
-- ---------------------------------------------------------------------------
create or replace function public.movein_is_deal_member(p_deal uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.movein_deals d
     where d.id = p_deal
       and auth.uid() is not null
       and (d.user_id = auth.uid() or d.owner_id = auth.uid())
  )
$$;

create or replace function public.movein_customer_view(p_deal uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if not public.movein_is_deal_member(p_deal) then
    raise exception 'not_authorized_for_deal' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'reference', d.reference,
    'company', d.company,
    'state', d.state,
    'progress', (select round(100.0 * count(distinct a.to_state) / 9.0)
                   from public.movein_audit a
                  where a.deal_id = d.id
                    and a.to_state::text = any (array['PLAN_ACCEPTED','DEPOSIT_PAID_50','MIGRATION_PREP',
                        'DATA_VERIFIED','CUTOVER_SCHEDULED','CUTOVER_EXECUTED',
                        'POST_CUTOVER_VERIFIED','FINAL_50_PAID','HANDOVER_COMPLETE'])),
    'cutover_window', jsonb_build_object('start', d.cutover_window_start, 'end', d.cutover_window_end),
    'cutover_note', 'Scheduled overnight cut-over designed to avoid interruption.',
    'payments', (select coalesce(jsonb_agg(jsonb_build_object('leg', leg, 'amount_gbp', amount_gbp,
                        'state', state) order by leg), '[]'::jsonb)
                   from public.movein_payments where deal_id = d.id),
    'dns_proof', (select coalesce(jsonb_agg(jsonb_build_object('phase', phase, 'record', record,
                        'result', result, 'checked_at', checked_at) order by phase, record), '[]'::jsonb)
                   from public.movein_dns_proof where deal_id = d.id),
    'mailboxes_verified', (select count(*) from public.movein_mailboxes where deal_id = d.id and result='VERIFIED'),
    'mailboxes_total', (select count(*) from public.movein_mailboxes where deal_id = d.id),
    'customer_action', (select coalesce(jsonb_agg(jsonb_build_object('reason', reason,
                        'required_action', required_action)), '[]'::jsonb)
                   from public.movein_exceptions
                  where deal_id = d.id and resolved_at is null
                    and severity = 'CUSTOMER_ACTION_REQUIRED'),
    'health', public.movein_health_calc(d.id)
  ) into v from public.movein_deals d where d.id = p_deal;

  return coalesce(v, jsonb_build_object('ok', false, 'error', 'deal_not_found'));
end $$;

-- ---------------------------------------------------------------------------
-- P0.3  FOUNDER DATA EXPOSURE CLOSE
--       Global views/RPCs sirf service_role. Customer ke liye user-filtered views.
-- ---------------------------------------------------------------------------
revoke all on public.movein_cash_clock    from authenticated, anon;
revoke all on public.movein_attention     from authenticated, anon;
revoke all on public.movein_mailbox_gaps  from authenticated, anon;
revoke all on public.movein_dns_proof     from authenticated, anon;
grant select on public.movein_cash_clock, public.movein_attention,
  public.movein_mailbox_gaps, public.movein_dns_proof to service_role;

-- capacity_state public promise hai (kitne slot bache) — read rehne do
grant select on public.movein_capacity_state to authenticated, service_role;

-- customer-safe, strictly user-filtered
create or replace view public.movein_my_mailbox_gaps
with (security_invoker = on) as
  select g.* from public.movein_mailbox_gaps g
   where exists (select 1 from public.movein_deals d
                  where d.id = g.deal_id
                    and (d.user_id = auth.uid() or d.owner_id = auth.uid()));

create or replace view public.movein_my_dns_proof
with (security_invoker = on) as
  select p.* from public.movein_dns_proof p
   where exists (select 1 from public.movein_deals d
                  where d.id = p.deal_id
                    and (d.user_id = auth.uid() or d.owner_id = auth.uid()));

grant select on public.movein_my_mailbox_gaps, public.movein_my_dns_proof
  to authenticated, service_role;

-- evidence bundle + cockpit = founder/service-role only (P0.1 revoke already)
grant execute on function public.movein_evidence_bundle(uuid) to service_role;
grant execute on function public.movein_cockpit() to service_role;

-- customer-callable RPCs (khud authorization karte hain)
grant execute on function public.movein_is_deal_member(uuid) to authenticated;
grant execute on function public.movein_customer_view(uuid)  to authenticated;

-- ---------------------------------------------------------------------------
-- P0.4  PAYMENT INTENT BINDING — galat intent kabhi attach na ho
-- ---------------------------------------------------------------------------
create unique index if not exists movein_payments_intent_uidx
  on public.movein_payments (intent_id) where intent_id is not null;

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

  perform public.movein_sync_payments(p_deal);
  select amount_gbp into v_expected from public.movein_payments where deal_id = p_deal and leg = p_leg;
  if v_expected is null or coalesce(i.amount_expected, -1) <> v_expected then
    raise exception 'intent_amount_mismatch:expected=% got=%', v_expected, i.amount_expected
      using errcode = '22023';
  end if;

  -- already attached to another deal/leg?
  if exists (select 1 from public.movein_payments p
              where p.intent_id = p_intent and not (p.deal_id = p_deal and p.leg = p_leg)) then
    raise exception 'intent_already_attached' using errcode = '23505';
  end if;

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

-- ---------------------------------------------------------------------------
-- P0.5  MAILBOX VERIFICATION GATE — zero-mailbox kabhi pass na ho
-- ---------------------------------------------------------------------------
create or replace function public.movein_data_verified_ok(p_deal uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select (count(*) > 0)
       and (count(*) = greatest(coalesce(d.mailbox_count, 0), 1))
       and (count(*) filter (where m.result <> 'VERIFIED') = 0)
       and (count(*) filter (where m.messages_source <= 0) = 0)
       and (count(*) filter (where m.messages_verified < m.messages_source) = 0)
      from public.movein_mailboxes m where m.deal_id = d.id
  ), false)
  from public.movein_deals d where d.id = p_deal
$$;

-- transition: sirf data_verified gate ki jagah nayi strict check (baqi same)
create or replace function public.movein_transition(
  p_deal uuid,
  p_to public.movein_state,
  p_actor text default 'founder',
  p_reason text default null,
  p_evidence text default null,
  p_actor_id uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare d record; v_gate text; v_ok boolean := true; v_why text;
begin
  select * into d from public.movein_deals where id = p_deal for update;
  if d is null then return jsonb_build_object('ok', false, 'error', 'deal_not_found'); end if;
  if d.state = p_to then
    return jsonb_build_object('ok', true, 'state', p_to, 'idempotent', true);
  end if;

  select gate into v_gate from public.movein_transitions
   where from_state = d.state and to_state = p_to;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'illegal_transition',
      'from', d.state, 'to', p_to,
      'allowed', (select coalesce(jsonb_agg(to_state), '[]'::jsonb)
                    from public.movein_transitions where from_state = d.state));
  end if;

  if v_gate = 'deposit_paid' and not public.movein_leg_paid(p_deal, 'deposit') then
    v_ok := false; v_why := 'deposit_50_not_paid';
  elsif v_gate = 'final_paid' and not public.movein_leg_paid(p_deal, 'final') then
    v_ok := false; v_why := 'final_50_not_paid';
  elsif v_gate = 'data_verified' and not public.movein_data_verified_ok(p_deal) then
    v_ok := false; v_why := 'mailbox_ledger_not_verified';
  elsif v_gate = 'cutover_ready' and not public.movein_cutover_ready(p_deal) then
    v_ok := false; v_why := 'runbook_or_dns_or_exception_open';
  elsif v_gate = 'cutover_armed' and d.cutover_armed_at is null then
    v_ok := false; v_why := 'cutover_not_armed';
  elsif v_gate = 'dns_green' and not public.movein_dns_green(p_deal, 'POST') then
    v_ok := false; v_why := 'post_cutover_dns_not_green';
  end if;

  if not v_ok then
    insert into public.movein_audit (deal_id, actor, actor_id, action, from_state, to_state, reason, payload)
      values (p_deal, p_actor, p_actor_id, 'transition_blocked', d.state, p_to, v_why,
              jsonb_build_object('gate', v_gate));
    return jsonb_build_object('ok', false, 'error', 'gate_blocked', 'gate', v_gate, 'reason', v_why);
  end if;

  update public.movein_deals set
      state = p_to,
      cutover_executed_at = case when p_to = 'CUTOVER_EXECUTED' then now() else cutover_executed_at end,
      closed_at = case when p_to in ('CLOSED','CANCELLED') then now() else closed_at end,
      updated_at = now()
   where id = p_deal;

  insert into public.movein_audit (deal_id, actor, actor_id, action, from_state, to_state, reason, evidence, payment_state, payload)
    values (p_deal, p_actor, p_actor_id, 'state_changed', d.state, p_to, p_reason, p_evidence,
            case when public.movein_leg_paid(p_deal,'final') then 'final_paid'
                 when public.movein_leg_paid(p_deal,'deposit') then 'deposit_paid'
                 else 'unpaid' end,
            jsonb_build_object('gate', v_gate));

  -- slot free hua to waitlist promote
  if p_to in ('CANCELLED','CLOSED') and d.scheduled_month is not null then
    perform public.movein_promote_waitlist(d.scheduled_month);
  end if;

  perform public.movein_health(p_deal);
  return jsonb_build_object('ok', true, 'from', d.state, 'state', p_to, 'gate', v_gate);
end $$;

-- ---------------------------------------------------------------------------
-- P1.1  REFERENCE GENERATOR — atomic yearly counter (no count(*) + 1)
-- ---------------------------------------------------------------------------
create table if not exists public.movein_reference_counter (
  year       int primary key,
  last_value int not null default 0
);
grant all on public.movein_reference_counter to service_role;
alter table public.movein_reference_counter enable row level security;

create or replace function public.movein_next_reference()
returns text language plpgsql security definer set search_path = public as $$
declare v_year int := extract(year from now())::int; n int;
begin
  insert into public.movein_reference_counter (year, last_value)
    values (v_year, 1)
  on conflict (year) do update set last_value = public.movein_reference_counter.last_value + 1
  returning last_value into n;
  return 'MOVE-IN-' || v_year::text || '-' || lpad(n::text, 3, '0');
end $$;
revoke all on function public.movein_next_reference() from public, anon, authenticated;
grant execute on function public.movein_next_reference() to service_role;

-- purani references se counter align (ek dafa, safe)
insert into public.movein_reference_counter (year, last_value)
select extract(year from created_at)::int, count(*)
  from public.movein_deals where reference is not null
 group by 1
on conflict (year) do update
  set last_value = greatest(public.movein_reference_counter.last_value, excluded.last_value);

-- ---------------------------------------------------------------------------
-- P1.2  CAPACITY / WAITLIST INTEGRITY
-- ---------------------------------------------------------------------------
-- ek deal ki ek hi active waitlist position
create unique index if not exists movein_waitlist_active_deal_uidx
  on public.movein_waitlist (deal_id) where released_at is null;
-- ek month mein position duplicate na ho
create unique index if not exists movein_waitlist_month_pos_uidx
  on public.movein_waitlist (month, position) where released_at is null;

-- ---------------------------------------------------------------------------
-- P1.3  WAITLIST PROMOTION — slot khali hua to pehla waitlisted deal andar
-- ---------------------------------------------------------------------------
create or replace function public.movein_promote_waitlist(p_month date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_month date := date_trunc('month', p_month)::date;
        v_total int; v_used int; w record; v_promoted jsonb := '[]'::jsonb;
begin
  perform pg_advisory_xact_lock(hashtext('movein_capacity:' || v_month::text));
  insert into public.movein_capacity (month) values (v_month) on conflict (month) do nothing;
  select slots_total into v_total from public.movein_capacity where month = v_month;

  loop
    select count(*) into v_used from public.movein_deals
     where scheduled_month = v_month and waitlisted = false and state <> 'CANCELLED';
    exit when v_used >= coalesce(v_total, 2);

    select w2.* into w from public.movein_waitlist w2
      join public.movein_deals d on d.id = w2.deal_id
     where w2.month = v_month and w2.released_at is null and d.state <> 'CANCELLED'
     order by w2.position asc, w2.created_at asc
     limit 1;
    exit when w is null;

    update public.movein_deals
       set scheduled_month = v_month, waitlisted = false, updated_at = now()
     where id = w.deal_id;
    update public.movein_waitlist set released_at = now() where id = w.id;

    insert into public.movein_audit (deal_id, actor, action, reason, payload)
      values (w.deal_id, 'system', 'waitlist_promoted', 'slot released, promoted from waitlist',
              jsonb_build_object('month', v_month, 'position', w.position));
    v_promoted := v_promoted || jsonb_build_object('deal_id', w.deal_id, 'position', w.position);
    w := null;
  end loop;

  return jsonb_build_object('ok', true, 'month', v_month, 'promoted', v_promoted);
end $$;
revoke all on function public.movein_promote_waitlist(date) from public, anon, authenticated;
grant execute on function public.movein_promote_waitlist(date) to service_role;

-- ---------------------------------------------------------------------------
-- P1.4  ROLLBACK — create / validate / use (table hona kaafi nahi)
-- ---------------------------------------------------------------------------
create or replace function public.movein_rollback_create(p_deal uuid, p_label text default 'pre-cutover',
                                                        p_operator text default 'founder')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not exists (select 1 from public.movein_deals where id = p_deal) then
    return jsonb_build_object('ok', false, 'error', 'deal_not_found');
  end if;

  insert into public.movein_rollback_points (deal_id, label, operator,
    source_state, destination_state, dns_state, verification_state, available)
  values (p_deal, p_label, p_operator,
    (select coalesce(jsonb_agg(jsonb_build_object('address', address, 'source_provider', source_provider,
        'messages_source', messages_source)), '[]'::jsonb) from public.movein_mailboxes where deal_id = p_deal),
    (select coalesce(jsonb_agg(jsonb_build_object('address', address, 'destination', destination,
        'destination_status', destination_status)), '[]'::jsonb) from public.movein_mailboxes where deal_id = p_deal),
    (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.movein_dns_proof p where p.deal_id = p_deal),
    public.movein_health_calc(p_deal),
    true)
  returning id into v_id;

  insert into public.movein_audit (deal_id, actor, action, reason, evidence)
    values (p_deal, p_operator, 'rollback_point_created', p_label, v_id::text);
  return jsonb_build_object('ok', true, 'rollback_id', v_id);
end $$;

create or replace function public.movein_rollback_validate(p_deal uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record;
begin
  select * into r from public.movein_rollback_points
   where deal_id = p_deal and available and used_at is null
   order by created_at desc limit 1;
  if r is null then
    return jsonb_build_object('ok', false, 'error', 'no_rollback_point');
  end if;
  return jsonb_build_object('ok',
      jsonb_array_length(coalesce(r.source_state,'[]'::jsonb)) > 0
      and jsonb_array_length(coalesce(r.dns_state,'[]'::jsonb)) > 0,
    'rollback_id', r.id, 'label', r.label,
    'source_entries', jsonb_array_length(coalesce(r.source_state,'[]'::jsonb)),
    'dns_entries', jsonb_array_length(coalesce(r.dns_state,'[]'::jsonb)),
    'created_at', r.created_at);
end $$;

create or replace function public.movein_rollback_use(p_deal uuid, p_reason text default 'cutover failed',
                                                     p_operator text default 'founder')
returns jsonb language plpgsql security definer set search_path = public as $$
declare r record; v jsonb;
begin
  v := public.movein_rollback_validate(p_deal);
  if coalesce((v->>'ok')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'error', 'rollback_invalid', 'detail', v);
  end if;

  select * into r from public.movein_rollback_points where id = (v->>'rollback_id')::uuid for update;
  update public.movein_rollback_points
     set available = false, used_at = now() where id = r.id;

  insert into public.movein_exceptions (deal_id, scope, ref, severity, reason, required_action, blocks_cutover)
    values (p_deal, 'cutover', r.id::text, 'ROLLBACK_REQUIRED', p_reason,
            'Rollback executed — re-verify data then re-arm cut-over', true);

  update public.movein_deals
     set cutover_armed_at = null, cutover_executed_at = null, updated_at = now()
   where id = p_deal;

  insert into public.movein_audit (deal_id, actor, action, reason, evidence, payload)
    values (p_deal, p_operator, 'rollback_used', p_reason, r.id::text, r.dns_state);

  perform public.movein_transition(p_deal, 'ROLLBACK'::public.movein_state, p_operator, p_reason, r.id::text);
  return jsonb_build_object('ok', true, 'rollback_id', r.id, 'state', 'ROLLBACK');
end $$;

revoke all on function public.movein_rollback_create(uuid, text, text) from public, anon, authenticated;
revoke all on function public.movein_rollback_validate(uuid) from public, anon, authenticated;
revoke all on function public.movein_rollback_use(uuid, text, text) from public, anon, authenticated;
grant execute on function public.movein_rollback_create(uuid, text, text) to service_role;
grant execute on function public.movein_rollback_validate(uuid) to service_role;
grant execute on function public.movein_rollback_use(uuid, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- P1.5  DATA VALIDATION — impossible counts band
--       verified <= copied <= source, sab counts >= 0
-- ---------------------------------------------------------------------------
alter table public.movein_mailboxes drop constraint if exists movein_mailboxes_counts_chk;
alter table public.movein_mailboxes add constraint movein_mailboxes_counts_chk check (
  messages_source >= 0 and messages_copied >= 0 and messages_verified >= 0
  and folders_found >= 0 and contacts_count >= 0 and calendar_events >= 0
  and aliases_count >= 0 and signatures_count >= 0 and exceptions >= 0
  and messages_copied <= messages_source
  and messages_verified <= messages_copied
) not valid;

-- ---------------------------------------------------------------------------
-- SMALL HARDENING — DNS constraints + owner_id + blocks_cutover usage
-- ---------------------------------------------------------------------------
alter table public.movein_dns_checks add column if not exists owner_id uuid;

alter table public.movein_dns_checks drop constraint if exists movein_dns_phase_chk;
alter table public.movein_dns_checks add constraint movein_dns_phase_chk
  check (phase in ('PRE','POST')) not valid;
alter table public.movein_dns_checks drop constraint if exists movein_dns_record_chk;
alter table public.movein_dns_checks add constraint movein_dns_record_chk
  check (record in ('MX','SPF','DKIM','DMARC')) not valid;

create or replace function public.movein_dns_owner_fill()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is null then
    select coalesce(d.owner_id, d.user_id) into new.owner_id
      from public.movein_deals d where d.id = new.deal_id;
  end if;
  return new;
end $$;

drop trigger if exists movein_dns_owner_fill_trg on public.movein_dns_checks;
create trigger movein_dns_owner_fill_trg before insert or update on public.movein_dns_checks
for each row execute function public.movein_dns_owner_fill();

update public.movein_dns_checks c
   set owner_id = coalesce(d.owner_id, d.user_id)
  from public.movein_deals d
 where d.id = c.deal_id and c.owner_id is null;

-- blocks_cutover ab asli readiness logic ka hissa (severity list ke saath)
create or replace function public.movein_cutover_ready(p_deal uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select count(*) = 0 from public.movein_runbook
      where deal_id = p_deal and required and result <> 'VERIFIED'), false)
   and coalesce((select count(*) > 0 from public.movein_runbook where deal_id = p_deal), false)
   and public.movein_dns_green(p_deal, 'PRE')
   and coalesce((select count(*) = 0 from public.movein_exceptions
      where deal_id = p_deal and resolved_at is null
        and (blocks_cutover
             or severity in ('BLOCKED','FAILED','ROLLBACK_REQUIRED','CUSTOMER_ACTION_REQUIRED'))), true)
$$;

-- severity high ho to blocks_cutover khud true
create or replace function public.movein_exception_blocks_fill()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.severity in ('BLOCKED','FAILED','ROLLBACK_REQUIRED') then
    new.blocks_cutover := true;
  end if;
  return new;
end $$;
drop trigger if exists movein_exception_blocks_trg on public.movein_exceptions;
create trigger movein_exception_blocks_trg before insert or update on public.movein_exceptions
for each row execute function public.movein_exception_blocks_fill();

-- ---------------------------------------------------------------------------
-- FINAL SWEEP — koi bhi naya movein_* function public/anon se open na rahe
-- ---------------------------------------------------------------------------
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname like 'movein_%'
  loop
    execute format('revoke all on function %s from public', f.sig);
    execute format('revoke all on function %s from anon', f.sig);
    if f.proname not in ('movein_customer_view','movein_is_deal_member') then
      execute format('revoke all on function %s from authenticated', f.sig);
    end if;
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;

commit;
