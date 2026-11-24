#!/usr/bin/env bash
# Prints the ONE fixed install line (his 25 Nov 2026 04:53 order: copy, never retype). Usage: install-line.sh sql | web
F="$(dirname "$0")/INSTALL-LINES-FINAL.txt"
case "$1" in sql) sed -n 2p "$F";; web) sed -n 4p "$F";; *) echo "usage: install-line.sh sql|web"; exit 2;; esac
