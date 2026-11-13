
-- E172 (QUI-H3, 13 Nov 2026): the mail ledger ROWS door for the browser kernel (Q-ledger-kernel).
-- Why: a verifier must not be the party being verified (RFC 6962 principle). Today the SERVER says "the chain is fine". With this door the WASM kernel in the browser
-- gets the raw rows and re-computes every SHA-256 link itself.
-- TECHNOLOGY: SQL (PostgreSQL 16, RLS stays forced on fmail_ledger, security-definer door with a fixed search_path, service_role only, keyset paging).
-- The fields come back EXACTLY as the one hash formula (fmail_ledger_hash_167, 'fmail-ledger-v1', length-prefixed fields) consumes them: meta as its stored jsonb::text, ts/seq as text,
-- so no JSON re-serialisation in Rust or the browser can change a byte. Read-only: it writes nothing.
create or replace function public.fmail_ledger_rows172(p_after bigint default 0, p_limit int default 500)
returns jsonb language sql stable security definer set search_path = pg_catalog, public, extensions as $$
  select jsonb_build_object(
    'v', 'fmail-ledger-v1',
    'zero', repeat('0', 64),
    'rows', coalesce(jsonb_agg(jsonb_build_object('seq', t.seq::text, 'ts', t.ts_ms::text, 'actor', t.actor::text, 'action', t.action, 'target', t.target, 'reason', t.reason,
                                                   'meta', t.meta::text, 'prev', t.prev_hash, 'hash', t.row_hash) order by t.seq), '[]'::jsonb),
    'more', (select count(*) > coalesce((select count(*) from (select 1 from public.fmail_ledger where seq > greatest(coalesce(p_after, 0), 0) order by seq limit least(greatest(coalesce(p_limit, 500), 1), 1000)) z), 0)
               from public.fmail_ledger where seq > greatest(coalesce(p_after, 0), 0)))
  from (select * from public.fmail_ledger where seq > greatest(coalesce(p_after, 0), 0) order by seq limit least(greatest(coalesce(p_limit, 500), 1), 1000)) t
$$;
revoke all on function public.fmail_ledger_rows172(bigint, int) from public, anon, authenticated;
grant execute on function public.fmail_ledger_rows172(bigint, int) to service_role;
