-- ============================================================================
-- ANEXOCHAT · PHASE 23 — PROMISE RECOVERY ENGINE
--   Promise → deadline → reminder → deadline change (reason ke saath) →
--   reassignment → downstream impact → kept/broken, poori tarah insaani faisla.
--
-- Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
-- Har naya public table par GRANT pehle, phir RLS, phir policy.
--
-- LOCK (non-negotiable):
--   1. Engine khud kabhi promise nahi todti aur khud kabhi deadline nahi
--      badalti. Har recovery action ek insaan karta hai, reason ke saath.
--   2. Deadline change bina reason (8+ char) namumkin. Original deadline
--      kabhi overwrite nahi hota (`original_due_at` pehli dafa hi seal).
--   3. Reminder ASLI hai: conversation mein ek real message jata hai
--      (`chat_send`), koi khaali "reminded" flag nahi.
--   4. "Kept" bina evidence namumkin — `chat_work_complete` hi raasta hai.
--   5. Poora ledger append-only (`promise_recovery_log`): koi update/delete
--      policy nahi. Follow-through score isi ledger se banta hai.
--   6. Parsing/decision DETERMINISTIC — insaani guftagu kisi AI API par nahi
--      jati (Phase 22 lock isi tarah qaayam).
--   7. LOOPHOLE FIX (device ban): ban SIRF device hash par hota hai — IP,
--      network ya WiFi kabhi ban nahi (cafe/office ke masoom log safe).
--      Har ban appealable hai: `device_ban_appeals` + logged decision.
--   8. No duplicate: Phase 3 ka `chat_work_items` (kind='promise') hi promise
--      ka ghar hai; yeh layer uske OOPAR recovery + ledger hai.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) plan entitlements
-- ---------------------------------------------------------------------------
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note) values
  ('basic',        'promise_recovery', false, null, 'ANEXOChat included nahi'),
  ('pro',          'promise_recovery', false, null, 'ANEXOChat included nahi'),
  ('business',     'promise_recovery', true,  null, 'remind · deadline change with reason · kept/cancel'),
  ('business_pro', 'promise_recovery', true,  null, null),
  ('ai_pro',       'promise_recovery', true,  null, null),
  ('ai_business',  'promise_recovery', true,  null, null),
  ('ai_executive', 'promise_recovery', true,  null, null),
  ('founder',      'promise_recovery', true,  null, null),

  ('basic',        'promise_reassign', false, null, null),
  ('pro',          'promise_reassign', false, null, null),
  ('business',     'promise_reassign', false, null, 'reassignment Business Pro se'),
  ('business_pro', 'promise_reassign', true,  null, 'owner handover with logged reason'),
  ('ai_pro',       'promise_reassign', false, null, null),
  ('ai_business',  'promise_reassign', true,  null, null),
  ('ai_executive', 'promise_reassign', true,  null, null),
  ('founder',      'promise_reassign', true,  null, null),

  ('basic',        'device_appeal',    true,  null, 'ban ke khilaf appeal har plan par'),
  ('pro',          'device_appeal',    true,  null, null),
  ('business',     'device_appeal',    true,  null, null),
  ('business_pro', 'device_appeal',    true,  null, null),
  ('ai_pro',       'device_appeal',    true,  null, null),
  ('ai_business',  'device_appeal',    true,  null, null),
  ('ai_executive', 'device_appeal',    true,  null, null),
  ('founder',      'device_appeal',    true,  null, null)
on conflict (plan, feature) do update
  set allowed = excluded.allowed,
      limit_value = excluded.limit_value,
      note = excluded.note;

-- ---------------------------------------------------------------------------
-- 1) promise columns on the existing work item (no duplicate table)
-- ---------------------------------------------------------------------------
alter table public.chat_work_items
  add column if not exists original_due_at   timestamptz,
  add column if not exists original_owner_id uuid references auth.users(id) on delete set null,
  add column if not exists deadline_changes  int not null default 0,
  add column if not exists reminders_sent    int not null default 0,
  add column if not exists reassignments     int not null default 0,
  add column if not exists downstream_impact text,
  add column if not exists cancel_reason     text;

-- pehli dafa: jo promises pehle se hain unka original seal kar do
update public.chat_work_items
   set original_due_at   = coalesce(original_due_at, due_at),
       original_owner_id = coalesce(original_owner_id, owner_user_id)
 where original_due_at is null or original_owner_id is null;

