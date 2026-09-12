-- ============================================================================
-- E6 — Business Pro: company-wide delete for everyone (NO time limit)
-- ============================================================================
--
-- Card promise (plans.ts Business Pro — no-touch):
--   "Company-wide delete for everyone (no time limit) with audit record"
--
-- Existing rule (anexochat_phase07 — founder blueprint, NO-TOUCH):
--   chat_delete_message(_msg, _user) = 1 hour window, har plan ke liye same.
--   Us function ko yahan HATH NAHI lagaya gaya.
--
-- Yeh NAYA function sirf Business Pro entitlement ke liye hai:
--   entitlement_state.plan = 'business_pro'  [Phase 36, canonical]
--
-- Audit: chat_log action 'message.delete_anytime' — seq + plan ke saath.
-- Security: service_role / authenticated dono se callable, lekin plan gate
--           function ke ANDAR hai — client par bharosa nahi.
-- ============================================================================

create or replace function public.chat_delete_message_anytime(_msg uuid, _user uuid)
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

  -- ── sirf sender apna message delete kar sakta hai ────────────────────────
  if m.sender_user_id <> _user then
    raise exception 'only_sender_can_delete';
  end if;

  -- ── Business Pro entitlement gate (canonical plan, Phase 36) ────────────
  select lower(nullif(btrim(es.plan), ''))
    into user_plan
  from public.entitlement_state es
  where es.user_id = _user
  limit 1;

  if user_plan is distinct from 'business_pro' then
    -- 1-hour window wala normal rule lagao — Business Pro ke baghair
    -- anytime delete nahi. Purana function wahi kaam karta hai.
    raise exception 'business_pro_required';
  end if;

  -- ── delete — koi time window nahi (Business Pro card) ───────────────────
  update public.chat_messages
     set deleted_at = now(),
         body = 'Message deleted by sender'
   where chat_messages.id = _msg
     and chat_messages.deleted_at is null;

  -- ── audit record — card: "with audit record" ─────────────────────────────
  perform public.chat_log(
    m.workspace_id,
    _user,
    'message.delete_anytime',
    _msg::text,
    jsonb_build_object('seq', m.seq, 'plan', user_plan, 'window', 'none')
  );

  return query
    select mm.id, mm.deleted_at
    from public.chat_messages mm
    where mm.id = _msg;
end $$;

-- ── permissions ──────────────────────────────────────────────────────────────
revoke all on function public.chat_delete_message_anytime(uuid, uuid) from public;
grant execute on function public.chat_delete_message_anytime(uuid, uuid)
  to authenticated, service_role;

-- ============================================================================
-- Verify (run after):
--   select proname from pg_proc where proname = 'chat_delete_message_anytime';
-- ============================================================================
