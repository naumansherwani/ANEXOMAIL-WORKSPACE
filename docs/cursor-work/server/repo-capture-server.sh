#!/usr/bin/env bash
# A2-A4: server par jo hai magar repo mein nahi, use repo mein laata hai.
#   * SQL schema-only (koi data nahi), * 3 farq wali Brain files + Rust main.rs (live copy, alag folder),
#   * Caddy/Postfix/Dovecot/OpenDKIM + cron scripts (secret chhupa kar), * cron ki dobara-line ka saboot.
# Kuch overwrite nahi karta: sab docs/cursor-work/live-snapshot/ mein jata hai (merge main karunga).
# Secret mila to push NAHI hota. Chalana:
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/repo-capture-server.sh)
set -u
WEB="${WEB:-/opt/anexomail-web}"; BRAIN="${BRAIN:-/opt/anexomail/src}"
RS="${RS:-$(ls -d /opt/anexomail-rust/src 2>/dev/null | head -1)}"
WORK="$(mktemp -d /root/snap-XXXX)"
git -C "$WEB" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
URL=$(git -C "$WEB" remote get-url origin)
git clone -q --depth 1 "$URL" "$WORK/repo" || { echo "FAIL: clone"; exit 2; }
SNAP="$WORK/repo/docs/cursor-work/live-snapshot"; mkdir -p "$SNAP"/{sql,brain,rust,config,cron}
STAMP=$(date -u +%FT%TZ)

# secret chhupane wala filter: password/secret/token/key/pass wali value [REDACTED]
redact() { sed -E \
  -e 's/((pass(word|wd)?|secret|token|api[_-]?key|private[_-]?key|auth_token|sasl_passwd)[A-Za-z0-9_]*[[:space:]]*[=:][[:space:]]*)[^[:space:]#]+/\1[REDACTED]/Ig' \
  -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/=-]{12,}/\1[REDACTED]/g' \
  -e 's/(postgres(ql)?:\/\/[^:]+:)[^@]+@/\1[REDACTED]@/g' \
  -e 's/(eyJ[A-Za-z0-9_-]{20,})/[REDACTED-JWT]/g'; }

echo "== 1) SQL schema-only (public) — koi data nahi"
. /etc/anexomail/sync.env 2>/dev/null
if [ -n "${WORKING_URL:-}" ] && command -v pg_dump >/dev/null; then
  if pg_dump "$WORKING_URL" --schema-only --no-owner --no-privileges --schema=public -f "$WORK/schema.raw" 2>"$WORK/pgdump.err"; then
    redact < "$WORK/schema.raw" > "$SNAP/sql/schema-public.sql"; rm -f "$WORK/schema.raw"
    echo "   pg_dump OK ($(wc -l <"$SNAP/sql/schema-public.sql") lines)"
  else
    echo "   pg_dump fail ($(head -c 300 "$WORK/pgdump.err")) — psql catalog se banata hoon"
    psql "$WORKING_URL" -Atc "select pg_get_functiondef(p.oid)||';' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind in ('f','p') order by p.proname" > "$SNAP/sql/functions.sql" 2>/dev/null
    psql "$WORKING_URL" -Atc "select 'POLICY '||schemaname||'.'||tablename||' '||policyname||' '||cmd||' roles='||roles::text||' using='||coalesce(qual,'')||' check='||coalesce(with_check,'') from pg_policies where schemaname='public' order by 1" > "$SNAP/sql/policies.txt" 2>/dev/null
    psql "$WORKING_URL" -Atc "select table_name||'.'||column_name||' '||data_type||' null='||is_nullable||' def='||coalesce(column_default,'') from information_schema.columns where table_schema='public' order by table_name, ordinal_position" > "$SNAP/sql/columns.txt" 2>/dev/null
    echo "   catalog export: $(wc -l <"$SNAP/sql/functions.sql") fn lines, $(wc -l <"$SNAP/sql/policies.txt") policies, $(wc -l <"$SNAP/sql/columns.txt") columns"
  fi
else echo "   WORKING_URL ya pg_dump nahi — SQL chhoda"; fi

