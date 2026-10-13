-- ============================================================================
-- E7 — Business: delete for everyone within 48 HOURS (card promise)
-- ============================================================================
--
-- Founder decision (12 Sep 2026): Option 2 — Business = 48 hours.
--
-- Card promise (plans.ts Business — no-touch):
--   "Delete for me · delete for everyone — still works after 48 hours"
--
-- Existing rule (anexochat_phase07 — founder blueprint, NO-TOUCH):
--   chat_delete_message(_msg, _user) = 1 hour window. Us ko HATH NAHI.
--
-- Ladder (locked):
--   Basic / Pro    → 1 hour   (phase07 function, untouched)
--   Business       → 48 hours (YEH function)
--   Business Pro   → no limit (E6 chat_delete_message_anytime)
--
-- Gate: entitlement_state.plan [Phase 36, canonical]
--   'business'      → 48h window enforce
--   'business_pro'  → no window (E6 ke baghair bhi kaam kare)
--   anything else   → business_required
--
-- Audit: chat_log action 'message.delete_48h' — seq + plan + window.
-- ============================================================================

create or replace function public.chat_delete_message_48h(_msg uuid, _user uuid)
returns table (id uuid, deleted_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  m record;
  user_plan text;
begin
  -- ── message ──────────────────────────────────────────────────────────────
  select * into m from public.chat_messages where chat_messages.id = _msg;
  if m.id is null then
    raise exception 'message_not_found';
  end if;

  -- ── sirf sender ──────────────────────────────────────────────────────────
  if m.sender_user_id <> _user then
    raise exception 'only_sender_can_delete';
  end if;

  -- ── entitlement gate (canonical plan, Phase 36) ──────────────────────────
  select lower(nullif(btrim(es.plan), ''))
    into user_plan
  from public.entitlement_state es
  where es.user_id = _user
  limit 1;

  if user_plan is null or user_plan not in ('business', 'business_pro') then
    raise exception 'business_required';
  end if;

  -- ── window: Business = 48h, Business Pro = no limit ──────────────────────
  if user_plan = 'business'
     and m.created_at < now() - interval '48 hours' then
    raise exception 'delete_window_closed_48h';
  end if;

  -- ── delete ───────────────────────────────────────────────────────────────
  update public.chat_messages
     set deleted_at = now(),
         body = 'Message deleted by sender'
   where chat_messages.id = _msg
     and chat_messages.deleted_at is null;

  -- ── audit record ─────────────────────────────────────────────────────────
  perform public.chat_log(
    m.workspace_id,
    _user,
    'message.delete_48h',
    _msg::text,
    jsonb_build_object(
      'seq', m.seq,
      'plan', user_plan,
      'window', case when user_plan = 'business_pro' then 'none' else '48h' end
    )
  );

  return query
    select mm.id, mm.deleted_at
    from public.chat_messages mm
    where mm.id = _msg;
end $$;

-- ── permissions ──────────────────────────────────────────────────────────────
revoke all on function public.chat_delete_message_48h(uuid, uuid) from public;
grant execute on function public.chat_delete_message_48h(uuid, uuid)
  to authenticated, service_role;

-- ============================================================================
-- Verify (run after):
--   select proname from pg_proc where proname = 'chat_delete_message_48h';
-- ============================================================================
