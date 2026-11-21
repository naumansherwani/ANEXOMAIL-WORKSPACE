#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK: give the Desk its OWN database login (role desk_app), by HIS run, nothing typed, no secret printed (AD1b step; his 21 Nov 2026 login order).
# 1) makes desk_app LOGIN with a random password (openssl, 48 hex chars)  2) writes /etc/anexomail-desk/app.env = DESK_APP_URL for desk_app ONLY (root:anexomail-desk 0640; the admin URL in db.env is never given to the service)
# 3) systemd drop-in EnvironmentFile=app.env, restart the Desk, check /desk/v1/auth/me answers 401 (door alive, database reachable). Rerun = new password. Rollback line printed if the check fails.
set -uo pipefail
ENVF=/etc/anexomail-desk/db.env; APP=/etc/anexomail-desk/app.env; SVC=anexomail-desk
[ -r "$ENVF" ] || { echo "FAIL: $ENVF missing (ad-db-env.sh)"; exit 2; }; . "$ENVF"
command -v python3 >/dev/null && command -v openssl >/dev/null && command -v psql >/dev/null || { echo "FAIL: python3/openssl/psql needed"; exit 2; }
PW="$(openssl rand -hex 24)"
URL="$(DESK_ADMIN_URL="$DESK_DB_URL" DESK_PW="$PW" python3 - <<'P'
import os,urllib.parse as u
a=u.urlsplit(os.environ["DESK_ADMIN_URL"]); user=u.unquote(a.username or "postgres")
nu="desk_app"+("."+user.split(".",1)[1] if "." in user else "")      # Supabase pooler wants role.projectref
host=a.hostname+(":"+str(a.port) if a.port else "")
q=dict(u.parse_qsl(a.query)); q.setdefault("sslmode","require")
print(u.urlunsplit((a.scheme,nu+":"+os.environ["DESK_PW"]+"@"+host,a.path,u.urlencode(q),"")))
P
)" || { echo "FAIL: could not build the desk_app url"; exit 3; }
# the statement goes through stdin: psql only expands :'pw' there (never with -c)
printf "alter role desk_app login password :'pw';\n" | env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -q -v ON_ERROR_STOP=1 -v pw="$PW" 2>&1 | tail -3
[ "${PIPESTATUS[1]}" = 0 ] || { echo "FAIL: ALTER ROLE desk_app (AD1 must be in the database)"; exit 4; }
id $SVC >/dev/null 2>&1 || { echo "FAIL: run desk-install.sh first"; exit 2; }
# The database's own CA: Supabase signs its pooler certificate with "Supabase Root 2021 CA", which is not a public root (his openssl 21 Nov 21:35: issuer Supabase Intermediate 2021 CA, verify 19).
# Take the self-signed root from the chain the server itself sends, accept it ONLY if its subject is Supabase Inc / Supabase Root 2021 CA, store it root-owned and print its SHA-256 fingerprint.
CA=/etc/anexomail-desk/db-ca.pem; HP="$(DESK_ADMIN_URL="$DESK_DB_URL" python3 -c 'import os,urllib.parse as u;a=u.urlsplit(os.environ["DESK_ADMIN_URL"]);print(a.hostname+":"+str(a.port or 5432))')"
T="$(mktemp -d)"; openssl s_client -starttls postgres -connect "$HP" -showcerts </dev/null 2>/dev/null | awk -v d="$T" '/BEGIN CERT/{n++} n{print > (d "/c" n ".pem")} /END CERT/{}' 
ROOTF=""; for f in "$T"/c*.pem; do [ -s "$f" ] || continue; S="$(openssl x509 -in "$f" -noout -subject -nameopt RFC2253 2>/dev/null)"; I="$(openssl x509 -in "$f" -noout -issuer -nameopt RFC2253 2>/dev/null)"
  [ "${S#subject=}" = "${I#issuer=}" ] && echo "$S" | grep -q "O=Supabase Inc" && echo "$S" | grep -q "CN=Supabase Root 2021 CA" && ROOTF="$f"; done
if [ -n "$ROOTF" ]; then cp "$ROOTF" "$CA"; chown root:$SVC "$CA"; chmod 640 "$CA"; echo "database CA pinned: $(openssl x509 -in "$CA" -noout -subject -nameopt RFC2253) sha256=$(openssl x509 -in "$CA" -noout -fingerprint -sha256 | cut -d= -f2)"
else echo "note: no Supabase Root 2021 CA in the chain from $HP (public roots only)"; CA=""; fi; rm -rf "$T"
( umask 037; printf 'DESK_APP_URL=%s\n' "$URL" >"$APP"; [ -n "$CA" ] && printf 'DESK_DB_CA=%s\n' "$CA" >>"$APP" ); chown root:$SVC "$APP"; chmod 640 "$APP"; unset PW URL
mkdir -p /etc/systemd/system/$SVC.service.d; printf '[Service]\nEnvironmentFile=%s\n' "$APP" >/etc/systemd/system/$SVC.service.d/db.conf
systemctl daemon-reload; systemctl restart $SVC; sleep 3
C="$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: admindesk.anexomail.com' http://127.0.0.1:4400/desk/v1/auth/me)"
J="$(journalctl -u $SVC -n 15 --no-pager 2>/dev/null | grep -E 'desk door' | tail -2)"
echo "me without a session: $C (want 401)"; echo "$J"
R=0; echo "$J" | grep -q "connection ready" && R=1
[ "$C" = 401 ] && [ "$R" = 1 ] && echo "OK: the Desk has its own database login; the sign-in door is live" || { echo "FAIL: the Desk could not open its database connection (see the desk door line above). rollback = rm /etc/systemd/system/$SVC.service.d/db.conf && systemctl daemon-reload && systemctl restart $SVC"; exit 5; }