-- ---------------------------------------------------------------------------
-- 2) append-only recovery ledger
-- ---------------------------------------------------------------------------
create table if not exists public.promise_recovery_log (
  id        bigserial primary key,
  item_id   uuid not null references public.chat_work_items(id) on delete cascade,
  actor_id  uuid references auth.users(id) on delete set null,
  action    text not null check (action in
              ('remind','deadline_change','reassign','impact_set','kept','cancelled')),
  reason    text,
  prev      jsonb not null default '{}'::jsonb,
  next      jsonb not null default '{}'::jsonb,
  at        timestamptz not null default now()
);
create index if not exists promise_recovery_log_idx on public.promise_recovery_log(item_id, id);

grant select on public.promise_recovery_log to authenticated;
grant all on public.promise_recovery_log to service_role;
grant usage, select on sequence public.promise_recovery_log_id_seq to service_role;

alter table public.promise_recovery_log enable row level security;
do $$
begin
  -- sirf SELECT policy: append-only, koi update/delete raasta nahi
  if not exists (select 1 from pg_policies
                  where tablename='promise_recovery_log' and policyname='promise log read') then
    create policy "promise log read" on public.promise_recovery_log
      for select to authenticated using (exists (
        select 1 from public.chat_work_items w
         where w.id = item_id and public.chat_in_conversation(w.conversation_id, auth.uid())));
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) promise state — deterministic, DB hi sach bolta hai
-- ---------------------------------------------------------------------------
create or replace function public.promise_state_of(
  _state text, _due timestamptz, _completed timestamptz, _original_due timestamptz)
returns text language sql immutable set search_path = public as $$
  select case
    when _state = 'cancelled' then 'cancelled'
    when _state = 'done' and _completed is not null and _original_due is not null
         and _completed > _original_due then 'kept_late'
    when _state = 'done' then 'kept'
    when _due is not null and _due < now() then 'overdue'
    when _due is not null and _due < now() + interval '24 hours' then 'due_soon'
    else 'pending'
  end
$$;

-- ---------------------------------------------------------------------------
-- 4) recovery board — kya toot raha hai, kis par, kab tak
-- ---------------------------------------------------------------------------
create or replace function public.promise_board(_user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from public.chat_members where user_id = _user limit 1;
  if v_ws is null then
    return jsonb_build_object('plan', public.chat_feature_allowed(_user,'promise_recovery'),
                              'reassign', public.chat_feature_allowed(_user,'promise_reassign'),
                              'items', '[]'::jsonb, 'summary', '{}'::jsonb);
  end if;

  return jsonb_build_object(
    'plan',     public.chat_feature_allowed(_user, 'promise_recovery'),
    'reassign', public.chat_feature_allowed(_user, 'promise_reassign'),
    'summary', (
      select jsonb_build_object(
        'open',      count(*) filter (where w.state in ('open','blocked')),
        'overdue',   count(*) filter (where w.state in ('open','blocked')
                                        and w.due_at is not null and w.due_at < now()),
        'due_soon',  count(*) filter (where w.state in ('open','blocked') and w.due_at is not null
                                        and w.due_at >= now() and w.due_at < now() + interval '24 hours'),
        'kept',      count(*) filter (where w.state = 'done'),
        'kept_late', count(*) filter (where w.state = 'done' and w.original_due_at is not null
                                        and w.completed_at > w.original_due_at),
        'cancelled', count(*) filter (where w.state = 'cancelled'),
        'slipped',   count(*) filter (where w.deadline_changes > 0))
        from public.chat_work_items w
       where w.workspace_id = v_ws and w.kind = 'promise'),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', w.id, 'title', w.title, 'state', w.state,
          'promise_state', public.promise_state_of(w.state, w.due_at, w.completed_at, w.original_due_at),
          'owner_user_id', w.owner_user_id, 'original_owner_id', w.original_owner_id,
          'due_at', w.due_at, 'original_due_at', w.original_due_at,
          'slipped_by_hours', case
              when w.due_at is not null and w.original_due_at is not null
              then round(extract(epoch from (w.due_at - w.original_due_at)) / 3600.0)::int
              else 0 end,
          'deadline_changes', w.deadline_changes,
          'reminders_sent', w.reminders_sent,
          'reassignments', w.reassignments,
          'downstream_impact', w.downstream_impact,
          'conversation_id', w.conversation_id, 'message_id', w.message_id,
          'created_at', w.created_at, 'completed_at', w.completed_at,
          'evidence_count', (select count(*) from public.chat_work_evidence e
                              where e.item_id = w.id and e.kind <> 'message'),
          'last_action', (select l.action from public.promise_recovery_log l
                           where l.item_id = w.id order by l.id desc limit 1))
        order by (w.state not in ('open','blocked')),
                 (w.due_at is null), w.due_at)
        from public.chat_work_items w
       where w.workspace_id = v_ws and w.kind = 'promise'
         and (w.state in ('open','blocked') or w.closed_at > now() - interval '30 days')),
      '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------------
