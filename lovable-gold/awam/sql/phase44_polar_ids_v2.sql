-- ANEXOMAIL — Phase 44 RETIRED (merged into Phase 43 v3)
-- Is file ko ab run karne ki zaroorat nahi.
-- Compatibility guard: agar ghalti se run ho jaye to fail nahi hogi.
do $$
begin
  if to_regclass('public.billing_price_book') is null then
    raise notice 'Phase 44 skipped: run sql/phase43_annual_billing_lock.sql v3 in Supabase SQL Editor.';
  else
    raise notice 'Phase 44 already merged: no action required.';
  end if;
end $$;
