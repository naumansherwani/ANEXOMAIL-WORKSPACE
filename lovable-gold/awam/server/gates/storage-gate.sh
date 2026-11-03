#!/usr/bin/env bash
# ============================================================================
# GATE 7 — STORAGE (Hetzner Storage Box + volumes + quota truth)
#   bash server/gates/storage-gate.sh
# ============================================================================
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

MNT=/mnt/anexomail-box

echo "=== GATE 7 · STORAGE ==="

echo "--- mount ---"
check_cmd "sshfs installed" bash -c "command -v sshfs"
check_cmd "$MNT mounted" mountpoint -q "$MNT"
check_cmd "attachments folder maujood" test -d "$MNT/attachments"
check_cmd "write test (asli file likh kar hataayi)" bash -c "t=$MNT/attachments/.gate-$$; echo ok > \$t && grep -q ok \$t && rm -f \$t"
check_cmd "mount unit enabled (reboot-safe)" bash -c "systemctl is-enabled 'mnt-anexomail\\x2dbox.mount'"
check_cmd "capacity >= 900GB" bash -c "[ \"\$(df -B1G --output=size $MNT | tail -1 | tr -d ' ')\" -ge 900 ]"

echo "--- DB truth ---"
check_sql "storage_volumes table maujood" \
  "select count(*)>0 from information_schema.tables where table_schema='public' and table_name='storage_volumes';" "t"
check_sql "storage_box volume registered" \
  "select count(*)>0 from public.storage_volumes where kind='storage_box';" "t"
check_sql "sirf ek volume accepts_new" \
  "select count(*) from public.storage_volumes where accepts_new;" "1"
check_sql "quota limits maujood" \
  "select count(*)>0 from public.file_plan_limits;" "t"

gate_result "STORAGE BOX 1TB"