-- 5) recovery action — har action insaani, har action reason ke saath logged
-- ---------------------------------------------------------------------------
create or replace function public.promise_recover(
  _item uuid, _user uuid, _action text,
  _reason text default null, _new_due timestamptz default null,
  _new_owner uuid default null, _impact text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_row public.chat_work_items;
  v_reason text := btrim(coalesce(_reason, ''));
  v_msg  record;
  v_body text;
  v_owner_name text;
begin
  select * into v_row from public.chat_work_items where id = _item;
  if not found then raise exception 'item_not_found'; end if;
  if v_row.kind <> 'promise' then return jsonb_build_object('ok', false, 'error', 'not_a_promise'); end if;
  if not public.chat_in_conversation(v_row.conversation_id, _user) then raise exception 'not_participant'; end if;

  if not coalesce((public.chat_feature_allowed(_user,'promise_recovery')->>'allowed')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'not_entitled',
      'plan', public.chat_feature_allowed(_user,'promise_recovery')->>'plan');
  end if;

  if _action in ('deadline_change','reassign','cancelled') and length(v_reason) < 8 then
    return jsonb_build_object('ok', false, 'error', 'reason_required',
      'message', 'This action changes the record. Write at least 8 characters of reason.');
  end if;

  if _action = 'remind' then
    if v_row.state not in ('open','blocked') then
      return jsonb_build_object('ok', false, 'error', 'promise_closed');
    end if;
    select coalesce(p.display_name, 'the owner') into v_owner_name
      from public.chat_members p
     where p.user_id = coalesce(v_row.owner_user_id, v_row.created_by) limit 1;

    v_body := 'Promise reminder for ' || coalesce(v_owner_name, 'the owner')
              || ' — "' || v_row.title || '"'
              || case when v_row.due_at is not null
                      then ' · due ' || to_char(v_row.due_at, 'DD Mon YYYY HH24:MI') else '' end
              || case when v_reason <> '' then ' · ' || v_reason else '' end;

    select * into v_msg from public.chat_send(
      v_row.conversation_id, _user,
      'promise-remind-' || _item::text || '-' || extract(epoch from now())::bigint::text,
      v_body, 'promise-engine', v_row.message_id);

    update public.chat_work_items
       set reminders_sent = reminders_sent + 1 where id = _item;

    insert into public.promise_recovery_log (item_id, actor_id, action, reason, next)
    values (_item, _user, 'remind', nullif(v_reason,''),
            jsonb_build_object('message_id', v_msg.id, 'body', v_body));

    insert into public.chat_work_events (item_id, actor_id, action, detail)
    values (_item, _user, 'promise_reminded', jsonb_build_object('message_id', v_msg.id));

    return jsonb_build_object('ok', true, 'action', 'remind', 'message_id', v_msg.id, 'body', v_body);

  elsif _action = 'deadline_change' then
    if _new_due is null then return jsonb_build_object('ok', false, 'error', 'new_due_required'); end if;
    if v_row.state not in ('open','blocked') then
      return jsonb_build_object('ok', false, 'error', 'promise_closed');
    end if;

    update public.chat_work_items
       set due_at = _new_due,
           original_due_at = coalesce(original_due_at, v_row.due_at),
           deadline_changes = deadline_changes + 1
     where id = _item;

    insert into public.promise_recovery_log (item_id, actor_id, action, reason, prev, next)
    values (_item, _user, 'deadline_change', v_reason,
            jsonb_build_object('due_at', v_row.due_at),
            jsonb_build_object('due_at', _new_due));

    insert into public.chat_work_events (item_id, actor_id, action, detail)
    values (_item, _user, 'deadline_changed',
            jsonb_build_object('from', v_row.due_at, 'to', _new_due, 'reason', v_reason));

    return jsonb_build_object('ok', true, 'action', 'deadline_change',
      'from', v_row.due_at, 'to', _new_due,
      'original_due_at', coalesce(v_row.original_due_at, v_row.due_at));

  elsif _action = 'reassign' then
    if _new_owner is null then return jsonb_build_object('ok', false, 'error', 'new_owner_required'); end if;
    if not coalesce((public.chat_feature_allowed(_user,'promise_reassign')->>'allowed')::boolean, false) then
      return jsonb_build_object('ok', false, 'error', 'not_entitled_reassign',
        'plan', public.chat_feature_allowed(_user,'promise_reassign')->>'plan');
    end if;
    if not public.chat_in_conversation(v_row.conversation_id, _new_owner) then
      return jsonb_build_object('ok', false, 'error', 'new_owner_not_participant');
    end if;

    update public.chat_work_items
       set owner_user_id = _new_owner,
           original_owner_id = coalesce(original_owner_id, v_row.owner_user_id),
           reassignments = reassignments + 1
     where id = _item;

    insert into public.promise_recovery_log (item_id, actor_id, action, reason, prev, next)
    values (_item, _user, 'reassign', v_reason,
            jsonb_build_object('owner_user_id', v_row.owner_user_id),
            jsonb_build_object('owner_user_id', _new_owner));

    insert into public.chat_work_events (item_id, actor_id, action, detail)
    values (_item, _user, 'promise_reassigned',
            jsonb_build_object('from', v_row.owner_user_id, 'to', _new_owner, 'reason', v_reason));

    return jsonb_build_object('ok', true, 'action', 'reassign', 'owner_user_id', _new_owner);

  elsif _action = 'impact_set' then
    if btrim(coalesce(_impact,'')) = '' then
      return jsonb_build_object('ok', false, 'error', 'impact_required');
    end if;

    update public.chat_work_items set downstream_impact = btrim(_impact) where id = _item;

    insert into public.promise_recovery_log (item_id, actor_id, action, reason, prev, next)
    values (_item, _user, 'impact_set', nullif(v_reason,''),
            jsonb_build_object('downstream_impact', v_row.downstream_impact),
            jsonb_build_object('downstream_impact', btrim(_impact)));

    return jsonb_build_object('ok', true, 'action', 'impact_set', 'downstream_impact', btrim(_impact));

  elsif _action = 'cancelled' then
    if v_row.state = 'done' then return jsonb_build_object('ok', false, 'error', 'already_kept'); end if;

    update public.chat_work_items
       set state = 'cancelled', cancel_reason = v_reason, closed_at = now()
     where id = _item;

    update public.chat_work_items set state = 'open'
     where depends_on = _item and state = 'blocked';

    insert into public.promise_recovery_log (item_id, actor_id, action, reason, prev, next)
    values (_item, _user, 'cancelled', v_reason,
            jsonb_build_object('state', v_row.state),
            jsonb_build_object('state', 'cancelled'));

    insert into public.chat_work_events (item_id, actor_id, from_state, to_state, action, detail)
    values (_item, _user, v_row.state, 'cancelled', 'promise_cancelled',
            jsonb_build_object('reason', v_reason));

    return jsonb_build_object('ok', true, 'action', 'cancelled', 'state', 'cancelled');
  end if;

  return jsonb_build_object('ok', false, 'error', 'unknown_action');
end $$;

-- "Kept" ka raasta sirf evidence wala completion hai (Phase 22 lock)
create or replace function public.promise_keep(_item uuid, _user uuid, _evidence jsonb default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_res jsonb; v_row public.chat_work_items;
begin
  select * into v_row from public.chat_work_items where id = _item;
  if not found then raise exception 'item_not_found'; end if;
  if v_row.kind <> 'promise' then return jsonb_build_object('ok', false, 'error', 'not_a_promise'); end if;

  v_res := public.chat_work_complete(_item, _user, _evidence);
  if coalesce((v_res->>'ok')::boolean, false) then
    insert into public.promise_recovery_log (item_id, actor_id, action, prev, next)
    values (_item, _user, 'kept',
            jsonb_build_object('state', v_row.state, 'original_due_at', v_row.original_due_at),
            jsonb_build_object('state', 'done', 'kept_at', now(),
              'late', v_row.original_due_at is not null and now() > v_row.original_due_at));
  end if;
  return v_res;
end $$;

-- ---------------------------------------------------------------------------
-- 6) promise history — original wada, har tabdeeli, har wajah, aakhri natija
-- ---------------------------------------------------------------------------
create or replace function public.promise_history(_item uuid, _user uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
declare v_row public.chat_work_items;
begin
  select * into v_row from public.chat_work_items where id = _item;
  if not found then raise exception 'item_not_found'; end if;
  if not public.chat_in_conversation(v_row.conversation_id, _user) then raise exception 'not_participant'; end if;

  return jsonb_build_object(
    'item', jsonb_build_object(
      'id', v_row.id, 'title', v_row.title, 'state', v_row.state,
      'promise_state', public.promise_state_of(v_row.state, v_row.due_at,
                                               v_row.completed_at, v_row.original_due_at),
      'owner_user_id', v_row.owner_user_id, 'original_owner_id', v_row.original_owner_id,
      'due_at', v_row.due_at, 'original_due_at', v_row.original_due_at,
      'deadline_changes', v_row.deadline_changes, 'reminders_sent', v_row.reminders_sent,
      'reassignments', v_row.reassignments, 'downstream_impact', v_row.downstream_impact,
      'cancel_reason', v_row.cancel_reason, 'completed_at', v_row.completed_at),
    'provenance', v_row.provenance,
    'log', coalesce((select jsonb_agg(jsonb_build_object(
        'action', l.action, 'reason', l.reason, 'prev', l.prev, 'next', l.next,
        'actor_id', l.actor_id, 'at', l.at) order by l.id)
      from public.promise_recovery_log l where l.item_id = _item), '[]'::jsonb),
    'evidence', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', e.kind, 'ref', e.ref, 'sha256', e.sha256, 'at', e.at) order by e.id)
      from public.chat_work_evidence e where e.item_id = _item), '[]'::jsonb),
    'append_only', true);
