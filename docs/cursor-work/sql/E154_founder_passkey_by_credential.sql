
-- ==============================================================================================================================
-- E154 (G-MIX 2b / S7 fix, 10 Nov 2026) - FOUNDER: the passkey sign-in door can find a key by its credential id.
-- Found live 10 Nov 20:30 PKT: the passkey tap failed with 503 because Rust read founder_passkeys.passkey directly, but E117 grants service_role
-- NO select on that column (the key body is readable only through a SQL door). This door is that door: one active credential in, user id + key body out,
-- service_role only. Unknown / revoked / malformed id = null (the caller gives the same generic 401 for all of them).
-- Needs E117 + E151 first. Idempotent: safe to run twice.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.founder_passkeys') is null then
    raise exception 'E117 pehle chalao' using errcode = '55000'; end if;
end $$;

create or replace function public.founder_passkey_by_credential(p_credential_id text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare r record;
begin
  if p_credential_id is null or p_credential_id !~ '^[A-Za-z0-9_-]{16,255}$' then return null; end if;
  select user_id, passkey into r from public.founder_passkeys where credential_id = p_credential_id and revoked_at is null limit 1;
  if not found then return null; end if;
  return jsonb_build_object('user_id', r.user_id, 'passkey', r.passkey);
end $$;

revoke all on function public.founder_passkey_by_credential(text) from public, anon, authenticated;
grant execute on function public.founder_passkey_by_credential(text) to service_role;
comment on function public.founder_passkey_by_credential(text) is 'E154: one ACTIVE passkey by credential id (user id + key body). service_role only; null for unknown, revoked or malformed ids.';
