#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK: create (or reset the password of) a REAL Desk owner, by HIS hands on the server. His 21 Nov 2026 10:35/10:41 words: login = admindesk@anexomail.com, password TYPED ON THE SERVER (never in chat, never in a file, never in argv).
# Flow: asks the password twice with no echo -> `anexomail-desk hashpw` makes the ARGON2ID hash from stdin -> psql inserts into desk.fadm_owner (+ a ledger line). The password is never printed or stored; only the hash goes to the database.
# DESK ISOLATION: touches ONLY schema desk, using the Desk's own /etc/anexomail-desk/db.env. Usage: bash desk-owner.sh   (optional env: OWNER_EMAIL, OWNER_NAME, OWNER_ROLE=owner|agent)
set -uo pipefail
ENVF=/etc/anexomail-desk/db.env; BIN=/opt/anexomail-desk/anexomail-desk
EM="$(printf '%s' "${OWNER_EMAIL:-admindesk@anexomail.com}" | tr 'A-Z' 'a-z')"; NM="${OWNER_NAME:-Admin Desk}"; RL="${OWNER_ROLE:-owner}"
[ -r "$ENVF" ] || { echo "FAIL: $ENVF missing (run ad-db-env.sh)"; exit 2; }; . "$ENVF"
[ -x "$BIN" ] || { echo "FAIL: $BIN missing (run desk-install.sh first)"; exit 2; }
"$BIN" hashpw </dev/null >/dev/null 2>&1; [ $? = 3 ] || { echo "FAIL: installed Desk binary has no hashpw (run desk-install.sh again)"; exit 2; }
[ -t 0 ] || { echo "FAIL: run this in your terminal (it asks for the password)"; exit 2; }
echo "Desk owner: $EM ($RL). Type the password (12+ characters), nothing is shown."
read -rs -p "password: " P1; echo; read -rs -p "again:    " P2; echo
[ "$P1" = "$P2" ] || { echo "FAIL: the two passwords differ, nothing changed"; exit 3; }
H="$(printf '%s\n' "$P1" | "$BIN" hashpw)" || { unset P1 P2; echo "FAIL: password refused (12 to 256 characters)"; exit 3; }; unset P1 P2
case "$H" in '$argon2id$'*) ;; *) echo "FAIL: not an ARGON2ID hash"; exit 3;; esac
env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -q -v ON_ERROR_STOP=1 -v em="$EM" -v nm="$NM" -v rl="$RL" -v h="$H" <<'S'
begin;
insert into desk.fadm_owner (email, display_name, role, pw_hash) values (:'em', :'nm', :'rl', :'h')
  on conflict (email) do update set pw_hash = excluded.pw_hash, active = true;
insert into desk.fadm_ledger (kind, detail) values ('owner.password_set', jsonb_build_object('email', :'em', 'role', :'rl'));
commit;
select email, role, active, left(pw_hash, 9) as hash_kind from desk.fadm_owner where email = :'em';
S
echo "done: password never stored, only the ARGON2ID hash. The login door itself arrives with the next Desk install."
