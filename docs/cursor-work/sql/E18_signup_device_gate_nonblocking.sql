-- =============================================================================
-- E18 — signup_device_gate: auto-block hata do (Phase 24A ladder ki violation thi)
-- Supabase #4 SQL Editor mein poori file paste → Run. Idempotent.
--
-- BUG (13 Oct 2026, founder ne khud live pakda — Ali Khan test signup):
--   phase63_f3a_passkey_family.sql mein likha gaya signup_device_gate() naye
--   signup ko seedha 403 de kar PRE-AUTH hi block kar deta tha jab isi "device
--   shape" (coarse signals bucket) se >=3 accounts ban chuke hon.
--
--   Yeh TEEN cheezon ka ulta tha jo is repo mein already locked/moujood hain:
--
--   1. anexochat/sql/phase24a_account_integrity.sql, Rule #2 (locked):
--        "Engine khud kisi ko block NAHI karti... Ladder: clean -> suspicious
--         -> warned (INSAAN) -> blocked (INSAAN, warning ke baad hi)."
--      signup_device_gate() ne isi rule ko seedha tod diya — engine khud,
--      bina kisi insaan ke, signup ko permanently block kar rahi thi.
--
--   2. anexochat/sql/phase19_22_device_safety_work.sql ka device_vault_register()
--      (jo isi signup flow mein ISKE BAAD already call hota hai,
--      server/routes/auth.ts line ~552) yeh kaam SAHI tareeqe se already karta
--      hai: v_users >= 3 par sirf state='suspicious' mark karta hai, signup
--      kabhi block nahi karta. signup_device_gate() isi logic ka ek DUPLICATE
--      tha — Rule 6 "No mix, no duplicate... Duplicate systems nahi" ki
--      violation.
--
--   3. Coarse "device shape" hash (sirf platform/browser/timezone/screen/
--      language) ek fingerprint nahi, ek BUCKET hai — alag-alag asli log jo
--      common OS+browser+timezone+screen-size share karte hain, wohi hash
--      share kar sakte hain. Hard-block se yeh ek real risk tha ke koi
--      unrelated naya real customer bhi day-1 pe hi "This device already has
--      accounts" dekh kar signup na kar paaye.
--
-- FIX: signup_device_gate() se sirf "too_many_accounts" wala auto-block
--      hataya gaya hai. device_banned check (insaan ka confirmed ban,
--      device_bans table) wahi rehta hai — woh locked ladder ke "blocked"
--      stage ka hi enforcement hai, naya auto-block nahi.
--
--      Signup ke baad device_vault_register() apna kaam pehle jaisa hi karta
--      rahega (suspicious-mark, non-blocking) — koi JS/Rust change zaroori
--      nahi, woh call already maujood hai.
-- =============================================================================
set search_path = public, extensions;

create or replace function public.signup_device_gate(_signals jsonb, _key text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ua       text := coalesce(_signals->>'ua', '');
  v_platform text;
  v_browser  text;
  v_tz       int;
  v_screen   text;
  v_lang     text;
  v_canon    text;
  v_hash     text;
  v_banned   boolean := false;
begin
  if to_regclass('public.device_vault') is null then
    return jsonb_build_object('ok', true, 'device_hash', null, 'skipped', true);
  end if;
  v_platform := coalesce(nullif(_signals->>'platform_class',''), public.device_signal_class(v_ua,'platform'));
  v_browser  := coalesce(nullif(_signals->>'browser_class',''), public.device_signal_class(v_ua,'browser'));
  v_tz       := coalesce((_signals->>'tz_offset_minutes')::int, 0) / 60;
  v_screen   := coalesce(_signals->>'screen_bucket', 'unknown');
  v_lang     := lower(left(coalesce(_signals->>'language','xx'), 2));
  v_canon    := concat_ws('|', v_platform, v_browser, v_tz::text, v_screen, v_lang);
  v_hash     := encode(digest(v_canon || '|' || coalesce(_key, 'no-pepper'), 'sha256'), 'hex');

  -- Sirf insaan ke confirm kiye hue ban ko yahan rokte hain (ladder ka
  -- "blocked" stage already lagu ho chuka). Koi automatic account-count
  -- threshold yahan dobara nahi — woh device_vault_register() mein
  -- non-blocking tareeqe se already handle hota hai.
  if to_regclass('public.device_bans') is not null then
    select exists (
      select 1 from public.device_bans b
       where b.device_hash = v_hash and (b.expires_at is null or b.expires_at > now())
    ) into v_banned;
  end if;
  if v_banned then
    return jsonb_build_object('ok', false, 'error', 'device_banned', 'device_hash', v_hash);
  end if;

  return jsonb_build_object('ok', true, 'device_hash', v_hash);
end $$;

revoke all on function public.signup_device_gate(jsonb, text) from public, anon, authenticated;
grant execute on function public.signup_device_gate(jsonb, text) to service_role;
