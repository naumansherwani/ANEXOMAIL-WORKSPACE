-- =============================================================================
-- E19 — password reset: atomic token consume + rate limit + cleanup
-- Supabase #4 SQL Editor mein poori file paste → Run. Idempotent.
--
-- WAJAH (13 Oct 2026, founder ne khud dekha): /forgot-password abhi tak kabhi
-- kabhi Supabase ka raw action_link (https://<ref>.supabase.co/auth/v1/verify?...)
-- seedha user ko mail kar deta tha — unprofessional, backend vendor expose karta
-- hai. Code mein already ek saaf "apna token" system tha
-- (account_recovery_tokens, phase63_f3a_passkey_family.sql) jo sirf
-- anexomail.com link bhejta hai, lekin woh sirf FALLBACK tha (Supabase ke fail
-- hone par). server/routes/auth.ts (E19 commit) ab isi apne system ko HAMESHA
-- use karta hai — Supabase ka raw link kabhi user ko nahi jata.
--
-- Is file ka kaam sirf database side: jo cheez JS mein do-step (SELECT, phir
-- UPDATE) ho rahi thi usay ek atomic RPC banana (race condition: do requests
-- same token ek sath consume kar sakte the), aur rate-limit + cleanup add
-- karna jo pehle bilkul nahi tha (koi bhi kitni baar reset request bhej sakta
-- tha).
--
-- account_recovery_tokens table khud phase63_f3a_passkey_family.sql
-- (LOCKED — touch nahi) mein bani thi; yahan sirf ek column add ho raha hai
-- aur naye functions ban rahe hain — purani file edit nahi ho rahi.
-- =============================================================================
set search_path = public, extensions;

-- ── 1) created_at — rate-limit ke liye zaroori, purani table mein nahi tha ──
alter table public.account_recovery_tokens
  add column if not exists created_at timestamptz not null default now();

create index if not exists account_recovery_tokens_user_created_idx
  on public.account_recovery_tokens (user_id, created_at desc);

-- ── 2) rate check — ek user, max 5 reset-request per hour ──
create or replace function public.password_reset_rate_ok(_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_count int;
begin
  if _user_id is null then
    return jsonb_build_object('ok', true, 'count', 0);
  end if;
  select count(*) into v_count
    from public.account_recovery_tokens
   where user_id = _user_id
     and created_at > now() - interval '1 hour';
  if v_count >= 5 then
    return jsonb_build_object('ok', false, 'error', 'too_many_requests', 'count', v_count);
  end if;
  return jsonb_build_object('ok', true, 'count', v_count);
end $$;

revoke all on function public.password_reset_rate_ok(uuid) from public, anon, authenticated;
grant execute on function public.password_reset_rate_ok(uuid) to service_role;

-- ── 3) atomic consume — ek hi UPDATE mein expiry+used check+claim, no race ──
create or replace function public.consume_password_reset_token(_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid;
begin
  update public.account_recovery_tokens
     set used_at = now()
   where token_hash = _token_hash
     and used_at is null
     and expires_at > now()
   returning user_id into v_user_id;

  if v_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_or_expired');
  end if;
  return jsonb_build_object('ok', true, 'user_id', v_user_id);
end $$;

revoke all on function public.consume_password_reset_token(text) from public, anon, authenticated;
grant execute on function public.consume_password_reset_token(text) to service_role;

-- ── 4) cleanup — purane tokens hataye (1 din se zyada purane), housekeeping ──
create or replace function public.cleanup_password_reset_tokens()
returns void
language sql
security definer
set search_path = public, extensions
as $$
  delete from public.account_recovery_tokens
   where expires_at < now() - interval '1 day';
$$;

revoke all on function public.cleanup_password_reset_tokens() from public, anon, authenticated;
grant execute on function public.cleanup_password_reset_tokens() to service_role;
