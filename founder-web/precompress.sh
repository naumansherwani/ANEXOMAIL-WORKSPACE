#!/usr/bin/env bash
# Run after `vite build` (sandbox only; the server never builds). The Rust server (tower-http precompressed_gzip) sends X.js.gz when the browser accepts gzip.
set -euo pipefail
cd "$(dirname "$0")/dist"
for f in assets/*.js assets/*.css; do gzip -9 -k -f "$f"; done
ls -la assets | awk '{print $5, $9}' | grep -v woff