end $$;

-- ---------------------------------------------------------------------------
-- 7) LOOPHOLE FIX — device ban appeal (ban device par, network par kabhi nahi)
-- ---------------------------------------------------------------------------
alter table public.device_bans
  add column if not exists appealable boolean not null default true;

do $$
begin
  if exists (select 1 from pg_constraint where conname = 'device_trust_events_event_check') then
    alter table public.device_trust_events drop constraint device_trust_events_event_check;
  end if;
  alter table public.device_trust_events
    add constraint device_trust_events_event_check
    check (event in ('registered','seen','trusted','suspicious','revoked','banned','purged',
                     'appealed','unbanned','appeal_denied'));
exception when duplicate_object then null;
end $$;

create table if not exists public.device_ban_appeals (
  id           uuid primary key default gen_random_uuid(),
  device_hash  text not null,
  user_id      uuid not null references auth.users(id) on delete cascade,
  statement    text not null,
  state        text not null default 'new' check (state in ('new','reviewing','granted','denied')),
  decided_by   uuid references auth.users(id) on delete set null,
  decision_reason text,
  created_at   timestamptz not null default now(),
  decided_at   timestamptz
);
create index if not exists device_ban_appeals_idx on public.device_ban_appeals(state, created_at desc);
create index if not exists device_ban_appeals_user_idx on public.device_ban_appeals(user_id, created_at desc);

