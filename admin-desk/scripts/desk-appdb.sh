#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK: the Desk's OWN database login (role desk_app). Called by desk-install.sh as its last step (his 21 Nov 2026 21:41: ONE install command does everything); nothing typed, no secret printed.
# --ensure (what the installer uses): pin the database CA, keep the existing desk_app login if the Desk connects with it; only when it does not, make a new random password.
# The service gets ONLY /etc/anexomail-desk/app.env (DESK_APP_URL for desk_app + DESK_DB_CA), root:anexomail-desk 0640; the admin URL in db.env never reaches the service.
set -uo pipefail
MODE="${1:-}"; ENVF=/etc/anexomail-desk/db.env; APP=/etc/anexomail-desk/app.env; SVC=anexomail-desk; CA=/etc/anexomail-desk/db-ca.pem
[ -r "$ENVF" ] || { echo "FAIL: $ENVF missing (ad-db-env.sh)"; exit 2; }; . "$ENVF"
command -v python3 >/dev/null && command -v openssl >/dev/null && command -v psql >/dev/null || { echo "FAIL: python3/openssl/psql needed"; exit 2; }
id $SVC >/dev/null 2>&1 || { echo "FAIL: the Desk service user is missing"; exit 2; }

# 1) the database's own CA: Supabase signs the pooler certificate with "Supabase Root 2021 CA", not a public root (his openssl 21 Nov 21:35: issuer Supabase Intermediate 2021 CA, verify 19).
#    Take the self-signed root from the chain the server sends; accept it ONLY if its subject is Supabase Inc / Supabase Root 2021 CA; print its SHA-256.
HP="$(DESK_ADMIN_URL="$DESK_DB_URL" python3 -c 'import os,urllib.parse as u;a=u.urlsplit(os.environ["DESK_ADMIN_URL"]);print(a.hostname+":"+str(a.port or 5432))')"
T="$(mktemp -d)"; openssl s_client -starttls postgres -connect "$HP" -showcerts </dev/null 2>/dev/null | awk -v d="$T" '/BEGIN CERT/{n++} n{print > (d "/c" n ".pem")}'
ROOTF=""; for f in "$T"/c*.pem; do [ -s "$f" ] || continue; S="$(openssl x509 -in "$f" -noout -subject -nameopt RFC2253 2>/dev/null)"; I="$(openssl x509 -in "$f" -noout -issuer -nameopt RFC2253 2>/dev/null)"
  [ "${S#subject=}" = "${I#issuer=}" ] && echo "$S" | grep -q "O=Supabase Inc" && echo "$S" | grep -q "CN=Supabase Root 2021 CA" && ROOTF="$f"; done
if [ -n "$ROOTF" ]; then cp "$ROOTF" "$CA"; chown root:$SVC "$CA"; chmod 640 "$CA"; echo "   database CA pinned: Supabase Root 2021 CA sha256=$(openssl x509 -in "$CA" -noout -fingerprint -sha256 | cut -d= -f2)"
else echo "   note: no Supabase Root 2021 CA in the chain from $HP (public roots only)"; rm -f "$CA"; fi; rm -rf "$T"

check() {  # restart the Desk with app.env and read its own words: "database connection ready"
  mkdir -p /etc/systemd/system/$SVC.service.d; printf '[Service]\nEnvironmentFile=%s\n' "$APP" >/etc/systemd/system/$SVC.service.d/db.conf
  systemctl daemon-reload; systemctl restart $SVC; sleep 3
  J="$(journalctl -u $SVC --since '-20s' --no-pager 2>/dev/null | grep 'desk door' | tail -1)"; echo "   $J"
  C="$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: admindesk.anexomail.com' http://127.0.0.1:4400/desk/v1/auth/me)"
  [ "$C" = 401 ] && echo "$J" | grep -q "connection ready"
}
write_app() { ( umask 037; printf 'DESK_APP_URL=%s\n' "$1" >"$APP"; [ -s "$CA" ] && printf 'DESK_DB_CA=%s\n' "$CA" >>"$APP" ); chown root:$SVC "$APP"; chmod 640 "$APP"; }

# 2) --ensure: keep a working login
if [ "$MODE" = "--ensure" ] && [ -s "$APP" ] && grep -q '^DESK_APP_URL=' "$APP"; then
  OLD="$(grep '^DESK_APP_URL=' "$APP" | head -1 | cut -d= -f2-)"; write_app "$OLD"; unset OLD
  if check; then echo "OK: database login live (desk_app), sign-in door ready"; exit 0; fi
  echo "   existing desk_app login does not connect: making a new one"
fi

# 3) new random password for desk_app
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
[ "${PIPESTATUS[1]}" = 0 ] || { echo "FAIL: ALTER ROLE desk_app (AD1 must be in the database: run the Desk SQL line)"; exit 4; }
write_app "$URL"; unset PW URL
if check; then echo "OK: database login live (desk_app), sign-in door ready"
else echo "FAIL: the Desk could not open its database connection (the desk door line above says why). The Desk itself keeps running; the sign-in door answers 503 until fixed."; exit 5; fi
