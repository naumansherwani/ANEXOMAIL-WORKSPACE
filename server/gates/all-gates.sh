#!/usr/bin/env bash
# ============================================================================
# FINAL AUDIT — saare gates ek command mein (sab kuch ho jane ke BAAD)
#   cd /opt/anexomail-web && git pull && bash server/gates/all-gates.sh
# Kuch deploy nahi karta — sirf sach padhta hai.
# ============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
GREEN=0; RED=0; REDLIST=""

run_gate() {
  echo
  echo "############################################################"
  echo "# $1"
  echo "############################################################"
  if bash "$DIR/$2"; then GREEN=$((GREEN+1)); else RED=$((RED+1)); REDLIST="$REDLIST $1"; fi
}

echo "--- block 1 · DATABASE (59 SQL phases) ---"
if bash /opt/anexomail-web/sql/verify.sh; then GREEN=$((GREEN+1)); else RED=$((RED+1)); REDLIST="$REDLIST DATABASE"; fi

run_gate "RUST ENGINE :3200"  rust-gate.sh
run_gate "CADDY + FRONTEND"   web-gate.sh
run_gate "MAIL 13 ADDRESSES"  mail-gate.sh
run_gate "PAYMENTS :3400"     payments-gate.sh
run_gate "ANEXOChat"          chat-gate.sh
run_gate "ANEXOVideoCall"     videocall-gate.sh

echo
echo "================= FINAL AUDIT ================="
echo "GREEN BLOCKS = $GREEN   RED BLOCKS = $RED"
[ -n "$REDLIST" ] && echo "RED:$REDLIST"
if [ "$RED" -eq 0 ]; then
  echo "POORA PROJECT GREEN — har block ne asli response diya."
else
  echo "Abhi launch-ready nahi. Upar wale RED blocks ka output bhejo."
  exit 1
fi
echo "==============================================="