grant select on public.device_ban_appeals to authenticated;
grant all on public.device_ban_appeals to service_role;

alter table public.device_ban_appeals enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                  where tablename='device_ban_appeals' and policyname='own appeal read') then
    create policy "own appeal read" on public.device_ban_appeals
      for select to authenticated
      using (user_id = auth.uid() or public.safety_can_review(auth.uid()));
  end if;
end $$;

create or replace function public.device_appeal_open(_user uuid, _device_hash text, _statement text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_id uuid; v_txt text := btrim(coalesce(_statement,''));
begin
  if _user is null or coalesce(_device_hash,'') = '' then raise exception 'user_device_required'; end if;
  if length(v_txt) < 20 then
    return jsonb_build_object('ok', false, 'error', 'statement_required',
      'message', 'Tell us in at least 20 characters why this block is wrong.');
  end if;
  if not exists (select 1 from public.device_bans b
                  where b.device_hash = _device_hash and b.appealable) then
    return jsonb_build_object('ok', false, 'error', 'no_appealable_ban');
  end if;
  if exists (select 1 from public.device_ban_appeals a
              where a.device_hash = _device_hash and a.user_id = _user and a.state in ('new','reviewing')) then
    return jsonb_build_object('ok', false, 'error', 'appeal_already_open');
  end if;

  insert into public.device_ban_appeals (device_hash, user_id, statement)
  values (_device_hash, _user, v_txt) returning id into v_id;

  insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
  values (_user, _device_hash, 'appealed', 'user', jsonb_build_object('appeal_id', v_id));

  return jsonb_build_object('ok', true, 'appeal_id', v_id, 'state', 'new');
end $$;

create or replace function public.device_appeal_queue(_actor uuid, _state text default null)
returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $$
begin
  if not public.safety_can_review(_actor) then
    return jsonb_build_object('allowed', false, 'appeals', '[]'::jsonb);
  end if;
  return jsonb_build_object('allowed', true, 'appeals', coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', a.id, 'device_hash', left(a.device_hash, 12) || '…', 'user_id', a.user_id,
        'statement', a.statement, 'state', a.state, 'created_at', a.created_at,
        'decision_reason', a.decision_reason, 'decided_at', a.decided_at)
      order by a.created_at desc)
      from public.device_ban_appeals a
     where _state is null or a.state = _state), '[]'::jsonb));
