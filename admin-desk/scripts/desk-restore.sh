#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK PARTIAL RESTORE (his 22 Nov 2026 11:39 word: backups are RESERVED; when code is needed, one command restores ONLY the files asked for, not everything).
# Usage: bash desk-restore.sh <backup-name-fragment> <path-fragment> [<path-fragment> ...]
#   no arguments = only LISTS the backups. A backup name fragment must match exactly one backup. Every path fragment must match at least one file in that backup.
#   Files are written next to the live ones with the live code untouched until you say: default = extract into /tmp/desk-restore-<time>/ and print the copy lines;
#   add RESTORE_APPLY=1 in front to write the matched files into the repo (new code of those files is replaced by the backup; all other files stay as they are).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; B="$REPO/backups/desk"
[ -d "$B" ] || { echo "FAIL: $B missing"; exit 2; }
if [ $# -lt 2 ]; then echo "BACKUPS (newest last):"; ls -1 "$B" | grep -E '^[0-9]{8}-' ; echo "usage: bash desk-restore.sh <backup-name-fragment> <path-fragment> ..."; exit 0; fi
FR="$1"; shift
M="$(ls -1 "$B" | grep -E '^[0-9]{8}-' | grep -- "$FR")"; [ "$(echo "$M" | grep -c .)" = 1 ] || { echo "FAIL: '$FR' must match exactly ONE backup, matched: $(echo "$M" | tr '\n' ' ')"; exit 2; }
T="$B/$M/code.tar.gz"; [ -f "$T" ] || { echo "FAIL: $T missing"; exit 2; }
( cd "$B/$M" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ) || echo "NOTE: SHA256SUMS of the backup did not verify with sha256sum -c (check python3 docs/cursor-work/server/code-backup.py verify)"
LIST="$(mktemp)"; W="$(mktemp)"; trap 'rm -f "$LIST" "$W"' EXIT
tar -tzf "$T" | grep -v '/$' >"$LIST"
: >"$W"
for p in "$@"; do n="$(grep -F -- "$p" "$LIST" | tee -a "$W" | wc -l)"; [ "$n" -gt 0 ] || { echo "FAIL: '$p' matches no file in $M"; exit 2; }; echo "  '$p' -> $n file(s)"; done
sort -u "$W" -o "$W"; echo "TOTAL $(wc -l <"$W") file(s) from $M"
if [ "${RESTORE_APPLY:-0}" = 1 ]; then tar -xzf "$T" -C "$REPO" -T "$W" && echo "RESTORED into $REPO (only the files above); now: desk-copy-sync.py sync, build, tests, commit"; else
  D="/tmp/desk-restore-$(date +%H%M%S)"; mkdir -p "$D"; tar -xzf "$T" -C "$D" -T "$W" && echo "EXTRACTED to $D (live code untouched). To write them into the repo run the same line with RESTORE_APPLY=1 in front."; fi
