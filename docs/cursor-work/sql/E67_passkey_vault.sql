
-- E67 — PASSKEY VAULT (22 Oct 2026, founder: passkey ka sensitive data vault mein, encrypted; authenticated ka select band).
-- Dobara chalana safe. Koi DROP TABLE/COLUMN nahi; purani webauthn_credentials jaisi hai (Phase C mein Rust data encrypt karke yahan laata hai, phir purani band).
-- Rule 38/42/43. DESIGN (AUTH-MIGRATION-PLAN.md):
--   * ENVELOPE ENCRYPTION Rust mein (AES-256-GCM, key server env VAULT_KEY_<key_id>, repo/DB mein kabhi nahi): `enc` = nonce(12) || ciphertext || tag(16) ka ek blob.
--     Andar: credential_id, public key (COSE), aaguid — jo bhi sensitive. DB ko plaintext kabhi nahi milta; SQL ke paas decrypt ka raasta hi nahi.
--   * BLIND INDEX: login par credential id se row dhoondhni hoti hai — `cred_hmac` = HMAC-SHA256(key, credential_id) (32 byte); plaintext id DB mein nahi.
--   * KEY ROTATION: `key_id` har row par; naya key aane par Rust purani rows dobara encrypt kare (key_id badle) — table ya schema nahi badalta.
--   * sign_count (clone-detection) plaintext rehti hai (secret nahi); passkey_vault_bump atomic: sirf badhne par update, warna FALSE (clone ka shak).
--   * Metadata jo UI ko chahiye (device_name, transports, kab banayi/kab chali, backup flags) plaintext; secret kuch nahi.
--   * Authenticated/anon ke saare haq band. Purani `webauthn_credentials` / `account_recovery` se authenticated ka SELECT bhi wapas liya (backend service_role hai; browser seedha table nahi padhta).
--   * WAPAS LENA (haath se): drop function public.passkey_vault_find(bytea), public.passkey_vault_bump(uuid,bigint), public.passkey_vault_list(uuid); table passkey_vault data ke liye rehne do.
set lock_timeout = '3s';
set statement_timeout = '60s';

create table if not exists public.passkey_vault (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users (id) on delete cascade,
  cred_hmac       bytea       not null unique check (octet_length(cred_hmac) = 32),
  enc             bytea       not null check (octet_length(enc) between 29 and 8192),     -- 12 nonce + >=1 data + 16 tag
  key_id          smallint    not null default 1 check (key_id > 0),
  sign_count      bigint      not null default 0 check (sign_count >= 0),
  device_name     text        not null default 'This device'
                              check (char_length(btrim(device_name)) between 1 and 80 and device_name !~ E'[\\x00-\\x1f\\x7f]'),
  transports      text[]      not null default array['internal']::text[]
                              check (transports <@ array['usb', 'nfc', 'ble', 'internal', 'hybrid', 'smart-card']::text[] and cardinality(transports) <= 6),
  backup_eligible boolean     not null default false,
  backup_state    boolean     not null default false,
  created_at      timestamptz not null default now(),
  last_used_at    timestamptz,
  constraint passkey_vault_backup_ck check (backup_state is false or backup_eligible)
);
create index if not exists passkey_vault_user_idx on public.passkey_vault (user_id, created_at desc);

alter table public.passkey_vault enable row level security;
revoke all on table public.passkey_vault from public, anon, authenticated;
grant select, insert, update, delete on table public.passkey_vault to service_role;
do $$
begin
  if not exists (select 1 from pg_policy p where p.polrelid = 'public.passkey_vault'::regclass and p.polname = 'ax_service_role_only') then
    create policy ax_service_role_only on public.passkey_vault for all to service_role using (true) with check (true);
  end if;
end $$;

-- login: blind index se row (enc Rust decrypt karta hai)
create or replace function public.passkey_vault_find(p_cred_hmac bytea)
returns table (id uuid, user_id uuid, enc bytea, key_id smallint, sign_count bigint)
language sql stable set search_path = pg_catalog, public as $$
  select v.id, v.user_id, v.enc, v.key_id, v.sign_count from public.passkey_vault v where v.cred_hmac = p_cred_hmac
$$;

-- counter sirf aage badh sakta hai (0 -> 0 un authenticators ke liye jo counter nahi rakhte). FALSE = clone/replay ka shak.
create or replace function public.passkey_vault_bump(p_id uuid, p_new_count bigint)
returns boolean language plpgsql volatile set search_path = pg_catalog, public as $$
declare n integer;
begin
  if p_new_count is null or p_new_count < 0 then raise exception 'bad_counter' using errcode = '22023'; end if;
  update public.passkey_vault
     set sign_count = p_new_count, last_used_at = now()
   where id = p_id and (p_new_count > sign_count or (p_new_count = 0 and sign_count = 0));
  get diagnostics n = row_count;
  return n = 1;
end $$;

-- UI ke liye: sirf metadata (enc / cred_hmac kabhi nahi)
create or replace function public.passkey_vault_list(p_user uuid)
returns table (id uuid, device_name text, transports text[], backup_eligible boolean, backup_state boolean, created_at timestamptz, last_used_at timestamptz)
language sql stable set search_path = pg_catalog, public as $$
  select v.id, v.device_name, v.transports, v.backup_eligible, v.backup_state, v.created_at, v.last_used_at
    from public.passkey_vault v where v.user_id = p_user order by v.created_at desc
$$;

do $$
declare f text;
begin
  foreach f in array array['public.passkey_vault_find(bytea)', 'public.passkey_vault_bump(uuid,bigint)', 'public.passkey_vault_list(uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- purane tables se browser (authenticated) ka seedha SELECT wapas (service_role pe asar nahi)
do $$
declare t text;
begin
  foreach t in array array['webauthn_credentials', 'webauthn_challenges', 'account_recovery'] loop
    if to_regclass('public.' || t) is not null then
      execute format('revoke all on table public.%I from anon, authenticated', t);
    end if;
  end loop;
end $$;

comment on table public.passkey_vault is 'Passkey credentials (E67): AES-256-GCM blob (enc) + HMAC blind index (cred_hmac). Plaintext credential id / public key never stored. service_role only.';

do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public.passkey_vault'::regclass) then
    raise exception 'E67 POST-CONDITION: passkey_vault par RLS ON nahi' using errcode = 'AX067';
  end if;
  if has_table_privilege('authenticated', 'public.passkey_vault', 'select') or has_table_privilege('anon', 'public.passkey_vault', 'select') then
    raise exception 'E67 POST-CONDITION: anon/authenticated ko passkey_vault ka haq mila hua hai' using errcode = 'AX067';
  end if;
end $$;

notify pgrst, 'reload schema';
