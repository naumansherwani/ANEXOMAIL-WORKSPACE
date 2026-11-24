#!/usr/bin/env bash
# DESK SQL INSTALL (his 25 Nov 2026 03:02 PKT: the word SQL belongs in the SQL install command). SQL only: runs every Desk AD file not yet in the database (CHECK first, "already run" for the rest). It never builds Rust, the page or the kernel: that is desk-install.sh.
set -uo pipefail
echo "== DESK SQL INSTALL (SQL only, no web build)"
REPO="${REPO:-/opt/anexomail-web}"
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
bash <(git -C "$REPO" show origin/main:admin-desk/scripts/ad-auto.sh)