end $$;

create or replace function public.device_appeal_decide(
  _actor uuid, _appeal uuid, _decision text, _reason text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_row public.device_ban_appeals; v_reason text := btrim(coalesce(_reason,''));
begin
  if not public.safety_can_review(_actor) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if _decision not in ('reviewing','granted','denied') then
    return jsonb_build_object('ok', false, 'error', 'bad_decision');
  end if;
  if _decision in ('granted','denied') and length(v_reason) < 12 then
    return jsonb_build_object('ok', false, 'error', 'reason_required',
      'message', 'A decision on someone’s access needs at least 12 characters of reason.');
  end if;

  select * into v_row from public.device_ban_appeals where id = _appeal;
  if not found then raise exception 'appeal_not_found'; end if;
  if v_row.state in ('granted','denied') then
    return jsonb_build_object('ok', false, 'error', 'already_decided', 'state', v_row.state);
  end if;

  update public.device_ban_appeals
     set state = _decision,
         decided_by = case when _decision = 'reviewing' then null else _actor end,
         decision_reason = nullif(v_reason,''),
         decided_at = case when _decision = 'reviewing' then null else now() end
   where id = _appeal;

  if _decision = 'granted' then
    delete from public.device_bans where device_hash = v_row.device_hash;
    update public.device_vault
       set state = 'pending', reasons = '[]'::jsonb
     where device_hash = v_row.device_hash and state = 'banned';
    insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
    values (v_row.user_id, v_row.device_hash, 'unbanned', 'reviewer',
            jsonb_build_object('appeal_id', _appeal, 'reason', v_reason));
  elsif _decision = 'denied' then
    insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
    values (v_row.user_id, v_row.device_hash, 'appeal_denied', 'reviewer',
            jsonb_build_object('appeal_id', _appeal, 'reason', v_reason));
  end if;

  return jsonb_build_object('ok', true, 'appeal_id', _appeal, 'state', _decision);
end $$;

-- ---------------------------------------------------------------------------
-- EXECUTE grants
-- ---------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'public.promise_state_of(text,timestamptz,timestamptz,timestamptz)',
    'public.promise_board(uuid)',
    'public.promise_recover(uuid,uuid,text,text,timestamptz,uuid,text)',
    'public.promise_keep(uuid,uuid,jsonb)',
    'public.promise_history(uuid,uuid)',
    'public.device_appeal_open(uuid,text,text)',
    'public.device_appeal_queue(uuid,text)',
    'public.device_appeal_decide(uuid,uuid,text,text)'
  ]
  loop
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ============================================================================
-- PHASE 23 GREEN CHECK (Supabase editor mein last query):
--   select public.promise_board(auth.uid());
--   select public.device_appeal_queue(auth.uid());
-- ============================================================================
