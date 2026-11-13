#!/bin/bash
# BACKUP before the ledger-box hybrid (P1+P2), his order 13 Nov 19:55. Read-only for the live site: only COPIES the live SPA + Rust binary + env names to a fixed backup folder.
# usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-ui-backup.sh)
set -e
ROOT=/opt/anexomail-founder; B=/root/backups/ledger-hybrid-13nov
[ -d "$ROOT/web" ] || { echo "FAIL: $ROOT/web nahi mila"; exit 2; }
mkdir -p "$B"; rm -rf "$B/web"; cp -a "$ROOT/web" "$B/web"
BIN="$(ls "$ROOT"/target/release/anexomail-founder "$ROOT"/anexomail-founder 2>/dev/null | head -1)"; [ -n "$BIN" ] && cp -a "$BIN" "$B/anexomail-founder.bin"
git -C /opt/anexomail-web rev-parse HEAD > "$B/repo-commit.txt" 2>/dev/null || true
( cd "$B" && find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256 )
echo "BACKUP OK: $B | files $(wc -l < "$B/MANIFEST.sha256") | web index: $(grep -o 'index-[A-Za-z0-9_-]*\.js' "$B/web/index.html" | head -1) | binary: ${BIN:-none}"
echo "ROLLBACK (only if he dislikes the new look): bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-ui-rollback.sh)"
