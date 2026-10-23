#!/usr/bin/env bash
# ANEXOMAIL — CalDAV C1 read-only check (kuch nahi badalta): Caddy ke raaste aur seedha Rust :3200 par OPTIONS/PROPFIND ke headers.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caldav-check.sh)
set -uo pipefail
for base in "https://anexomail.com" "http://127.0.0.1:3200"; do
  echo "=========== $base"
  for m in OPTIONS PROPFIND; do
    echo "--- $m /dav/"
    curl -s -m 10 -i -X "$m" -H 'Depth: 0' "$base/dav/" | tr -d '\r' | head -14 | cut -c1-160
  done
done
echo "=========== pm2 / route"
grep -c 'dav_glue::handle' /opt/anexomail-rust/src/main.rs | sed 's/^/main.rs mein dav_glue::handle jagah: /'
grep -n '"/dav' /opt/anexomail-rust/src/main.rs | head -5
grep -c '^CALDAV_PEPPER=' /opt/anexomail-rust/.env | sed 's/^/.env mein CALDAV_PEPPER lines: /'
