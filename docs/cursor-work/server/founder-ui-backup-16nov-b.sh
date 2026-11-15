#!/bin/bash
# SECOND BACKUP 16 Nov 01:30 (live QUI-LIVE bundle before the declutter install), his order, own folder so the first restore point is never overwritten. Read-only for the live site: COPIES the live SPA + Rust binary to /root/backups/founder-ui-16nov and also writes the source of commit e22020ab (founder-web/src) as a tar.gz with SHA-256.
# usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-ui-backup-16nov-b.sh) 2>&1 | tail -12
set -e
ROOT=/opt/anexomail-founder; B=/root/backups/founder-ui-16nov-0130-before-declutter; C=e22020ab
[ -d "$ROOT/web" ] || { echo "FAIL: $ROOT/web nahi mila"; exit 2; }
mkdir -p "$B"; cp -a "$ROOT/web" "$B/web"
BIN="$(ls "$ROOT"/target/release/anexomail-founder "$ROOT"/anexomail-founder 2>/dev/null | head -1)"; [ -n "$BIN" ] && cp -a "$BIN" "$B/anexomail-founder.bin"
git -C /opt/anexomail-web rev-parse HEAD > "$B/repo-commit.txt" 2>/dev/null || true
if git -C /opt/anexomail-web cat-file -e "$C^{commit}" 2>/dev/null; then git -C /opt/anexomail-web archive --format=tar.gz -o "$B/founder-web-src-$C.tar.gz" "$C" founder-web/src; fi
( cd "$B" && find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256 )
echo "BACKUP OK: $B | files $(wc -l < "$B/MANIFEST.sha256") | web index: $(grep -o 'index-[A-Za-z0-9_-]*\.js' "$B/web/index.html" | head -1) | source tar: $(ls "$B"/founder-web-src-*.tar.gz 2>/dev/null | head -1 || echo none)"
[ -f "$B/founder-web-src-$C.tar.gz" ] && sha256sum "$B/founder-web-src-$C.tar.gz"
echo "ROLLBACK (only if he dislikes the new mailbox): bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-ui-rollback-16nov.sh)"
