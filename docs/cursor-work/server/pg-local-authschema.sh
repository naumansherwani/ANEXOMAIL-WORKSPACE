#!/usr/bin/env bash
# pg-local-authschema.sh (20 Nov 2026, QCONNECT step 7, SQL SCHEMA-FIRST LAW). READ-ONLY, local copy only (anexo_copy), nothing is changed, no hash or token is printed.
# Prints the REAL shape of the identity tables the Rust signin will own (auth.users, auth.sessions, auth.refresh_tokens, auth.mfa_factors, auth.identities) from the copy of his managed database, so the Rust code is written on top of the real schema and not on my stub.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pg-local-authschema.sh) 2>&1 | tail -80
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
S=/var/run/postgresql; Q() { psql -X -h $S -d anexo_copy -At -F ' | ' -c "$1" 2>&1; }
for T in users sessions refresh_tokens mfa_factors identities; do echo "== auth.$T columns (name | type | null | default)"; Q "select column_name, data_type, is_nullable, coalesce(left(column_default, 40), '') from information_schema.columns where table_schema='auth' and table_name='$T' order by ordinal_position"; done
echo "== counts"; Q "select 'users', count(*) from auth.users union all select 'sessions', count(*) from auth.sessions union all select 'refresh_tokens', count(*) from auth.refresh_tokens union all select 'mfa_factors', count(*) from auth.mfa_factors"
echo "== password hash kinds (prefix only, no hash)"; Q "select left(encrypted_password, 4) as prefix, count(*) from auth.users group by 1"
echo "== founder accounts and their identity shape (no email, no hash)"; Q "select (u.encrypted_password is not null and u.encrypted_password <> '') as has_password, u.email_confirmed_at is not null as confirmed, u.banned_until is not null as banned, u.deleted_at is not null as deleted, (select count(*) from auth.mfa_factors f where f.user_id=u.id and f.status='verified') as verified_factors from auth.users u join public.founder_accounts a on a.user_id = u.id"
echo "== one session row shape (values only for non-secret columns)"; Q "select aal::text, (not_after is not null) as has_not_after, (refreshed_at is not null) as refreshed, (user_agent is not null) as has_ua from auth.sessions order by created_at desc limit 3"
echo "== refresh token rotation shape"; Q "select revoked, (parent is not null) as has_parent, count(*) from auth.refresh_tokens group by 1,2 order by 3 desc limit 6"
echo "== triggers on the auth tables"; Q "select event_object_table, trigger_name from information_schema.triggers where event_object_schema='auth' order by 1,2"
echo "== jwt settings in the copy"; Q "select name, left(setting, 30) from pg_settings where name like 'app.settings%' or name like 'request.jwt%' limit 6"
echo "DONE (read only)."