echo "== 2) Brain: farq wali / server-only files (live copy, redact)"
for f in anexochat.ts index.ts routes/crm.ts routes/index.ts routes/storage-client.ts server.ts start.ts; do
  [ -f "$BRAIN/$f" ] && { mkdir -p "$SNAP/brain/$(dirname "$f")"; redact < "$BRAIN/$f" > "$SNAP/brain/$f"; echo "   $f"; }; done

echo "== 3) Rust: live main.rs + anexomail-deliver.rs"
if [ -n "$RS" ]; then for f in main.rs bin/anexomail-deliver.rs anexomail-deliver.rs; do [ -f "$RS/$f" ] && { redact < "$RS/$f" > "$SNAP/rust/$(basename "$f")"; echo "   $f"; }; done; fi

echo "== 4) Config (redacted)"
for f in /etc/caddy/Caddyfile /etc/postfix/main.cf /etc/postfix/master.cf /etc/dovecot/dovecot.conf /etc/opendkim.conf; do
  [ -f "$f" ] && { redact < "$f" > "$SNAP/config/$(basename "$f")"; echo "   $f"; }; done
ls /etc/dovecot/conf.d 2>/dev/null | head -50 > "$SNAP/config/dovecot-conf.d.list.txt"

echo "== 5) Cron + scripts (redacted)"
{ echo "# crontab -l (root)"; crontab -l 2>/dev/null; for f in /etc/cron.d/*; do echo "# $f"; cat "$f" 2>/dev/null; done; } | redact > "$SNAP/cron/cron-all.txt"
for f in /usr/local/bin/anexomail-sync-domains.sh /usr/local/bin/anexomail-sync-maps.sh; do [ -f "$f" ] && { redact < "$f" > "$SNAP/cron/$(basename "$f")"; echo "   $f"; }; done
echo "   (dobara-line saboot: sync-maps wali lines kitni jagah)"; grep -c "anexomail-sync-maps.sh" "$SNAP/cron/cron-all.txt"

echo "== 6) safety: secret bacha to push NAHI"
BAD=$(grep -rEIn '(pass(word)?|secret|token|api[_-]?key)[A-Za-z0-9_]*[[:space:]]*[=:][[:space:]]*[^[:space:]\[]{8,}' "$SNAP" --exclude-dir=sql 2>/dev/null | grep -v "REDACTED" | grep -vE 'process\.env|\$\{|\$[A-Z_]+|=\s*(true|false|null|""|'"''"')' | head -8)
# SQL dump: function bodies mein 'token = ...' normal hai; sirf lambi random literal (hardcoded secret jaisi) rokte hain
BADSQL=$(grep -rEIn "'[A-Za-z0-9+/=_-]{32,}'|eyJ[A-Za-z0-9_-]{20,}|sk_(live|test)_|whsec_" "$SNAP/sql" 2>/dev/null | head -8)
BAD="$BAD$BADSQL"
if [ -n "$BAD" ]; then echo "RED: shak wali lines (sirf file:line, value nahi):"; echo "$BAD" | sed -E "s#^$SNAP/##; s/'[A-Za-z0-9+\/=_-]{32,}'/'<LONG-LITERAL>'/g; s/eyJ[A-Za-z0-9_-]{20,}/<JWT>/g; s/(sk_(live|test)_|whsec_)[A-Za-z0-9]+/\1<X>/g" | cut -c1-170 | sort -u; echo "Push roka. Folder: $SNAP"; exit 1; fi
echo "   saaf"

cd "$WORK/repo" && echo "snapshot $STAMP" > "$SNAP/README.txt" && git add docs/cursor-work/live-snapshot && git -c user.name="anexomail-server" -c user.email="server@anexomail.com" commit -qm "live-snapshot $STAMP (schema-only SQL, Brain/Rust diffs, redacted config, cron)" && git push -q origin HEAD:main && { echo "PUSHED $(git rev-parse --short HEAD)"; cd /; rm -rf "$WORK"; } || echo "PUSH fail — folder: $SNAP"
