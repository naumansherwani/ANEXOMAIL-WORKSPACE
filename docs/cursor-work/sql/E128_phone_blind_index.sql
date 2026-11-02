-- =============================================================================
-- E128 — PX2b: phone numbers get a keyed blind index (HASHING.md: guessable personal data = HMAC-SHA256 with a server key, never plain SHA-256).
-- account_phones.e164_hmac = HMAC-SHA256(HMAC(DEVICE_VAULT_KEY, "anexomail/signx/v1/phone/v1"), e164), written by the Rust door signx.phones.add (signx_core::phone_blind_index).
-- Why: abuse work can ask "does another account hold this number?" by comparing blind indexes, WITHOUT searching or logging the plain number.
-- The same number on several accounts stays ALLOWED (founder 2 Nov 09:07) — this is a plain index, NOT unique.
-- Idempotent. Needs E127. Old rows (none yet) stay NULL until the owner re-saves.
-- =============================================================================
set search_path = public, extensions;
alter table public.account_phones add column if not exists e164_hmac text;
do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.account_phones'::regclass and conname = 'account_phones_e164_hmac_chk') then
    alter table public.account_phones add constraint account_phones_e164_hmac_chk check (e164_hmac is null or e164_hmac ~ '^[0-9a-f]{64}$');
  end if;
end $$;
create index if not exists account_phones_hmac_idx on public.account_phones (e164_hmac) where e164_hmac is not null;
